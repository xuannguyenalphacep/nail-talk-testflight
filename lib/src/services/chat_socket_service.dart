import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../game_tien_len/features/tien_len/data/realtime_game_models.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../models/session_user.dart';

class ChatPinsUpdate {
  const ChatPinsUpdate({required this.roomId, required this.pins});

  final int? roomId;
  final List<ChatPinnedMessage> pins;
}

class ChatSocketService {
  ChatSocketService();

  io.Socket? _socket;
  Future<void>? _connectFuture;
  String? _connectionFingerprint;
  _TienLenJoinSession? _tienLenSession;
  bool _restoringTienLenRoom = false;
  int _tienLenSessionGeneration = 0;

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
  final StreamController<ChatPinsUpdate> _pinsUpdatedController =
      StreamController<ChatPinsUpdate>.broadcast();
  final StreamController<Map<String, dynamic>> _messageRecalledController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  final StreamController<TienLenRoomState> _tienLenRoomStateController =
      StreamController<TienLenRoomState>.broadcast();
  final StreamController<Map<String, dynamic>> _tienLenEventController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<List<ChatRoom>> get roomsStream => _roomsController.stream;
  Stream<List<ChatRoom>> get hiddenRoomsStream => _hiddenRoomsController.stream;
  Stream<ChatMessage> get newMessageStream => _newMessageController.stream;
  Stream<Map<String, dynamic>> get notifyStream => _notifyController.stream;
  Stream<Set<int>> get onlineUsersStream => _onlineUsersController.stream;
  Stream<Map<String, dynamic>> get readReceiptStream =>
      _readReceiptController.stream;
  Stream<Map<String, dynamic>> get reactionUpdatedStream =>
      _reactionUpdatedController.stream;
  Stream<ChatPinsUpdate> get pinsUpdatedStream => _pinsUpdatedController.stream;
  Stream<Map<String, dynamic>> get messageRecalledStream =>
      _messageRecalledController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<TienLenRoomState> get tienLenRoomStateStream =>
      _tienLenRoomStateController.stream;
  Stream<Map<String, dynamic>> get tienLenEventStream =>
      _tienLenEventController.stream;

  bool get isConnected => _socket?.connected == true;
  String? get activeTienLenRoomId => _tienLenSession?.roomId;

  Future<void> connect({
    required String socketUrl,
    required SessionUser user,
    required String notifyApiUrl,
    required String accessToken,
  }) {
    final fingerprint = '$socketUrl|${user.id}|${user.companyId}|$accessToken';
    if (isConnected && _connectionFingerprint == fingerprint) {
      return Future<void>.value();
    }

    final pending = _connectFuture;
    if (pending != null) {
      return pending.then<void>((_) async {
        if (isConnected && _connectionFingerprint == fingerprint) return;
        await connect(
          socketUrl: socketUrl,
          user: user,
          notifyApiUrl: notifyApiUrl,
          accessToken: accessToken,
        );
      });
    }

    final preserveGameSession = _connectionFingerprint == fingerprint;
    final future = _performConnect(
      socketUrl: socketUrl,
      user: user,
      notifyApiUrl: notifyApiUrl,
      accessToken: accessToken,
      fingerprint: fingerprint,
      preserveGameSession: preserveGameSession,
    );
    _connectFuture = future;
    return future.whenComplete(() {
      if (identical(_connectFuture, future)) _connectFuture = null;
    });
  }

