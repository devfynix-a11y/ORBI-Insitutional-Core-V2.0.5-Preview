import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'app_config.dart';

/// ORBI NEXUS CLIENT (DART)
/// -------------------------
/// A robust WebSocket client for real-time financial updates.
/// Handles connection, authentication, and event parsing.

class NexusClient {
  WebSocket? _socket;
  final String _url = AppConfig.wsUrl;
  final StreamController<Map<String, dynamic>> _eventController = StreamController.broadcast();
  bool _isConnected = false;
  Timer? _pingTimer;

  Stream<Map<String, dynamic>> get events => _eventController.stream;

  /// Connect to the Nexus Stream
  Future<void> connect(String accessToken) async {
    try {
      print('🔌 Connecting to Nexus Stream: $_url');
      _socket = await WebSocket.connect(_url);
      _isConnected = true;
      print('✅ Connected to Nexus.');

      // Authenticate immediately
      _send({'type': 'AUTH', 'token': accessToken});

      // Listen for messages
      _socket!.listen(
        (data) {
          try {
            final event = jsonDecode(data);
            _handleEvent(event);
          } catch (e) {
            print('⚠️ Failed to parse Nexus message: $e');
          }
        },
        onDone: () {
          print('🔌 Nexus Disconnected (Server Closed)');
          _isConnected = false;
          _scheduleReconnect(accessToken);
        },
        onError: (error) {
          print('❌ Nexus Error: $error');
          _isConnected = false;
          _scheduleReconnect(accessToken);
        },
      );

      // Start Heartbeat
      _startHeartbeat();

    } catch (e) {
      print('❌ Connection Failed: $e');
      _scheduleReconnect(accessToken);
    }
  }

  void _handleEvent(Map<String, dynamic> event) {
    if (event['event'] == 'PONG') {
      // Heartbeat response, ignore
      return;
    }

    print('📨 Nexus Event: ${event['type']}');
    _eventController.add(event);
  }

  void _send(Map<String, dynamic> data) {
    if (_isConnected && _socket != null) {
      _socket!.add(jsonEncode(data));
    }
  }

  void _startHeartbeat() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (_isConnected) {
        _send({'event': 'PING'});
      }
    });
  }

  void _scheduleReconnect(String accessToken) {
    if (!_isConnected) {
      print('🔄 Reconnecting in 5s...');
      Future.delayed(Duration(seconds: 5), () => connect(accessToken));
    }
  }

  void disconnect() {
    _pingTimer?.cancel();
    _socket?.close();
    _isConnected = false;
    print('🔌 Nexus Disconnected (Client Request)');
  }
}
