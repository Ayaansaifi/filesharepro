import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../features/chat/models/user_profile.dart';

class LocalDevice {
  final String id;
  final String name;
  final String ip;
  final int lastSeen;

  LocalDevice({
    required this.id,
    required this.name,
    required this.ip,
    required this.lastSeen,
  });
}

class LocalNetworkService {
  static const int _udpPort = 45000;

  // ── Dynamic TCP port — tries base port first, then increments ──
  int _tcpPort;
  final int _baseTcpPort;
  static const int _maxPortAttempts = 20;

  int get tcpPort => _tcpPort;

  RawDatagramSocket? _udpSocket;
  Timer? _broadcastTimer;
  ServerSocket? _tcpServer;
  Socket? _activeTcpSocket;

  final Map<String, LocalDevice> _discoveredDevices = {};

  // ─── Callbacks ─────────────────────────────────────────────
  ValueChanged<List<LocalDevice>>? onDevicesChanged;
  ValueChanged<Socket>? onIncomingConnection;
  ValueChanged<String>? onError;

  LocalNetworkService({int baseTcpPort = 45001})
      : _baseTcpPort = baseTcpPort,
        _tcpPort = baseTcpPort;

  /// Starts device discovery via UDP broadcast on local network
  Future<void> startDiscovery(UserProfile profile) async {
    try {
      _discoveredDevices.clear();

      // Setup UDP Listener
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _udpPort);
      _udpSocket?.readEventsEnabled = true;
      _udpSocket?.broadcastEnabled = true;

      _udpSocket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpSocket?.receive();
          if (datagram != null) {
            _handleDatagram(datagram);
          }
        }
      });

      // Start broadcasting our presence every 2 seconds
      _broadcastTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        _broadcastPresence(profile);
        _cleanupStaleDevices();
      });
    } catch (e) {
      onError?.call('Failed to start UDP discovery: $e');
    }
  }

  void _handleDatagram(Datagram datagram) {
    try {
      final message = utf8.decode(datagram.data);
      if (message.startsWith('FSP_PING:')) {
        final data = message.substring(9).split('|');
        if (data.length >= 2) {
          final id = data[0];
          final name = data[1];
          final ip = datagram.address.address;

          // Don't add ourselves
          // (caller should ensure profile.uniqueId differs)

          _discoveredDevices[id] = LocalDevice(
            id: id,
            name: name,
            ip: ip,
            lastSeen: DateTime.now().millisecondsSinceEpoch,
          );

          onDevicesChanged?.call(_discoveredDevices.values.toList());
        }
      }
    } catch (_) {}
  }

  Future<void> _broadcastPresence(UserProfile profile) async {
    if (_udpSocket == null) return;
    try {
      final message = 'FSP_PING:${profile.uniqueId}|${profile.displayName}';
      final data = utf8.encode(message);

      // Global broadcast
      _udpSocket?.send(data, InternetAddress('255.255.255.255'), _udpPort);

      // Subnet-specific broadcasts for strict routers & hotspot scenarios
      try {
        for (var interface in await NetworkInterface.list()) {
          for (var addr in interface.addresses) {
            if (addr.type == InternetAddressType.IPv4) {
              final parts = addr.address.split('.');
              if (parts.length == 4) {
                final broadcastIp = '${parts[0]}.${parts[1]}.${parts[2]}.255';
                _udpSocket?.send(data, InternetAddress(broadcastIp), _udpPort);
              }
            }
          }
        }
      } catch (_) {}

      // Also try common mobile hotspot subnets (192.168.43.x, 172.20.10.x for iOS)
      try {
        _udpSocket?.send(data, InternetAddress('192.168.43.255'), _udpPort);
        _udpSocket?.send(data, InternetAddress('172.20.10.255'), _udpPort);
      } catch (_) {}
    } catch (_) {}
  }

  void _cleanupStaleDevices() {
    final now = DateTime.now().millisecondsSinceEpoch;
    bool changed = false;
    _discoveredDevices.removeWhere((key, device) {
      if (now - device.lastSeen > 10000) {
        // 10 seconds timeout (increased from 8)
        changed = true;
        return true;
      }
      return false;
    });
    if (changed) {
      onDevicesChanged?.call(_discoveredDevices.values.toList());
    }
  }

  void stopDiscovery() {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _udpSocket?.close();
    _udpSocket = null;
    _discoveredDevices.clear();
    onDevicesChanged?.call([]);
  }

  // ─── TCP Connection & Framing ────────────────────────────

  /// Starts TCP server with dynamic port binding.
  /// If base port is busy, tries next ports up to _maxPortAttempts.
  Future<void> startTcpServer() async {
    // If already running, don't restart
    if (_tcpServer != null) return;

    for (int i = 0; i < _maxPortAttempts; i++) {
      final port = _baseTcpPort + i;
      try {
        _tcpServer = await ServerSocket.bind(InternetAddress.anyIPv4, port);
        _tcpPort = port;
        debugPrint('LocalNetworkService: TCP server bound on port $port');
        _tcpServer?.listen((Socket client) {
          debugPrint('LocalNetworkService: Incoming connection from ${client.address.address}');
          onIncomingConnection?.call(client);
        });
        return; // Success
      } catch (e) {
        debugPrint('LocalNetworkService: Port $port busy, trying next...');
      }
    }
    onError?.call('Failed to bind TCP server on any port in range $_baseTcpPort-${_baseTcpPort + _maxPortAttempts}');
  }

  void stopTcpServer() {
    _tcpServer?.close();
    _tcpServer = null;
  }

  Future<Socket?> connectTo(String ip) async {
    try {
      // Connect to the same port range the server might be on
      for (int i = 0; i < _maxPortAttempts; i++) {
        try {
          final port = _baseTcpPort + i;
          final socket = await Socket.connect(
            ip,
            port,
            timeout: const Duration(seconds: 3),
          );
          _activeTcpSocket = socket;
          debugPrint('LocalNetworkService: Connected to $ip:$port');
          return socket;
        } catch (_) {
          // Try next port
        }
      }
      onError?.call('Failed to connect to $ip: No open port found');
      return null;
    } catch (e) {
      onError?.call('Failed to connect to $ip: $e');
      return null;
    }
  }

  void disconnectActiveSocket() {
    try {
      _activeTcpSocket?.destroy();
      _activeTcpSocket = null;
    } catch (_) {}
  }

  /// Read framed messages from a TCP socket (4-byte length prefix + data)
  static Stream<Uint8List> frameStream(Socket socket) async* {
    final buffer = <int>[];
    int expectedLength = -1;

    await for (final data in socket) {
      buffer.addAll(data);

      while (true) {
        if (expectedLength == -1 && buffer.length >= 4) {
          final lengthBytes = Uint8List.fromList(buffer.sublist(0, 4));
          final bdata = ByteData.view(lengthBytes.buffer);
          expectedLength = bdata.getUint32(0, Endian.big);
          buffer.removeRange(0, 4);
        }

        if (expectedLength != -1 && buffer.length >= expectedLength) {
          final frame = Uint8List.fromList(buffer.sublist(0, expectedLength));
          buffer.removeRange(0, expectedLength);
          expectedLength = -1;
          yield frame;
        } else {
          break;
        }
      }
    }
  }

  /// Send a framed message (4-byte length prefix + data)
  static void sendFrame(Socket socket, Uint8List data) {
    try {
      final lengthBytes = Uint8List(4);
      ByteData.view(lengthBytes.buffer).setUint32(0, data.length, Endian.big);
      socket.add(lengthBytes);
      socket.add(data);
    } catch (_) {}
  }

  void dispose() {
    stopDiscovery();
    stopTcpServer();
    disconnectActiveSocket();
  }
}
