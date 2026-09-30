import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/scan_model.dart';

enum ScanProcessingStep {
  idle,
  uploading,
  aiProcessing,
  validating,
  success,
  error,
}

class ScanState {
  final ScanProcessingStep step;
  final String statusMessage;
  final ScanModel? currentScan;
  final List<ScanModel> scanHistory;
  final String? errorMessage;

  ScanState({
    this.step = ScanProcessingStep.idle,
    this.statusMessage = "",
    this.currentScan,
    this.scanHistory = const [],
    this.errorMessage,
  });

  bool get isLoading =>
      step == ScanProcessingStep.uploading ||
      step == ScanProcessingStep.aiProcessing ||
      step == ScanProcessingStep.validating;

  ScanState copyWith({
    ScanProcessingStep? step,
    String? statusMessage,
    ScanModel? currentScan,
    List<ScanModel>? scanHistory,
    String? errorMessage,
  }) {
    return ScanState(
      step: step ?? this.step,
      statusMessage: statusMessage ?? this.statusMessage,
      currentScan: currentScan ?? this.currentScan,
      scanHistory: scanHistory ?? this.scanHistory,
      errorMessage: errorMessage,
    );
  }
}

class ScanNotifier extends StateNotifier<ScanState> {
  static const String _cacheKey = "cached_scan_history";

  ScanNotifier() : super(ScanState()) {
    fetchScanHistory();
  }

  Future<ScanModel?> uploadKhataImage(XFile imageFile) async {
    state = state.copyWith(
      step: ScanProcessingStep.uploading,
      statusMessage: "Uploading paper khata photo...",
      errorMessage: null,
    );

    try {
      final bytes = await imageFile.readAsBytes();

      final filename =
          imageFile.name.isNotEmpty ? imageFile.name : "paper_khata.jpg";

      final formData = FormData.fromMap({
        "file": MultipartFile.fromBytes(
          bytes,
          filename: filename,
        ),
      });

      state = state.copyWith(
        step: ScanProcessingStep.aiProcessing,
        statusMessage: "Analyzing handwriting with Gemini Vision AI...",
      );

      // REAL backend + REAL Gemini OCR.
      final resp = await ApiClient.client.post(
        ApiConstants.uploadScan,
        data: formData,
      );

      state = state.copyWith(
        step: ScanProcessingStep.validating,
        statusMessage: "Validating confidence scores and ledger matching...",
      );

      final data = Map<String, dynamic>.from(resp.data);

      final scan = ScanModel.fromJson(data);

      await _saveScanToLocalCache(data);

      state = state.copyWith(
        step: ScanProcessingStep.success,
        statusMessage: "Extracted ${scan.totalEntries} entries successfully!",
        currentScan: scan,
        scanHistory: [
          scan,
          ...state.scanHistory.where((s) => s.id != scan.id),
        ],
      );

      return scan;
    } on DioException catch (e) {
      state = state.copyWith(
        step: ScanProcessingStep.error,
        errorMessage: e.error?.toString() ??
            "Could not extract entries. Internet connection is required for AI scanning.",
      );

      return null;
    } catch (e) {
      state = state.copyWith(
        step: ScanProcessingStep.error,
        errorMessage: e.toString(),
      );

      return null;
    }
  }

  Future<void> fetchScanHistory() async {
    try {
      // First load locally so scans remain visible without laptop.
      final localScans = await _loadLocalScanHistory();

      if (localScans.isNotEmpty) {
        state = state.copyWith(
          scanHistory: localScans,
        );
      }

      // Then refresh from real backend when internet is available.
      final resp = await ApiClient.client.get(
        ApiConstants.scans,
      );

      final list = (resp.data as List)
          .map(
            (s) => ScanModel.fromJson(
              Map<String, dynamic>.from(s),
            ),
          )
          .toList();

      state = state.copyWith(
        scanHistory: list,
      );

      await _replaceLocalCache(resp.data);
    } catch (_) {
      // Offline:
      // local cached scans remain available.
    }
  }

  Future<void> loadScan(int scanId) async {
    // Try local cache first.
    final local = state.scanHistory.where(
      (scan) => scan.id == scanId,
    );

    if (local.isNotEmpty) {
      state = state.copyWith(
        currentScan: local.first,
      );
    }

    try {
      // Refresh from real backend if available.
      final resp = await ApiClient.client.get(
        "${ApiConstants.scans}$scanId",
      );

      final scan = ScanModel.fromJson(
        Map<String, dynamic>.from(resp.data),
      );

      state = state.copyWith(
        currentScan: scan,
      );

      await _saveScanToLocalCache(
        Map<String, dynamic>.from(resp.data),
      );
    } catch (_) {
      // Local scan stays available offline.
    }
  }

