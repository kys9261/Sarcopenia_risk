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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStepIndicator(),
              const SizedBox(height: 12),
              if (_step == 0) _buildStep1(),
              if (_step == 1) _buildStep2(),
              if (_step == 2) _buildStep3(),
              const SizedBox(height: 20),
              if (_error != null) _buildErrorCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('단계 ${_step + 1} / 3', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
        Text('${_formValues.values.where((v) => v.trim().isNotEmpty).length}/${_controllers.length}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
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
        ...BiaField.fields.where((f) => f.key != 'HE_ht').map((field) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(field.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
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
            ),
          );
        }).toList(),
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
                      Text(
                        '$riskScore%',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '위험도: ${_result!.riskClass}',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
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
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      riskLevel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
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
