import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/contact_model.dart';
import '../models/user_profile.dart';

class ContactsService {
  static const String _keyPairedContacts = 'paired_contacts';
  static const String _keyMyProfile = 'my_profile';

  final SharedPreferences _prefs;

  ContactsService(this._prefs);

  /// Request permissions and load all phone contacts
  Future<List<AppContact>> getPhoneContacts() async {
    if (!kIsWeb) {
      if (await Permission.contacts.request().isGranted) {
        final contacts = await FlutterContacts.getContacts(
            withProperties: true, withPhoto: false);
        return contacts.map((c) => AppContact.fromFlutterContact(c)).toList();
      }
    }
    return [];
  }

  /// Load paired contacts from local storage
  List<AppContact> getPairedContacts() {
    final jsonStr = _prefs.getString(_keyPairedContacts);
    if (jsonStr == null) return [];

    try {
      final List<dynamic> list = json.decode(jsonStr);
      return list.map((m) => AppContact.fromJson(m)).toList();
    } catch (e) {
      debugPrint('Error loading paired contacts: $e');
      return [];
    }
  }

  /// Save a paired contact
  Future<void> savePairedContact(AppContact contact) async {
    final paired = getPairedContacts();
    
    // Update if exists, otherwise add
    final index = paired.indexWhere((c) => c.deviceId == contact.deviceId);
    if (index >= 0) {
      paired[index] = contact;
    } else {
      paired.add(contact);
    }

    final jsonStr = json.encode(paired.map((c) => c.toJson()).toList());
    await _prefs.setString(_keyPairedContacts, jsonStr);
  }

  /// Delete a paired contact
  Future<void> deletePairedContact(String deviceId) async {
    final paired = getPairedContacts();
    paired.removeWhere((c) => c.deviceId == deviceId);
    
    final jsonStr = json.encode(paired.map((c) => c.toJson()).toList());
    await _prefs.setString(_keyPairedContacts, jsonStr);
  }

  // ─── User Profile Management ───────────────────────────────

  UserProfile? getMyProfile() {
    final jsonStr = _prefs.getString(_keyMyProfile);
    if (jsonStr == null) return null;

    try {
      return UserProfile.fromJson(json.decode(jsonStr));
    } catch (e) {
      debugPrint('Error loading my profile: $e');
      return null;
    }
  }

  Future<void> saveMyProfile(UserProfile profile) async {
    final jsonStr = json.encode(profile.toJson());
    await _prefs.setString(_keyMyProfile, jsonStr);
  }
}
