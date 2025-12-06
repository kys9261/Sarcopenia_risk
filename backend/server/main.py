from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List, Dict, Literal
import numpy as np
from catboost import CatBoostClassifier, Pool
from sqlalchemy import create_engine, Column, Integer, String, Float, DateTime, func
from sqlalchemy.orm import declarative_base, sessionmaker
from sqlalchemy.exc import SQLAlchemyError
import math, os, logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+psycopg2://sarcopenia_user:sarcopenia_pass@db:5432/sarcopenia_db",
)

engine = create_engine(DATABASE_URL, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)
Base = declarative_base()

APP_VERSION = "v1"

FEATURE_ORDER = ["HE_ht","BIA_FFM","BIA_LRA","BIA_LLA","BIA_LRL","BIA_LLL","BIA_TBW","BIA_ICW","BIA_ECW","BIA_WBPA50"]
CATEGORICAL_FEATURES: List[int] = []

class PredictionRecord(Base):
    __tablename__ = "prediction_records"

    id = Column(Integer, primary_key=True, index=True)
    sex = Column(String(10), nullable=False)
    HE_ht = Column(Float, nullable=False)
    BIA_FFM = Column(Float, nullable=False)
    BIA_LRA = Column(Float, nullable=False)
    BIA_LLA = Column(Float, nullable=False)
    BIA_LRL = Column(Float, nullable=False)
    BIA_LLL = Column(Float, nullable=False)
    BIA_TBW = Column(Float, nullable=False)
    BIA_ICW = Column(Float, nullable=False)
    BIA_ECW = Column(Float, nullable=False)
    BIA_WBPA50 = Column(Float, nullable=False)
    risk_score = Column(Float, nullable=False)
    risk_class = Column(String(20), nullable=False)
    model_version = Column(String(20), nullable=False)
    used_model = Column(String(50), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

class BIAInput(BaseModel):
    sex: Literal["male", "female"]
    HE_ht: float; BIA_FFM: float; BIA_LRA: float; BIA_LLA: float; BIA_LRL: float; BIA_LLL: float; BIA_TBW: float; BIA_ICW: float; BIA_ECW: float; BIA_WBPA50: float

class Prediction(BaseModel):
    id: int
    risk_score: float
    risk_class: str
    model_version: str
    used_model: str
    explanations: Optional[List[Dict]] = None

class PredictionRecordResponse(BaseModel):
    id: int
    sex: str
    HE_ht: float; BIA_FFM: float; BIA_LRA: float; BIA_LLA: float; BIA_LRL: float; BIA_LLL: float; BIA_TBW: float; BIA_ICW: float; BIA_ECW: float; BIA_WBPA50: float
    risk_score: float; risk_class: str; model_version: str; used_model: str
    created_at: Optional[str] = None

app = FastAPI(title="Sarcopenia Risk API (10 features)", version=APP_VERSION)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])

model_male = CatBoostClassifier(); model_female = CatBoostClassifier()
model_male.load_model(os.getenv("MODEL_M_PATH", "artifacts/model_male_10.cbm"))
model_female.load_model(os.getenv("MODEL_F_PATH", "artifacts/model_female_10.cbm"))

@app.on_event("startup")
def on_startup():
    try:
        Base.metadata.create_all(bind=engine)
        logger.info("✅ Database initialized successfully")
    except Exception as e:
        logger.error(f"❌ Failed to initialize database: {str(e)}")

def choose_model(sex:str):
    if sex=='male': return model_male
    if sex=='female': return model_female
    raise HTTPException(status_code=400, detail="Invalid sex")

@app.get('/api/health')
def health(): return {'status':'ok','version':APP_VERSION,'features':FEATURE_ORDER}

@app.post('/api/predict', response_model=Prediction)
def predict(bia:BIAInput):
    for f in FEATURE_ORDER:
        v = getattr(bia, f)
        if v is None or (isinstance(v, float) and (math.isnan(v) or math.isinf(v))):
            raise HTTPException(status_code=422, detail=f'Invalid value for {f}')
    row=[getattr(bia,f) for f in FEATURE_ORDER]
    pool=Pool([row], feature_names=FEATURE_ORDER, cat_features=CATEGORICAL_FEATURES)
    model=choose_model(bia.sex)
    proba=float(model.predict_proba(pool)[0][1])
    risk='낮음' if proba<0.33 else ('중간' if proba<0.66 else '높음')
    explanations=None
    try:
        shap=model.get_feature_importance(data=pool, type='ShapValues')[0][:-1]
        idx=np.argsort(np.abs(shap))[-5:][::-1]
        explanations=[{'feature':FEATURE_ORDER[i],'contribution':float(shap[i])} for i in idx]
    except Exception: pass
    used_model=f'model_{bia.sex}_10'
    session=SessionLocal()
    try:
        record=PredictionRecord(
            sex=bia.sex,
            HE_ht=bia.HE_ht,
            BIA_FFM=bia.BIA_FFM,
            BIA_LRA=bia.BIA_LRA,
            BIA_LLA=bia.BIA_LLA,
            BIA_LRL=bia.BIA_LRL,
            BIA_LLL=bia.BIA_LLL,
            BIA_TBW=bia.BIA_TBW,
            BIA_ICW=bia.BIA_ICW,
            BIA_ECW=bia.BIA_ECW,
            BIA_WBPA50=bia.BIA_WBPA50,
            risk_score=proba,
            risk_class=risk,
            model_version=APP_VERSION,
            used_model=used_model,
        )
        session.add(record)
        session.commit()
        logger.info(f"✅ Prediction saved successfully - ID: {record.id}, Sex: {bia.sex}")
        session.refresh(record)
        return {'id':record.id, 'risk_score':proba,'risk_class':risk,'model_version':APP_VERSION,'used_model':used_model,'explanations':explanations}
    except SQLAlchemyError as e:
        session.rollback()
        logger.error(f"❌ Database error while saving prediction: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to save prediction result - Database error")
    except Exception as e:
        session.rollback()
        logger.error(f"❌ Unexpected error while saving prediction: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to save prediction result - {str(e)}")
    finally:
        session.close()

@app.get('/api/predictions/{prediction_id}', response_model=PredictionRecordResponse)
def get_prediction(prediction_id:int):
    session=SessionLocal()
    try:
        record=session.get(PredictionRecord, prediction_id)
        if record is None:
            logger.warning(f"⚠️ Prediction not found - ID: {prediction_id}")
            raise HTTPException(status_code=404, detail='Prediction not found')
        logger.info(f"✅ Prediction retrieved successfully - ID: {prediction_id}")
        created_at=record.created_at.isoformat() if record.created_at else None
        return {
            'id':record.id,
            'sex':record.sex,
            'HE_ht':record.HE_ht,
            'BIA_FFM':record.BIA_FFM,
            'BIA_LRA':record.BIA_LRA,
            'BIA_LLA':record.BIA_LLA,
            'BIA_LRL':record.BIA_LRL,
            'BIA_LLL':record.BIA_LLL,
            'BIA_TBW':record.BIA_TBW,
            'BIA_ICW':record.BIA_ICW,
            'BIA_ECW':record.BIA_ECW,
            'BIA_WBPA50':record.BIA_WBPA50,
            'risk_score':record.risk_score,
            'risk_class':record.risk_class,
            'model_version':record.model_version,
            'used_model':record.used_model,
            'created_at':created_at,
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Error retrieving prediction - ID: {prediction_id}, Error: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to retrieve prediction")
    finally:
        session.close()
