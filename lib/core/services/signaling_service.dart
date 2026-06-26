import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class SignalingMessage {
  final String senderId;
  final String targetId;
  final String type;
  final Map<String, dynamic> data;

  SignalingMessage({
    required this.senderId,
    required this.targetId,
    required this.type,
    required this.data,
  });

  Map<String, dynamic> toJson() => {
        'senderId': senderId,
        'targetId': targetId,
        'type': type,
        'data': data,
      };

  factory SignalingMessage.fromJson(Map<String, dynamic> json) {
    return SignalingMessage(
      senderId: json['senderId'] ?? '',
      targetId: json['targetId'] ?? '',
      type: json['type'] ?? '',
      data: json['data'] ?? {},
    );
  }
}

class SignalingService {
  MqttServerClient? _client;
  String? _myId;
  bool _isConnected = false;

  // ── Reconnection state ──
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  bool _isDisposed = false;

  // ── Broker fallback list ──
  static const List<_BrokerConfig> _brokers = [
    _BrokerConfig(host: 'broker.hivemq.com', port: 1883, wsPort: 8884, useTls: true),
    _BrokerConfig(host: 'test.mosquitto.org', port: 1883, wsPort: 8081, useTls: false),
    _BrokerConfig(host: 'broker.emqx.io', port: 1883, wsPort: 8083, useTls: false),
  ];
  int _activeBrokerIndex = 0;

  Function(SignalingMessage)? onMessageReceived;
  Function(bool)? onConnectionStateChanged;

  bool get isConnected => _isConnected;
  String? get myId => _myId;

  Future<void> connect(String myPhoneId) async {
    if (_isConnected) return;

    _myId = myPhoneId;
    _isDisposed = false;
    _reconnectAttempts = 0;

    await _tryConnectToBroker();
  }

  /// Attempts to connect to brokers in order, with fallback
  Future<void> _tryConnectToBroker() async {
    if (_isDisposed || _isConnected) return;

    // Try each broker in sequence
    for (int i = 0; i < _brokers.length; i++) {
      final brokerIndex = (_activeBrokerIndex + i) % _brokers.length;
      final broker = _brokers[brokerIndex];

      final success = await _connectToSingleBroker(broker);
      if (success) {
        _activeBrokerIndex = brokerIndex;
        debugPrint('SignalingService: Connected to ${broker.host}');
        return;
      }

      debugPrint('SignalingService: Failed to connect to ${broker.host}, trying next...');
    }

    // All brokers failed — start reconnection loop
    _scheduleReconnect();
  }

