import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../core/localization/app_localizer.dart';
import '../core/utils/chat_content_utils.dart';
import '../models/chat_message.dart';
import '../models/chat_message_page.dart';
import '../models/chat_room.dart';
import '../models/chat_search_result.dart';
import '../models/chat_user_option.dart';
import '../services/chat_api_service.dart';
import '../services/chat_socket_service.dart';
import 'session_controller.dart';

enum RoomCollectionFilter { groups, privateChats, bookmarked, hidden }

class ChatController extends ChangeNotifier {
  ChatController({
    required SessionController sessionController,
    required ChatApiService apiService,
    required ChatSocketService socketService,
  }) : _sessionController = sessionController,
       _apiService = apiService,
       _socketService = socketService {
    _sessionController.addListener(_onSessionChanged);
  }

  final SessionController _sessionController;
  final ChatApiService _apiService;
  final ChatSocketService _socketService;

  final List<ChatRoom> _rooms = [];
  final List<ChatRoom> _hiddenRooms = [];
  final List<ChatMessage> _messages = [];
  final List<ChatPinnedMessage> _pinnedMessages = [];
  final List<ChatUserOption> _userResults = [];
  final List<ChatUserOption> _mentionResults = [];
  final Set<int> _onlineUserIds = <int>{};
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _socketStreamsBound = false;
  Timer? _realtimeFallbackTimer;
  final Map<int, _RoomMessageCache> _roomMessageCaches =
      <int, _RoomMessageCache>{};

  ChatRoom? _activeRoom;
  RoomCollectionFilter _roomFilter = RoomCollectionFilter.groups;
  String _roomSearch = '';
  bool _connecting = false;
  bool _loadingRooms = false;
  bool _loadingMessages = false;
  bool _sending = false;
  bool _connected = false;
  String? _error;
  int _messagePage = 1;
  int _messageLastPage = 1;
  bool _initializedForSession = false;
  Future<void>? _connectFuture;
  int _incomingNoticeToken = 0;
  int? _incomingNoticeRoomId;
  String? _incomingNoticeRoomTitle;
  String? _incomingNoticePreview;
  int _messageScrollToken = 0;
  int _focusTargetToken = 0;
  int? _focusTargetMessageId;

  List<ChatRoom> get rooms => List.unmodifiable(_rooms);
  List<ChatRoom> get hiddenRooms => List.unmodifiable(_hiddenRooms);
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<ChatPinnedMessage> get pinnedMessages =>
      List.unmodifiable(_pinnedMessages);
  List<ChatUserOption> get userResults => List.unmodifiable(_userResults);
  List<ChatUserOption> get mentionResults => List.unmodifiable(_mentionResults);
  ChatRoom? get activeRoom => _activeRoom;
  RoomCollectionFilter get roomFilter => _roomFilter;
  bool get connecting => _connecting;
  bool get loadingRooms => _loadingRooms;
  bool get loadingMessages => _loadingMessages;
  bool get sending => _sending;
  bool get connected => _connected;
  String? get error => _error;
  bool get hasMoreMessages => _messagePage < _messageLastPage;
  int get incomingNoticeToken => _incomingNoticeToken;
  int? get incomingNoticeRoomId => _incomingNoticeRoomId;
  String? get incomingNoticeRoomTitle => _incomingNoticeRoomTitle;
  String? get incomingNoticePreview => _incomingNoticePreview;
  int get messageScrollToken => _messageScrollToken;
  int get focusTargetToken => _focusTargetToken;
  int? get focusTargetMessageId => _focusTargetMessageId;
  bool isUserOnline(int? userId) =>
      userId != null && _onlineUserIds.contains(userId);

  List<ChatRoom> get visibleRooms {
    final source = switch (_roomFilter) {
      RoomCollectionFilter.hidden => _hiddenRooms,
      RoomCollectionFilter.groups =>
        _rooms.where((room) => room.isGroup).toList(),
      RoomCollectionFilter.privateChats =>
        _rooms.where((room) => room.isPrivate).toList(),
      RoomCollectionFilter.bookmarked =>
        _rooms.where((room) => room.bookmarked).toList(),
    };

    if (_roomSearch.trim().isEmpty) {
      return List.unmodifiable(source);
    }

    final keyword = _roomSearch.toLowerCase();
    return source.where((room) {
      final lastMessage = room.lastMessage?.content.toLowerCase() ?? '';
      return room.title.toLowerCase().contains(keyword) ||
          lastMessage.contains(keyword);
    }).toList();
  }

