import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/transfer_manager.dart';
import '../../../core/services/local_network_service.dart';
import '../../chat/providers/chat_provider.dart';

/// TransferManager now uses the SHARED LocalNetworkService instance
/// (same as ChatService) so there is NO port conflict between
/// file-sharing and chat features.
final transferManagerProvider = Provider<TransferManager>((ref) {
  // Reuse the single shared network service from chat_provider
  final networkService = ref.watch(localNetworkServiceProvider);
  final manager = TransferManager(sharedNetworkService: networkService);
  ref.onDispose(() => manager.dispose());
  return manager;
});

final transferStateProvider =
    StateNotifierProvider<TransferStateNotifier, TransferUiState>((ref) {
  final manager = ref.watch(transferManagerProvider);
  return TransferStateNotifier(manager);
});

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
      connectionLink: _manager.connectionLink,
      answerLink: _manager.answerLink,
      currentFileName: _manager.currentFileName,
      filesSent: _manager.filesSent,
      totalFiles: _manager.totalFiles,
      encryptionEnabled: _manager.encryptionEnabled,
      discoveredDevices: _manager.discoveredDevices,
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

  void setReceiverDecryptPin(String? pin) {
    _manager.setReceiverDecryptPin(pin);
  }

  Future<void> startSending(List<File> files) async {
    await _manager.startSending(files);
    _syncState();
  }

  Future<void> startNearbyDiscovery() async {
    await _manager.startNearbyDiscovery();
    _syncState();
  }

  Future<void> connectAndSend(LocalDevice device) async {
    await _manager.connectAndSend(device);
    _syncState();
  }

  Future<void> startWebRTCReceiveFromLink(String link) async {
    await _manager.startWebRTCReceiveFromLink(link);
    _syncState();
  }

  Future<void> startWebRTCReceive(String roomCode) async {
    await _manager.startWebRTCReceive(roomCode);
    _syncState();
  }

  Future<bool> applyReceiverAnswer(String link) async {
    final ok = await _manager.applyReceiverAnswer(link);
    _syncState();
    return ok;
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

class TransferUiState {
  final TransferMode mode;
  final TransferState transferState;
  final double progress;
  final String statusMessage;
  final String? roomCode;
  final String? errorMessage;
  final String? connectionLink;
  final String? answerLink;
  final String? currentFileName;
  final int filesSent;
  final int totalFiles;
  final bool encryptionEnabled;
  final List<LocalDevice> discoveredDevices;

  const TransferUiState({
    required this.mode,
    required this.transferState,
    required this.progress,
    required this.statusMessage,
    this.roomCode,
    this.errorMessage,
    this.connectionLink,
    this.answerLink,
    this.currentFileName,
    this.filesSent = 0,
    this.totalFiles = 0,
    this.encryptionEnabled = false,
    this.discoveredDevices = const [],
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
  bool get isWaiting => transferState == TransferState.waiting;
}

final nearbyDevicesProvider =
    StateNotifierProvider<NearbyDevicesNotifier, List<LocalDevice>>((ref) {
  return NearbyDevicesNotifier();
});

class NearbyDevicesNotifier extends StateNotifier<List<LocalDevice>> {
  NearbyDevicesNotifier() : super([]);

  void addDevice(LocalDevice device) {
    if (!state.any((d) => d.id == device.id)) {
      state = [...state, device];
    }
  }

  void clear() {
    state = [];
  }
}
