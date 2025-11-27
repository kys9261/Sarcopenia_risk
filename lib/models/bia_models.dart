class BiaInput {
  final String sex;
  final double heHt;
  final double biaFfm;
  final double biaLra;
  final double biaLla;
  final double biaLrl;
  final double biaLll;
  final double biaTbw;
  final double biaIcw;
  final double biaEcw;
  final double biaWbpa50;

  BiaInput({
    required this.sex,
    required this.heHt,
    required this.biaFfm,
    required this.biaLra,
    required this.biaLla,
    required this.biaLrl,
    required this.biaLll,
    required this.biaTbw,
    required this.biaIcw,
    required this.biaEcw,
    required this.biaWbpa50,
  });

  Map<String, dynamic> toJson() {
    return {
      'sex': sex,
      'HE_ht': heHt,
      'BIA_FFM': biaFfm,
      'BIA_LRA': biaLra,
      'BIA_LLA': biaLla,
      'BIA_LRL': biaLrl,
      'BIA_LLL': biaLll,
      'BIA_TBW': biaTbw,
      'BIA_ICW': biaIcw,
      'BIA_ECW': biaEcw,
      'BIA_WBPA50': biaWbpa50,
    };
  }
}

class PredictionResult {
  final double riskScore;
  final String riskClass;
  final String modelVersion;
  final String usedModel;
  final List<Explanation>? explanations;

  PredictionResult({
    required this.riskScore,
    required this.riskClass,
    required this.modelVersion,
    required this.usedModel,
    this.explanations,
  });

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    List<Explanation>? expList;
    if (json['explanations'] != null) {
      expList = (json['explanations'] as List)
          .map((e) => Explanation.fromJson(e))
          .toList();
    }

    return PredictionResult(
      riskScore: (json['risk_score'] as num).toDouble(),
      riskClass: json['risk_class'] as String,
      modelVersion: json['model_version'] as String,
      usedModel: json['used_model'] as String,
      explanations: expList,
    );
  }
}

class Explanation {
  final String feature;
  final double contribution;

  Explanation({
    required this.feature,
    required this.contribution,
  });

  factory Explanation.fromJson(Map<String, dynamic> json) {
    return Explanation(
      feature: json['feature'] as String,
      contribution: (json['contribution'] as num).toDouble(),
    );
  }
}

// 필드 정의
class BiaField {
  final String key;
  final String label;

  const BiaField(this.key, this.label);

  static const List<BiaField> fields = [
    BiaField('HE_ht', '신장 (HE_ht)'),
    BiaField('BIA_FFM', '제지방량 (BIA_FFM)'),
    BiaField('BIA_LRA', '우측 팔 근육량 (BIA_LRA)'),
    BiaField('BIA_LLA', '좌측 팔 근육량 (BIA_LLA)'),
    BiaField('BIA_LRL', '우측 다리 근육량 (BIA_LRL)'),
    BiaField('BIA_LLL', '좌측 다리 근육량 (BIA_LLL)'),
    BiaField('BIA_TBW', '체수분량 (BIA_TBW)'),
    BiaField('BIA_ICW', '세포내수분 (BIA_ICW)'),
    BiaField('BIA_ECW', '세포외수분 (BIA_ECW)'),
    BiaField('BIA_WBPA50', '전신 위상각 (BIA_WBPA50)'),
  ];
}
