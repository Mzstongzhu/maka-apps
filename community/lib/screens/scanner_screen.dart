import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/qr_router.dart';

/// 扫一扫：相机实时扫码 + 相册选图识别。仅路由 makazs.xyz 本站链接。
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.trim().isNotEmpty, orElse: () => null);
    if (raw == null) return;
    _busy = true;
    await _controller.stop();
    if (!mounted) return;
    try {
      await handleScanned(context, raw);
    } finally {
      if (mounted) {
        await _controller.start();
        _busy = false;
      }
    }
  }

  Future<void> _pickFromAlbum() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final messenger = ScaffoldMessenger.of(context);
    BarcodeCapture? result;
    try {
      result = await _controller.analyzeImage(file.path);
    } catch (_) {
      result = null;
    }
    final raw = result?.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.trim().isNotEmpty, orElse: () => null);
    if (raw == null) {
      messenger.showSnackBar(const SnackBar(content: Text('图片中未识别到二维码')));
      return;
    }
    if (!mounted) return;
    await handleScanned(context, raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('扫一扫'),
        actions: [
          IconButton(
            tooltip: '相册识别',
            icon: const Icon(Icons.image_outlined),
            onPressed: _pickFromAlbum,
          ),
          IconButton(
            tooltip: '手电筒',
            icon: const Icon(Icons.flashlight_on_outlined),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.no_photography_outlined, size: 40, color: Colors.grey),
                  const SizedBox(height: 10),
                  Text('相机无法使用：${error.errorCode.name}',
                      style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white70, width: 2),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          Align(
            alignment: Alignment(0, 0.42),
            child: const Text(
              '将二维码放入框内即可识别\n仅支持玛卡之声本站链接',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 13, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}
