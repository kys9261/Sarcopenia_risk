import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/bia_models.dart';
import '../services/api_service.dart';

class BiaRiskScreen extends StatefulWidget {
  final String gender;

  const BiaRiskScreen({super.key, required this.gender});

  @override
  State<BiaRiskScreen> createState() => _BiaRiskScreenState();
}

class _BiaRiskScreenState extends State<BiaRiskScreen> {
  final _apiService = ApiService();
  final _formValues = <String, String>{};
  final _focusNode = FocusNode();
  late String _gender;

  final Map<String, TextEditingController> _controllers = {};
  bool _loading = false;
  String? _error;
  PredictionResult? _result;

  int _step = 0; // 0: 기본정보, 1: BIA 입력, 2: 결과

  // 추가 필드: 나이, 체중
  static const List<Map<String, String>> extraFields = [
    {'key': 'age', 'label': '나이'},
    {'key': 'weight', 'label': '체중 (kg)'},
  ];

  // 각 필드 도움말 텍스트 (샘플 문장)
  final Map<String, String> _helpTexts = {
    'BIA_FFM': '예: 체지방을 제외한 제지방량(kg)입니다. 측정 장비의 지침을 따르세요.',
    'BIA_LRA': '예: 오른쪽 상지의 근육량(kg)입니다. 측정 시 팔 위치를 고정하세요.',
    'BIA_LLA': '예: 왼쪽 상지의 근육량(kg)입니다. 동일 조건에서 측정하세요.',
    'BIA_LRL': '예: 오른쪽 하지의 근육량(kg)입니다. 체중 분산을 일정하게 유지하세요.',
    'BIA_LLL': '예: 왼쪽 하지의 근육량(kg)입니다. 양쪽 비교를 위해 동일 자세로 측정하세요.',
    'BIA_TBW': '예: 총 체수분(%) 또는 (L) 단위입니다. 수분 상태에 따라 값이 변할 수 있습니다.',
    'BIA_ICW': '예: 세포내 수분량(ICW)입니다. 측정 전 충분한 휴식이 필요합니다.',
    'BIA_ECW': '예: 세포외 수분량(ECW)입니다. 부종이 있는 경우 값이 달라질 수 있습니다.',
    'BIA_WBPA50': '예: 전신 저주파 임피던스 값입니다. 장치와 프로토콜을 확인하세요.',
  };

