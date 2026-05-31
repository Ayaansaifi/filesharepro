import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../models/contact_model.dart';
import '../providers/chat_provider.dart';

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
                    final filtered = contacts
                        .where((c) =>
                            c.displayName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                            c.phoneNumber.contains(_searchQuery))
                        .toList();
                        
                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          'No contacts found',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.textHint),
                        ),
                      );
                    }
                    
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        return _buildContactTile(filtered[index]);
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryCyan)),
                  error: (error, stack) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Unable to load contacts. Please grant permissions in settings.',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.error),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
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

  Widget _buildContactTile(AppContact contact) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        borderRadius: 16,
        onTap: () {
          // Since it's a P2P app, we invite them via SMS if they aren't paired yet
          final message = 'Let\'s chat securely on FileShare Pro! Download it here and enter my Room Code to connect.';
          Share.share(message);
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
            TextButton(
              onPressed: () {
                final message = 'Let\'s chat securely on FileShare Pro!';
                Share.share(message);
              },
              child: Text(
                'INVITE',
                style: AppTypography.labelMedium.copyWith(color: AppColors.primaryCyan),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
