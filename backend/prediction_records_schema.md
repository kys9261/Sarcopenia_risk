# `prediction_records` 테이블 스키마

| 컬럼 | 타입 | 제약 조건 | 설명 |
| --- | --- | --- | --- |
| `id` | `INTEGER` | 기본 키, 자동 증가, `NOT NULL` | 각 예측 요청 식별자 |
| `sex` *(입력)* | `VARCHAR(10)` | `NOT NULL` | 입력 받은 성별 (`male`/`female`) |
| `HE_ht` *(입력)* | `FLOAT` | `NOT NULL` | 키(Height) 지표 |
| `BIA_FFM` *(입력)* | `FLOAT` | `NOT NULL` | 제지방량(Fat Free Mass) |
| `BIA_LRA` *(입력)* | `FLOAT` | `NOT NULL` | 오른팔 임피던스 |
| `BIA_LLA` *(입력)* | `FLOAT` | `NOT NULL` | 왼팔 임피던스 |
| `BIA_LRL` *(입력)* | `FLOAT` | `NOT NULL` | 오른다리 임피던스 |
| `BIA_LLL` *(입력)* | `FLOAT` | `NOT NULL` | 왼다리 임피던스 |
| `BIA_TBW` *(입력)* | `FLOAT` | `NOT NULL` | 체수분량(Total Body Water) |
| `BIA_ICW` *(입력)* | `FLOAT` | `NOT NULL` | 세포내 수분량(Intracellular Water) |
| `BIA_ECW` *(입력)* | `FLOAT` | `NOT NULL` | 세포외 수분량(Extracellular Water) |
| `BIA_WBPA50` *(입력)* | `FLOAT` | `NOT NULL` | 전신 위상각(50kHz) |
| `risk_score` *(출력)* | `FLOAT` | `NOT NULL` | CatBoost 추론 확률 (0~1) |
| `risk_class` *(출력)* | `VARCHAR(20)` | `NOT NULL` | `낮음/중간/높음` 위험 등급 |
| `model_version` *(출력)* | `VARCHAR(20)` | `NOT NULL` | 백엔드 앱 버전 (`v1`) |
| `used_model` *(출력)* | `VARCHAR(50)` | `NOT NULL` | 사용한 CatBoost 모델명 (예: `model_male_10`) |
| `created_at` | `TIMESTAMP WITH TIME ZONE` | 기본값 `NOW()`, `NOT NULL` | 레코드 생성 시각 |

> 생성 위치: `backend/server/main.py` 의 `PredictionRecord` SQLAlchemy 모델 정의를 그대로 반영했습니다.
