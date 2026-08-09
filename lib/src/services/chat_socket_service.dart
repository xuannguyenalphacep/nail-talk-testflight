import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../models/session_user.dart';

class ChatSocketService {
  ChatSocketService();

  io.Socket? _socket;

  final StreamController<List<ChatRoom>> _roomsController =
      StreamController<List<ChatRoom>>.broadcast();
  final StreamController<List<ChatRoom>> _hiddenRoomsController =
      StreamController<List<ChatRoom>>.broadcast();
  final StreamController<ChatMessage> _newMessageController =
      StreamController<ChatMessage>.broadcast();
  final StreamController<Map<String, dynamic>> _notifyController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Set<int>> _onlineUsersController =
      StreamController<Set<int>>.broadcast();
  final StreamController<Map<String, dynamic>> _readReceiptController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _reactionUpdatedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<List<ChatPinnedMessage>> _pinsUpdatedController =
      StreamController<List<ChatPinnedMessage>>.broadcast();
  final StreamController<Map<String, dynamic>> _messageRecalledController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  Stream<List<ChatRoom>> get roomsStream => _roomsController.stream;
  Stream<List<ChatRoom>> get hiddenRoomsStream => _hiddenRoomsController.stream;
  Stream<ChatMessage> get newMessageStream => _newMessageController.stream;
  Stream<Map<String, dynamic>> get notifyStream => _notifyController.stream;
  Stream<Set<int>> get onlineUsersStream => _onlineUsersController.stream;
  Stream<Map<String, dynamic>> get readReceiptStream =>
      _readReceiptController.stream;
  Stream<Map<String, dynamic>> get reactionUpdatedStream =>
      _reactionUpdatedController.stream;
  Stream<List<ChatPinnedMessage>> get pinsUpdatedStream =>
      _pinsUpdatedController.stream;
  Stream<Map<String, dynamic>> get messageRecalledStream =>
      _messageRecalledController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  bool get isConnected => _socket?.connected == true;