  Future<bool> confirmEntry(
    int scanId,
    int entryId, {
    int? customerId,
  }) async {
    try {
      final resp = await ApiClient.client.post(
        "${ApiConstants.scans}entries/$entryId/confirm",
        data: customerId != null ? {"customer_id": customerId} : null,
      );

      final updatedEntry = ScanEntryModel.fromJson(
        Map<String, dynamic>.from(resp.data),
      );

      _replaceEntryInCurrentScan(updatedEntry);

      await _updateCachedCurrentScan();

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> editAndConfirmEntry(
    int scanId,
    int entryId, {
    String? customerName,
    double? amount,
    String? transactionType,
    DateTime? date,
    String? notes,
    int? customerId,
  }) async {
    try {
      final resp = await ApiClient.client.post(
        "${ApiConstants.scans}entries/$entryId/edit-and-confirm",
        data: {
          "customer_name": customerName ?? "Unknown",
          "amount": amount ?? 0.0,
          "transaction_type": transactionType ?? "CREDIT",
          if (date != null) "date": date.toIso8601String(),
          if (notes != null) "notes": notes,
          if (customerId != null) "customer_id": customerId,
        },
      );

      final updatedEntry = ScanEntryModel.fromJson(
        Map<String, dynamic>.from(resp.data),
      );

      _replaceEntryInCurrentScan(updatedEntry);

      await _updateCachedCurrentScan();

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> rejectEntry(
    int scanId,
    int entryId, {
    String? reason,
  }) async {
    try {
      final resp = await ApiClient.client.post(
        "${ApiConstants.scans}entries/$entryId/reject",
        data: {
          "reason": reason ?? "Rejected by shopkeeper",
        },
      );

      final updatedEntry = ScanEntryModel.fromJson(
        Map<String, dynamic>.from(resp.data),
      );

      _replaceEntryInCurrentScan(updatedEntry);

      await _updateCachedCurrentScan();

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> batchConfirmHighConfidence(
    int scanId,
  ) async {
    try {
      final resp = await ApiClient.client.post(
        ApiConstants.batchConfirmHigh,
        data: {
          "scan_id": scanId,
        },
      );

      await loadScan(scanId);

      final count = resp.data["confirmed_count"] ?? 0;

      return count > 0;
    } catch (_) {
      return false;
    }
  }

  void _replaceEntryInCurrentScan(
    ScanEntryModel updated,
  ) {
    if (state.currentScan == null) return;

    final current = state.currentScan!;

    final updatedEntries = current.entries.map((entry) {
      return entry.id == updated.id ? updated : entry;
    }).toList();

    final updatedScan = ScanModel(
      id: current.id,
      shopId: current.shopId,
      originalImageUrl: current.originalImageUrl,
      processedImageUrl: current.processedImageUrl,
      thumbnailUrl: current.thumbnailUrl,
      status: current.status,
      errorMessage: current.errorMessage,
      totalEntries: current.totalEntries,
      confirmedEntries: updatedEntries.where((e) => e.isConfirmed).length,
      highConfidenceEntries: current.highConfidenceEntries,
      modelName: current.modelName,
      processingTimeMs: current.processingTimeMs,
      createdAt: current.createdAt,
      entries: updatedEntries,
    );

    state = state.copyWith(
      currentScan: updatedScan,
      scanHistory: [
        updatedScan,
        ...state.scanHistory.where((s) => s.id != updatedScan.id),
      ],
    );
  }

  Future<void> _saveScanToLocalCache(
    Map<String, dynamic> scanJson,
  ) async {
    try {
      final prefs = await LocalStoragePrefs.instance;

      final existing = prefs.getStringList(_cacheKey) ?? [];

      final scanId = scanJson["id"]?.toString();

      final updated = <String>[];

      bool replaced = false;

      for (final item in existing) {
        try {
          final decoded = jsonDecode(item);

          if (decoded["id"]?.toString() == scanId) {
            updated.add(
              jsonEncode(scanJson),
            );
            replaced = true;
          } else {
            updated.add(item);
          }
        } catch (_) {
          updated.add(item);
        }
      }

      if (!replaced) {
        updated.insert(
          0,
          jsonEncode(scanJson),
        );
      }

      await prefs.setStringList(
        _cacheKey,
        updated,
      );
    } catch (_) {}
  }

  Future<void> _replaceLocalCache(
    dynamic scans,
  ) async {
    try {
      final prefs = await LocalStoragePrefs.instance;

      final list = (scans as List)
          .map(
            (item) => jsonEncode(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();

      await prefs.setStringList(
        _cacheKey,
        list,
      );
    } catch (_) {}
  }

  Future<List<ScanModel>> _loadLocalScanHistory() async {
    try {
      final prefs = await LocalStoragePrefs.instance;

      final cached = prefs.getStringList(_cacheKey) ?? [];

      final scans = <ScanModel>[];

      for (final item in cached) {
        try {
          final json = jsonDecode(item);

          scans.add(
            ScanModel.fromJson(
              Map<String, dynamic>.from(json),
            ),
          );
        } catch (_) {}
      }

      return scans;
    } catch (_) {
      return [];
    }
  }

  Future<void> _updateCachedCurrentScan() async {
    final scan = state.currentScan;

    if (scan == null) return;

    try {
      final prefs = await LocalStoragePrefs.instance;

      final cached = prefs.getStringList(_cacheKey) ?? [];

      final updated = <String>[];

      for (final item in cached) {
        try {
          final json = Map<String, dynamic>.from(
            jsonDecode(item),
          );

          if (json["id"]?.toString() == scan.id.toString()) {
            // Keep cache update simple:
            // server response remains authoritative.
            updated.add(item);
          } else {
            updated.add(item);
          }
        } catch (_) {
          updated.add(item);
        }
      }

      await prefs.setStringList(
        _cacheKey,
        updated,
      );
    } catch (_) {}
  }
}

class LocalStoragePrefs {
  static Future<dynamic> get instance async {
    final directory = await getApplicationDocumentsDirectory();

    return _SimplePrefs(directory);
  }
}

class _SimplePrefs {
  final Directory directory;

  _SimplePrefs(this.directory);

  Future<List<String>?> getStringList(
    String key,
  ) async {
    final file = File(
      "${directory.path}/$key.json",
    );

    if (!await file.exists()) {
      return null;
    }

    try {
      final content = await file.readAsString();
      final decoded = jsonDecode(content);

      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}

    return null;
  }

  Future<bool> setStringList(
    String key,
    List<String> value,
  ) async {
    final file = File(
      "${directory.path}/$key.json",
    );

    await file.writeAsString(
      jsonEncode(value),
    );

    return true;
  }
}

final scanProvider = StateNotifierProvider<ScanNotifier, ScanState>(
  (ref) => ScanNotifier(),
);
