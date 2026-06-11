class AppConstants {
  AppConstants._();

  // ─── App Info ────────────────────────────────────────────
  static const String appName = 'FileShare Pro';
  static const String appVersion = '1.1.0';
  static const String appPackage = 'com.filesharepro.filesharepro';

  // ─── WebRTC STUN Servers (Free, No Database) ────────────
  static const List<Map<String, dynamic>> iceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
    {'urls': 'stun:stun2.l.google.com:19302'},
    {'urls': 'stun:stun3.l.google.com:19302'},
    {'urls': 'stun:stun4.l.google.com:19302'},
    {'urls': 'stun:stun.services.mozilla.com'},
    {'urls': 'stun:stun.cloudflare.com:3478'},
  ];

  // ─── Transfer Settings ──────────────────────────────────
  static const int nearbyChunkSize = 65536; // 64KB for Wi-Fi Direct
  static const int webrtcChunkSize = 16384; // 16KB for WebRTC DataChannel
  static const int maxRetries = 3;
  static const int connectionTimeoutSec = 30;
  static const int transferHistoryLimit = 50;

  // ─── Encryption Settings ────────────────────────────────
  static const int pbkdf2Iterations = 100000;
  static const int aesKeyLength = 32; // 256-bit
  static const int saltLength = 16;
  static const int ivLength = 16;
  static const List<int> magicBytes = [0x56, 0x4C, 0x54, 0x46]; // "VLTF"
  static const String encryptedExtension = '.vaultfile';

  // ─── WhatsApp Paths ─────────────────────────────────────
  static const List<String> whatsappStatusPaths = [
    'Android/media/com.whatsapp/WhatsApp/Media/.Statuses',
    'WhatsApp/Media/.Statuses',
  ];

  static const List<String> whatsappBusinessPaths = [
    'Android/media/com.whatsapp.w4b/WhatsApp Business/Media/.Statuses',
    'WhatsApp Business/Media/.Statuses',
  ];

  // ─── Vault Settings ─────────────────────────────────────
  static const String vaultDirName = '.secure_vault';
  static const String vaultMetaFile = 'vault_meta.json';
  static const String nomediaFile = '.nomedia';

  // ─── SharedPreferences Keys ─────────────────────────────
  static const String keyVaultPinHash = 'vault_pin_hash';
  static const String keyVaultSalt = 'vault_salt';
  static const String keySafUri = 'saf_uri';
  static const String keySafUriBusiness = 'saf_uri_business';
  static const String keyTransferHistory = 'transfer_history';
  static const String keyFirstLaunch = 'first_launch';
  static const String keyThemeMode = 'theme_mode';

  // ─── Signaling Room Code ────────────────────────────────
  static const int roomCodeLength = 6;
  static const String roomCodeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
}
