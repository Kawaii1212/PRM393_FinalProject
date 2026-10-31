import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/racket_model.dart';
import '../../models/tension_log_model.dart';
import '../../models/notification_model.dart';
import '../../providers/racket_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/racket_image_widget.dart';
import '../auth/login_register_screen.dart';

class AddEditRacketScreen extends StatefulWidget {
  final Racket? existingRacket;

  const AddEditRacketScreen({super.key, this.existingRacket});

  @override
  State<AddEditRacketScreen> createState() => _AddEditRacketScreenState();
}

class _AddEditRacketScreenState extends State<AddEditRacketScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  String _brand = 'Yonex';
  final _customBrandController = TextEditingController();
  final _modelController = TextEditingController();
  final _editionController = TextEditingController();
  final _colorwayController = TextEditingController();

  String _weightU = '4U (80-84g)';
  String _gripG = 'G5';
  String _shaftStiffness = 'Cứng (Stiff)';
  double _balancePointMm = 298;
  String _frameProfile = 'Lai (Aero-Box)';
  double _maxTensionLbs = 28.0;

  final _stringModelController = TextEditingController();
  final _initialTensionController = TextEditingController();
  String? _imageUrl;

  final List<String> _brands = [
    'Yonex',
    'Victor',
    'Li-Ning',
    'Mizuno',
    'Felet',
    'Kumpoo',
    'Khác',
  ];
  final List<String> _weights = [
    '3U (85-89g)',
    '4U (80-84g)',
    '5U (75-79g)',
    '6U/F (<75g)',
  ];
  final List<String> _grips = ['G4', 'G5', 'G6'];
  final List<String> _stiffnessList = [
    'Rất cứng (Extra Stiff)',
    'Cứng (Stiff)',
    'Trung bình (Medium)',
    'Dẻo (Flexible)',
    'Rất dẻo (Hi-Flex)',
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
      if (_brands.contains(r.brand) && r.brand != 'Khác') {
        _brand = r.brand;
      } else {
        _brand = 'Khác';
        _customBrandController.text = r.brand == 'Khác' ? '' : r.brand;
      }
      _modelController.text = r.modelName;
      _editionController.text = r.editionGen;
      _colorwayController.text = r.colorway;
      _weightU = _weights.contains(r.weightU) ? r.weightU : _weights[1];
      _gripG = _grips.contains(r.gripG) ? r.gripG : _grips[1];
      _shaftStiffness = _stiffnessList.contains(r.shaftStiffness)
          ? r.shaftStiffness
          : _stiffnessList[1];
      _balancePointMm = r.balancePointMm.toDouble().clamp(280.0, 315.0);
      _frameProfile =
          _frames.contains(r.frameProfile) ? r.frameProfile : _frames.first;
      _maxTensionLbs = r.maxTensionLbs.clamp(24.0, 35.0);
      _stringModelController.text = r.currentStringModel;
      _initialTensionController.text = r.initialTensionLbs.toString();
      _imageUrl = r.imageUrl;
    }
  }

  @override
  void dispose() {
    _customBrandController.dispose();
    _modelController.dispose();
    _editionController.dispose();
    _colorwayController.dispose();
    _stringModelController.dispose();
    _initialTensionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 70,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        if (!mounted) return;
        setState(() {
          _imageUrl = base64String;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể chọn ảnh: $e'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  void _showUrlInputDialog() {
    final urlController = TextEditingController(
      text: (_imageUrl != null && _imageUrl!.startsWith('http'))
          ? _imageUrl
          : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Nhập đường dẫn ảnh (URL)',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        content: TextField(
          controller: urlController,
          decoration: const InputDecoration(
            labelText: 'Link ảnh cây vợt (https://...)',
            prefixIcon: Icon(Icons.link_rounded, color: AppTheme.primary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Hủy',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final url = urlController.text.trim();
              setState(() {
                _imageUrl = url.isEmpty ? null : url;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Áp dụng'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveRacket() async {
    if (_formKey.currentState!.validate()) {
      final authProv = context.read<AuthProvider>();
      final racketProv = context.read<RacketProvider>();
      final existing = widget.existingRacket;

      // Giới hạn số vợt cho Khách dùng thử (Tối đa 3 cây vợt)
      if (authProv.isGuest && existing == null && racketProv.allRackets.length >= 3) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Row(
              children: [
                Icon(Icons.lock_outline_rounded, color: AppTheme.accent),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Giới Hạn Khách Dùng Thử',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: const Text(
              'Tài khoản Khách Dùng Thử chỉ được thêm tối đa 3 cây vợt vào Gara.\n\nVui lòng đăng nhập hoặc tạo tài khoản để quản lý không giới hạn số lượng vợt!',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Để sau', style: TextStyle(color: AppTheme.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginRegisterScreen()),
                  );
                },
                child: const Text('Đăng nhập ngay'),
              ),
            ],
          ),
        );
        return;
      }

      final tensionVal =
          double.tryParse(_initialTensionController.text.trim()) ?? 0.0;
      final racketId =
          existing?.id ?? 'racket_${DateTime.now().millisecondsSinceEpoch}';
      final finalBrand = _brand == 'Khác'
          ? _customBrandController.text.trim()
          : _brand;

      final newRacket = Racket(
        id: racketId,
        brand: finalBrand,
        modelName: _modelController.text.trim(),
        editionGen: _editionController.text.trim().isEmpty
            ? 'Tiêu chuẩn'
            : _editionController.text.trim(),
        colorway: _colorwayController.text.trim().isEmpty
            ? 'Mặc định'
            : _colorwayController.text.trim(),
        weightU: _weightU,
        gripG: _gripG,
        shaftStiffness: _shaftStiffness,
        balancePointMm: _balancePointMm.toInt(),
        frameProfile: _frameProfile,
        maxTensionLbs: _maxTensionLbs,
        currentStringModel: _stringModelController.text.trim(),
        initialTensionLbs: tensionVal,
        strungDate: existing?.strungDate ?? DateTime.now(),
        sessionsPlayed: existing?.sessionsPlayed ?? 0,
        gripCondition: existing?.gripCondition ?? 'Bọc quấn cán mới',
        imageUrl: _imageUrl,
        tensionLogs: existing != null
            ? existing.tensionLogs
            : [
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
      if (existing != null) {
        await provider.updateRacket(newRacket);
      } else {
        await provider.addRacket(newRacket);
        if (mounted) {
          context.read<NotificationProvider>().addNotification(
            title: '🏸 Đã thêm vợt mới vào Gara!',
            message:
                'Cây vợt $finalBrand ${_modelController.text} đã được lưu lên Cloud Firestore.',
            type: NotificationType.orderStatus,
            targetRacketId: racketId,
          );
        }
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã lưu thành công cây vợt $finalBrand ${_modelController.text} lên Cloud Firestore!',
          ),
          backgroundColor: AppTheme.primaryDark,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingRacket != null
              ? 'Chỉnh Sửa Vợt'
              : 'Thêm Vợt Vào Gara',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Group 0: Hình ảnh cây vợt (Racket Avatar)
              _sectionHeader('Ảnh Đại Diện Cây Vợt'),
              const SizedBox(height: 10),
              RacketImageWidget(
                imageUrl: _imageUrl,
                brand: _brand,
                height: 175,
                borderRadius: 16,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(
                        Icons.photo_library_outlined,
                        size: 18,
                        color: AppTheme.primary,
                      ),
                      label: const Text(
                        'Thư viện ảnh',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.primary),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(
                        Icons.camera_alt_outlined,
                        size: 18,
                        color: AppTheme.primaryDark,
                      ),
                      label: const Text(
                        'Chụp ảnh',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.border),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _showUrlInputDialog,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.border),
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Icon(
                      Icons.link_rounded,
                      size: 18,
                      color: AppTheme.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Group 1: Brand & Model
              _sectionHeader('1. Định Danh & Thương Hiệu'),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _brand,
                decoration: const InputDecoration(labelText: 'Hãng sản xuất'),
                items: _brands
                    .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                    .toList(),
                onChanged: (v) => setState(() => _brand = v!),
              ),
              if (_brand == 'Khác') ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _customBrandController,
                  decoration: const InputDecoration(
                    labelText: 'Nhập Tên Hãng Vợt *',
                    hintText: 'Ví dụ: Apacs, Proace, Kawasaki, Gosen, VNB...',
                    prefixIcon: Icon(
                      Icons.branding_watermark_outlined,
                      color: AppTheme.primary,
                    ),
                  ),
                  validator: (v) {
                    if (_brand == 'Khác' && (v == null || v.trim().isEmpty)) {
                      return 'Vui lòng nhập tên hãng vợt';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 14),
              TextFormField(
                controller: _modelController,
                decoration: const InputDecoration(
                  labelText: 'Tên Model Vợt *',
                  hintText: 'Ví dụ: Astrox 100ZZ, Ryuga II, Halbertec 8000',
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Vui lòng nhập tên model' : null,
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
                      decoration:
                          const InputDecoration(labelText: 'Trọng lượng (U)'),
                      items: _weights
                          .map((w) => DropdownMenuItem(value: w, child: Text(w)))
                          .toList(),
                      onChanged: (v) => setState(() => _weightU = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _gripG,
                      decoration: const InputDecoration(labelText: 'Cỡ cán (G)'),
                      items: _grips
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (v) => setState(() => _gripG = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _shaftStiffness,
                decoration:
                    const InputDecoration(labelText: 'Độ cứng thân đũa (Flex)'),
                items: _stiffnessList
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _shaftStiffness = v!),
              ),
              const SizedBox(height: 16),

              // Balance Point Slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Điểm cân bằng tĩnh: ',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  Text(
                    '${_balancePointMm.toInt()} mm (${_balancePointMm > 295 ? "Nặng đầu - Thiên công" : (_balancePointMm < 290 ? "Nhẹ đầu - Thiên thủ" : "Cân bằng")})',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
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
                decoration:
                    const InputDecoration(labelText: 'Biên dạng khung vợt'),
                items: _frames
                    .map(
                      (f) => DropdownMenuItem(
                        value: f,
                        child: Text(f, style: const TextStyle(fontSize: 13)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _frameProfile = v!),
              ),
              const SizedBox(height: 16),

              // Max tension
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Sức căng tối đa khuyến nghị của khung: ',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  Text(
                    '${_maxTensionLbs.toInt()} lbs',
                    style: const TextStyle(
                      color: AppTheme.accent,
                      fontWeight: FontWeight.bold,
                    ),
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
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Lực căng (lbs)',
                        hintText: '15.0 - 60.0',
                        suffixText: 'lbs',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          if (_stringModelController.text.trim().isNotEmpty) {
                            return 'Vui lòng nhập lực căng';
                          }
                          return null;
                        }
                        final parsed = double.tryParse(v.trim());
                        if (parsed == null) {
                          return 'Phải là số thực (vd: 24.5)';
                        }
                        if (parsed < 15.0 || parsed > 60.0) {
                          return 'Từ 15.0 đến 60.0 lbs';
                        }
                        return null;
                      },
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
                    widget.existingRacket != null
                        ? 'Cập Nhật Vợt'
                        : 'Lưu Vợt Vào Gara Ngay',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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