  Future<void> connectIfNeeded() async {
    if (!_sessionController.isLoggedIn ||
        _initializedForSession ||
        _connected) {
      return;
    }
    if (_connectFuture != null) {
      return _connectFuture!;
    }

    final future = _performConnect();
    _connectFuture = future;
    try {
      await future;
    } finally {
      if (identical(_connectFuture, future)) {
        _connectFuture = null;
      }
    }
  }

  Future<void> _performConnect() async {
    if (_connecting) return;

    final user = _sessionController.user!;
    final app = _sessionController.selectedApp!;

    _connecting = true;
    _error = null;
    _ensureRealtimeFallbackPolling();
    notifyListeners();

    try {
      _bindSocketStreams();
      if (kDebugMode) {
        debugPrint(
          '[ChatController] connect socket user=${user.id} company=${user.companyId} socket=${app.socketUrl}',
        );
      }
      await _socketService.connect(
        socketUrl: app.socketUrl,
        user: user,
        notifyApiUrl: _sessionController.notifyApiUrl,
      );
      _initializedForSession = true;
      _connected = true;
      _error = null;
      await Future.wait([
        refreshRooms(silent: true),
        refreshHiddenRooms(silent: true),
      ]);
      await _syncOfflineNotifications();
      if (kDebugMode) {
        debugPrint(
          '[ChatController] socket connected; rooms=${_rooms.length} hidden=${_hiddenRooms.length}',
        );
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[ChatController] connect failed: $error');
      }
      try {
        await Future.wait([
          refreshRooms(silent: true),
          refreshHiddenRooms(silent: true),
        ]);
      } catch (_) {
        // Ignore secondary failures; keep the original socket error behavior.
      }
      if (_rooms.isEmpty) {
        _error = AppLocalizer.current.tr('Failed to load chat rooms.');
      } else {
        _error = null;
      }
      _connected = false;
    } finally {
      _connecting = false;
      notifyListeners();
    }
  }

  void _bindSocketStreams() {
    if (_socketStreamsBound) {
      return;
    }
    _socketStreamsBound = true;
    _subscriptions
      ..add(_socketService.roomsStream.listen(_replaceRooms))
      ..add(_socketService.hiddenRoomsStream.listen(_replaceHiddenRooms))
      ..add(_socketService.newMessageStream.listen(_handleIncomingMessage))
      ..add(_socketService.onlineUsersStream.listen(_replaceOnlineUsers))
      ..add(_socketService.readReceiptStream.listen(_handleReadReceipt))
      ..add(_socketService.reactionUpdatedStream.listen(_handleReactionUpdated))
      ..add(_socketService.pinsUpdatedStream.listen(_replacePinnedMessages))
      ..add(_socketService.messageRecalledStream.listen(_handleMessageRecalled))
      ..add(
        _socketService.connectionStream.listen((status) {
          final wasConnected = _connected;
          _connected = status;
          if (status) {
            _error = null;
            if (!wasConnected) {
              unawaited(refreshRooms(silent: true));
              unawaited(refreshHiddenRooms(silent: true));
            }
          }
          notifyListeners();
        }),
      );
  }

