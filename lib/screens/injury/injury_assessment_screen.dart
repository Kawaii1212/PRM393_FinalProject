import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/injury_model.dart';
import '../../models/racket_model.dart';
import '../../providers/racket_provider.dart';
import '../../providers/injury_provider.dart';
import '../../theme/app_theme.dart';
import 'injury_result_screen.dart';
import 'injury_history_screen.dart';

class InjuryAssessmentScreen extends StatefulWidget {
  final BodyPart? initialBodyPart;

  const InjuryAssessmentScreen({super.key, this.initialBodyPart});

  @override
  State<InjuryAssessmentScreen> createState() => _InjuryAssessmentScreenState();
}

class _InjuryAssessmentScreenState extends State<InjuryAssessmentScreen> {
  late BodyPart _selectedPart;
  double _painScore = 4.0;
  final Set<String> _selectedSymptoms = {};
  String _triggerAction = 'Ve cầu trái tay (Backhand)';
  String _onsetTime = '1 - 3 ngày gần đây';
  String? _selectedRacketId;

  final Map<BodyPart, List<String>> _symptomsByPart = {
    BodyPart.elbow: [
      'Đau nhói mặt ngoài khuỷu tay',
      'Đau nhức mặt trong khuỷu tay',
      'Đau tăng khi ve trái tay (backhand)',
      'Đau khi gập úp cổ tay đập smash',
      'Yếu lực cầm nắm, khó mở nắp chai',
      'Cảm giác thốn dọc theo cẳng tay',
      'Sưng nhẹ hoặc nóng rát khớp',
    ],
    BodyPart.wrist: [
      'Đau thốn cạnh ngón út (phía xương trụ)',
      'Đau sưng ở gốc ngón tay cái',
      'Đau nhói khi xoay vặn cổ tay hoặc phát lực',
      'Khớp cổ tay kêu lạo xạo hoặc lỏng lẻo',
      'Đau dữ dội khi chống bàn tay xuống mặt phẳng',
      'Cảm giác râm ran/tê bì ngón tay',
    ],
    BodyPart.shoulder: [
      'Đau âm ỉ sâu trong khớp vai',
      'Đau buốt khi giơ tay quá đầu góc 60-120 độ',
      'Khó nằm nghiêng sang bên vai đau khi ngủ',
      'Mất lực rõ rệt khi phông cầu cao sâu hoặc smash',
      'Nghe tiếng lục cục trong chỏm vai khi xoay tay',
    ],
    BodyPart.knee: [
      'Đau nhói ngay dưới xương bánh chè',
      'Đau tăng khi bước dồn chân (lunge) đón cầu',
      'Cứng khớp gối vào buổi sáng sau trận đấu',
      'Đau khi bật nhảy tiếp đất hoặc xuống cầu thang',
      'Sưng phù quanh khớp gối',
    ],
    BodyPart.ankle: [
      'Sưng tấy và bầm tím mắt cá chân ngoài',
      'Đau nhói khi dồn trọng lượng cơ thể lên chân',
      'Cảm giác lỏng lẻo sợ lật chân trở lại',
      'Đau thốn gân gót Achilles khi nhón chân',
      'Đau buốt gót chân bước đầu tiên khi ngủ dậy',
    ],
    BodyPart.back: [
      'Đau nhức ê ẩm vùng thắt lưng sau trận đấu',
      'Cứng lưng khó cúi người hoặc xoay hông',
      'Cơ 2 bên thắt lưng co cứng nổi cộm',
      'Đau sau pha ngửa người cứu cầu muộn sau lưng',
    ],
  };

  final List<String> _triggerActions = [
    'Ve cầu trái tay (Backhand)',
    'Đập cầu gập cổ tay (Smash)',
    'Phông cầu cao sâu qua đầu',
    'Chụp lưới / Tạt cầu nhanh',
    'Bật nhảy đập cầu và tiếp đất',
    'Bước dồn chân (Lunge) cứu cầu lưới',
    'Bị trượt ngã / Lật chân trên sân',
    'Ngửa người cứu cầu muộn phía sau',
    'Không rõ / Tự nhiên phát đau',
  ];

