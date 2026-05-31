import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/vault_service.dart';

/// Provider for VaultService singleton
final vaultServiceProvider = Provider<VaultService>((ref) {
  return VaultService();
});

/// Provider for vault state
final vaultProvider = StateNotifierProvider<VaultNotifier, VaultState>((ref) {
  final service = ref.watch(vaultServiceProvider);
  return VaultNotifier(service);
});

class VaultNotifier extends StateNotifier<VaultState> {
  final VaultService _service;

  VaultNotifier(this._service) : super(VaultState.initial()) {
    _init();
  }

  Future<void> _init() async {
    final isSetup = await _service.isVaultSetup();
    state = state.copyWith(isSetup: isSetup, isLoading: false);
  }

  Future<bool> setupVault(String pin) async {
    await _service.setupVault(pin);
    state = state.copyWith(isSetup: true, isLocked: false, currentPin: pin);
    await loadItems();
    return true;
  }

  Future<bool> unlock(String pin) async {
    final valid = await _service.verifyPin(pin);
    if (valid) {
      state = state.copyWith(isLocked: false, currentPin: pin);
      await loadItems();
    }
    return valid;
  }

  void lock() {
    state = state.copyWith(isLocked: true, currentPin: null);
  }

  Future<void> loadItems() async {
    final items = await _service.getVaultItems();
    final stats = await _service.getVaultStats();
    state = state.copyWith(items: items, stats: stats);
  }

  Future<bool> addFile(File file) async {
    if (state.currentPin == null) return false;
    final item = await _service.addToVault(file, state.currentPin!);
    if (item != null) {
      await loadItems();
      return true;
    }
    return false;
  }

  Future<int> addFiles(List<File> files) async {
    if (state.currentPin == null) return 0;
    int added = 0;
    for (final file in files) {
      final item = await _service.addToVault(file, state.currentPin!);
      if (item != null) added++;
    }
    await loadItems();
    return added;
  }

  Future<Uint8List?> decryptFile(VaultItem item) async {
    if (state.currentPin == null) return null;
    return await _service.decryptVaultFile(item, state.currentPin!);
  }

  Future<File?> exportFile(VaultItem item) async {
    if (state.currentPin == null) return null;
    return await _service.exportFromVault(item, state.currentPin!);
  }

  Future<void> deleteFile(VaultItem item) async {
    await _service.removeFromVault(item);
    await loadItems();
  }
}

/// Immutable state for the Vault screen
class VaultState {
  final bool isSetup;
  final bool isLocked;
  final bool isLoading;
  final String? currentPin;
  final List<VaultItem> items;
  final Map<String, dynamic> stats;

  const VaultState({
    required this.isSetup,
    required this.isLocked,
    required this.isLoading,
    this.currentPin,
    required this.items,
    required this.stats,
  });

  factory VaultState.initial() => const VaultState(
    isSetup: false,
    isLocked: true,
    isLoading: true,
    items: [],
    stats: {},
  );

  VaultState copyWith({
    bool? isSetup,
    bool? isLocked,
    bool? isLoading,
    String? currentPin,
    List<VaultItem>? items,
    Map<String, dynamic>? stats,
  }) {
    return VaultState(
      isSetup: isSetup ?? this.isSetup,
      isLocked: isLocked ?? this.isLocked,
      isLoading: isLoading ?? this.isLoading,
      currentPin: currentPin ?? this.currentPin,
      items: items ?? this.items,
      stats: stats ?? this.stats,
    );
  }

  int get totalFiles => stats['totalFiles'] as int? ?? 0;
  int get imageCount => stats['images'] as int? ?? 0;
  int get videoCount => stats['videos'] as int? ?? 0;
  int get docCount => stats['documents'] as int? ?? 0;
  int get totalSize => stats['totalSize'] as int? ?? 0;
}
