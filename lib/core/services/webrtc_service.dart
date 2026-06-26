import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'signaling_service.dart';

enum WebRtcConnectionState {
  disconnected,
  connecting,
  connected,
  failed,
}

class WebRtcService {
  final SignalingService _signaling;
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;

  String? _targetId;
  bool _isCaller = false;

  /// The peer id of the currently (or last) connected remote party.
  /// Set both when we initiate (`connectTo`) and when an offer arrives
  /// (passive/callee side) so the chat layer knows whom we're talking to.
  String? get remotePeerId => _targetId;
  bool get isCaller => _isCaller;

  Function(String text)? onTextMessage;
  Function(Uint8List data)? onBinaryMessage;
  Function(WebRtcConnectionState state)? onConnectionStateChanged;

  WebRtcService(this._signaling) {
    _signaling.onMessageReceived = _handleSignalingMessage;
  }

  // Google's free public STUN servers
  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'url': 'stun:stun.l.google.com:19302'},
      {'url': 'stun:stun1.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  Future<void> _createPeerConnection() async {
    _peerConnection = await createPeerConnection(_configuration);

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (_targetId != null) {
        _signaling.sendMessage(SignalingMessage(
          senderId: _signaling.myId!,
          targetId: _targetId!,
          type: 'candidate',
          data: {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        ));
      }
    };

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('WebRTC ICE Connection State: $state');
      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
        case RTCIceConnectionState.RTCIceConnectionStateCompleted:
          onConnectionStateChanged?.call(WebRtcConnectionState.connected);
          break;
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          onConnectionStateChanged?.call(WebRtcConnectionState.failed);
          break;
        default:
          break;
      }
    };

    _peerConnection!.onDataChannel = (RTCDataChannel channel) {
      _setupDataChannel(channel);
    };
  }

  void _setupDataChannel(RTCDataChannel channel) {
    _dataChannel = channel;
    _dataChannel!.onDataChannelState = (RTCDataChannelState state) {
      debugPrint('DataChannel state: $state');
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        onConnectionStateChanged?.call(WebRtcConnectionState.connected);
      }
    };
    _dataChannel!.onMessage = (RTCDataChannelMessage message) {
      if (message.isBinary) {
        onBinaryMessage?.call(message.binary);
      } else {
        onTextMessage?.call(message.text);
      }
    };
  }

  /// Initiate a connection to a remote user (Global Chat)
  Future<void> connectTo(String targetId) async {
    if (_signaling.myId == null) throw Exception('Signaling not initialized');
    
    _targetId = targetId;
    _isCaller = true;
    onConnectionStateChanged?.call(WebRtcConnectionState.connecting);

    await _createPeerConnection();

    // Create Data Channel for Chat & Files
    final channelInit = RTCDataChannelInit()
      ..ordered = true
      ..maxRetransmits = 30; // Reliable channel
    
    _dataChannel = await _peerConnection!.createDataChannel('file_share_chat', channelInit);
    _setupDataChannel(_dataChannel!);

    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    _signaling.sendMessage(SignalingMessage(
      senderId: _signaling.myId!,
      targetId: _targetId!,
      type: 'offer',
      data: {'sdp': offer.sdp, 'type': offer.type},
    ));
  }

  Future<void> _handleSignalingMessage(SignalingMessage msg) async {
    // Ignore messages not meant for us
    if (msg.targetId != _signaling.myId) return;

    switch (msg.type) {
      case 'offer':
        _targetId = msg.senderId;
        _isCaller = false;
        onConnectionStateChanged?.call(WebRtcConnectionState.connecting);
        
        await _createPeerConnection();
        
        final desc = RTCSessionDescription(msg.data['sdp'], msg.data['type']);
        await _peerConnection!.setRemoteDescription(desc);
        
        final answer = await _peerConnection!.createAnswer();
        await _peerConnection!.setLocalDescription(answer);
        
        _signaling.sendMessage(SignalingMessage(
          senderId: _signaling.myId!,
          targetId: _targetId!,
          type: 'answer',
          data: {'sdp': answer.sdp, 'type': answer.type},
        ));
        break;
        
      case 'answer':
        if (_isCaller && msg.senderId == _targetId) {
          final desc = RTCSessionDescription(msg.data['sdp'], msg.data['type']);
          await _peerConnection!.setRemoteDescription(desc);
        }
        break;
        
      case 'candidate':
        if (msg.senderId == _targetId) {
          final candidate = RTCIceCandidate(
            msg.data['candidate'],
            msg.data['sdpMid'],
            msg.data['sdpMLineIndex'],
          );
          await _peerConnection!.addCandidate(candidate);
        }
        break;
    }
  }

  void sendText(String text) {
    if (_dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen) {
      _dataChannel!.send(RTCDataChannelMessage(text));
    } else {
      debugPrint('Cannot send text: DataChannel is not open');
    }
  }

  void sendBinary(Uint8List data) {
    if (_dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen) {
      _dataChannel!.send(RTCDataChannelMessage.fromBinary(data));
    } else {
      debugPrint('Cannot send binary: DataChannel is not open');
    }
  }

  void disconnect() {
    _dataChannel?.close();
    _peerConnection?.close();
    _dataChannel = null;
    _peerConnection = null;
    _targetId = null;
    onConnectionStateChanged?.call(WebRtcConnectionState.disconnected);
  }
}
