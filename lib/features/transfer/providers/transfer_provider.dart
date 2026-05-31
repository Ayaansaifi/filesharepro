import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/transfer_manager.dart';
import '../services/nearby_service.dart';

/// Provider for the TransferManager singleton
final transferManagerProvider = Provider<TransferManager>((ref) {
  final manager = TransferManager();
  ref.onDispose(() => manager.dispose());
  return manager;
});

/// Provider for the current transfer state  
final transferStateProvider = StateNotifierProvider<TransferStateNotifier, TransferUiState>((ref) {
  final manager = ref.watch(transferManagerProvider);
  return TransferStateNotifier(manager);
});

/// Transfer state notifier for UI reactivity
class TransferStateNotifier extends StateNotifier<TransferUiState> {
  final TransferManager _manager;

  TransferStateNotifier(this._manager) : super(TransferUiState.initial()) {
    _manager.onStateChanged = _syncState;
  }

  void _syncState() {
    state = TransferUiState(
      mode: _manager.mode,
      transferState: _manager.state,
      progress: _manager.progress,
      statusMessage: _manager.statusMessage,
      roomCode: _manager.roomCode,
      errorMessage: _manager.errorMessage,
      currentFileName: _manager.currentFileName,
      filesSent: _manager.filesSent,
      totalFiles: _manager.totalFiles,
      encryptionEnabled: _manager.encryptionEnabled,
    );
  }

  void setMode(TransferMode mode) {
    _manager.setMode(mode);
    _syncState();
  }

  void setEncryption({required bool enabled, String? pin}) {
    _manager.setEncryption(enabled: enabled, pin: pin);
    _syncState();
  }

  Future<void> startSending(List<File> files) async {
    await _manager.startSending(files);
  }

  Future<void> startNearbyReceive(String address) async {
    await _manager.startNearbyReceive(address);
  }

  Future<void> startWebRTCReceive(String roomCode) async {
    await _manager.startWebRTCReceive(roomCode);
  }

  Future<void> cancel() async {
    await _manager.cancel();
    _syncState();
  }

  @override
  void dispose() {
    _manager.dispose();
    super.dispose();
  }
}

/// Immutable UI state for transfers
class TransferUiState {
  final TransferMode mode;
  final TransferState transferState;
  final double progress;
  final String statusMessage;
  final String? roomCode;
  final String? errorMessage;
  final String? currentFileName;
  final int filesSent;
  final int totalFiles;
  final bool encryptionEnabled;

  const TransferUiState({
    required this.mode,
    required this.transferState,
    required this.progress,
    required this.statusMessage,
    this.roomCode,
    this.errorMessage,
    this.currentFileName,
    this.filesSent = 0,
    this.totalFiles = 0,
    this.encryptionEnabled = false,
  });

  factory TransferUiState.initial() => const TransferUiState(
    mode: TransferMode.nearby,
    transferState: TransferState.idle,
    progress: 0,
    statusMessage: 'Ready to transfer',
  );

  bool get isIdle => transferState == TransferState.idle;
  bool get isTransferring => transferState == TransferState.transferring;
  bool get isCompleted => transferState == TransferState.completed;
  bool get hasError => transferState == TransferState.error;
}

/// Provider for discovered nearby devices
final nearbyDevicesProvider = StateNotifierProvider<NearbyDevicesNotifier, List<NearbyDevice>>((ref) {
  return NearbyDevicesNotifier();
});

class NearbyDevicesNotifier extends StateNotifier<List<NearbyDevice>> {
  NearbyDevicesNotifier() : super([]);

  void addDevice(NearbyDevice device) {
    // Avoid duplicates by address
    if (!state.any((d) => d.address == device.address)) {
      state = [...state, device];
    }
  }

  void clear() {
    state = [];
  }
}