  Future<void> connect({
    required String socketUrl,
    required SessionUser user,
    required String notifyApiUrl,
  }) async {
    await disconnect();

    final completer = Completer<void>();
    Timer? connectFallbackTimer;

    _socket = io.io(
      socketUrl,
      io.OptionBuilder()
          .setPath('/socket.io')
          .setTransports(kIsWeb ? ['polling', 'websocket'] : ['websocket'])
          .setUpgrade(kIsWeb)
          .setRememberUpgrade(false)
          .enableForceNew()
          .disableMultiplex()
          .setTimeout(20000)
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(999)
          .setReconnectionDelay(1200)
          .build(),
    );

    _socket!
      ..onConnect((_) {
        if (kDebugMode) {
          debugPrint('[ChatSocket] onConnect');
        }
        _connectionController.add(true);
        var completed = false;

        void completeReady() {
          if (!completed && !completer.isCompleted) {
            completed = true;
            connectFallbackTimer?.cancel();
            completer.complete();
          }
        }

        _socket!.emitWithAck('chat-register', {
          'user_id': user.id,
          'company_id': user.companyId,
          'notify_api_url': notifyApiUrl,
        }, ack: (_) => completeReady());

        Future<void>.delayed(const Duration(milliseconds: 350), completeReady);
      })
      ..onDisconnect((payload) {
        if (kDebugMode) {
          debugPrint('[ChatSocket] onDisconnect: $payload');
        }
        _connectionController.add(false);
      })
      ..onConnectError((payload) {
        if (kDebugMode) {
          debugPrint('[ChatSocket] onConnectError: $payload');
        }
        if (!completer.isCompleted) {
          connectFallbackTimer?.cancel();
          completer.completeError(Exception('Socket connect failed'));
        }
      })
      ..onError((payload) {
        if (kDebugMode) {
          debugPrint('[ChatSocket] onError: $payload');
        }
        if (!completer.isCompleted) {
          connectFallbackTimer?.cancel();
          completer.completeError(Exception('Socket error'));
        }
      })
      ..on('chat-online-users', (payload) {
        final users = (payload is Map && payload['users'] is List)
            ? (payload['users'] as List)
                  .map((item) => int.tryParse(item.toString()))
                  .whereType<int>()
                  .toSet()
            : <int>{};
        _onlineUsersController.add(users);
      })
      ..on('chat-new-message', (payload) {
        if (payload is Map<String, dynamic>) {
          _newMessageController.add(ChatMessage.fromJson(payload));
        } else if (payload is Map) {
          _newMessageController.add(
            ChatMessage.fromJson(Map<String, dynamic>.from(payload)),
          );
        }
      })
      ..on('receive_notify', (payload) {
        if (payload is Map<String, dynamic>) {
          _notifyController.add(payload);
        } else if (payload is Map) {
          _notifyController.add(Map<String, dynamic>.from(payload));
        }
      })
      ..on('chat-read-receipt', (payload) {
        if (payload is Map<String, dynamic>) {
          _readReceiptController.add(payload);
        } else if (payload is Map) {
          _readReceiptController.add(Map<String, dynamic>.from(payload));
        }
      })
      ..on('chat-reaction-updated', (payload) {
        if (payload is Map<String, dynamic>) {
          _reactionUpdatedController.add(payload);
        } else if (payload is Map) {
          _reactionUpdatedController.add(Map<String, dynamic>.from(payload));
        }
      })
      ..on('chat-pins-updated', (payload) {
        final rawPins = payload is Map ? payload['pins'] : null;
        final pins = (rawPins as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map>()
            .map(
              (item) =>
                  ChatPinnedMessage.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
        _pinsUpdatedController.add(pins);
      })
      ..on('chat-message-recalled', (payload) {
        if (payload is Map<String, dynamic>) {
          _messageRecalledController.add(payload);
        } else if (payload is Map) {
          _messageRecalledController.add(Map<String, dynamic>.from(payload));
        }
      });

    _socket!.connect();

    connectFallbackTimer = Timer(const Duration(seconds: 4), () {
      final socket = _socket;
      if (!completer.isCompleted && socket?.connected == true) {
        if (kDebugMode) {
          debugPrint('[ChatSocket] fallback complete via connected=true');
        }
        completer.complete();
      }
    });

    try {
      return await completer.future.timeout(const Duration(seconds: 12));
    } finally {
      connectFallbackTimer.cancel();
    }
  }

  Future<void> disconnect() async {
    _socket?.dispose();
    _socket = null;
    _connectionController.add(false);
  }

  Future<List<ChatRoom>> fetchRooms() async {
    final response = await _emitWithAck<Map<String, dynamic>>('chat-get-rooms');
    final rooms = ((response['rooms'] as List?) ?? const [])
        .map(
          (item) => ChatRoom.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    _roomsController.add(rooms);
    return rooms;
  }

  Future<List<ChatRoom>> fetchHiddenRooms() async {
    final response = await _emitWithAck<Map<String, dynamic>>(
      'chat-get-hidden-rooms',
    );
    final rooms = ((response['rooms'] as List?) ?? const [])
        .map(
          (item) => ChatRoom.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    _hiddenRoomsController.add(rooms);
    return rooms;
  }

  Future<int> createPrivateRoom(int userId) async {
    final response = await _emitWithAck<Map<String, dynamic>>(
      'chat-create-private',
      userId,
    );
    return (response['room_id'] as num?)?.toInt() ?? 0;
  }

  Future<void> hideRoom(int roomId) async {
    await _emitWithAck<Map<String, dynamic>>('chat-hide-room', {
      'room_id': roomId,
    });
  }

  Future<void> unhideRoom(int roomId) async {
    await _emitWithAck<Map<String, dynamic>>('chat-unhide-room', {
      'room_id': roomId,
    });
  }

  Future<bool> toggleBookmark(int roomId) async {
    final response = await _emitWithAck<Map<String, dynamic>>(
      'chat-toggle-bookmark',
      {'room_id': roomId},
    );
    return response['bookmarked'] == true;
  }

  void joinRoom(int roomId) {
    _socket?.emit('chat-join-room', roomId);
  }

  Future<void> sendMessage(Map<String, dynamic> payload) async {
    await _emitWithAck<Map<String, dynamic>>('chat-send-message', payload);
  }

  Future<List<ChatPinnedMessage>> fetchPinnedMessages(int roomId) async {
    final response = await _emitWithAck<Map<String, dynamic>>(
      'chat-get-pinned-messages',
      roomId,
    );
    final pins = ((response['pins'] as List?) ?? const [])
        .whereType<Map>()
        .map(
          (item) => ChatPinnedMessage.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
    _pinsUpdatedController.add(pins);
    return pins;
  }

  Future<void> togglePin({required int roomId, required int messageId}) async {
    await _emitWithAck<Map<String, dynamic>>('chat-toggle-pin', {
      'room_id': roomId,
      'message_id': messageId,
    });
  }

  Future<void> toggleReaction({
    required int roomId,
    required int messageId,
    String reaction = 'like',
  }) async {
    await _emitWithAck<Map<String, dynamic>>('chat-toggle-reaction', {
      'room_id': roomId,
      'message_id': messageId,
      'reaction': reaction,
    });
  }

  Future<void> recallMessage({
    required int roomId,
    required int messageId,
  }) async {
    await _emitWithAck<Map<String, dynamic>>('chat-recall-message', {
      'room_id': roomId,
      'message_id': messageId,
    });
  }

  Future<void> sendReadRoomUsers(int companyId) async {
    await _emitWithAck<Map<String, dynamic>>(
      'chat-get-online-users',
      companyId,
    );
  }

  Future<T> _emitWithAck<T>(String event, [dynamic payload]) {
    final socket = _socket;
    if (socket == null) {
      return Future.error(StateError('Socket not initialized'));
    }

    final completer = Completer<T>();

    void callback(dynamic response) {
      if (response is Map && response['ok'] == false) {
        completer.completeError(
          Exception(
            (response['message'] ?? 'Socket request failed').toString(),
          ),
        );
        return;
      }

      completer.complete(response as T);
    }

    socket.emitWithAck(event, payload, ack: callback);

    return completer.future.timeout(const Duration(seconds: 15));
  }

  Future<void> dispose() async {
    await disconnect();
    await _roomsController.close();
    await _hiddenRoomsController.close();
    await _newMessageController.close();
    await _notifyController.close();
    await _onlineUsersController.close();
    await _readReceiptController.close();
    await _reactionUpdatedController.close();
    await _pinsUpdatedController.close();
    await _messageRecalledController.close();
    await _connectionController.close();
  }
}