  void _ensureRealtimeFallbackPolling() {
    _realtimeFallbackTimer ??= Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_sessionController.isLoggedIn || _connecting || _connected) {
        return;
      }
      unawaited(refreshRooms(silent: true));
      unawaited(refreshHiddenRooms(silent: true));
      final roomId = _activeRoom?.id;
      if (roomId != null && !_loadingMessages) {
        unawaited(_refreshActiveRoomMessagesSilently(roomId));
      }
    });
  }

  Future<void> refreshRooms({bool silent = false}) async {
    if (!_sessionController.isLoggedIn) return;
    if (!silent) {
      _loadingRooms = true;
      notifyListeners();
    }
    try {
      final rooms = await _fetchRoomsViaApi();
      _replaceRooms(rooms);
      if (kDebugMode) {
        debugPrint('[ChatController] refreshRooms -> ${rooms.length} rooms');
      }
      _error = null;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[ChatController] refreshRooms failed: $error');
      }
      if (!silent) {
        _error = AppLocalizer.current.tr('Failed to load chat rooms.');
      }
    } finally {
      if (!silent) {
        _loadingRooms = false;
        notifyListeners();
      }
    }
  }

  Future<void> refreshHiddenRooms({bool silent = false}) async {
    if (!_sessionController.isLoggedIn) return;
    try {
      final rooms = await _fetchHiddenRoomsViaApi();
      _replaceHiddenRooms(rooms);
    } catch (_) {
      // Optional collection, ignore.
      if (!silent) {
        notifyListeners();
      }
    }
  }

  Future<void> openRoom(ChatRoom room) async {
    if (room.canJoin) {
      try {
        final joinedRoom = await _apiService.joinPublicGroup(room.id);
        await refreshRooms(silent: true);
        room =
            findRoomById(joinedRoom.id) ??
            joinedRoom.copyWith(isJoined: true, canJoin: false);
      } catch (_) {
        _error = AppLocalizer.current.tr('Failed to join this group.');
        notifyListeners();
        return;
      }
    }

    if (kDebugMode) {
      debugPrint(
        '[ChatController] openRoom start room=${room.id} "${room.title}"',
      );
    }
    final cached = _roomMessageCaches[room.id];
    _activeRoom = room;
    _pinnedMessages.clear();
    _focusTargetMessageId = null;
    if (cached != null) {
      _restoreMessageCache(cached);
      _loadingMessages = false;
      _error = null;
      _messageScrollToken++;
    } else {
      _messages.clear();
      _messagePage = 1;
      _messageLastPage = 1;
      _loadingMessages = true;
    }
    notifyListeners();

    try {
      _socketService.joinRoom(room.id);
      unawaited(
        _apiService.fetchRoom(room.id).then(_replaceRoom).catchError((_) {}),
      );

      final messagePage = await _apiService.fetchMessages(room.id);
      if (kDebugMode) {
        debugPrint(
          '[ChatController] openRoom messages loaded room=${room.id} count=${messagePage.messages.length} page=${messagePage.currentPage}/${messagePage.lastPage}',
        );
      }
      _setMessagePage(messagePage);
      _cacheMessagesForRoom(room.id);
      unawaited(loadPinnedMessages());
      _messageScrollToken++;
      unawaited(_apiService.markRoomReadAll(room.id));
      _markRoomUnread(room.id, 0);
      _error = null;
    } catch (_) {
      if (kDebugMode) {
        debugPrint('[ChatController] openRoom failed room=${room.id}');
      }
      if (cached == null || _messages.isEmpty) {
        _error = AppLocalizer.current.tr('Failed to load chat history.');
      }
    } finally {
      _loadingMessages = false;
      notifyListeners();
    }
  }

  Future<void> _refreshActiveRoomMessagesSilently(int roomId) async {
    if (_activeRoom?.id != roomId) {
      return;
    }
    try {
      final page = await _apiService.fetchMessages(roomId);
      final latest = page.messages.map(_normalizeMessage).toList();
      if (latest.isEmpty) {
        return;
      }
      final latestIds = latest.map((item) => item.id).toSet();
      final olderMessages = _messages
          .where((item) => !latestIds.contains(item.id))
          .toList();
      final merged = <ChatMessage>[...latest, ...olderMessages];
      if (_sameMessageSnapshot(_messages, merged)) {
        return;
      }
      _messages
        ..clear()
        ..addAll(merged);
      _messageLastPage = page.lastPage;
      if (_messagePage < 1) {
        _messagePage = 1;
      }
      _cacheMessagesForRoom(roomId);
      _error = null;
      notifyListeners();
    } catch (_) {
      // Ignore fallback polling errors.
    }
  }

  Future<void> loadMoreMessages() async {
    if (_activeRoom == null || !hasMoreMessages || _loadingMessages) return;
    _loadingMessages = true;
    notifyListeners();

    try {
      final nextPage = _messagePage + 1;
      final page = await _apiService.fetchMessages(
        _activeRoom!.id,
        page: nextPage,
      );
      _messages.addAll(page.messages.map(_normalizeMessage));
      _messagePage = page.currentPage;
      _messageLastPage = page.lastPage;
      _cacheMessagesForRoom(_activeRoom!.id);
    } catch (_) {
      _error = AppLocalizer.current.tr('Failed to load older messages.');
    } finally {
      _loadingMessages = false;
      notifyListeners();
    }
  }

  Future<void> sendText(String rawText, {ChatMessage? replyTo}) async {
    final room = _activeRoom;
    final user = _sessionController.user;
    if (room == null || user == null) return;

    final text = rawText.trim();
    if (text.isEmpty) return;

    _sending = true;
    notifyListeners();
    try {
      await _socketService.sendMessage({
        'room_id': room.id,
        'type': 'text',
        'content': text,
        'reply_to_id': replyTo?.id,
      });
      _optimisticallyBumpRoom(room.id, text, user.id, user.name);
    } catch (_) {
      _error = AppLocalizer.current.tr('Failed to send the message.');
      notifyListeners();
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  Future<void> sendFile(PlatformFile file, {ChatMessage? replyTo}) async {
    final room = _activeRoom;
    final user = _sessionController.user;
    if (room == null || user == null) return;

    _sending = true;
    notifyListeners();
    try {
      final uploaded = await _apiService.uploadFile(file);
      await _socketService.sendMessage({
        'room_id': room.id,
        'type': uploaded.type,
        'content': uploaded.type == 'file'
            ? ChatContentUtils.encodeFileContent(uploaded.fileName)
            : uploaded.fileName,
        'file_path': uploaded.filePath,
        'file_size': uploaded.fileSize,
        'reply_to_id': replyTo?.id,
      });
      _optimisticallyBumpRoom(
        room.id,
        uploaded.type == 'file'
            ? '[File] ${uploaded.fileName}'
            : uploaded.fileName,
        user.id,
        user.name,
      );
    } catch (_) {
      _error = AppLocalizer.current.tr('Failed to send the file.');
      notifyListeners();
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  Future<void> createPrivateChat(ChatUserOption user) async {
    await openPrivateChatByUserId(user.id);
  }

  Future<void> openPrivateChatByUserId(int userId) async {
    final currentUserId = _sessionController.user?.id;
    if (userId <= 0 || currentUserId == null || userId == currentUserId) {
      _error = AppLocalizer.current.tr(
        'Unable to start a chat with this account.',
      );
      notifyListeners();
      return;
    }

    try {
      final roomId = await _apiService.createPrivateRoom(userId);
      await refreshRooms(silent: true);
      await refreshHiddenRooms(silent: true);
      var room = _findPrivateRoomForUser(userId, preferredRoomId: roomId);
      if (room == null) {
        await Future<void>.delayed(const Duration(milliseconds: 280));
        await refreshRooms(silent: true);
        await refreshHiddenRooms(silent: true);
        room = _findPrivateRoomForUser(userId, preferredRoomId: roomId);
      }
      room ??= await _fetchPrivateRoomFallback(roomId);
      if (room == null) {
        throw StateError('Private room was not returned for user $userId');
      }
      final hiddenMatch = _hiddenRooms.any((item) => item.id == room!.id);
      if (hiddenMatch) {
        await unhideRoom(room);
        room = findRoomById(room.id) ?? room;
      }
      _roomFilter = RoomCollectionFilter.privateChats;
      await openRoom(room);
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[ChatController] openPrivateChatByUserId failed user=$userId error=$error',
        );
      }
      _error = AppLocalizer.current.tr('Failed to start the chat.');
      notifyListeners();
    }
  }

  Future<ChatRoom?> _fetchPrivateRoomFallback(int roomId) async {
    if (roomId <= 0) {
      return null;
    }

    try {
      final room = await _apiService.fetchRoom(roomId);
      _replaceRoom(room);
      return findRoomById(roomId) ?? room;
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[ChatController] private room fallback failed room=$roomId error=$error',
        );
      }
      return null;
    }
  }

  ChatRoom? _findPrivateRoomForUser(int userId, {int? preferredRoomId}) {
    if (preferredRoomId != null && preferredRoomId > 0) {
      final directMatch = findRoomById(preferredRoomId);
      if (directMatch != null) {
        return directMatch;
      }
    }

    for (final room in _rooms) {
      if (room.isPrivate && room.peerId == userId) {
        return room;
      }
    }
    for (final room in _hiddenRooms) {
      if (room.isPrivate && room.peerId == userId) {
        return room;
      }
    }
    return null;
  }

  Future<List<ChatUserOption>> fetchGroupMembers(int roomId) async {
    final members = await _apiService.fetchGroupMembers(roomId);
    final currentUserId = _sessionController.user?.id;
    return members
        .map(_normalizeUserOption)
        .where((user) => !user.mentionAll && user.id != currentUserId)
        .toList();
  }

  Future<void> createGroup({
    required String name,
    required List<int> memberIds,
  }) async {
    try {
      final roomId = await _apiService.createGroup(
        name: name,
        memberIds: memberIds,
      );
      await refreshRooms();
      final room = _rooms.firstWhere((item) => item.id == roomId);
      await openRoom(room);
    } catch (_) {
      _error = AppLocalizer.current.tr('Failed to create the group.');
      notifyListeners();
    }
  }

  Future<void> renameActiveGroup(String name) async {
    final room = _activeRoom;
    if (room == null || !room.isGroup) return;

    try {
      await _apiService.renameGroup(roomId: room.id, name: name);
      _replaceRoom(room.copyWith(title: name));
    } catch (_) {
      _error = AppLocalizer.current.tr('Failed to rename the group.');
      notifyListeners();
    }
  }

  Future<void> toggleBookmark(ChatRoom room) async {
    try {
      final bookmarked = await _socketService.toggleBookmark(room.id);
      _replaceRoom(room.copyWith(bookmarked: bookmarked));
    } catch (_) {
      _error = AppLocalizer.current.tr('Failed to update favorites.');
      notifyListeners();
    }
  }

  Future<void> hideRoom(ChatRoom room) async {
    try {
      await _socketService.hideRoom(room.id);
      _rooms.removeWhere((item) => item.id == room.id);
      await refreshHiddenRooms();
      if (_activeRoom?.id == room.id) {
        _activeRoom = null;
        _messages.clear();
      }
      notifyListeners();
    } catch (_) {
      _error = AppLocalizer.current.tr('Failed to hide the room.');
      notifyListeners();
    }
  }

  Future<void> unhideRoom(ChatRoom room) async {
    try {
      await _socketService.unhideRoom(room.id);
      _hiddenRooms.removeWhere((item) => item.id == room.id);
      await refreshRooms();
      notifyListeners();
    } catch (_) {
      _error = AppLocalizer.current.tr('Failed to restore the room.');
      notifyListeners();
    }
  }

  Future<void> searchUsers(String keyword) async {
    try {
      final users = await _apiService.fetchUsers(keyword);
      _userResults
        ..clear()
        ..addAll(users.map(_normalizeUserOption));
      _error = null;
      notifyListeners();
    } catch (_) {
      _error = AppLocalizer.current.tr('Failed to search users.');
      _userResults.clear();
      notifyListeners();
    }
  }

  Future<void> searchMentionUsers(String keyword) async {
    try {
      final users = await _apiService.fetchUsers(keyword, mention: true);
      _mentionResults
        ..clear()
        ..addAll(users.map(_normalizeUserOption));
      notifyListeners();
    } catch (_) {
      _mentionResults.clear();
      notifyListeners();
    }
  }

  void clearMentionUsers() {
    if (_mentionResults.isEmpty) return;
    _mentionResults.clear();
    notifyListeners();
  }

  Future<List<ChatSearchResult>> searchMessages(String keyword) async {
    final room = _activeRoom;
    if (room == null || keyword.trim().isEmpty) return const [];
    return _apiService.searchMessages(room.id, keyword.trim());
  }

  Future<void> jumpToMessage(
    int messageId, {
    String failureMessage = 'Failed to load the referenced message.',
  }) async {
    final room = _activeRoom;
    if (room == null) return;

    if (_messages.any((message) => message.id == messageId)) {
      _focusTargetMessageId = messageId;
      _focusTargetToken++;
      notifyListeners();
      return;
    }

    try {
      while (hasMoreMessages &&
          !_messages.any((message) => message.id == messageId)) {
        final nextPage = _messagePage + 1;
        final page = await _apiService.fetchMessages(room.id, page: nextPage);
        final fetched = page.messages.map(_normalizeMessage).toList();
        if (fetched.isEmpty) {
          _messagePage = page.currentPage;
          _messageLastPage = page.lastPage;
          break;
        }

        final existingIds = _messages.map((message) => message.id).toSet();
        final uniqueFetched = fetched
            .where((message) => !existingIds.contains(message.id))
            .toList();
        _messages.addAll(uniqueFetched);
        _messagePage = page.currentPage;
        _messageLastPage = page.lastPage;
      }

      if (_messages.any((message) => message.id == messageId)) {
        _cacheMessagesForRoom(room.id);
        _focusTargetMessageId = messageId;
        _focusTargetToken++;
        notifyListeners();
        return;
      }

      final focused = await _apiService.focusMessage(room.id, messageId);
      if (focused.isEmpty) {
        _error = failureMessage;
        notifyListeners();
        return;
      }

      _messages
        ..clear()
        ..addAll(focused.map(_normalizeMessage));
      _cacheMessagesForRoom(room.id);
      _focusTargetMessageId = messageId;
      _focusTargetToken++;
      notifyListeners();
    } catch (_) {
      _error = failureMessage;
      notifyListeners();
    }
  }

  Future<void> focusPinnedMessage(int messageId) async {
    if (messageId <= 0) return;
    await jumpToMessage(
      messageId,
      failureMessage: AppLocalizer.current.tr(
        'Failed to load the pinned message.',
      ),
    );
  }

  Future<void> loadPinnedMessages() async {
    final room = _activeRoom;
    if (room == null) return;
    try {
      final pins = await _socketService.fetchPinnedMessages(room.id);
      _replacePinnedMessages(pins);
    } catch (_) {
      _error = AppLocalizer.current.tr('Failed to load pinned messages.');
      notifyListeners();
    }
  }

  Future<void> togglePin(ChatMessage message) async {
    final room = _activeRoom;
    if (room == null) return;
    try {
      await _socketService.togglePin(roomId: room.id, messageId: message.id);
    } catch (_) {
      _error = AppLocalizer.current.tr('Failed to update the pin.');
      notifyListeners();
    }
  }

  Future<void> toggleLike(ChatMessage message) async {
    final room = _activeRoom;
    if (room == null || message.isRecalled) return;
    try {
      await _socketService.toggleReaction(
        roomId: room.id,
        messageId: message.id,
      );
    } catch (_) {
      _error = AppLocalizer.current.tr('Failed to update the like.');
      notifyListeners();
    }
  }

  Future<void> recallMessage(ChatMessage message) async {
    final room = _activeRoom;
    final currentUserId = _sessionController.user?.id;
    if (room == null ||
        currentUserId == null ||
        message.senderId != currentUserId ||
        message.isRecalled) {
      return;
    }

    try {
      await _socketService.recallMessage(
        roomId: room.id,
        messageId: message.id,
      );
    } catch (_) {
      _error = AppLocalizer.current.tr('Failed to recall the message.');
      notifyListeners();
    }
  }

  void setRoomFilter(RoomCollectionFilter filter) {
    _roomFilter = filter;
    notifyListeners();
  }

  void setRoomSearch(String value) {
    _roomSearch = value;
    notifyListeners();
  }

  void clearActiveRoom() {
    _activeRoom = null;
    _messages.clear();
    _pinnedMessages.clear();
    _focusTargetMessageId = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> reset() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    _socketStreamsBound = false;
    _rooms.clear();
    _hiddenRooms.clear();
    _messages.clear();
    _pinnedMessages.clear();
    _roomMessageCaches.clear();
    _userResults.clear();
    _mentionResults.clear();
    _onlineUserIds.clear();
    _activeRoom = null;
    _roomFilter = RoomCollectionFilter.groups;
    _roomSearch = '';
    _connecting = false;
    _loadingRooms = false;
    _loadingMessages = false;
    _sending = false;
    _connected = false;
    _initializedForSession = false;
    _incomingNoticeRoomId = null;
    _incomingNoticeRoomTitle = null;
    _incomingNoticePreview = null;
    _focusTargetMessageId = null;
    _realtimeFallbackTimer?.cancel();
    _realtimeFallbackTimer = null;
    await _socketService.disconnect();
    notifyListeners();
  }

  ChatRoom? findRoomById(int roomId) {
    for (final room in _rooms) {
      if (room.id == roomId) return room;
    }
    for (final room in _hiddenRooms) {
      if (room.id == roomId) return room;
    }
    return null;
  }

  @override
  void dispose() {
    _sessionController.removeListener(_onSessionChanged);
    unawaited(reset());
    super.dispose();
  }

  void _replaceRooms(List<ChatRoom> rooms) {
    _rooms
      ..clear()
      ..addAll(_sortRooms(rooms.map(_normalizeRoom).toList()));
    notifyListeners();
  }

  void _replaceHiddenRooms(List<ChatRoom> rooms) {
    _hiddenRooms
      ..clear()
      ..addAll(_sortRooms(rooms.map(_normalizeRoom).toList()));
    notifyListeners();
  }

  void _replaceRoom(ChatRoom room) {
    room = _normalizeRoom(room);
    final index = _rooms.indexWhere((item) => item.id == room.id);
    if (index == -1) {
      _rooms.insert(0, room);
    } else {
      _rooms[index] = room;
    }

    if (_activeRoom?.id == room.id) {
      _activeRoom = room;
    }

    _rooms.sort(_roomComparator);
    notifyListeners();
  }

  void _replaceOnlineUsers(Set<int> userIds) {
    _onlineUserIds
      ..clear()
      ..addAll(userIds);
    notifyListeners();
  }

  void _handleIncomingMessage(ChatMessage message) {
    message = _normalizeMessage(message);
    final activeRoomId = _activeRoom?.id;
    final currentUserId = _sessionController.user?.id;
    final preview = message.type == 'file'
        ? '[File] ${ChatContentUtils.decodeFileContent(message.content)}'
        : ChatContentUtils.renderPlainText(message.content);
    if (activeRoomId == message.roomId) {
      final exists = _messages.any((item) => item.id == message.id);
      if (!exists) {
        _messages.insert(0, message);
        _cacheMessagesForRoom(message.roomId);
        _messageScrollToken++;
      }

      unawaited(_apiService.markRoomReadAll(message.roomId));
      _markRoomUnread(message.roomId, 0);
    } else {
      final currentUnread = (_rooms.firstWhere(
        (item) => item.id == message.roomId,
        orElse: () => ChatRoom(
          id: message.roomId,
          type: 'group',
          title: AppLocalizer.current.tr('Chat'),
          description: '',
          avatar: '',
          peerId: null,
          tableName: null,
          uuidTableRecord: null,
          unreadCount: 0,
          bookmarked: false,
          hiddenAt: null,
          lastMessage: null,
          isPublic: false,
          isActive: true,
          isJoined: true,
          canJoin: false,
          memberCount: 0,
        ),
      )).unreadCount;
      _markRoomUnread(message.roomId, currentUnread + 1);
      if (message.senderId != currentUserId) {
        final room = findRoomById(message.roomId);
        _incomingNoticeRoomId = message.roomId;
        _incomingNoticeRoomTitle =
            room?.title ?? AppLocalizer.current.tr('Chat');
        _incomingNoticePreview = preview.isEmpty
            ? AppLocalizer.current.tr('You have a new message.')
            : preview;
        _incomingNoticeToken++;
      }
    }

    _optimisticallyBumpRoom(
      message.roomId,
      preview,
      message.senderId,
      message.senderName,
      message.createdAt,
    );
  }

  void _handleReadReceipt(Map<String, dynamic> payload) {
    final messageId = (payload['message_id'] as num?)?.toInt();
    if (messageId == null) return;
    final index = _messages.indexWhere((item) => item.id == messageId);
    if (index == -1) return;
    _messages[index] = _messages[index].copyWith(isRead: true);
    if (_activeRoom != null) {
      _cacheMessagesForRoom(_activeRoom!.id);
    }
    notifyListeners();
  }

  void _handleReactionUpdated(Map<String, dynamic> payload) {
    final messageId = (payload['message_id'] as num?)?.toInt();
    if (messageId == null) return;
    final index = _messages.indexWhere((item) => item.id == messageId);
    if (index == -1) return;

    final likes = (payload['likes'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map(
          (item) => ChatMessageLike.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();

    _messages[index] = _messages[index].copyWith(
      likes: likes,
      likeCount: (payload['like_count'] as num?)?.toInt() ?? likes.length,
      likedByMe: payload['liked_by_me'] == true || payload['liked_by_me'] == 1,
    );
    if (_activeRoom != null) {
      _cacheMessagesForRoom(_activeRoom!.id);
    }
    notifyListeners();
  }

  void _replacePinnedMessages(List<ChatPinnedMessage> pins) {
    _pinnedMessages
      ..clear()
      ..addAll(pins);

    final pinnedIds = pins.map((item) => item.id).toSet();
    for (var index = 0; index < _messages.length; index++) {
      final message = _messages[index];
      _messages[index] = message.copyWith(
        isPinned: pinnedIds.contains(message.id),
      );
    }
    if (_activeRoom != null) {
      _cacheMessagesForRoom(_activeRoom!.id);
    }
    notifyListeners();
  }

  void _handleMessageRecalled(Map<String, dynamic> payload) {
    final messageId = (payload['message_id'] as num?)?.toInt();
    if (messageId == null) return;
    final index = _messages.indexWhere((item) => item.id == messageId);
    if (index == -1) return;

    _messages[index] = _messages[index].copyWith(
      content:
          (payload['content'] ??
                  AppLocalizer.current.tr('This message was recalled'))
              .toString(),
      isRecalled: true,
    );
    if (_activeRoom != null) {
      _cacheMessagesForRoom(_activeRoom!.id);
    }
    notifyListeners();
  }

  void _setMessagePage(ChatMessagePage page) {
    _messages
      ..clear()
      ..addAll(page.messages.map(_normalizeMessage));
    _messagePage = page.currentPage;
    _messageLastPage = page.lastPage;
  }

  bool _sameMessageSnapshot(List<ChatMessage> before, List<ChatMessage> after) {
    if (identical(before, after)) {
      return true;
    }
    if (before.length != after.length) {
      return false;
    }
    for (var i = 0; i < before.length; i++) {
      final left = before[i];
      final right = after[i];
      if (left.id != right.id ||
          left.content != right.content ||
          left.filePath != right.filePath ||
          left.likeCount != right.likeCount ||
          left.isPinned != right.isPinned ||
          left.isRecalled != right.isRecalled ||
          left.isRead != right.isRead) {
        return false;
      }
    }
    return true;
  }

  void _cacheMessagesForRoom(int roomId) {
    _roomMessageCaches[roomId] = _RoomMessageCache(
      messages: List<ChatMessage>.from(_messages),
      currentPage: _messagePage,
      lastPage: _messageLastPage,
    );
  }

  void _restoreMessageCache(_RoomMessageCache cache) {
    _messages
      ..clear()
      ..addAll(cache.messages);
    _messagePage = cache.currentPage;
    _messageLastPage = cache.lastPage;
  }

  void _markRoomUnread(int roomId, int unreadCount) {
    final index = _rooms.indexWhere((room) => room.id == roomId);
    if (index == -1) return;
    _rooms[index] = _rooms[index].copyWith(unreadCount: unreadCount);
    notifyListeners();
  }

  void _optimisticallyBumpRoom(
    int roomId,
    String preview,
    int senderId,
    String senderName, [
    DateTime? createdAt,
  ]) {
    final index = _rooms.indexWhere((item) => item.id == roomId);
    if (index == -1) return;

    _rooms[index] = _rooms[index].copyWith(
      lastMessage: ChatRoomLastMessage(
        content: preview,
        createdAt: createdAt ?? DateTime.now(),
        senderName: senderName,
        senderId: senderId,
      ),
    );
    _rooms.sort(_roomComparator);
    notifyListeners();
  }

  List<ChatRoom> _sortRooms(List<ChatRoom> rooms) {
    final sorted = [...rooms]..sort(_roomComparator);
    return sorted;
  }

  int _roomComparator(ChatRoom left, ChatRoom right) {
    final leftTime = left.lastMessage?.createdAt;
    final rightTime = right.lastMessage?.createdAt;
    if (leftTime == null && rightTime == null) {
      return left.title.toLowerCase().compareTo(right.title.toLowerCase());
    }
    if (leftTime == null) return 1;
    if (rightTime == null) return -1;
    return rightTime.compareTo(leftTime);
  }

  Future<void> syncOfflineNotifications() => _syncOfflineNotifications();

  Future<void> _onSessionChanged() async {
    if (_sessionController.isLoggedIn) {
      await connectIfNeeded();
    } else if (_initializedForSession ||
        _rooms.isNotEmpty ||
        _messages.isNotEmpty) {
      await reset();
    }
  }

  Future<List<ChatRoom>> _fetchRoomsViaApi() async {
    if (_connected || _socketService.isConnected) {
      try {
        return await _socketService.fetchRooms();
      } catch (_) {
        // Fallback to API if socket fetch fails after connection.
      }
    }
    try {
      return await _apiService.fetchRooms();
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 450));
      try {
        return await _apiService.fetchRooms();
      } catch (_) {
        return _socketService.fetchRooms();
      }
    }
  }

  Future<List<ChatRoom>> _fetchHiddenRoomsViaApi() async {
    if (_connected || _socketService.isConnected) {
      try {
        return await _socketService.fetchHiddenRooms();
      } catch (_) {
        // Fallback to API if socket fetch fails after connection.
      }
    }
    try {
      return await _apiService.fetchHiddenRooms();
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 450));
      try {
        return await _apiService.fetchHiddenRooms();
      } catch (_) {
        return _socketService.fetchHiddenRooms();
      }
    }
  }

  ChatRoom _normalizeRoom(ChatRoom room) {
    return room.copyWith(avatar: _apiService.resolvePublicUrl(room.avatar));
  }

  Future<void> _syncOfflineNotifications() async {
    try {
      final notifications = await _apiService.fetchUnreadNotifications(
        limit: 10,
      );
      if (notifications.isEmpty) {
        return;
      }

      final latest = notifications.first;
      final latestRoomId = latest.roomId;
      final latestRoom = latestRoomId == null
          ? null
          : findRoomById(latestRoomId);

      _incomingNoticeRoomId = latestRoomId;
      _incomingNoticeRoomTitle =
          latestRoom?.title ?? AppLocalizer.current.tr('Chat');
      _incomingNoticePreview = notifications.length == 1
          ? (latest.content.trim().isEmpty
                ? AppLocalizer.current.tr('You have a new message.')
                : latest.content.trim())
          : AppLocalizer.current.tr('You have {count} unread chat updates.', {
              'count': '${notifications.length}',
            });
      _incomingNoticeToken++;
      notifyListeners();

      await _apiService.markNotificationsRead(
        notifications.map((item) => item.id).toList(),
      );
    } catch (_) {
      // Ignore offline-notification sync failures.
    }
  }

  ChatMessage _normalizeMessage(ChatMessage message) {
    final currentUser = _sessionController.user;
    final fallbackAvatar =
        currentUser != null &&
            message.senderId == currentUser.id &&
            (message.senderAvatar.trim().isEmpty)
        ? currentUser.avatarUrl
        : message.senderAvatar;

    return message.copyWith(
      senderAvatar: _apiService.resolvePublicUrl(fallbackAvatar),
      filePath: _apiService.resolvePublicUrl(message.filePath),
    );
  }

  ChatUserOption _normalizeUserOption(ChatUserOption user) {
    return user.copyWith(
      avatarUrl: _apiService.resolvePublicUrl(user.avatarUrl),
    );
  }
}

class _RoomMessageCache {
  const _RoomMessageCache({
    required this.messages,
    required this.currentPage,
    required this.lastPage,
  });

  final List<ChatMessage> messages;
  final int currentPage;
  final int lastPage;
}