  final List<String> _onsetTimes = [
    'Mới bị trong vòng 24 giờ qua',
    '1 - 3 ngày gần đây',
    '1 - 2 tuần gần đây',
    'Đau âm ỉ kéo dài trên 3 tuần',
  ];

  @override
  void initState() {
    super.initState();
    _selectedPart = widget.initialBodyPart ?? BodyPart.elbow;
    _setDefaultSymptomsForPart(_selectedPart);
  }

  void _setDefaultSymptomsForPart(BodyPart part) {
    _selectedSymptoms.clear();
    final list = _symptomsByPart[part] ?? [];
    if (list.isNotEmpty) {
      _selectedSymptoms.add(list.first);
    }
  }

  void _onPartChanged(BodyPart part) {
    setState(() {
      _selectedPart = part;
      _setDefaultSymptomsForPart(part);
    });
  }

  void _submitAssessment() {
    if (_selectedSymptoms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ít nhất 1 triệu chứng bạn đang gặp phải!'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    final racketProv = context.read<RacketProvider>();
    Racket? selectedRacket;
    if (_selectedRacketId != null) {
      selectedRacket = racketProv.getRacketById(_selectedRacketId!);
    } else if (racketProv.allRackets.isNotEmpty) {
      selectedRacket = racketProv.allRackets.first;
    }

    final input = InjuryAssessmentInput(
      bodyPart: _selectedPart,
      painScore: _painScore.round(),
      selectedSymptoms: _selectedSymptoms.toList(),
      triggerAction: _triggerAction,
      onsetTime: _onsetTime,
      relatedRacketId: selectedRacket?.id,
      relatedRacketName: selectedRacket != null
          ? '${selectedRacket.brand} ${selectedRacket.modelName}'
          : null,
      racketTensionLbs: selectedRacket?.initialTensionLbs,
      racketShaftStiffness: selectedRacket?.shaftStiffness,
      racketBalanceMm: selectedRacket?.balancePointMm,
      racketTensionLossPercent: selectedRacket?.tensionLossPercent,
    );

    final result = context.read<InjuryProvider>().runDiagnosis(input);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InjuryResultScreen(
          result: result,
          input: input,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final racketProv = context.watch<RacketProvider>();
    final rackets = racketProv.allRackets;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bác Sĩ Thể Thao 🩺'),
        actions: [
          IconButton(
            tooltip: 'Lịch sử chấn thương',
            icon: const Icon(Icons.history_edu_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const InjuryHistoryScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Intro Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppTheme.cardGradient,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.healing_rounded,
                      color: AppTheme.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sàng Lọc Chấn Thương Cầu Lông',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Hệ thống kết hợp triệu chứng cơ thể và thông số cây vợt bạn đang dùng để tìm ra nguyên nhân chính xác nhất.',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Step 1: Chọn Vùng Cơ Thể Đau
            _sectionHeader('1. Chọn Vùng Cơ Thể Bị Đau / Khó Chịu', Icons.accessibility_rounded),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.2,
              ),
              itemCount: BodyPart.values.length,
              itemBuilder: (context, idx) {
                final part = BodyPart.values[idx];
                final isSelected = part == _selectedPart;
                return InkWell(
                  onTap: () => _onPartChanged(part),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primary.withOpacity(0.15)
                          : AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppTheme.primary : AppTheme.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          part.icon,
                          color: isSelected ? AppTheme.primary : AppTheme.textMuted,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            part.shortLabel,
                            style: TextStyle(
                              color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Step 2: Mức Độ Đau (Thang điểm 1 - 10)
            _sectionHeader('2. Đánh Giá Mức Độ Đau (Thang 1 - 10)', Icons.speed_rounded),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Điểm đau hiện tại: ${_painScore.round()}/10',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: PainSeverity.fromScore(_painScore.round()).color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: PainSeverity.fromScore(_painScore.round()).color,
                          ),
                        ),
                        child: Text(
                          PainSeverity.fromScore(_painScore.round()).label,
                          style: TextStyle(
                            color: PainSeverity.fromScore(_painScore.round()).color,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: PainSeverity.fromScore(_painScore.round()).color,
                      thumbColor: PainSeverity.fromScore(_painScore.round()).color,
                      inactiveTrackColor: AppTheme.surfaceLight,
                      trackHeight: 6,
                    ),
                    child: Slider(
                      value: _painScore,
                      min: 1.0,
                      max: 10.0,
                      divisions: 9,
                      label: '${_painScore.round()}',
                      onChanged: (val) => setState(() => _painScore = val),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('1: Ê ẩm nhẹ', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                      Text('5: Đau nhói khi đánh', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                      Text('10: Đau dữ dội', style: TextStyle(color: AppTheme.danger, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Step 3: Triệu Chứng Chi Tiết
            _sectionHeader('3. Triệu Chứng Bạn Đang Gặp Phải', Icons.checklist_rounded),
            const SizedBox(height: 8),
            Text(
              'Chọn các cảm giác thực tế tại ${_selectedPart.shortLabel}:',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (_symptomsByPart[_selectedPart] ?? []).map((symptom) {
                final isSelected = _selectedSymptoms.contains(symptom);
                return FilterChip(
                  label: Text(symptom),
                  selected: isSelected,
                  selectedColor: AppTheme.primary.withOpacity(0.25),
                  checkmarkColor: AppTheme.primary,
                  backgroundColor: AppTheme.surface,
                  side: BorderSide(
                    color: isSelected ? AppTheme.primary : AppTheme.border,
                  ),
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedSymptoms.add(symptom);
                      } else {
                        _selectedSymptoms.remove(symptom);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Step 4: Động Tác Kích Hoạt Đau
            _sectionHeader('4. Động Tác Khiến Bạn Bị Đau Nhất', Icons.sports_tennis_rounded),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _triggerAction,
                  isExpanded: true,
                  dropdownColor: AppTheme.surface,
                  items: _triggerActions.map((act) {
                    return DropdownMenuItem(
                      value: act,
                      child: Text(act, style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _triggerAction = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Step 5: Thời Gian Xuất Hiện Đau
            _sectionHeader('5. Thời Gian Đau Xuất Hiện', Icons.access_time_rounded),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _onsetTime,
                  isExpanded: true,
                  dropdownColor: AppTheme.surface,
                  items: _onsetTimes.map((time) {
                    return DropdownMenuItem(
                      value: time,
                      child: Text(time, style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _onsetTime = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Step 6: Cây Vợt Liên Quan Trong Gara
            _sectionHeader('6. Cây Vợt Bạn Sử Dụng Gần Nhất', Icons.badge_rounded),
            const SizedBox(height: 6),
            const Text(
              'Hệ thống sẽ phân tích độ căng lbs, độ cứng đũa và điểm cân bằng của vợt:',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 10),
            if (rackets.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.textMuted, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Gara của bạn chưa có vợt nào. Kết quả sẽ chẩn đoán theo thông số chuẩn.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _selectedRacketId ?? rackets.first.id,
                    isExpanded: true,
                    dropdownColor: AppTheme.surface,
                    items: rackets.map((r) {
                      return DropdownMenuItem<String?>(
                        value: r.id,
                        child: Text(
                          '${r.brand} ${r.modelName} (${r.weightU} • Căng ${r.initialTensionLbs} lbs • ${r.shaftStiffness})',
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => _selectedRacketId = val);
                    },
                  ),
                ),
              ),
            const SizedBox(height: 30),

            // Nút Bắt Đầu Chuẩn Đoán
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _submitAssessment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
                icon: const Icon(Icons.analytics_rounded, size: 22),
                label: const Text(
                  'PHÂN TÍCH & CHUẨN ĐOÁN NGAY',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