  Future<bool> _connectToSingleBroker(_BrokerConfig broker) async {
    try {
      // Clean up old client if exists
      _cleanupClient();

      final clientId = 'fsp_${_myId}_${Random().nextInt(99999)}';

      // Browsers can ONLY speak WebSocket — raw TCP (port 1883) throws
      // "Unsupported operation: default SecurityContext getter" on the web.
      // Native platforms can use either, but WebSocket works everywhere and
      // keeps the behavior identical, so we use it on all platforms. TLS brokers
      // use wss://; plain brokers use ws://. The wsPort for each broker is
      // declared in _BrokerConfig.
      final isWeb = kIsWeb;
      final port = isWeb ? broker.wsPort : broker.port;

      if (broker.useTls) {
        _client = MqttServerClient.withPort(broker.host, clientId, port);
        _client!.useWebSocket = true;
        _client!.secure = true;
        _client!.onBadCertificate = (_) => true; // Allow self-signed certs for public brokers
      } else {
        _client = MqttServerClient.withPort(broker.host, clientId, port);
        _client!.useWebSocket = true;
      }

      _client!.logging(on: false);
      _client!.keepAlivePeriod = 30; // Reduced from 60 for faster disconnect detection
      _client!.onDisconnected = _onDisconnected;
      _client!.onConnected = _onConnected;
      _client!.onSubscribed = _onSubscribed;

      final connMess = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);
      _client!.connectionMessage = connMess;

      debugPrint('SignalingService: Connecting to ${broker.host}:$port '
          '(WebSocket ${broker.useTls ? "wss" : "ws"})...');
      await _client!.connect();

      if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
        _isConnected = true;
        _reconnectAttempts = 0;
        onConnectionStateChanged?.call(true);

        // Subscribe to my own topic to receive offers/answers
        final myTopic = 'filesharepro/signaling/$_myId';
        _client!.subscribe(myTopic, MqttQos.atLeastOnce);

        // Also subscribe to presence topic
        _client!.subscribe('filesharepro/presence/$_myId', MqttQos.atLeastOnce);

        _client!.updates!.listen(_handleIncomingMessage);

        return true;
      } else {
        _cleanupClient();
        return false;
      }
    } catch (e) {
      debugPrint('SignalingService: Exception connecting to ${broker.host}: $e');
      _cleanupClient();
      return false;
    }
  }

  void _handleIncomingMessage(List<MqttReceivedMessage<MqttMessage?>>? messages) {
    if (messages == null || messages.isEmpty) return;

    final received = messages[0];
    final topic = received.topic;

    // Skip presence messages
    if (topic.contains('/presence/')) return;

    final recMess = received.payload as MqttPublishMessage;
    final pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

    try {
      final json = jsonDecode(pt);
      final msg = SignalingMessage.fromJson(json);
      onMessageReceived?.call(msg);
    } catch (e) {
      debugPrint('SignalingService: Failed to parse message: $e');
    }
  }

  void _scheduleReconnect() {
    if (_isDisposed || _isConnected) return;

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('SignalingService: Max reconnection attempts reached');
      onConnectionStateChanged?.call(false);
      return;
    }

    // Exponential backoff: 3s, 6s, 12s, 24s, capped at 30s
    final delay = Duration(seconds: min(30, 3 * (1 << _reconnectAttempts)));
    _reconnectAttempts++;

    debugPrint('SignalingService: Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts/$_maxReconnectAttempts)');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () async {
      if (_isDisposed || _isConnected) return;

      // Try current broker first, then rotate to next
      await _tryConnectToBroker();
    });
  }

  void _onConnected() {
    debugPrint('SignalingService: Connected');
  }

  void _onDisconnected() {
    debugPrint('SignalingService: Disconnected');
    _isConnected = false;
    onConnectionStateChanged?.call(false);

    // Auto-reconnect
    if (!_isDisposed) {
      _scheduleReconnect();
    }
  }

  void _onSubscribed(String topic) {
    debugPrint('SignalingService: Subscribed to $topic');
  }

  void _cleanupClient() {
    try {
      _client?.disconnect();
    } catch (_) {}
    _client = null;
  }

  void sendMessage(SignalingMessage msg) {
    if (!_isConnected || _client == null) {
      debugPrint('SignalingService: Cannot send — not connected');
      return;
    }

    try {
      final targetTopic = 'filesharepro/signaling/${msg.targetId}';
      final builder = MqttClientPayloadBuilder();
      builder.addString(jsonEncode(msg.toJson()));

      _client!.publishMessage(targetTopic, MqttQos.atLeastOnce, builder.payload!);
    } catch (e) {
      debugPrint('SignalingService: Error sending message: $e');
    }
  }

  /// Publish presence update (online/offline)
  void publishPresence(bool isOnline) {
    if (!_isConnected || _client == null || _myId == null) return;

    try {
      final topic = 'filesharepro/presence/$_myId';
      final builder = MqttClientPayloadBuilder();
      builder.addString(jsonEncode({
        'userId': _myId,
        'online': isOnline,
        'timestamp': DateTime.now().toIso8601String(),
      }));

      // Use retained message so new subscribers get current status
      _client!.publishMessage(
        topic,
        MqttQos.atLeastOnce,
        builder.payload!,
        retain: true,
      );
    } catch (e) {
      debugPrint('SignalingService: Error publishing presence: $e');
    }
  }

  void disconnect() {
    publishPresence(false);
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _cleanupClient();
    _isConnected = false;
  }
}

class _BrokerConfig {
  final String host;
  final int port;
  final int wsPort;
  final bool useTls;

  const _BrokerConfig({
    required this.host,
    required this.port,
    required this.wsPort,
    required this.useTls,
  });
}
