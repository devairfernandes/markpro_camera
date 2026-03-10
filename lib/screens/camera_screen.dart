import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
import 'package:shared_preferences/shared_preferences.dart';
import '../services/location_service.dart';
import '../services/image_processor.dart';
import '../services/update_service.dart';

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
  String? _customLogoPath;

  Map<String, bool> _settings = {
    'showTime': true,
    'showAddress': true,
    'showMap': true,
    'showLogo': true,
    'showCoords': true,
    'showAltitude': true,
  };

  @override
  void initState() {
    super.initState();
    _initCamera(_selectedCameraIndex);
    _startTimer();
    _updateLocation();
    _loadSettings();

    // VERIFICAR ATUALIZAÇÃO NO LANÇAMENTO
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkUpdate(context);
    });
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
      ).then((resultPath) {
        if (mounted) {
          setState(() {
            _isWatermarking = false;
            if (resultPath != null) _lastPhotoPath = resultPath;
          });
        }
      });
    } catch (e) {
      setState(() => _isProcessingRaw = false);
    }
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

  void _exportConfig() {
    final String config = jsonEncode({'settings': _settings, 'version': '1.0'});
    Share.share(config, subject: 'Minhas Configurações MarkPro Camera');
  }

  void _importConfig() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Importar Configuração"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "Cole o código de configuração aqui",
          ),
          maxLines: 5,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () {
              try {
                final Map<String, dynamic> data = jsonDecode(controller.text);
                if (data.containsKey('settings')) {
                  setState(() {
                    _settings = (data['settings'] as Map<String, dynamic>).map(
                      (k, v) => MapEntry(k, v as bool),
                    );
                  });
                  _saveSettings();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Configurações importadas!")),
                  );
                }
              } catch (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Código inválido!")),
                );
              }
            },
            child: const Text("Importar"),
          ),
        ],
      ),
    );
  }

  void _showEditModel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Editar modelo",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  _buildToggleItem(
                    "Hora: $_currentTimeString",
                    "showTime",
                    setModalState,
                  ),
                  _buildToggleItem("Endereço", "showAddress", setModalState),
                  _buildToggleItem("Mapa", "showMap", setModalState),
                  _buildToggleItem("Lat/Long", "showCoords", setModalState),
                  _buildToggleItem("Altitude", "showAltitude", setModalState),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      "Logo",
                      style: TextStyle(fontSize: 14, color: Colors.black),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_customLogoPath != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.file(
                              File(_customLogoPath!),
                              width: 30,
                              height: 30,
                              fit: BoxFit.cover,
                            ),
                          ),
                        const SizedBox(width: 8),
                        Switch(
                          value: _settings['showLogo']!,
                          activeThumbColor: const Color(0xFF00E676),
                          onChanged: (val) {
                            setModalState(() => _settings['showLogo'] = val);
                            setState(() => _settings['showLogo'] = val);
                            _saveSettings();
                          },
                        ),
                      ],
                    ),
                    onTap: () async {
                      await _pickLogo();
                      setModalState(() {});
                    },
                  ),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _exportConfig,
                          icon: const Icon(Icons.ios_share, size: 18),
                          label: const Text("Exportar"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _importConfig,
                          icon: const Icon(Icons.input, size: 18),
                          label: const Text("Importar"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildToggleItem(String label, String key, StateSetter setModalState) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: const TextStyle(fontSize: 14, color: Colors.black),
      ),
      trailing: Switch(
        value: _settings[key]!,
        activeThumbColor: const Color(0xFF00E676),
        onChanged: (val) {
          setModalState(() => _settings[key] = val);
          setState(() => _settings[key] = val);
          _saveSettings();
        },
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
              "MARKPRO CAMERA",
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
                  if (_settings['showTime']!)
                    Row(
                      children: [
                        Text(
                          _currentTimeString,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const VerticalDivider(
                          color: Color(0xFF00E676),
                          thickness: 2,
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentDateString,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              _currentDayString.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  if (_settings['showAddress']!)
                    Text(
                      _currentAddress,
                      style: const TextStyle(fontSize: 11, color: Colors.white),
                      maxLines: 2,
                    ),
                ],
              ),
            ),
            if (_currentPosition != null && _settings['showMap']!)
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
              if (_lastPhotoPath != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PhotoPreviewScreen(path: _lastPhotoPath!),
                  ),
                );
              }
            },
            child: Container(
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
  const PhotoPreviewScreen({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () => Share.shareXFiles([XFile(path)]),
          ),
        ],
      ),
      body: Center(child: InteractiveViewer(child: Image.file(File(path)))),
    );
  }
}