  Future<void> _performConnect({
    required String socketUrl,
    required SessionUser user,
    required String notifyApiUrl,
    required String accessToken,
    required String fingerprint,
    required bool preserveGameSession,
  }) async {
    await _disconnect(clearGameSession: !preserveGameSession);
    _connectionFingerprint = fingerprint;

    final completer = Completer<void>();
    final socket = io.io(
      socketUrl,
      io.OptionBuilder()
          .setPath('/socket.io')
          .setTransports(kIsWeb ? ['polling', 'websocket'] : ['websocket'])
          .setAuth(<String, dynamic>{
            'token': accessToken,
            'access_token': accessToken,
          })
          .setExtraHeaders(<String, String>{
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
          })
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
    _socket = socket;

    socket
      ..onConnect((_) {
        if (!identical(_socket, socket)) return;
        if (kDebugMode) {
          debugPrint('[ChatSocket] onConnect');
        }
        _connectionController.add(true);
        socket.emitWithAck(
          'chat-register',
          {
            'user_id': user.id,
            'company_id': user.companyId,
            'notify_api_url': notifyApiUrl,
          },
          ack: (response) {
            if (!identical(_socket, socket)) return;
            if (response is Map && response['ok'] == false) {
              if (!completer.isCompleted) {
                completer.completeError(
                  Exception(
                    (response['message'] ?? 'Socket registration failed')
                        .toString(),
                  ),
                );
              }
              return;
            }
            if (!completer.isCompleted) completer.complete();
            unawaited(_restoreTienLenRoom());
          },
        );
      })
      ..onDisconnect((payload) {
        if (!identical(_socket, socket)) return;
        if (kDebugMode) {
          debugPrint('[ChatSocket] onDisconnect: $payload');
        }
        _connectionController.add(false);
      })
      ..onConnectError((payload) {
        if (!identical(_socket, socket)) return;
        if (kDebugMode) {
          debugPrint('[ChatSocket] onConnectError: $payload');
        }
        if (!completer.isCompleted) {
          completer.completeError(Exception('Socket connect failed'));
        }
      })
      ..onError((payload) {
        if (!identical(_socket, socket)) return;
        if (kDebugMode) {
          debugPrint('[ChatSocket] onError: $payload');
        }
        if (!completer.isCompleted) {
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
        final roomId = payload is Map
            ? int.tryParse(
                (payload['room_id'] ?? payload['roomId'] ?? '').toString(),
              )
            : null;
        final pins = (rawPins as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map>()
            .map(
              (item) =>
                  ChatPinnedMessage.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
        _pinsUpdatedController.add(ChatPinsUpdate(roomId: roomId, pins: pins));
      })
      ..on('chat-message-recalled', (payload) {
        if (payload is Map<String, dynamic>) {
          _messageRecalledController.add(payload);
        } else if (payload is Map) {
          _messageRecalledController.add(Map<String, dynamic>.from(payload));
        }
      });

    _registerTienLenListeners(socket);

    socket.connect();

    try {
      return await completer.future.timeout(const Duration(seconds: 12));
    } catch (_) {
      if (identical(_socket, socket)) {
        socket.dispose();
        _socket = null;
        _connectionController.add(false);
      }
      rethrow;
    }
  }

  Future<void> disconnect() async {
    await _disconnect(clearGameSession: true);
  }

  Future<void> _disconnect({required bool clearGameSession}) async {
    _socket?.dispose();
    _socket = null;
    _connectionFingerprint = null;
    if (clearGameSession) {
      _tienLenSessionGeneration++;
      _tienLenSession = null;
    }
    _connectionController.add(false);
  }

  void _registerTienLenListeners(io.Socket socket) {
    void addEvent(String event, dynamic payload) {
      final data = payload is Map<String, dynamic>
          ? payload
          : payload is Map
          ? Map<String, dynamic>.from(payload)
          : <String, dynamic>{'payload': payload};
      _tienLenEventController.add(<String, dynamic>{'event': event, ...data});
    }

    socket
      ..on('tien-len:room-state', (payload) {
        if (payload is Map<String, dynamic>) {
          _tienLenRoomStateController.add(TienLenRoomState.fromJson(payload));
        } else if (payload is Map) {
          _tienLenRoomStateController.add(
            TienLenRoomState.fromJson(Map<String, dynamic>.from(payload)),
          );
        }
      })
      ..on('tien-len:kicked', (payload) => addEvent('kicked', payload))
      ..on(
        'tien-len:player-kicked',
        (payload) => addEvent('player-kicked', payload),
      )
      ..on('tien-len:player-joined', (payload) {
        addEvent('player-joined', payload);
      })
      ..on('tien-len:player-left', (payload) {
        addEvent('player-left', payload);
      })
      ..on('tien-len:round-started', (payload) {
        addEvent('round-started', payload);
      })
      ..on(
        'tien-len:turn-timeout',
        (payload) => addEvent('turn-timeout', payload),
      )
      ..on(
        'tien-len:round-settled',
        (payload) => addEvent('round-settled', payload),
      )
      ..on('tien-len:session-replaced', (payload) {
        _tienLenSessionGeneration++;
        _tienLenSession = null;
        addEvent('session-replaced', payload);
      })
      ..on(
        'tien-len:feature-paused',
        (payload) => addEvent('feature-paused', payload),
      )
      ..on('tien-len:played', (payload) => addEvent('played', payload))
      ..on('tien-len:passed', (payload) => addEvent('passed', payload))
      ..on('tien-len:room-chat', (payload) => addEvent('room-chat', payload))
      ..on('tien-len:reaction', (payload) => addEvent('reaction', payload));
  }

  Future<List<TienLenRoomSummary>> listTienLenRooms() async {
    final response = await _emitWithAck<Map<String, dynamic>>(
      'tien-len:list-rooms',
      <String, dynamic>{},
    );
    final rooms = (response['rooms'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map(
          (item) =>
              TienLenRoomSummary.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
    return rooms;
  }

  Future<TienLenRoomState> createTienLenRoom({
    required String roomId,
    required String title,
    required int baseBet,
    required int userId,
    required String name,
    required int coins,
    int maxPlayers = 4,
  }) async {
    final sessionGeneration = _tienLenSessionGeneration;
    final response = await _emitWithAck<Map<String, dynamic>>(
      'tien-len:create-room',
      <String, dynamic>{
        'roomId': roomId,
        'title': title,
        'baseBet': baseBet,
        'maxPlayers': maxPlayers,
        'autoJoin': true,
        'user_id': userId,
        'name': name,
        'coins': coins,
      },
    );
    final state = TienLenRoomState.fromJson(
      Map<String, dynamic>.from(response['room'] as Map),
    );
    if (sessionGeneration != _tienLenSessionGeneration) {
      await _leaveCancelledTienLenJoin();
      throw StateError('Tiến Lên room join was cancelled');
    }
    _tienLenSession = _TienLenJoinSession(
      roomId: state.roomId,
      title: title,
      baseBet: baseBet,
      maxPlayers: maxPlayers,
      userId: userId,
      name: name,
      coins: state.viewerPlayer?.coins ?? coins,
    );
    return state;
  }

  Future<TienLenRoomState> joinTienLenRoom({
    required String roomId,
    required int userId,
    required String name,
    required int coins,
    String? title,
    int? baseBet,
  }) async {
    final sessionGeneration = _tienLenSessionGeneration;
    final payload = <String, dynamic>{
      'roomId': roomId,
      'maxPlayers': 4,
      'user_id': userId,
      'name': name,
      'coins': coins,
    };
    if (title != null) payload['title'] = title;
    if (baseBet != null) payload['baseBet'] = baseBet;

    final response = await _emitWithAck<Map<String, dynamic>>(
      'tien-len:join-room',
      payload,
    );
    final state = TienLenRoomState.fromJson(
      Map<String, dynamic>.from(response['room'] as Map),
    );
    if (sessionGeneration != _tienLenSessionGeneration) {
      await _leaveCancelledTienLenJoin();
      throw StateError('Tiến Lên room join was cancelled');
    }
    _tienLenSession = _TienLenJoinSession(
      roomId: state.roomId,
      title: title ?? state.title,
      baseBet: baseBet ?? state.baseBet,
      maxPlayers: state.maxPlayers,
      userId: userId,
      name: name,
      coins: state.viewerPlayer?.coins ?? coins,
    );
    return state;
  }

  Future<TienLenRoomState> addTienLenBot() async {
    final response = await _emitWithAck<Map<String, dynamic>>(
      'tien-len:add-bot',
      <String, dynamic>{},
    );
    return TienLenRoomState.fromJson(
      Map<String, dynamic>.from(response['room'] as Map),
    );
  }

  Future<TienLenRoomState> kickTienLenPlayer(String playerId) async {
    final response = await _emitWithAck<Map<String, dynamic>>(
      'tien-len:kick-player',
      <String, dynamic>{'playerId': playerId},
    );
    return TienLenRoomState.fromJson(
      Map<String, dynamic>.from(response['room'] as Map),
    );
  }

  Future<void> sendTienLenChat(String message) async {
    await _emitWithAck<Map<String, dynamic>>(
      'tien-len:room-chat',
      <String, dynamic>{'message': message},
    );
  }

  Future<void> sendTienLenReaction(String reaction) async {
    await _emitWithAck<Map<String, dynamic>>(
      'tien-len:reaction',
      <String, dynamic>{'reaction': reaction},
    );
  }

  Future<TienLenRoomState> readyTienLen({bool ready = true}) async {
    final response = await _emitWithAck<Map<String, dynamic>>(
      'tien-len:ready',
      <String, dynamic>{'ready': ready},
    );
    return TienLenRoomState.fromJson(
      Map<String, dynamic>.from(response['room'] as Map),
    );
  }

  Future<TienLenRoomState> startTienLenRoom({bool fillBots = false}) async {
    final response = await _emitWithAck<Map<String, dynamic>>(
      'tien-len:start',
      <String, dynamic>{'fillBots': fillBots},
    );
    return TienLenRoomState.fromJson(
      Map<String, dynamic>.from(response['room'] as Map),
    );
  }

  Future<TienLenRoomState> retryTienLenSettlement() async {
    final response = await _emitWithAck<Map<String, dynamic>>(
      'tien-len:retry-settlement',
      <String, dynamic>{},
    );
    return TienLenRoomState.fromJson(
      Map<String, dynamic>.from(response['room'] as Map),
    );
  }

  Future<TienLenRoomState> sortTienLenHand() async {
    await _emitWithAck<Map<String, dynamic>>(
      'tien-len:sort-hand',
      <String, dynamic>{},
    );
    return fetchTienLenState();
  }

  Future<TienLenRoomState> playTienLenCards(List<String> cardCodes) async {
    final response = await _emitWithAck<Map<String, dynamic>>(
      'tien-len:play-cards',
      <String, dynamic>{'cards': cardCodes},
    );
    return TienLenRoomState.fromJson(
      Map<String, dynamic>.from(response['room'] as Map),
    );
  }

  Future<TienLenRoomState> passTienLenTurn() async {
    final response = await _emitWithAck<Map<String, dynamic>>(
      'tien-len:pass',
      <String, dynamic>{},
    );
    return TienLenRoomState.fromJson(
      Map<String, dynamic>.from(response['room'] as Map),
    );
  }

  Future<TienLenRoomState> fetchTienLenState() async {
    final response = await _emitWithAck<Map<String, dynamic>>(
      'tien-len:state',
      <String, dynamic>{},
    );
    return TienLenRoomState.fromJson(
      Map<String, dynamic>.from(response['room'] as Map),
    );
  }

  Future<void> leaveTienLenRoom() async {
    await _leaveTienLenRoom(forceServerLeave: false);
  }

  /// Clears a possibly half-created room after a create acknowledgement fails.
  ///
  /// In that case [_tienLenSession] was never assigned, but the server may
  /// already have joined this socket to the room. A normal leave intentionally
  /// avoids emitting without a known session; recovery must force the server
  /// cleanup before attempting another fresh room ID.
  Future<void> forceLeaveTienLenRoom() async {
    await _leaveTienLenRoom(forceServerLeave: true);
  }

  Future<void> _leaveTienLenRoom({required bool forceServerLeave}) async {
    final activeSession = _tienLenSession;
    _tienLenSessionGeneration++;
    _tienLenSession = null;
    if (!isConnected || (activeSession == null && !forceServerLeave)) return;
    await _emitWithAck<Map<String, dynamic>>(
      'tien-len:leave-room',
      <String, dynamic>{},
    );
  }

  Future<void> _restoreTienLenRoom() async {
    final session = _tienLenSession;
    if (session == null || _restoringTienLenRoom || !isConnected) return;

    _restoringTienLenRoom = true;
    _tienLenEventController.add(<String, dynamic>{
      'event': 'reconnecting',
      'roomId': session.roomId,
    });
    try {
      final response = await _emitWithAck<Map<String, dynamic>>(
        'tien-len:join-room',
        session.toPayload(),
      );
      final state = TienLenRoomState.fromJson(
        Map<String, dynamic>.from(response['room'] as Map),
      );
      if (!identical(_tienLenSession, session)) {
        if (_tienLenSession == null) await _leaveCancelledTienLenJoin();
        return;
      }
      _tienLenSession = session.copyWith(
        coins: state.viewerPlayer?.coins ?? session.coins,
      );
      _tienLenRoomStateController.add(state);
      _tienLenEventController.add(<String, dynamic>{
        'event': 'reconnected',
        'roomId': session.roomId,
      });
    } catch (error) {
      _tienLenEventController.add(<String, dynamic>{
        'event': 'reconnect-failed',
        'roomId': session.roomId,
        'message': error.toString(),
      });
    } finally {
      _restoringTienLenRoom = false;
    }
  }

  Future<void> _leaveCancelledTienLenJoin() async {
    if (!isConnected) return;
    try {
      await _emitWithAck<Map<String, dynamic>>(
        'tien-len:leave-room',
        <String, dynamic>{},
      );
    } catch (_) {
      // The socket may already have disconnected or the room may be gone.
    }
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
    _pinsUpdatedController.add(ChatPinsUpdate(roomId: roomId, pins: pins));
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
    if (socket == null || !socket.connected) {
      return Future.error(StateError('Socket is not connected'));
    }

    final completer = Completer<T>();

    void callback(dynamic response) {
      if (completer.isCompleted) return;
      if (response is Map && response['ok'] == false) {
        completer.completeError(
          Exception(
            (response['message'] ?? 'Socket request failed').toString(),
          ),
        );
        return;
      }

      try {
        completer.complete(response as T);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    }

    socket.emitWithAck(event, payload, ack: callback);

    final timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (!completer.isCompleted) {
        completer.completeError(
          TimeoutException('Socket ack timed out for $event'),
        );
      }
    });
    return completer.future.whenComplete(timeoutTimer.cancel);
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
    await _tienLenRoomStateController.close();
    await _tienLenEventController.close();
  }
}

class _TienLenJoinSession {
  const _TienLenJoinSession({
    required this.roomId,
    required this.title,
    required this.baseBet,
    required this.maxPlayers,
    required this.userId,
    required this.name,
    required this.coins,
  });

  final String roomId;
  final String title;
  final int baseBet;
  final int maxPlayers;
  final int userId;
  final String name;
  final int coins;

  Map<String, dynamic> toPayload() => <String, dynamic>{
    'roomId': roomId,
    'title': title,
    'baseBet': baseBet,
    'maxPlayers': maxPlayers,
    'user_id': userId,
    'name': name,
    'coins': coins,
  };

  _TienLenJoinSession copyWith({int? coins}) {
    return _TienLenJoinSession(
      roomId: roomId,
      title: title,
      baseBet: baseBet,
      maxPlayers: maxPlayers,
      userId: userId,
      name: name,
      coins: coins ?? this.coins,
    );
  }
}
