import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/racket_model.dart';
import '../../models/tension_log_model.dart';
import '../../models/notification_model.dart';
import '../../providers/racket_provider.dart';
import '../../providers/notification_provider.dart';
import '../../theme/app_theme.dart';

class AddEditRacketScreen extends StatefulWidget {
  final Racket? existingRacket;

  const AddEditRacketScreen({super.key, this.existingRacket});

  @override
  State<AddEditRacketScreen> createState() => _AddEditRacketScreenState();
}

class _AddEditRacketScreenState extends State<AddEditRacketScreen> {
  final _formKey = GlobalKey<FormState>();

  String _brand = 'Yonex';
  final _modelController = TextEditingController();
  final _editionController = TextEditingController();
  final _colorwayController = TextEditingController();

  String _weightU = '4U (80-84g)';
  String _gripG = 'G5';
  String _shaftStiffness = 'Cứng (Stiff)';
  double _balancePointMm = 298;
  String _frameProfile = 'Lai (Aero-Box)';
  double _maxTensionLbs = 28.0;

  final _stringModelController = TextEditingController(text: 'Yonex BG65');
  final _initialTensionController = TextEditingController(text: '24.0');

  final List<String> _brands = ['Yonex', 'Victor', 'Li-Ning', 'Mizuno', 'Felet', 'Kumpoo'];
  final List<String> _weights = ['3U (85-89g)', '4U (80-84g)', '5U (75-79g)', '6U/F (<75g)'];
  final List<String> _grips = ['G4', 'G5', 'G6'];
  final List<String> _stiffnessList = [
    'Rất cứng (Extra Stiff)',
    'Cứng (Stiff)',
    'Trung bình (Medium)',
    'Dẻo (Flexible)',
    'Rất dẻo (Hi-Flex)'
  ];
  final List<String> _frames = [
    'Lai (Aero-Box)',
    'Khung hộp (Box Frame - Smash uy lực)',
    'Khung vát xé gió (Aero / Sword - Tốc độ)',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingRacket != null) {
      final r = widget.existingRacket!;
      _brand = r.brand;
      _modelController.text = r.modelName;
      _editionController.text = r.editionGen;
      _colorwayController.text = r.colorway;
      _weightU = r.weightU;
      _gripG = r.gripG;
      _shaftStiffness = r.shaftStiffness;
      _balancePointMm = r.balancePointMm.toDouble();
      _frameProfile = r.frameProfile;
      _maxTensionLbs = r.maxTensionLbs;
      _stringModelController.text = r.currentStringModel;
      _initialTensionController.text = r.initialTensionLbs.toString();
    }
  }

  @override
  void dispose() {
    _modelController.dispose();
    _editionController.dispose();
    _colorwayController.dispose();
    _stringModelController.dispose();
    _initialTensionController.dispose();
    super.dispose();
  }

  void _saveRacket() {
    if (_formKey.currentState!.validate()) {
      final tensionVal = double.tryParse(_initialTensionController.text.trim()) ?? 0.0;
      final racketId = widget.existingRacket?.id ?? 'racket_${DateTime.now().millisecondsSinceEpoch}';

      final newRacket = Racket(
        id: racketId,
        brand: _brand,
        modelName: _modelController.text.trim(),
        editionGen: _editionController.text.trim().isEmpty ? 'Tiêu chuẩn' : _editionController.text.trim(),
        colorway: _colorwayController.text.trim().isEmpty ? 'Mặc định' : _colorwayController.text.trim(),
        weightU: _weightU,
        gripG: _gripG,
        shaftStiffness: _shaftStiffness,
        balancePointMm: _balancePointMm.toInt(),
        frameProfile: _frameProfile,
        maxTensionLbs: _maxTensionLbs,
        currentStringModel: _stringModelController.text.trim(),
        initialTensionLbs: tensionVal,
        strungDate: DateTime.now(),
        sessionsPlayed: 0,
        tensionLogs: [
          if (tensionVal > 0)
            TensionLog(
              id: 'log_init_${DateTime.now().millisecondsSinceEpoch}',
              racketId: racketId,
              stringModel: _stringModelController.text.trim(),
              tensionLbs: tensionVal,
              strungDate: DateTime.now(),
              shopName: 'Đan ban đầu khi thêm vào Gara',
              notes: 'Khởi tạo thông số vợt',
            ),
        ],
      );

      final provider = context.read<RacketProvider>();
      if (widget.existingRacket != null) {
        provider.updateRacket(newRacket);
      } else {
        provider.addRacket(newRacket);
        context.read<NotificationProvider>().addNotification(
          title: '🏸 Đã thêm vợt mới vào Gara!',
          message: 'Cây vợt $_brand ${_modelController.text} đã sẵn sàng được theo dõi vòng đời cước.',
          type: NotificationType.orderStatus,
          targetRacketId: racketId,
        );
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã lưu thành công cây vợt $_brand ${_modelController.text}!'),
          backgroundColor: AppTheme.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingRacket != null ? 'Chỉnh Sửa Vợt' : 'Thêm Vợt Vào Gara'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Group 1: Brand & Model
              _sectionHeader('1. Định Danh & Thương Hiệu'),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _brand,
                decoration: const InputDecoration(labelText: 'Hãng sản xuất'),
                items: _brands.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                onChanged: (v) => setState(() => _brand = v!),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _modelController,
                decoration: const InputDecoration(
                  labelText: 'Tên Model Vợt *',
                  hintText: 'Ví dụ: Astrox 100ZZ, Ryuga II, Halbertec 8000',
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Vui lòng nhập tên model' : null,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _editionController,
                      decoration: const InputDecoration(
                        labelText: 'Phiên bản / Đời',
                        hintText: 'Bản Pro / Kurenai',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _colorwayController,
                      decoration: const InputDecoration(
                        labelText: 'Phối màu',
                        hintText: 'Đỏ / Đen',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Group 2: Physical Specs
              _sectionHeader('2. Thông Số Vật Lý Chuyên Sâu'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _weightU,
                      decoration: const InputDecoration(labelText: 'Trọng lượng (U)'),
                      items: _weights.map((w) => DropdownMenuItem(value: w, child: Text(w))).toList(),
                      onChanged: (v) => setState(() => _weightU = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _gripG,
                      decoration: const InputDecoration(labelText: 'Cỡ cán (G)'),
                      items: _grips.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                      onChanged: (v) => setState(() => _gripG = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _shaftStiffness,
                decoration: const InputDecoration(labelText: 'Độ cứng thân đũa (Flex)'),
                items: _stiffnessList.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _shaftStiffness = v!),
              ),
              const SizedBox(height: 16),

              // Balance Point Slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Điểm cân bằng tĩnh: ', style: TextStyle(color: AppTheme.textSecondary)),
                  Text(
                    '${_balancePointMm.toInt()} mm (${_balancePointMm > 295 ? "Nặng đầu - Thiên công" : (_balancePointMm < 290 ? "Nhẹ đầu - Thiên thủ" : "Cân bằng")})',
                    style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Slider(
                value: _balancePointMm,
                min: 280,
                max: 315,
                divisions: 35,
                activeColor: AppTheme.primary,
                inactiveColor: AppTheme.surfaceLight,
                onChanged: (val) => setState(() => _balancePointMm = val),
              ),
              const SizedBox(height: 14),

              DropdownButtonFormField<String>(
                value: _frameProfile,
                decoration: const InputDecoration(labelText: 'Biên dạng khung vợt'),
                items: _frames.map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => setState(() => _frameProfile = v!),
              ),
              const SizedBox(height: 16),

              // Max tension
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Sức căng tối đa khuyến nghị của khung: ', style: TextStyle(color: AppTheme.textSecondary)),
                  Text(
                    '${_maxTensionLbs.toInt()} lbs',
                    style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Slider(
                value: _maxTensionLbs,
                min: 24,
                max: 35,
                divisions: 11,
                activeColor: AppTheme.accent,
                inactiveColor: AppTheme.surfaceLight,
                onChanged: (val) => setState(() => _maxTensionLbs = val),
              ),
              const SizedBox(height: 24),

              // Group 3: Current String Status
              _sectionHeader('3. Trạng Thái Cước Hiện Tại'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _stringModelController,
                      decoration: const InputDecoration(
                        labelText: 'Dây cước đang đan',
                        hintText: 'Exbolt 65, BG65Ti...',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _initialTensionController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Lực căng (lbs)',
                        suffixText: 'lbs',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveRacket,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    widget.existingRacket != null ? 'Cập Nhật Vợt' : 'Lưu Vợt Vào Gara Ngay',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.primaryDark,
        fontSize: 15,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }
}
