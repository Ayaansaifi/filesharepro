class AppConstants {
  AppConstants._();

  // ─── Gemini AI ──────────────────────────────────────────
  /// Replace with your real Gemini API key from https://aistudio.google.com/
  /// Or set via Settings screen for user-provided keys.
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );
  static const String geminiModel = 'gemini-1.5-flash';
  static const int aiRollingContextMax = 5; // max chat history items kept in RAM

  // ─── Stories (Ephemeral Cache) ───────────────────────────
  static const int storyExpiryHours = 24;
  static const int storyMaxCount = 30; // max stories per device before FIFO deletion
  static const int storyCleanupIntervalMin = 30; // periodic cleanup every 30 min
  static const String storyCacheDir = 'filesharepro_stories';
  static const String storyMetaKey = 'ephemeral_stories_meta';

  // ─── App Info ────────────────────────────────────────────
  static const String appName = 'FileShare Pro';
  static const String appVersion = '1.2.0';
  static const String appPackage = 'com.filesharepro.filesharepro';

  // ─── WebRTC STUN/TURN (long-distance P2P) ─────────────────
  static const List<Map<String, dynamic>> iceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
    {'urls': 'stun:stun.cloudflare.com:3478'},
    // WARNING: Public TURN relay (openrelay.metered.ca).
    // These are public demo credentials that may have bandwidth limits
    // or stop working. It is highly recommended to replace these with
    // your own metered.ca (or Twilio) TURN server credentials in production.
    {
      'urls': 'turn:openrelay.metered.ca:80',
      'username': 'openrelayproject',
      'credential': 'openrelayproject',
    },
    {
      'urls': 'turn:openrelay.metered.ca:443',
      'username': 'openrelayproject',
      'credential': 'openrelayproject',
    },
    {
      'urls': 'turn:openrelay.metered.ca:443?transport=tcp',
      'username': 'openrelayproject',
      'credential': 'openrelayproject',
    },
  ];

  // ─── Transfer Settings ──────────────────────────────────
  static const int nearbyChunkSize = 65536; // 64KB Wi‑Fi Direct
  static const int webrtcChunkSize = 65536; // 64KB — faster for movies
  static const int webrtcChunkDelayEvery = 20; // pause every N chunks (backpressure)
  static const int webrtcMaxBufferedAmount = 512 * 1024; // 512KB buffer window
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
  static const String supportEmail = 'filesharepro.support@gmail.com';
  static const String privacyPolicyUrl =
      'https://ayaansaifi.github.io/filesharepro/privacy_policy/';
  static const String termsUrl =
      'https://ayaansaifi.github.io/filesharepro/terms_and_conditions/';

  /// WARNING: Currently using Google AdMob TEST IDs because real IDs are not available.
  /// You MUST replace these with your real AdMob App ID and Banner Unit ID
  /// before submitting the final APK/AAB to the Google Play Store to earn revenue.
  /// (Using test IDs in production won't cause immediate rejection, but you won't earn money).
  static const String admobAppId = String.fromEnvironment(
    'ADMOB_APP_ID',
    defaultValue: 'ca-app-pub-3940256099942544~3347511713',
  );
  static const String admobBannerId = String.fromEnvironment(
    'ADMOB_BANNER_ID',
    defaultValue: 'ca-app-pub-3940256099942544/6300978111',
  );

  // ─── Signaling Room Code ────────────────────────────────
  static const int roomCodeLength = 6;
  static const String roomCodeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
}
