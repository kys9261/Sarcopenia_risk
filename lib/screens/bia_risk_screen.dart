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
  
  int _currentStep = 0;
  bool _loading = false;
  String? _error;
  PredictionResult? _result;

  @override
  void initState() {
    super.initState();
    // 모든 필드 초기화
    for (var field in BiaField.fields) {
      _formValues[field.key] = '';
    }
    // 첫 입력 필드에 포커스
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  int get _totalSteps => BiaField.fields.length;
  int get _filledCount => _formValues.values.where((v) => v.trim().isNotEmpty).length;
  double get _progress => _filledCount / _totalSteps;
  
  BiaField get _currentField => BiaField.fields[_currentStep];
  bool get _canProceed => _formValues[_currentField.key]?.trim().isNotEmpty ?? false;

  void _nextStep() {
    if (!_canProceed) return;
    
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
      _focusNode.requestFocus();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _focusNode.requestFocus();
    }
  }

  Future<void> _submit() async {
    if (!_canProceed) return;

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
        sex: widget.gender,
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
            _buildProgressSection(),
            const SizedBox(height: 16),
            if (_filledCount > 0) _buildFilledChips(),
            if (_filledCount > 0) const SizedBox(height: 16),
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

  Widget _buildFilledChips() {
    final filledFields = BiaField.fields
        .take(_currentStep)
        .where((field) => _formValues[field.key]?.trim().isNotEmpty ?? false)
        .toList();

    if (filledFields.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: filledFields.map((field) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  field.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formValues[field.key]!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        );
      }).toList(),
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
            '다음 값을 입력하세요',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currentField.label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: TextField(
              key: ValueKey(_currentField.key),
              focusNode: _focusNode,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: '숫자 입력 후 Enter',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              controller: TextEditingController(
                text: _formValues[_currentField.key],
              )..selection = TextSelection.collapsed(
                  offset: _formValues[_currentField.key]?.length ?? 0,
                ),
              onChanged: (value) {
                setState(() {
                  _formValues[_currentField.key] = value;
                });
              },
              onSubmitted: (_) {
                if (_currentStep < _totalSteps - 1) {
                  _nextStep();
                } else {
                  _submit();
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton(
                onPressed: _currentStep > 0 ? _previousStep : null,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '이전',
                  style: TextStyle(
                    fontSize: 14,
                    color: _currentStep > 0 ? Colors.grey.shade700 : Colors.grey.shade400,
                  ),
                ),
              ),
              if (_currentStep < _totalSteps - 1)
                ElevatedButton(
                  onPressed: _canProceed ? _nextStep : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '다음',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                )
              else
                ElevatedButton(
                  onPressed: (_canProceed && !_loading) ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _loading ? '계산 중...' : '위험 점수 계산',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
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
}
