import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' show join, basename;
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;
import '../services/location_service.dart';
import '../services/image_processor.dart';
import '../services/update_service.dart';
import '../services/photo_metadata_db.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  Position? _currentPosition;
  String _currentAddress = "Buscando localização...";
  Timer? _timer;
  String _currentTimeString = "";
  String _currentDateString = "";
  String _currentDayString = "";
  bool _isProcessingRaw = false;
  bool _isWatermarking = false;
  final int _selectedCameraIndex = 0;
  FlashMode _flashMode = FlashMode.off;
  String? _lastPhotoPath;
  double? _lastLat, _lastLon;
  String? _lastAddr;
  String? _customLogoPath;
  String _customTitle = "MARKPRO CAMERA";
  Uint8List? _fontData;

  Map<String, bool> _settings = {
    'showTime': true,
    'showAddress': true,
    'showMap': true,
    'showLogo': true,
    'showCoords': true,
    'showAltitude': true,
    'showDevWatermark': true,
  };

  @override
  void initState() {
    super.initState();
    _initCamera(_selectedCameraIndex);
    _startTimer();
    _loadSettings();
    _loadFont();

    // Pedir permissão + checar GPS logo na 1ª abertura
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkAndRequestLocation();
      // Verificar atualização depois das permissões
      if (mounted) UpdateService.checkUpdate(context);
    });
  }

  Future<void> _checkAndRequestLocation() async {
    // 1. Solicitar permissão de localização (garante o diálogo na 1ª abertura)
    final hasPermission = await LocationService.requestPermissions();

    if (!hasPermission) {
      if (!mounted) return;
      // Permissão negada — mostrar aviso com botão para configurações
      _showLocationPermissionDialog();
      return;
    }

    // 2. Verificar se o GPS está ligado
    final serviceOn = await LocationService.isLocationServiceEnabled();
    if (!serviceOn) {
      if (!mounted) return;
      _showGpsOffDialog();
      return;
    }

    // 3. Tudo OK — buscar localização
    _updateLocation();
  }

  void _showGpsOffDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.location_off_rounded, color: Color(0xFFFF5252)),
            const SizedBox(width: 10),
            Text(
              'GPS Desligado',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'O GPS está desativado no seu dispositivo.\n\nPara que as fotos tenham localização precisa, ative o GPS nas configurações.',
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Ignorar',
              style: GoogleFonts.outfit(color: Colors.white38),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await Geolocator.openLocationSettings();
              // Após voltar das configurações, tentar de novo
              await Future.delayed(const Duration(seconds: 1));
              if (mounted) _updateLocation();
            },
            icon: const Icon(Icons.settings_rounded, size: 16),
            label: Text(
              'Ativar GPS',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(
              Icons.location_disabled_rounded,
              color: Color(0xFFFF5252),
            ),
            const SizedBox(width: 10),
            Text(
              'Permissão Negada',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Sem permissão de localização, as fotos não terão coordenadas GPS.\n\nVá em Configurações → Permissões → Localização.',
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Ignorar',
              style: GoogleFonts.outfit(color: Colors.white38),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await openAppSettings();
            },
            icon: const Icon(Icons.settings_rounded, size: 16),
            label: Text(
              'Configurações',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadFont() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final fontFile = File(join(appDir.path, 'roboto_font.ttf'));

      if (await fontFile.exists()) {
        final data = await fontFile.readAsBytes();
        setState(() => _fontData = data);
      } else {
        // Download font if not exists (Roboto supports many accents)
        final response = await http
            .get(
              Uri.parse(
                "https://github.com/google/fonts/raw/main/apache/roboto/Roboto-Regular.ttf",
              ),
            )
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          await fontFile.writeAsBytes(response.bodyBytes);
          setState(() => _fontData = response.bodyBytes);
        }
      }
    } catch (e) {
      debugPrint("Erro ao carregar fonte: $e");
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedSettingsJson = prefs.getString('user_settings_v1');
    if (savedSettingsJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(savedSettingsJson);
        setState(() {
          _settings = decoded.map((key, value) => MapEntry(key, value as bool));
        });
      } catch (_) {}
    }
    setState(() {
      _customLogoPath = prefs.getString('custom_logo_path');
      _customTitle = prefs.getString('custom_title') ?? "MARKPRO CAMERA";
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_settings_v1', jsonEncode(_settings));
    if (_customLogoPath != null) {
      await prefs.setString('custom_logo_path', _customLogoPath!);
    } else {
      await prefs.remove('custom_logo_path');
    }
    await prefs.setString('custom_title', _customTitle);
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        final now = DateTime.now();
        setState(() {
          _currentTimeString = DateFormat('HH:mm').format(now);
          _currentDateString = DateFormat('dd MMM. yyyy').format(now);
          _currentDayString = DateFormat('E', 'pt_BR').format(now);
        });
      }
    });
  }

  Future<void> _updateLocation() async {
    final pos = await LocationService.getCurrentPosition();
    if (pos != null && mounted) {
      setState(() => _currentPosition = pos);
      final addr = await LocationService.getAddressFromLatLng(
        pos.latitude,
        pos.longitude,
      );
      if (mounted) setState(() => _currentAddress = addr);
    }
  }

  void _initCamera(int index) {
    _controller = CameraController(
      widget.cameras[index],
      ResolutionPreset.high,
      enableAudio: false,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  Future<void> _takePicture() async {
    if (_isProcessingRaw) return;
    try {
      setState(() => _isProcessingRaw = true);
      await _initializeControllerFuture;
      final XFile rawImage = await _controller.takePicture();
      setState(() {
        _isProcessingRaw = false;
        _isWatermarking = true;
      });

      final pos = _currentPosition;
      final addr = _currentAddress;
      final time = _currentTimeString;
      final date = _currentDateString;
      final day = _currentDayString;
      final settingsCopy = Map<String, bool>.from(_settings);
      final logoPathCopy = _customLogoPath;

      ImageProcessor.processAndSaveImage(
        path: rawImage.path,
        position: pos,
        address: addr,
        timeString: time,
        dateString: date,
        dayString: day,
        settings: settingsCopy,
        logoPath: logoPathCopy,
        customTitle: _customTitle,
        fontData: _fontData,
      ).then((resultPath) {
        if (mounted) {
          setState(() {
            _isWatermarking = false;
            if (resultPath != null) {
              _lastPhotoPath = resultPath;
              _lastLat = pos?.latitude;
              _lastLon = pos?.longitude;
              _lastAddr = addr;
            }
          });
        }
      });
    } catch (e) {
      setState(() => _isProcessingRaw = false);
    }
  }

  Future<void> _openGalleryAndShare() async {
    final photos = await PhotoMetadataDB.getAll();

    if (!mounted) return;

    if (photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nenhuma foto do MarkPro encontrada. Tire uma foto primeiro!',
          ),
          backgroundColor: Color(0xFF1A1A1A),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF121212),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Fotos MarkPro',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Segure para excluir',
                style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  controller: controller,
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  itemCount: photos.length,
                  itemBuilder: (_, i) {
                    final photo = photos[i];
                    final hasLocation = photo['lat'] != null;
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        if (mounted) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PhotoPreviewScreen(
                                path: photo['path'] as String,
                                lat: photo['lat'] != null
                                    ? (photo['lat'] as num).toDouble()
                                    : null,
                                lon: photo['lon'] != null
                                    ? (photo['lon'] as num).toDouble()
                                    : null,
                                address: photo['address'] as String?,
                              ),
                            ),
                          );
                        }
                      },
                      onLongPress: () async {
                        await PhotoMetadataDB.delete(photo['path'] as String);
                        if (mounted) Navigator.pop(ctx);
                        _openGalleryAndShare();
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(photo['path'] as String),
                              fit: BoxFit.cover,
                            ),
                          ),
                          if (hasLocation)
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00E676),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.black,
                                  size: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final String fileName = basename(image.path);
      final File localImage = await File(
        image.path,
      ).copy(join(appDir.path, 'custom_logo_$fileName'));
      setState(() {
        _customLogoPath = localImage.path;
      });
      _saveSettings();
    }
  }

  Future<void> _exportConfig() async {
    try {
      final String config = const JsonEncoder.withIndent('  ').convert({
        'settings': _settings,
        'customTitle': _customTitle,
        'version': '1.0.21',
        'showDevWatermark': _settings['showDevWatermark'] ?? true,
        'exportedAt': DateTime.now().toIso8601String(),
      });
      final tempDir = await getTemporaryDirectory();
      final file = File(join(tempDir.path, 'markpro_config.json'));
      await file.writeAsString(config);
      await Share.shareXFiles([
        XFile(file.path, mimeType: 'application/json'),
      ], subject: 'Configurações MarkPro Camera');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao exportar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importConfig() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Selecionar arquivo de configuração',
      );

      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      final Map<String, dynamic> data = jsonDecode(content);

      if (data.containsKey('settings')) {
        setState(() {
          final loaded = (data['settings'] as Map<String, dynamic>).map(
            (k, v) => MapEntry(k, v as bool),
          );
          _settings = {..._settings, ...loaded};
          // Restaurar a flag de marca do dev
          if (data.containsKey('showDevWatermark')) {
            _settings['showDevWatermark'] = data['showDevWatermark'] as bool;
          }
          if (data.containsKey('customTitle') &&
              (data['customTitle'] as String).isNotEmpty) {
            _customTitle = data['customTitle'] as String;
          }
        });
        await _saveSettings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Configurações importadas com sucesso!',
                style: GoogleFonts.outfit(color: Colors.black),
              ),
              backgroundColor: const Color(0xFF00E676),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Arquivo inválido! Não é uma configuração MarkPro.',
                style: GoogleFonts.outfit(color: Colors.white),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erro ao importar: $e',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDevWatermarkDialog(
    StateSetter setModalState, {
    required bool targetValue,
  }) {
    const _devPassword = '@6372@Fernandes';
    final passCtrl = TextEditingController();
    bool _obscure = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.lock_rounded, color: Color(0xFFFF5252)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  targetValue
                      ? 'Reativar Marca do Dev'
                      : 'Remover Marca do Dev',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                targetValue
                    ? 'Digite a senha para reativar a marca do desenvolvedor nas fotos.'
                    : 'Esta ação remove a assinatura do desenvolvedor das fotos.\n\nDigite a senha de autorização:',
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: passCtrl,
                obscureText: _obscure,
                autofocus: true,
                style: GoogleFonts.outfit(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Senha de autorização',
                  hintStyle: GoogleFonts.outfit(color: Colors.white24),
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: Colors.white38,
                    ),
                    onPressed: () => setDialogState(() => _obscure = !_obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancelar',
                style: GoogleFonts.outfit(color: Colors.white38),
              ),
            ),
            ElevatedButton.icon(
              icon: Icon(
                targetValue
                    ? Icons.check_circle_rounded
                    : Icons.no_accounts_rounded,
                size: 16,
              ),
              label: Text(
                targetValue ? 'Reativar' : 'Remover',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: targetValue
                    ? const Color(0xFF00E676)
                    : Colors.redAccent,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                if (passCtrl.text == _devPassword) {
                  Navigator.pop(ctx);
                  setModalState(
                    () => _settings['showDevWatermark'] = targetValue,
                  );
                  setState(() => _settings['showDevWatermark'] = targetValue);
                  _saveSettings();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        targetValue
                            ? '✅ Marca do desenvolvedor reativada!'
                            : '🔴 Marca do desenvolvedor removida!',
                        style: GoogleFonts.outfit(color: Colors.black),
                      ),
                      backgroundColor: targetValue
                          ? const Color(0xFF00E676)
                          : Colors.redAccent,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Senha incorreta!',
                        style: GoogleFonts.outfit(color: Colors.white),
                      ),
                      backgroundColor: Colors.red.shade900,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditModel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.88,
              maxChildSize: 0.97,
              builder: (_, scrollController) => Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF0E0E0E),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  children: [
                    // Handle
                    const SizedBox(height: 12),
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Header com badge de versão
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Configurações',
                                  style: GoogleFonts.outfit(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Personalize seu carimbo de prova',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    color: Colors.white38,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Badge de versão
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00E676), Color(0xFF00897B)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'v1.0.22',
                              style: GoogleFonts.outfit(
                                color: Colors.black,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFF1E1E1E),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white54,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Conteúdo rolável
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          // ── SEÇÃO: IDENTIDADE ──────────────────────────
                          _sectionLabel('🏷️  Identidade do Projeto'),
                          const SizedBox(height: 10),

                          // Card: Nome do projeto (editável inline)
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF00E676).withOpacity(0.08),
                                  const Color(0xFF00E676).withOpacity(0.02),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(
                                  0xFF00E676,
                                ).withOpacity(0.25),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF00E676,
                                  ).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.badge_rounded,
                                  color: Color(0xFF00E676),
                                  size: 22,
                                ),
                              ),
                              title: Text(
                                'Nome do Projeto',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                _customTitle,
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF00E676),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.edit_rounded,
                                color: Colors.white24,
                                size: 18,
                              ),
                              onTap: () {
                                final ctrl = TextEditingController(
                                  text: _customTitle,
                                );
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: const Color(0xFF1A1A1A),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    title: Text(
                                      'Nome do Projeto',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    content: TextField(
                                      controller: ctrl,
                                      autofocus: true,
                                      textCapitalization:
                                          TextCapitalization.characters,
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Ex: OBRA SP 2025',
                                        hintStyle: GoogleFonts.outfit(
                                          color: Colors.white24,
                                        ),
                                        filled: true,
                                        fillColor: const Color(0xFF2A2A2A),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        suffixIcon: const Icon(
                                          Icons.title_rounded,
                                          color: Color(0xFF00E676),
                                        ),
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: Text(
                                          'Cancelar',
                                          style: GoogleFonts.outfit(
                                            color: Colors.white38,
                                          ),
                                        ),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF00E676,
                                          ),
                                          foregroundColor: Colors.black,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                        onPressed: () {
                                          final v = ctrl.text
                                              .trim()
                                              .toUpperCase();
                                          if (v.isNotEmpty) {
                                            setModalState(
                                              () => _customTitle = v,
                                            );
                                            setState(() => _customTitle = v);
                                            _saveSettings();
                                          }
                                          Navigator.pop(ctx);
                                        },
                                        child: Text(
                                          'Salvar',
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Card: Logo da empresa
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: _settings['showLogo']!
                                    ? Colors.white24
                                    : Colors.white10,
                              ),
                            ),
                            child: Column(
                              children: [
                                ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 6,
                                  ),
                                  leading: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      color: const Color(0xFF2A2A2A),
                                    ),
                                    child: _customLogoPath != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            child: Image.file(
                                              File(_customLogoPath!),
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.image_rounded,
                                            color: Colors.white38,
                                            size: 22,
                                          ),
                                  ),
                                  title: Text(
                                    'Logotipo',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    _customLogoPath != null
                                        ? '✅ Logo carregada'
                                        : 'Sem logo — usa nome do projeto',
                                    style: GoogleFonts.outfit(
                                      color: _customLogoPath != null
                                          ? const Color(0xFF00E676)
                                          : Colors.white38,
                                      fontSize: 12,
                                    ),
                                  ),
                                  trailing: Switch(
                                    value: _settings['showLogo']!,
                                    activeThumbColor: const Color(0xFF00E676),
                                    onChanged: (v) {
                                      setModalState(
                                        () => _settings['showLogo'] = v,
                                      );
                                      setState(() => _settings['showLogo'] = v);
                                      _saveSettings();
                                    },
                                  ),
                                ),
                                // Botões de logo
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 16,
                                    right: 16,
                                    bottom: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(
                                              0xFF00E676,
                                            ),
                                            side: const BorderSide(
                                              color: Color(0xFF00E676),
                                              width: 1,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.upload_rounded,
                                            size: 16,
                                          ),
                                          label: Text(
                                            'Carregar',
                                            style: GoogleFonts.outfit(
                                              fontSize: 12,
                                            ),
                                          ),
                                          onPressed: () async {
                                            await _pickLogo();
                                            setModalState(() {});
                                          },
                                        ),
                                      ),
                                      if (_customLogoPath != null) ...[
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.redAccent,
                                              side: const BorderSide(
                                                color: Colors.redAccent,
                                                width: 1,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                            icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              size: 16,
                                            ),
                                            label: Text(
                                              'Remover',
                                              style: GoogleFonts.outfit(
                                                fontSize: 12,
                                              ),
                                            ),
                                            onPressed: () {
                                              setModalState(
                                                () => _customLogoPath = null,
                                              );
                                              setState(
                                                () => _customLogoPath = null,
                                              );
                                              _saveSettings();
                                            },
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // ── SEÇÃO: CARIMBO VISUAL ──────────────────────
                          _sectionLabel('📸  Informações no Carimbo'),
                          const SizedBox(height: 12),

                          // Grid compacto de toggles
                          _buildToggleGrid(setModalState),

                          const SizedBox(height: 24),

                          // ── SEÇÃO: DADOS E BACKUP ──────────────────────
                          _sectionLabel('⚙️  Configurações Avançadas'),
                          const SizedBox(height: 10),

                          Row(
                            children: [
                              Expanded(
                                child: _buildActionBtn(
                                  'Exportar Config',
                                  Icons.ios_share_rounded,
                                  const Color(0xFF448AFF),
                                  _exportConfig,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildActionBtn(
                                  'Importar Config',
                                  Icons.download_rounded,
                                  const Color(0xFFFF9800),
                                  _importConfig,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Botão de checar GPS
                          _buildActionBtn(
                            'Verificar GPS e Permissões',
                            Icons.gps_fixed_rounded,
                            const Color(0xFF00E676),
                            () {
                              Navigator.pop(context);
                              _checkAndRequestLocation();
                            },
                          ),

                          const SizedBox(height: 16),

                          // ── SEÇÃO: MARCA DO DESENVOLVEDOR ─────────────
                          _sectionLabel('🔒  Licença do Desenvolvedor'),
                          const SizedBox(height: 10),

                          // Card de remoção da marca
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: (_settings['showDevWatermark'] ?? true)
                                    ? Colors.white10
                                    : Colors.redAccent.withOpacity(0.4),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: (_settings['showDevWatermark'] ?? true)
                                      ? Colors.white10
                                      : Colors.redAccent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  (_settings['showDevWatermark'] ?? true)
                                      ? Icons.verified_user_rounded
                                      : Icons.no_accounts_rounded,
                                  color: (_settings['showDevWatermark'] ?? true)
                                      ? Colors.white38
                                      : Colors.redAccent,
                                  size: 22,
                                ),
                              ),
                              title: Text(
                                'Marca do Desenvolvedor',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                (_settings['showDevWatermark'] ?? true)
                                    ? 'Visível nas fotos'
                                    : '🔴 Removida (requer senha para reativar)',
                                style: GoogleFonts.outfit(
                                  color: (_settings['showDevWatermark'] ?? true)
                                      ? Colors.white38
                                      : Colors.redAccent,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Switch(
                                value: _settings['showDevWatermark'] ?? true,
                                activeColor: const Color(0xFF00E676),
                                inactiveThumbColor: Colors.redAccent,
                                onChanged: (v) {
                                  _showDevWatermarkDialog(
                                    setModalState,
                                    targetValue: v,
                                  );
                                },
                              ),
                            ),
                          ),

                          const SizedBox(height: 28),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          color: Colors.white54,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildToggleGrid(StateSetter setModalState) {
    final items = [
      {
        'key': 'showTime',
        'label': 'Data / Hora',
        'icon': Icons.access_time_filled_rounded,
      },
      {
        'key': 'showAddress',
        'label': 'Endereço',
        'icon': Icons.location_on_rounded,
      },
      {'key': 'showMap', 'label': 'Mini Mapa', 'icon': Icons.map_rounded},
      {
        'key': 'showCoords',
        'label': 'Coordenadas',
        'icon': Icons.explore_rounded,
      },
      {
        'key': 'showAltitude',
        'label': 'Altitude',
        'icon': Icons.landscape_rounded,
      },
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.map((item) {
        final key = item['key'] as String;
        final icon = item['icon'] as IconData;
        final label = item['label'] as String;
        final enabled = _settings[key]!;
        return GestureDetector(
          onTap: () {
            setModalState(() => _settings[key] = !enabled);
            setState(() => _settings[key] = !enabled);
            _saveSettings();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: (MediaQuery.of(context).size.width - 60) / 2,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: enabled
                  ? const Color(0xFF00E676).withOpacity(0.12)
                  : const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: enabled
                    ? const Color(0xFF00E676).withOpacity(0.5)
                    : Colors.white10,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: enabled ? const Color(0xFF00E676) : Colors.white24,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.outfit(
                      color: enabled ? Colors.white : Colors.white38,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: enabled ? const Color(0xFF00E676) : Colors.white12,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionBtn(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildCameraPreview(),
          _buildHeaderOverlay(),
          _buildInfoOverlay(),
          _buildActionButtons(),
          if (_isWatermarking)
            Positioned(
              bottom: 125,
              right: 20,
              child: Card(
                color: Colors.black54,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF00E676),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "Processando...",
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    return FutureBuilder<void>(
      future: _initializeControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return Center(child: CameraPreview(_controller));
        }
        return const Center(
          child: CircularProgressIndicator(color: Color(0xFF00E676)),
        );
      },
    );
  }

  Widget _buildHeaderOverlay() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _customTitle,
              style: GoogleFonts.outfit(
                color: const Color(0xFF00E676),
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            IconButton(
              icon: Icon(
                _flashMode == FlashMode.torch
                    ? Icons.flash_on
                    : Icons.flash_off,
                color: Colors.white,
              ),
              onPressed: () async {
                final next = _flashMode == FlashMode.off
                    ? FlashMode.torch
                    : FlashMode.off;
                await _controller.setFlashMode(next);
                setState(() => _flashMode = next);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoOverlay() {
    return Positioned(
      bottom: 140,
      left: 15,
      right: 15,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // DATA E HORA ao vivo
                  if (_settings['showTime']!) ...[
                    Row(
                      children: [
                        Text(
                          _currentTimeString.isEmpty
                              ? '--:--'
                              : _currentTimeString,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 2,
                          height: 22,
                          color: const Color(0xFF00E676),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentDateString.isEmpty
                                  ? '-- --- ----'
                                  : _currentDateString,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              _currentDayString.toUpperCase(),
                              style: GoogleFonts.outfit(
                                color: Colors.white54,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (_settings['showCoords']!)
                    Text(
                      _currentPosition != null
                          ? "${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}"
                          : "Obtendo GPS...",
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF00E676),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (_settings['showAltitude']!)
                    Text(
                      _currentPosition != null
                          ? "ALT: ${_currentPosition!.altitude.toStringAsFixed(1)}m ACC: ${_currentPosition!.accuracy.toStringAsFixed(1)}m"
                          : "Calculando altitude...",
                      style: GoogleFonts.outfit(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(height: 10),
                  if (_settings['showAddress']!)
                    Text(
                      _currentAddress,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (_settings['showMap']! && _currentPosition != null)
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFF00E676),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.5),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: ll.LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                      initialZoom: 15,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: ll.LatLng(
                              _currentPosition!.latitude,
                              _currentPosition!.longitude,
                            ),
                            width: 30,
                            height: 30,
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 30,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          GestureDetector(
            onTap: () {
              // Toque simples: abrir última foto tirada
              if (_lastPhotoPath != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PhotoPreviewScreen(
                      path: _lastPhotoPath!,
                      lat: _lastLat,
                      lon: _lastLon,
                      address: _lastAddr,
                    ),
                  ),
                );
              } else {
                // Se não há foto ainda, abrir galeria
                _openGalleryAndShare();
              }
            },
            onLongPress:
                _openGalleryAndShare, // Toque longo: escolher da galeria
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 2),
                    image: _lastPhotoPath != null
                        ? DecorationImage(
                            image: FileImage(File(_lastPhotoPath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _lastPhotoPath == null
                      ? const Icon(Icons.photo_library, color: Colors.white)
                      : null,
                ),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.collections_rounded,
                    color: Colors.black,
                    size: 12,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _takePicture,
            child: Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: Center(
                child: Container(
                  height: 65,
                  width: 65,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF00E676),
                  ),
                  child: _isProcessingRaw
                      ? const Padding(
                          padding: EdgeInsets.all(15),
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 3,
                          ),
                        )
                      : const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.black,
                          size: 30,
                        ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 35),
            onPressed: _showEditModel,
          ),
        ],
      ),
    );
  }
}

class PhotoPreviewScreen extends StatelessWidget {
  final String path;
  final double? lat;
  final double? lon;
  final String? address;

  const PhotoPreviewScreen({
    super.key,
    required this.path,
    this.lat,
    this.lon,
    this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () {
              String shareText =
                  "Confira esta foto verificada pelo MarkPro Camera!";
              if (lat != null && lon != null) {
                shareText += "\n\n📍 Localização: $address";
                shareText +=
                    "\n🌍 Ver no Maps: https://www.google.com/maps/search/?api=1&query=$lat,$lon";
              }
              Share.shareXFiles([XFile(path)], text: shareText);
            },
          ),
        ],
      ),
      body: Center(child: InteractiveViewer(child: Image.file(File(path)))),
    );
  }
}