  @override
  void initState() {
    super.initState();
    _gender = widget.gender;

    // 기본 및 추가 필드 초기화
    for (var field in extraFields) {
      _formValues[field['key']!] = '';
      final c = TextEditingController();
      c.addListener(() {
        _formValues[field['key']!] = c.text;
        setState(() {});
      });
      _controllers[field['key']!] = c;
    }

    for (var field in BiaField.fields) {
      _formValues[field.key] = '';
      final c = TextEditingController();
      c.addListener(() {
        _formValues[field.key] = c.text;
        setState(() {});
      });
      _controllers[field.key] = c;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    _focusNode.dispose();
    super.dispose();
  }

  // 유틸
  bool _step1Filled() {
    return (_formValues['age']?.trim().isNotEmpty ?? false) &&
        (_formValues['weight']?.trim().isNotEmpty ?? false) &&
        (_formValues['HE_ht']?.trim().isNotEmpty ?? false);
  }

  bool _step2Filled() {
    return BiaField.fields.where((f) => f.key != 'HE_ht').every((f) => _formValues[f.key]?.trim().isNotEmpty ?? false);
  }

  bool get _allFilled => _step1Filled() && _step2Filled();

  Future<void> _submit() async {
    if (!_allFilled) {
      setState(() => _error = '모든 값을 입력해주세요.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final input = BiaInput(
        sex: _gender,
        heHt: double.parse(_formValues['HE_ht']!),
        biaFfm: double.parse(_formValues['BIA_FFM']!),
        biaLra: double.parse(_formValues['BIA_LRA']!),
        biaLla: double.parse(_formValues['BIA_LLA']!),
        biaLrl: double.parse(_formValues['BIA_LRL']!),
        biaLll: double.parse(_formValues['BIA_LLL']!),
        biaTbw: double.parse(_formValues['BIA_TBW']!),
        biaIcw: double.parse(_formValues['BIA_ICW']!),
        biaEcw: double.parse(_formValues['BIA_ECW']!),
        biaWbpa50: double.parse(_formValues['BIA_WBPA50']!),
      );

      final result = await _apiService.predict(input);

      setState(() {
        _result = result;
        _loading = false;
        _step = 2; // 결과 화면으로 이동
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('근감소증 위험 평가'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStepIndicator(),
              const SizedBox(height: 12),
              // 콘텐츠 영역은 남은 화면을 차지해서 스크롤이 발생하지 않도록 함
              Expanded(
                child: Builder(builder: (context) {
                  if (_step == 0) return _buildStep1();
                  if (_step == 1) return _buildStep2();
                  return _buildStep3();
                }),
              ),
              const SizedBox(height: 20),
              if (_error != null) _buildErrorCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    // 기본 정보(나이, 체중, 신장)
    final basicKeys = ['age', 'weight', 'HE_ht'];
    final basicFilled = basicKeys.where((k) => _formValues[k]?.trim().isNotEmpty ?? false).length;
    final basicTotal = basicKeys.length;
    final basicProgress = basicTotal == 0 ? 0.0 : (basicFilled / basicTotal);

    // 신체 정보 (HE_ht 제외한 BiaField.fields)
    final physicalKeys = BiaField.fields.where((f) => f.key != 'HE_ht').map((f) => f.key).toList();
    final physicalFilled = physicalKeys.where((k) => _formValues[k]?.trim().isNotEmpty ?? false).length;
    final physicalTotal = physicalKeys.isEmpty ? 1 : physicalKeys.length;
    final physicalProgress = physicalTotal == 0 ? 0.0 : (physicalFilled / physicalTotal);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('단계 ${_step + 1} / 3', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          ],
        ),
        const SizedBox(height: 8),

        // 기본 정보 진행도
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('기본 정보 입력', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            Text('$basicFilled/$basicTotal', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: basicProgress.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(const Color(0xFF6366F1)),
          ),
        ),
        const SizedBox(height: 12),

        // 신체 정보 진행도
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('신체 정보 입력', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            Text('$physicalFilled/$physicalTotal', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: physicalProgress.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(const Color(0xFF6366F1)),
          ),
        ),
      ],
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGenderSelector(),
        const SizedBox(height: 12),
        Text('기본 정보 입력', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
        const SizedBox(height: 12),
        _buildFieldRow(label: '나이', keyName: 'age', hint: '숫자만 입력', isInteger: true),
        const SizedBox(height: 12),
        _buildFieldRow(label: '체중 (kg)', keyName: 'weight', hint: '숫자 입력'),
        const SizedBox(height: 12),
        _buildFieldRow(label: '신장 (cm)', keyName: 'HE_ht', hint: '숫자 입력'),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _step1Filled() ? () => setState(() => _step = 1) : null,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                child: const Text('다음', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('신체 정보 입력', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
        const SizedBox(height: 12),
        // 2열로 변경하고 부모 Expanded의 가로/세로 제약을 이용해 항목들이 화면에 딱 맞게 채워지도록 함
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            final physicalFields = BiaField.fields.where((f) => f.key != 'HE_ht').toList();
            final columns = 2;
            final spacing = 12.0;
            final rows = (physicalFields.length / columns).ceil();
            final itemWidth = (constraints.maxWidth - (columns - 1) * spacing) / columns;
            final itemHeight = (constraints.maxHeight - (rows - 1) * spacing) / rows;
            final childAspectRatio = itemWidth / itemHeight;

            return GridView.count(
              // 부모 Expanded에서 크기를 결정하므로 스크롤 비활성화
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: columns,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              childAspectRatio: childAspectRatio,
              children: physicalFields.map((field) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(field.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                        const SizedBox(width: 6),
                        // 원형 물음표 버튼
                        GestureDetector(
                          onTap: () {
                            showDialog<void>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(field.label),
                                content: Text(_helpTexts[field.key] ?? '샘플 설명입니다. 필요에 따라 수정해주세요.'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('닫기')),
                                ],
                              ),
                            );
                          },
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey.shade200,
                            ),
                            child: const Center(
                              child: Icon(Icons.help_outline, size: 16, color: Colors.black54),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _controllers[field.key],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                      decoration: InputDecoration(
                        hintText: '숫자 입력',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ],
                );
              }).toList(),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step = 0),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('이전', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _step2Filled() && !_loading ? _submit : null,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                child: Text(_loading ? '계산 중...' : '위험 점수 계산', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep3() {
    if (_result == null) {
      return Column(
        children: [
          const SizedBox(height: 20),
          Text('결과가 없습니다', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => setState(() => _step = 0),
            child: const Text('처음으로'),
          ),
        ],
      );
    }

    final riskScore = (_result!.riskScore * 100).round();
    final riskLevel = _result!.riskScore >= 0.66
      ? '높음'
      : _result!.riskScore >= 0.33
        ? '중간'
        : '낮음';

    final Color riskColor = _result!.riskScore >= 0.66
      ? Colors.red
      : _result!.riskScore >= 0.33
        ? Colors.black
        : const Color(0xFF3AA5EB);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('예측 결과', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFF3F4F6)),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade100,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: riskScore.toDouble()),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Text(
                            '${value.round()}%',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w600,
                              color: riskColor,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Text(
                            '위험도: ',
                            style: TextStyle(fontSize: 14, color: Colors.black),
                          ),
                          Text(
                            '${_result!.riskClass}',
                            style: TextStyle(fontSize: 14, color: riskColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '사용 모델: ${_result!.usedModel}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: riskColor),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      riskLevel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: riskColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_result!.explanations != null) ...[
                const Text('설명', style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 8),
                ..._result!.explanations!.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('${e.feature}: ${e.contribution.toStringAsFixed(3)}', style: const TextStyle(fontSize: 12)),
                    )),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _step = 1),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('수정'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                      child: const Text('완료'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFieldRow({required String label, required String keyName, String? hint, bool isInteger = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _controllers[keyName],
          keyboardType: isInteger ? TextInputType.number : const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: isInteger
              ? <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly]
              : <TextInputFormatter>[FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
          decoration: InputDecoration(
            hintText: hint ?? '숫자 입력',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorCard() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _error!,
        style: TextStyle(fontSize: 14, color: Colors.red.shade700),
      ),
    );
  }

  // 성별 선택 위젯
  Widget _buildGenderSelector() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => setState(() => _gender = 'male'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _gender == 'male' ? const Color(0xFF6366F1) : Colors.white,
              foregroundColor: _gender == 'male' ? Colors.white : Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              elevation: 0,
            ),
            child: const Text('남성', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () => setState(() => _gender = 'female'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _gender == 'female' ? const Color(0xFF6366F1) : Colors.white,
              foregroundColor: _gender == 'female' ? Colors.white : Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              elevation: 0,
            ),
            child: const Text('여성', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}
