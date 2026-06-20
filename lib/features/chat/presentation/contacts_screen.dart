import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/utils/permission_utils.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../models/contact_model.dart';
import '../providers/chat_provider.dart';
import 'chat_room_screen.dart';
import 'discovery_screen.dart';
import 'widgets/connect_dialog.dart';

final futureContactsProvider = FutureProvider<List<AppContact>>((ref) async {
  final service = ref.watch(contactsServiceProvider);
  return service.getPhoneContacts();
});

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(futureContactsProvider);
    final pairedContacts = ref.watch(pairedContactsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              _buildSearchBar(),
              Expanded(
                child: contactsAsync.when(
                  data: (contacts) {
                    // Merge paired status into phone contacts
                    
                    // Split into paired and unpaired
                    final paired = <AppContact>[];
                    final unpaired = <AppContact>[];
                    
                    for (final contact in contacts) {
                      final matchedPaired = pairedContacts
                          .where((p) => p.phoneNumber == contact.phoneNumber || p.id == contact.id)
                          .toList();
                      
                      if (matchedPaired.isNotEmpty) {
                        // Merge paired data
                        paired.add(contact.copyWith(
                          deviceId: matchedPaired.first.deviceId,
                          roomCode: matchedPaired.first.roomCode,
                        ));
                      } else {
                        unpaired.add(contact);
                      }
                    }
                    
                    // Also add paired contacts not in phone contacts
                    for (final pc in pairedContacts) {
                      if (!contacts.any((c) => c.phoneNumber == pc.phoneNumber || c.id == pc.id)) {
                        paired.add(pc);
                      }
                    }
                    
                    // Apply search filter
                    final filteredPaired = paired.where((c) =>
                        c.displayName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                        c.phoneNumber.contains(_searchQuery)).toList();
                    final filteredUnpaired = unpaired.where((c) =>
                        c.displayName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                        c.phoneNumber.contains(_searchQuery)).toList();

                    if (filteredPaired.isEmpty && filteredUnpaired.isEmpty) {
                      return Center(
                        child: Text(
                          _searchQuery.isNotEmpty ? 'No contacts found' : 'No contacts available',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.textHint),
                        ),
                      );
                    }

                    return ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      children: [
                        // ── Paired Contacts (FileShare Pro Users) ──
                        if (filteredPaired.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.success,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'FileShare Pro Users (${filteredPaired.length})',
                                  style: AppTypography.labelMedium.copyWith(
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...filteredPaired.map((c) => _buildPairedContactTile(c)),
                          const SizedBox(height: 16),
                        ],
                        
                        // ── Unpaired Contacts (Invite) ──
                        if (filteredUnpaired.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
                            child: Text(
                              'Invite to FileShare Pro (${filteredUnpaired.length})',
                              style: AppTypography.labelMedium.copyWith(
                                color: AppColors.textHint,
                              ),
                            ),
                          ),
                          ...filteredUnpaired.map((c) => _buildInviteContactTile(c)),
                        ],
                      ],
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryCyan)),
                  error: (error, stack) {
                    final isPermissionDenied = error.toString().contains('permission_denied');
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.primaryCyan.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.contacts_rounded, color: AppColors.primaryCyan, size: 48),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              isPermissionDenied ? 'Access Your Contacts' : 'Unable to load contacts',
                              style: AppTypography.heading3,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isPermissionDenied
                                  ? 'FileShare Pro needs access to your contacts to display names instead of phone numbers.\n\nYour contacts remain securely on your device and are never uploaded to any server.'
                                  : 'An error occurred while loading contacts.',
                              style: AppTypography.bodySmall.copyWith(height: 1.5),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),
                            if (isPermissionDenied)
                              GradientButton(
                                label: 'Allow Access',
                                icon: Icons.check_circle_outline_rounded,
                                onPressed: () async {
                                  final granted = await PermissionUtils.requestContactsPermission(context);
                                  if (granted) {
                                    ref.invalidate(futureContactsProvider);
                                  }
                                },
                              )
                            else
                              ElevatedButton(
                                onPressed: () => ref.invalidate(futureContactsProvider),
                                child: const Text('Retry'),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      // FAB to create new room
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.mediumImpact();
          _showCreateRoomDialog(context);
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        label: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryCyan.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('New Room',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          GlassCard(
            padding: const EdgeInsets.all(10),
            borderRadius: 14,
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Select Contact', style: AppTypography.heading3),
                Consumer(builder: (context, ref, child) {
                  final contactsAsync = ref.watch(futureContactsProvider);
                  return Text(
                    contactsAsync.maybeWhen(
                      data: (contacts) => '${contacts.length} contacts',
                      orElse: () => 'Loading...',
                    ),
                    style: AppTypography.caption.copyWith(color: AppColors.primaryCyan),
                  );
                }),
              ],
            ),
          ),
          GlassCard(
            padding: const EdgeInsets.all(10),
            borderRadius: 14,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DiscoveryScreen()));
            },
            child: const Icon(Icons.radar_rounded, color: AppColors.primaryCyan, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        borderRadius: 16,
        child: TextField(
          style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            icon: const Icon(Icons.search_rounded, color: AppColors.textHint, size: 20),
            hintText: 'Search contacts...',
            hintStyle: AppTypography.bodySmall.copyWith(color: AppColors.textHint),
            border: InputBorder.none,
          ),
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
      ),
    );
  }

  /// Paired contact — tap to open chat directly
  Widget _buildPairedContactTile(AppContact contact) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        borderRadius: 16,
        onTap: () {
          HapticFeedback.lightImpact();
          if (contact.roomCode != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatRoomScreen(roomCode: contact.roomCode!),
              ),
            );
          } else {
            // Create a room for this contact
            _createRoomForContact(contact);
          }
        },
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  contact.displayName.isNotEmpty ? contact.displayName[0].toUpperCase() : '?',
                  style: AppTypography.heading3.copyWith(color: Colors.white, fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          contact.displayName,
                          style: AppTypography.labelLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Paired',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.success,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    contact.phoneNumber.isNotEmpty ? contact.phoneNumber : 'Tap to chat',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chat_rounded, color: AppColors.primaryCyan, size: 20),
          ],
        ),
      ),
    );
  }

  /// Unpaired contact — show invite button
  Widget _buildInviteContactTile(AppContact contact) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        borderRadius: 16,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  contact.displayName.isNotEmpty ? contact.displayName[0].toUpperCase() : '?',
                  style: AppTypography.heading3.copyWith(
                    color: AppColors.textHint,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.displayName,
                    style: AppTypography.labelLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    contact.phoneNumber,
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                final message = 'Hey! Let\'s chat securely on FileShare Pro! Download it and we can share files instantly. 🚀\n\nhttps://play.google.com/store/apps/details?id=com.filesharepro.filesharepro';
                Share.share(message, subject: 'Join me on FileShare Pro');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'INVITE',
                  style: AppTypography.labelMedium.copyWith(
                    color: Colors.white,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createRoomForContact(AppContact contact) async {
    final chatRooms = ref.read(chatRoomsProvider.notifier);
    final code = await chatRooms.createRoom(contact.displayName);
    if (code != null && mounted) {
      // Save paired contact with room code
      final pairedContact = contact.copyWith(roomCode: code);
      await ref.read(contactsServiceProvider).savePairedContact(pairedContact);
      
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatRoomScreen(roomCode: code),
        ),
      );
    }
  }

  void _showCreateRoomDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ConnectDialog(isJoin: false),
    );
  }
}
