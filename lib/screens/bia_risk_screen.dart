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
  // 선택된 성별 상태 (화면에서 변경 가능)
  late String _gender;

  // 모든 입력 필드를 한 화면에서 관리
  final Map<String, TextEditingController> _controllers = {};
  bool _loading = false;
  String? _error;
  PredictionResult? _result;

  @override
  void initState() {
    super.initState();
    _gender = widget.gender; // 초기값 설정
    // 모든 필드 초기화 및 컨트롤러 생성
    for (var field in BiaField.fields) {
      _formValues[field.key] = '';
      final c = TextEditingController();
      c.addListener(() {
        _formValues[field.key] = c.text;
        setState(() {});
      });
      _controllers[field.key] = c;
    }
    // 포커스(필요시)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    // 컨트롤러 해제
    for (var c in _controllers.values) {
      c.dispose();
    }
    // _focusNode는 한 번만 dispose
    _focusNode.dispose();
    super.dispose();
  }

  int get _totalSteps => BiaField.fields.length;
  int get _filledCount => _formValues.values.where((v) => v.trim().isNotEmpty).length;
  double get _progress => _filledCount / _totalSteps;
  
  bool get _allFilled => _formValues.values.every((v) => v.trim().isNotEmpty);

  Future<void> _submit() async {
    if (!_allFilled) return;

    // 모든 필드 검증
    for (var field in BiaField.fields) {
      if (_formValues[field.key]?.trim().isEmpty ?? true) {
        setState(() {
          _error = '모든 값을 입력해주세요.';
        });
        return;
      }
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 화면 상단에 성별 선택 표시
            _buildGenderSelector(),
            const SizedBox(height: 12),
            _buildProgressSection(),
            const SizedBox(height: 16),
            _buildInputCard(),
            if (_error != null) ...[
              const SizedBox(height: 16),
              _buildErrorCard(),
            ],
            if (_result != null) ...[
              const SizedBox(height: 16),
              _buildResultCard(),
            ],
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '검사 정보 입력',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            Text(
              '$_filledCount/$_totalSteps',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: _progress,
            minHeight: 8,
            backgroundColor: Colors.grey.shade100,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
          ),
        ),
      ],
    );
  }

  Widget _buildInputCard() {
    return Container(
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
          Text(
            '모든 값을 입력하세요',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 12),
          ...BiaField.fields.map((field) {
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_allFilled && !_loading) ? _submit : null,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
              child: Text(_loading ? '계산 중...' : '위험 점수 계산', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
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

  Widget _buildResultCard() {
    final riskScore = (_result!.riskScore * 100).round();
    final riskLevel = _result!.riskScore >= 0.66
        ? '높음'
        : _result!.riskScore >= 0.33
            ? '중간'
            : '낮음';

    return Container(
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
          Text(
            '예측 결과',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
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
        ],
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
