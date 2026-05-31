import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/status_saver_service.dart';
import '../../../core/utils/file_utils.dart';

/// Provider for StatusSaverService singleton
final statusSaverServiceProvider = Provider<StatusSaverService>((ref) {
  return StatusSaverService();
});

/// Provider for status saver state
final statusSaverProvider = StateNotifierProvider<StatusSaverNotifier, StatusSaverState>((ref) {
  final service = ref.watch(statusSaverServiceProvider);
  return StatusSaverNotifier(service);
});

class StatusSaverNotifier extends StateNotifier<StatusSaverState> {
  final StatusSaverService _service;

  StatusSaverNotifier(this._service) : super(StatusSaverState.initial()) {
    _init();
  }

  Future<void> _init() async {
    final hasPerm = await _service.hasPermission();
    state = state.copyWith(hasPermission: hasPerm, isLoading: false);
    if (hasPerm) await loadStatuses();
  }

  Future<void> requestPermission() async {
    final granted = await _service.requestPermission();
    state = state.copyWith(hasPermission: granted);
    if (granted) await loadStatuses();
  }

  Future<void> loadStatuses() async {
    state = state.copyWith(isLoading: true);
    final statuses = await _service.getStatuses();
    
    final images = statuses.where((f) => FileUtils.isImage(f.path)).toList();
    final videos = statuses.where((f) => FileUtils.isVideo(f.path)).toList();
    
    state = state.copyWith(
      imageStatuses: images,
      videoStatuses: videos,
      isLoading: false,
    );
  }

  Future<bool> saveStatus(File file) async {
    return await _service.saveStatus(file);
  }

  Future<int> saveMultiple(List<File> files) async {
    int saved = 0;
    for (final file in files) {
      final success = await _service.saveStatus(file);
      if (success) saved++;
    }
    return saved;
  }

  void toggleSelection(int index) {
    final current = Set<int>.from(state.selectedIndices);
    if (current.contains(index)) {
      current.remove(index);
    } else {
      current.add(index);
    }
    state = state.copyWith(
      selectedIndices: current,
      isSelectionMode: current.isNotEmpty,
    );
  }

  void clearSelection() {
    state = state.copyWith(
      selectedIndices: {},
      isSelectionMode: false,
    );
  }
}

/// Immutable state for Status Saver screen
class StatusSaverState {
  final bool hasPermission;
  final bool isLoading;
  final List<File> imageStatuses;
  final List<File> videoStatuses;
  final Set<int> selectedIndices;
  final bool isSelectionMode;

  const StatusSaverState({
    required this.hasPermission,
    required this.isLoading,
    required this.imageStatuses,
    required this.videoStatuses,
    required this.selectedIndices,
    required this.isSelectionMode,
  });

  factory StatusSaverState.initial() => const StatusSaverState(
    hasPermission: false,
    isLoading: true,
    imageStatuses: [],
    videoStatuses: [],
    selectedIndices: {},
    isSelectionMode: false,
  );

  StatusSaverState copyWith({
    bool? hasPermission,
    bool? isLoading,
    List<File>? imageStatuses,
    List<File>? videoStatuses,
    Set<int>? selectedIndices,
    bool? isSelectionMode,
  }) {
    return StatusSaverState(
      hasPermission: hasPermission ?? this.hasPermission,
      isLoading: isLoading ?? this.isLoading,
      imageStatuses: imageStatuses ?? this.imageStatuses,
      videoStatuses: videoStatuses ?? this.videoStatuses,
      selectedIndices: selectedIndices ?? this.selectedIndices,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
    );
  }
}
