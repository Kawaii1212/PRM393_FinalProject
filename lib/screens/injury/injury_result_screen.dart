import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/injury_model.dart';
import '../../providers/injury_provider.dart';
import '../../theme/app_theme.dart';
import '../shop/shop_map_screen.dart';
import 'injury_history_screen.dart';

class InjuryResultScreen extends StatefulWidget {
  final InjuryDiagnosisResult result;
  final InjuryAssessmentInput input;

  const InjuryResultScreen({
    super.key,
    required this.result,
    required this.input,
  });

  @override
  State<InjuryResultScreen> createState() => _InjuryResultScreenState();
}

class _InjuryResultScreenState extends State<InjuryResultScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSaved = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _saveRecord() async {
    if (_isSaved || _isSaving) return;
    setState(() => _isSaving = true);

    try {
      await context.read<InjuryProvider>().saveDiagnosisRecord(
            result: widget.result,
            input: widget.input,
          );
      if (!mounted) return;
      setState(() {
        _isSaved = true;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã lưu thành công vào Sổ Tay Chấn Thương!'),
          backgroundColor: AppTheme.primaryDark,
          duration: Duration(seconds: 2),
        ),
      );

      // Đóng màn hình kết quả và chuyển ngay tới Sổ Tay Chấn Thương
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const InjuryHistoryScreen(),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final res = widget.result;
    final injury = res.injuryType;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kết Quả Chuẩn Đoán'),
        actions: [
          TextButton.icon(
            onPressed: _isSaved ? null : _saveRecord,
            icon: Icon(
              _isSaved ? Icons.check_circle_rounded : Icons.bookmark_add_rounded,
              color: _isSaved ? AppTheme.primary : Colors.white,
              size: 20,
            ),
            label: Text(
              _isSaved ? 'Đã lưu' : 'Lưu lại',
              style: TextStyle(
                color: _isSaved ? AppTheme.primary : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Chẩn đoán chính
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: AppTheme.cardGradient,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: res.severity.color.withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: res.severity.color.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: res.severity.color),
                        ),
                        child: Text(
                          res.severity.label,
                          style: TextStyle(
                            color: res.severity.color,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Độ tin cậy: ${res.confidencePercent}%',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    injury.nameVi,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Thuật ngữ y khoa: ${injury.medicalName}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    injury.description,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Safe to Play Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: res.canPlayBadmintonNow
                    ? AppTheme.primary.withOpacity(0.12)
                    : AppTheme.danger.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: res.canPlayBadmintonNow
                      ? AppTheme.primary.withOpacity(0.4)
                      : AppTheme.danger.withOpacity(0.4),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    res.canPlayBadmintonNow
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color: res.canPlayBadmintonNow
                        ? AppTheme.primary
                        : AppTheme.danger,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          res.canPlayBadmintonNow
                              ? 'CÓ THỂ VẬN ĐỘNG NHẸ'
                              : 'KHUYẾN CÁO: KHÔNG NÊN RA SÂN!',
                          style: TextStyle(
                            color: res.canPlayBadmintonNow
                                ? AppTheme.primary
                                : AppTheme.danger,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          res.safeToPlayAdvice,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Gear Insight Box (Tương quan vợt & cước)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: res.isGearFactorHigh
                      ? AppTheme.accent.withOpacity(0.6)
                      : AppTheme.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        res.isGearFactorHigh
                            ? Icons.warning_amber_rounded
                            : Icons.sports_tennis_rounded,
                        color: res.isGearFactorHigh
                            ? AppTheme.accent
                            : AppTheme.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Phân Tích Tương Quan Dụng Cụ',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (widget.input.relatedRacketName != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.sports_tennis_outlined,
                            size: 16,
                            color: AppTheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Vợt sử dụng: ${widget.input.relatedRacketName} (${widget.input.racketTensionLbs ?? 0} lbs)',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    res.gearAnalysisSummary,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                  if (res.isGearFactorHigh) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ShopMapScreen(),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: AppTheme.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.storefront_rounded, size: 18),
                        label: const Text(
                          'Tìm Tiệm Đan Hạ Lbs Gần Nhất',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tab Bar: Sơ cứu, Bài tập, Khuyến nghị Gear
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.primary,
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.textMuted,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: const [
                  Tab(text: 'Sơ Cứu R.I.C.E'),
                  Tab(text: 'Bài Tập Hồi Phục'),
                  Tab(text: 'Tư Vấn Gear'),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Tab View Contents
            SizedBox(
              height: 380,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: RICE
                  _buildRiceTab(injury.riceProtocol),
                  // Tab 2: Exercises
                  _buildExercisesTab(injury.exercises),
                  // Tab 3: Gear Advice
                  _buildGearTab(injury.gearAdvice),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Medical Disclaimer Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.security_update_warning_rounded,
                    color: AppTheme.textMuted,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lưu ý Y tế: Kết quả chuẩn đoán và bài tập trên đây được xây dựng theo tài liệu y học thể thao cơ bản. Nếu cơn đau dữ dội, khớp biến dạng hoặc kéo dài trên 7 ngày, hãy đến ngay bệnh viện hoặc cơ sở y tế chuyên khoa.',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildRiceTab(String riceText) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.ac_unit_rounded, color: AppTheme.primaryDark, size: 20),
                SizedBox(width: 8),
                Text(
                  'Nguyên Tắc Xử Lý R.I.C.E Trong 48 Giờ Đầu',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              riceText,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExercisesTab(List<RehabExercise> exercises) {
    if (exercises.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Center(
          child: Text(
            'Hiện tại nên nghỉ ngơi tĩnh, chưa cần tập bài tập vận động.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: exercises.length,
      separatorBuilder: (_, index) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        final ex = exercises[idx];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${idx + 1}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ex.name,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Thời lượng: ${ex.durationOrReps}',
                  style: const TextStyle(
                    color: AppTheme.primaryDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                ex.instructions,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 14,
                    color: AppTheme.accent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      ex.cautionNote,
                      style: const TextStyle(
                        color: AppTheme.accent,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGearTab(GearAdvice advice) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _gearRow('Mức căng cước (Tension):', advice.tensionAdvice, Icons.straighten_rounded),
            const Divider(color: AppTheme.border, height: 20),
            _gearRow('Thông số thân & đầu vợt:', advice.racketSpecAdvice, Icons.sports_tennis_rounded),
            const Divider(color: AppTheme.border, height: 20),
            _gearRow('Loại cước khuyến nghị:', advice.stringAdvice, Icons.waves_rounded),
            const Divider(color: AppTheme.border, height: 20),
            _gearRow('Giày & Dụng cụ phụ trợ:', advice.otherAdvice, Icons.sports_kabaddi_rounded),
          ],
        ),
      ),
    );
  }

  Widget _gearRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.primary, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
