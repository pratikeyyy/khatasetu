import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../core/theme/app_theme.dart';
import '../providers/scan_provider.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  XFile? _pickedImage;
  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickFromCamera() async {
    final file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        _pickedImage = file;
        _imageBytes = bytes;
      });
    }
  }

  Future<void> _pickFromGallery() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        _pickedImage = file;
        _imageBytes = bytes;
      });
    }
  }

  Future<void> _handleScan() async {
    if (_pickedImage == null) return;

    final scan = await ref.read(scanProvider.notifier).uploadKhataImage(_pickedImage!);
    if (scan != null && mounted) {
      context.pushReplacement("/scan-review/${scan.id}");
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(scanProvider);
    final isProcessing = scanState.step != ScanProcessingStep.idle &&
        scanState.step != ScanProcessingStep.success &&
        scanState.step != ScanProcessingStep.error;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("कागज़ी खाता स्कैन करें", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            Text("Scan Paper Khata with Gemini AI", style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: isProcessing ? null : () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Image Preview (Web and Mobile compatible using memory bytes) ──
              Expanded(
                child: _pickedImage == null || _imageBytes == null
                    ? _buildPickerPrompt()
                    : _buildImagePreview(),
              ),

              // ─── Processing Steps Indicator ──────────────────────────────────
              if (isProcessing || scanState.step == ScanProcessingStep.error) ...[
                const SizedBox(height: 16),
                _buildProcessingSteps(scanState.step),
              ],

              // ─── Error ──────────────────────────────────────────────────────
              if (scanState.errorMessage != null && !isProcessing) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.creditRed, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          scanState.errorMessage!,
                          style: const TextStyle(color: AppColors.creditRed, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // ─── Action Buttons ──────────────────────────────────────────────
              if (!isProcessing) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isProcessing ? null : _pickFromCamera,
                        icon: const Icon(Icons.camera_alt_rounded, size: 20),
                        label: const Text("कैमरा (Camera)"),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isProcessing ? null : _pickFromGallery,
                        icon: const Icon(Icons.photo_library_rounded, size: 20),
                        label: const Text("गैलरी (Gallery)"),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: (_pickedImage == null || isProcessing) ? null : _handleScan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
                  label: const Text(
                    "AI से खाता पढ़ें / Scan with AI",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ),
              ] else ...[
                // Loading Status Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        scanState.statusMessage.isNotEmpty
                            ? scanState.statusMessage
                            : "खाता पढ़ा जा रहा है...",
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickerPrompt() {
    return GestureDetector(
      onTap: _pickFromCamera,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.3),
            width: 2,
            strokeAlign: BorderSide.strokeAlignCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_a_photo_outlined, color: AppColors.primary, size: 48),
            ),
            const SizedBox(height: 18),
            const Text(
              "कागज़ी खाते की फोटो लें या अपलोड करें",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              "Photograph your khata register page and AI will extract all entries",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  _tipRow(Icons.wb_sunny_outlined, "अच्छी रोशनी में फोटो लें (Good Lighting)"),
                  _tipRow(Icons.straighten_rounded, "कैमरा पेज के सीधा ऊपर रखें (Hold Flat)"),
                  _tipRow(Icons.text_fields_rounded, "सुनिश्चित करें कि हस्तलिखित अक्षर साफ दिखें (Clear Text)"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 4))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Memory image works on Web, Android, iOS without dart:io File errors!
            Image.memory(_imageBytes!, fit: BoxFit.cover),
            // Re-pick overlay button
            Positioned(
              top: 12,
              right: 12,
              child: GestureDetector(
                onTap: _pickFromGallery,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.sync_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text("फोटो बदलें", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingSteps(ScanProcessingStep step) {
    final steps = [
      (ScanProcessingStep.uploading, Icons.upload_rounded, "अपलोड हो रहा है (Uploading)"),
      (ScanProcessingStep.aiProcessing, Icons.auto_awesome_rounded, "AI हस्तलेखन पहचान रहा है (AI Extracting)"),
      (ScanProcessingStep.validating, Icons.check_circle_outline_rounded, "विश्वास स्कोर व मिलान (Validating)"),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
      ),
      child: Column(
        children: steps.map((s) {
          final isDone = step.index > s.$1.index;
          final isCurrent = step == s.$1;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                if (isDone)
                  const Icon(Icons.check_circle_rounded, color: AppColors.paymentGreen, size: 18)
                else if (isCurrent)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                else
                  const Icon(Icons.radio_button_unchecked_rounded, color: AppColors.textMuted, size: 18),
                const SizedBox(width: 10),
                Text(
                  s.$3,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                    color: isCurrent ? AppColors.primary : isDone ? AppColors.paymentGreen : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _tipRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
        ],
      ),
    );
  }
}
