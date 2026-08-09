import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/chat_controller.dart';
import '../controllers/session_controller.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/app_date_utils.dart';
import '../core/utils/chat_content_utils.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../models/chat_user_option.dart';
import '../services/attachment_open_service.dart';
import 'attachment_preview_screen.dart';
import '../widgets/app_logo.dart';
import '../widgets/remote_image.dart';

class ChatHomeScreen extends StatefulWidget {
  const ChatHomeScreen({super.key});

  @override
  State<ChatHomeScreen> createState() => _ChatHomeScreenState();
}

class _ChatHomeScreenState extends State<ChatHomeScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _roomSearchController = TextEditingController();
  final ScrollController _messageScrollController = ScrollController();
  final Map<int, GlobalKey> _messageItemKeys = <int, GlobalKey>{};
  final Map<String, ChatUserOption> _selectedMentionsByToken =
      <String, ChatUserOption>{};
  Timer? _mentionSearchDebounce;
  Timer? _highlightClearTimer;
  ChatController? _chatController;
  ChatMessage? _replyingMessage;
  int _lastIncomingNoticeToken = 0;
  int _lastMessageScrollToken = 0;
  int _lastFocusTargetToken = 0;
  String? _lastShownError;
  int? _lastScrolledRoomId;
  int? _lastActiveRoomId;
  int? _highlightedMessageId;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_handleComposerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(context.read<ChatController>().connectIfNeeded());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = context.read<ChatController>();
    if (!identical(_chatController, controller)) {
      _chatController?.removeListener(_handleChatControllerChanged);
      _chatController = controller;
      _lastIncomingNoticeToken = controller.incomingNoticeToken;
      _lastMessageScrollToken = controller.messageScrollToken;
      _lastFocusTargetToken = controller.focusTargetToken;
      controller.addListener(_handleChatControllerChanged);
    }
  }

  @override
  void dispose() {
    _chatController?.removeListener(_handleChatControllerChanged);
    _mentionSearchDebounce?.cancel();
    _highlightClearTimer?.cancel();
    _messageController.removeListener(_handleComposerChanged);
    _messageController.dispose();
    _roomSearchController.dispose();
    _messageScrollController.dispose();
    super.dispose();
  }

  void _handleChatControllerChanged() {
    if (!mounted || _chatController == null) return;

    final controller = _chatController!;
    final currentActiveRoomId = controller.activeRoom?.id;
    if (_lastActiveRoomId != currentActiveRoomId) {
      _lastActiveRoomId = currentActiveRoomId;
      _replyingMessage = null;
      _selectedMentionsByToken.clear();
      _mentionSearchDebounce?.cancel();
      controller.clearMentionUsers();
    }
    if (controller.activeRoom == null) {
      _lastScrolledRoomId = null;
      _messageItemKeys.clear();
      _highlightedMessageId = null;
    }

    final focusToken = controller.focusTargetToken;
    if (focusToken != _lastFocusTargetToken) {
      _lastFocusTargetToken = focusToken;
      final targetId = controller.focusTargetMessageId;
      if (targetId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scheduleFocusMessage(targetId);
        });
      }
    }

    final error = controller.error;
    if (error == null) {
      _lastShownError = null;
    } else if (error != _lastShownError) {
      _lastShownError = error;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFBF3A3A),
          duration: const Duration(seconds: 4),
          showCloseIcon: true,
          closeIconColor: Colors.white,
          content: Text(
            error,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(_chatController, controller)) {
          controller.clearError();
        }
      });
    }

    final scrollToken = controller.messageScrollToken;
    if (scrollToken != _lastMessageScrollToken) {
      _lastMessageScrollToken = scrollToken;
      final roomId = controller.activeRoom?.id;
      if (roomId != null) {
        final shouldAnimate = _lastScrolledRoomId == roomId;
        _lastScrolledRoomId = roomId;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scheduleScrollToLatest(animated: shouldAnimate);
        });
      }
    }

    final token = controller.incomingNoticeToken;
    if (token == 0 || token == _lastIncomingNoticeToken) return;

    _lastIncomingNoticeToken = token;

    final roomTitle = controller.incomingNoticeRoomTitle ?? 'Chat';
    final preview = controller.incomingNoticePreview ?? 'You have a new message.';
    final roomId = controller.incomingNoticeRoomId;
    final messenger = ScaffoldMessenger.maybeOf(context);

    _playIncomingNotificationCue();
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        showCloseIcon: true,
        closeIconColor: Colors.white,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              roomTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
        action: roomId == null
            ? null
            : SnackBarAction(
                label: 'Open',
                onPressed: () {
                  final room = controller.findRoomById(roomId);
                  if (room != null) {
                    unawaited(controller.openRoom(room));
                  }
                },
              ),
      ),
    );
  }

  void _playIncomingNotificationCue() {
    if (kIsWeb) {
      return;
    }
    unawaited(SystemSound.play(SystemSoundType.alert));
    unawaited(HapticFeedback.mediumImpact());
  }

  void _scrollToLatest({required bool animated}) {
    if (!mounted || !_messageScrollController.hasClients) return;
    final position = _messageScrollController.position.maxScrollExtent;
    if (animated) {
      _messageScrollController.animateTo(
        position,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    } else {
      _messageScrollController.jumpTo(position);
    }
  }

  void _scheduleScrollToLatest({required bool animated}) {
    const delays = <int>[0, 24, 96, 220];
    for (var index = 0; index < delays.length; index++) {
      Future<void>.delayed(Duration(milliseconds: delays[index]), () {
        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final isLastAttempt = index == delays.length - 1;
          _scrollToLatest(animated: animated && isLastAttempt);
        });
      });
    }
  }

  void _scheduleFocusMessage(int messageId) {
    const delays = <int>[0, 24, 96, 220, 420];
    for (var index = 0; index < delays.length; index++) {
      final delay = delays[index];
      Future<void>.delayed(Duration(milliseconds: delay), () {
        if (!mounted) return;
        if (!_messageScrollController.hasClients) return;
        final key = _messageItemKeys[messageId];
        final targetContext = key?.currentContext;
        if (targetContext == null) {
          final controller = _chatController;
          final chronological =
              controller?.messages.reversed.toList() ?? const <ChatMessage>[];
          final targetIndex = chronological.indexWhere(
            (message) => message.id == messageId,
          );

          if (targetIndex >= 0 && chronological.length > 1) {
            final ratio = targetIndex / (chronological.length - 1);
            final approximateOffset =
                (_messageScrollController.position.maxScrollExtent * ratio)
                    .clamp(
                      _messageScrollController.position.minScrollExtent,
                      _messageScrollController.position.maxScrollExtent,
                    );

            if (index <= 1) {
              _messageScrollController.jumpTo(approximateOffset);
            } else {
              _messageScrollController.animateTo(
                approximateOffset,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
              );
            }
          }
          return;
        }
        // ignore: use_build_context_synchronously
        final renderObject = targetContext.findRenderObject();
        if (renderObject is! RenderObject || !renderObject.attached) return;

        final viewport = RenderAbstractViewport.of(renderObject);
        final reveal = viewport.getOffsetToReveal(renderObject, 0.18);
        final targetOffset = reveal.offset.clamp(
          _messageScrollController.position.minScrollExtent,
          _messageScrollController.position.maxScrollExtent,
        );

        if (delay == 0) {
          _messageScrollController.jumpTo(targetOffset);
        } else {
          _messageScrollController.animateTo(
            targetOffset,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
          );
        }

        setState(() => _highlightedMessageId = messageId);
        _highlightClearTimer?.cancel();
        _highlightClearTimer = Timer(const Duration(seconds: 2), () {
          if (!mounted) return;
          setState(() {
            if (_highlightedMessageId == messageId) {
              _highlightedMessageId = null;
            }
          });
        });
      });
    }
  }

  GlobalKey _messageKeyFor(int messageId) =>
      _messageItemKeys.putIfAbsent(messageId, GlobalKey.new);

  Future<void> _pickAndSendFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: kIsWeb,
      type: FileType.any,
    );
    final file = result?.files.single;
    if (file == null || !mounted) return;
    await context.read<ChatController>().sendFile(
      file,
      replyTo: _replyingMessage,
    );
    if (mounted) {
      setState(() => _replyingMessage = null);
    }
  }

  Future<void> _sendText() async {
    final chat = context.read<ChatController>();
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final content = _buildOutboundMessage(text);
    await chat.sendText(content, replyTo: _replyingMessage);
    _messageController.clear();
    if (mounted) {
      setState(() => _replyingMessage = null);
    }
    _selectedMentionsByToken.clear();
    chat.clearMentionUsers();
  }

  void _handleComposerChanged() {
    if (!mounted) return;
    final chat = context.read<ChatController>();
    if (chat.activeRoom == null) {
      _mentionSearchDebounce?.cancel();
      chat.clearMentionUsers();
      return;
    }

    final query = _extractMentionQuery(
      _messageController.text,
      _messageController.selection.baseOffset,
    );

    if (query == null) {
      _mentionSearchDebounce?.cancel();
      chat.clearMentionUsers();
      return;
    }

    _mentionSearchDebounce?.cancel();
    _mentionSearchDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      unawaited(chat.searchMentionUsers(query));
    });
  }

  String? _extractMentionQuery(String text, int caretOffset) {
    if (caretOffset < 0 || caretOffset > text.length) return null;
    final beforeCaret = text.substring(0, caretOffset);
    final match = RegExp(r'(^|\s)@([^\s@]{0,32})$').firstMatch(beforeCaret);
    if (match == null) return null;
    return (match.group(2) ?? '').trim();
  }

  String _mentionVisibleToken(ChatUserOption user) {
    if (user.mentionAll) return '@ALL';
    final key = user.mentionKey.isNotEmpty
        ? user.mentionKey
        : (user.username.isNotEmpty ? user.username : user.name);
    return '@$key';
  }

  String _mentionMarkup(ChatUserOption user) {
    if (user.mentionAll) return '@[ALL](all)';
    final label = user.name.isNotEmpty ? user.name : user.username;
    final target = user.mentionKey.isNotEmpty
        ? user.mentionKey
        : (user.username.isNotEmpty ? user.username : user.id.toString());
    return '@[$label]($target)';
  }

  Future<void> _insertMention(ChatUserOption user) async {
    final text = _messageController.text;
    final selection = _messageController.selection;
    final caretOffset = selection.baseOffset < 0
        ? text.length
        : selection.baseOffset;
    final beforeCaret = text.substring(0, caretOffset);
    final match = RegExp(r'(^|\s)@([^\s@]{0,32})$').firstMatch(beforeCaret);
    if (match == null) return;

    final replaceStart = match.start + (match.group(1)?.length ?? 0);
    final replaceEnd = caretOffset;
    final token = '${_mentionVisibleToken(user)} ';
    final updated = text.replaceRange(replaceStart, replaceEnd, token);

    _selectedMentionsByToken[_mentionVisibleToken(user).toLowerCase()] = user;
    _messageController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: replaceStart + token.length),
    );
    context.read<ChatController>().clearMentionUsers();
    if (mounted) {
      setState(() {});
    }
  }

  String _buildOutboundMessage(String input) {
    var result = input;
    final entries = _selectedMentionsByToken.entries.toList()
      ..sort((left, right) => right.key.length.compareTo(left.key.length));

    for (final entry in entries) {
      final token = entry.key;
      final mention = entry.value;
      final escaped = RegExp.escape(token);
      result = result.replaceAllMapped(
        RegExp('(^|\\s)($escaped)(?=\\s|\$)', caseSensitive: false),
        (match) => '${match.group(1) ?? ''}${_mentionMarkup(mention)}',
      );
    }

    return result;
  }

  Future<void> _showGroupMembersSheet(ChatRoom room) async {
    final membersFuture = context.read<ChatController>().fetchGroupMembers(
      room.id,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.62,
          minChildSize: 0.36,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: FutureBuilder<List<ChatUserOption>>(
                future: membersFuture,
                builder: (context, snapshot) {
                  final members = snapshot.data ?? const <ChatUserOption>[];
                  return Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 52,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4DDED),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF4FF),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.groups_rounded,
                                color: Color(0xFF316BFF),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    room.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF20324F),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Tap a member to open a private chat.',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6A7C97),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: switch (snapshot.connectionState) {
                          ConnectionState.waiting => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          _ when snapshot.hasError => const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 28),
                              child: Text(
                                'Unable to load members right now.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF6A7C97),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          _ when members.isEmpty => const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 28),
                              child: Text(
                                'This group does not have visible members yet.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF6A7C97),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          _ => ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                            itemCount: members.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final member = members[index];
                              return Material(
                                color: const Color(0xFFF7FAFF),
                                borderRadius: BorderRadius.circular(18),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () async {
                                    Navigator.of(context).pop();
                                    await this
                                        .context
                                        .read<ChatController>()
                                        .createPrivateChat(member);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        _Avatar(
                                          url: member.avatarUrl,
                                          name: member.name,
                                          radius: 23,
                                          fallbackIcon:
                                              Icons.person_rounded,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                member.name.isEmpty
                                                    ? member.username
                                                    : member.name,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF223553),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                member.email.isNotEmpty
                                                    ? member.email
                                                    : '@${member.username}',
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF8090A9),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE8F0FF),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: const Text(
                                            'Message',
                                            style: TextStyle(
                                              color: Color(0xFF316BFF),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        },
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showPinnedMessagesSheet() async {
    final chat = context.read<ChatController>();
    await chat.loadPinnedMessages();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.64,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Consumer<ChatController>(
              builder: (context, chat, _) {
                final pins = chat.pinnedMessages;
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 52,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4DDED),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Icon(
                              Icons.push_pin_rounded,
                              color: Color(0xFF316BFF),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Pinned messages',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: pins.isEmpty
                            ? const Center(
                                child: Text(
                                  'No data available',
                                  style: TextStyle(
                                    color: Color(0xFF6A7C97),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                controller: scrollController,
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  8,
                                  20,
                                  24,
                                ),
                                itemCount: pins.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final pin = pins[index];
                                  return Material(
                                    color: const Color(0xFFF7FAFF),
                                    borderRadius: BorderRadius.circular(18),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(18),
                                      onTap: () async {
                                        Navigator.of(context).pop();
                                        await Future<void>.delayed(
                                          const Duration(milliseconds: 260),
                                        );
                                        await chat.focusPinnedMessage(pin.id);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    pin.senderName.isEmpty
                                                        ? 'Unknown'
                                                        : pin.senderName,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: Color(0xFF223553),
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  AppDateUtils.formatRoomTime(
                                                    pin.pinnedAt ??
                                                        pin.createdAt,
                                                  ),
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF8090A9),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              pin.snippet.isEmpty
                                                  ? '-'
                                                  : pin.snippet,
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Color(0xFF5E708A),
                                                height: 1.45,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _showMessageActions(ChatMessage message, bool isMine) async {
    final chat = context.read<ChatController>();
    final currentFilter = chat.roomFilter;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 52,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4DDED),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  leading: const Icon(Icons.reply_rounded),
                  title: const Text('Reply'),
                  onTap: () {
                    Navigator.of(context).pop();
                    setState(() => _replyingMessage = message);
                  },
                ),
                ListTile(
                  leading: Icon(
                    message.isPinned
                        ? Icons.push_pin_rounded
                        : Icons.push_pin_outlined,
                  ),
                  title: Text(message.isPinned ? 'Unpin' : 'Pin'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await chat.togglePin(message);
                  },
                ),
                ListTile(
                  leading: Icon(
                    message.likedByMe
                        ? Icons.thumb_up_rounded
                        : Icons.thumb_up_outlined,
                  ),
                  title: Text(message.likedByMe ? 'Remove like' : 'Like'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await chat.toggleLike(message);
                  },
                ),
                if (isMine && !message.isRecalled)
                  ListTile(
                    leading: const Icon(Icons.undo_rounded),
                    title: const Text('Recall'),
                    onTap: () async {
                      Navigator.of(context).pop();
                      final ok = await showDialog<bool>(
                        context: this.context,
                        builder: (context) => AlertDialog(
                          title: const Text('Confirm'),
                          content: const Text('Do you want to recall this message?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Recall'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await chat.recallMessage(message);
                      }
                    },
                  ),
                if (currentFilter == RoomCollectionFilter.hidden)
                  const SizedBox(height: 6)
                else
                  const SizedBox(height: 6),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final theme = Theme.of(context);

    return Consumer<ChatController>(
      builder: (context, chat, _) {
        final room = chat.activeRoom;

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 16,
            title: Row(
              children: [
                const AppLogo(size: 44, showWordmark: false),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppConstants.appName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        room?.title ?? 'Rooms',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6A7C97),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              if (room != null)
                IconButton(
                  tooltip: 'Back',
                  onPressed: chat.clearActiveRoom,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'hidden') {
                    context.read<ChatController>().setRoomFilter(
                      RoomCollectionFilter.hidden,
                    );
                  } else if (value == 'logout') {
                    await session.logout();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'hidden', child: Text('Hidden chats')),
                  PopupMenuDivider(),
                  PopupMenuItem(value: 'logout', child: Text('Sign out')),
                ],
              ),
            ],
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF7FAFF), Color(0xFFF2F6FD)],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: room == null
                              ? _RoomListView(
                                  theme: theme,
                                  roomSearchController: _roomSearchController,
                                )
                              : _RoomChatView(
                                  room: room,
                                  messageController: _messageController,
                                  scrollController: _messageScrollController,
                                  replyingMessage: _replyingMessage,
                                  mentionResults: chat.mentionResults,
                                  messageKeyBuilder: _messageKeyFor,
                                  highlightedMessageId: _highlightedMessageId,
                                  onSendText: _sendText,
                                  onSendFile: _pickAndSendFile,
                                  onPickMention: _insertMention,
                                  onClearReply: () =>
                                      setState(() => _replyingMessage = null),
                                  onShowPinnedMessages:
                                      _showPinnedMessagesSheet,
                                  onShowMembers: room.isGroup
                                      ? () => _showGroupMembersSheet(room)
                                      : null,
                                  onShowMessageActions: _showMessageActions,
                                  onReplyTap: (messageId) => context
                                      .read<ChatController>()
                                      .jumpToMessage(messageId),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RoomListView extends StatelessWidget {
  const _RoomListView({
    required this.theme,
    required this.roomSearchController,
  });

  final ThemeData theme;
  final TextEditingController roomSearchController;

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatController>(
      builder: (context, chat, _) {
        final rooms = chat.visibleRooms;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: roomSearchController,
                      onChanged: chat.setRoomSearch,
                      decoration: const InputDecoration(
                        hintText: 'Search rooms',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    onPressed: chat.refreshRooms,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChipButton(
                      label: 'Groups',
                      selected: chat.roomFilter == RoomCollectionFilter.groups,
                      onTap: () =>
                          chat.setRoomFilter(RoomCollectionFilter.groups),
                    ),
                    _FilterChipButton(
                      label: 'Direct chats',
                      selected:
                          chat.roomFilter == RoomCollectionFilter.privateChats,
                      onTap: () =>
                          chat.setRoomFilter(RoomCollectionFilter.privateChats),
                    ),
                    _FilterChipButton(
                      label: 'Favorites',
                      selected:
                          chat.roomFilter == RoomCollectionFilter.bookmarked,
                      onTap: () =>
                          chat.setRoomFilter(RoomCollectionFilter.bookmarked),
                    ),
                    if (chat.roomFilter == RoomCollectionFilter.hidden)
                      _FilterChipButton(
                        label: 'Hidden chats',
                        selected:
                            chat.roomFilter == RoomCollectionFilter.hidden,
                        onTap: () =>
                            chat.setRoomFilter(RoomCollectionFilter.hidden),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: chat.loadingRooms && rooms.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : rooms.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF4FF),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 34,
                                color: Color(0xFF5C7CFA),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              switch (chat.roomFilter) {
                                RoomCollectionFilter.groups => 'No group chats yet',
                                RoomCollectionFilter.privateChats =>
                                  'No direct chats yet',
                                RoomCollectionFilter.bookmarked =>
                                  'No favorite rooms yet',
                                RoomCollectionFilter.hidden => 'No hidden chats yet',
                              },
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF213A63),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              switch (chat.roomFilter) {
                                RoomCollectionFilter.groups =>
                                  'Browse admin-created public groups and tap one to join.',
                                RoomCollectionFilter.privateChats =>
                                  'Existing one-to-one chats will appear here.',
                                RoomCollectionFilter.bookmarked =>
                                  'Rooms you favorite will appear here.',
                                RoomCollectionFilter.hidden =>
                                  'Rooms you hide will appear here.',
                              },
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: Color(0xFF6A7C97),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: rooms.length,
                        separatorBuilder: (_, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final room = rooms[index];
                          final preview = room.lastMessage == null
                              ? room.canJoin
                                    ? 'Tap to join this public group.'
                                    : (room.description.isNotEmpty
                                          ? room.description
                                          : 'No messages yet')
                              : ChatContentUtils.renderPlainText(
                                  room.lastMessage!.content,
                                );
                          final metaLine = room.isGroup
                              ? '${room.memberCount} members • ${room.isPublic ? 'Public group' : 'Private group'}'
                              : null;
                          return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(22),
                              onTap: () => chat.openRoom(room),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        _Avatar(
                                          url: room.avatar,
                                          name: room.title,
                                          radius: 26,
                                          fallbackIcon: room.isGroup
                                              ? Icons.groups_rounded
                                              : Icons.person_rounded,
                                        ),
                                        if (chat.isUserOnline(room.peerId))
                                          Positioned(
                                            right: -1,
                                            bottom: -1,
                                            child: Container(
                                              width: 14,
                                              height: 14,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF22C55E),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 2,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  room.title,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: theme
                                                      .textTheme
                                                      .titleMedium,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                AppDateUtils.formatRoomTime(
                                                  room.lastMessage?.createdAt,
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF8090A9),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            preview.isEmpty ? '-' : preview,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF5E708A),
                                              height: 1.4,
                                            ),
                                          ),
                                          if (metaLine != null) ...[
                                            const SizedBox(height: 8),
                                            Text(
                                              metaLine,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF90A0B8),
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      children: [
                                        IconButton(
                                          onPressed: () =>
                                              chat.toggleBookmark(room),
                                          icon: Icon(
                                            room.bookmarked
                                                ? Icons.star_rounded
                                                : Icons.star_border_rounded,
                                            color: room.bookmarked
                                                ? const Color(0xFFF59E0B)
                                                : const Color(0xFF96A4BA),
                                          ),
                                        ),
                                        if (room.canJoin)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE8F6EF),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: const Text(
                                              'Join',
                                              style: TextStyle(
                                                color: Color(0xFF0C8B55),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          )
                                        else if (room.unreadCount > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 9,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF316BFF),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              room.unreadCount.toString(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RoomChatView extends StatelessWidget {
  const _RoomChatView({
    required this.room,
    required this.messageController,
    required this.scrollController,
    required this.replyingMessage,
    required this.mentionResults,
    required this.messageKeyBuilder,
    required this.highlightedMessageId,
    required this.onSendText,
    required this.onSendFile,
    required this.onPickMention,
    required this.onClearReply,
    required this.onShowPinnedMessages,
    required this.onShowMembers,
    required this.onShowMessageActions,
    required this.onReplyTap,
  });

  final ChatRoom room;
  final TextEditingController messageController;
  final ScrollController scrollController;
  final ChatMessage? replyingMessage;
  final List<ChatUserOption> mentionResults;
  final GlobalKey Function(int messageId) messageKeyBuilder;
  final int? highlightedMessageId;
  final Future<void> Function() onSendText;
  final Future<void> Function() onSendFile;
  final Future<void> Function(ChatUserOption user) onPickMention;
  final VoidCallback onClearReply;
  final Future<void> Function() onShowPinnedMessages;
  final Future<void> Function()? onShowMembers;
  final Future<void> Function(ChatMessage message, bool isMine)
  onShowMessageActions;
  final Future<void> Function(int messageId) onReplyTap;

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatController>(
      builder: (context, chat, _) {
        final session = context.read<SessionController>();
        final currentUserId = session.user?.id;
        final chronological = chat.messages.reversed.toList();
        final pinnedCount = chat.pinnedMessages.length;

        return Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  _Avatar(
                    url: room.avatar,
                    name: room.title,
                    radius: 24,
                    fallbackIcon: room.isGroup
                        ? Icons.groups_rounded
                        : Icons.person_rounded,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          room.isPrivate
                              ? (chat.isUserOnline(room.peerId)
                                    ? 'Online'
                                    : 'Private chat')
                              : '${room.memberCount} members • ${room.isPublic ? 'Public group' : 'Group chat'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6F8098),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onShowMembers != null)
                        IconButton(
                          tooltip: 'Members',
                          onPressed: onShowMembers,
                          icon: const Icon(Icons.groups_rounded),
                        ),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            tooltip: 'Pinned messages',
                            onPressed: onShowPinnedMessages,
                            icon: const Icon(Icons.push_pin_rounded),
                          ),
                          if (pinnedCount > 0)
                            Positioned(
                              right: 4,
                              top: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF316BFF),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  pinnedCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'bookmark') {
                        await chat.toggleBookmark(room);
                      } else if (value == 'hide') {
                        await chat.hideRoom(room);
                      } else if (value == 'unhide') {
                        await chat.unhideRoom(room);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'bookmark',
                        child: Text(room.bookmarked ? 'Remove favorite' : 'Add to favorites'),
                      ),
                      PopupMenuItem(
                        value: chat.roomFilter == RoomCollectionFilter.hidden
                            ? 'unhide'
                            : 'hide',
                        child: Text(
                          chat.roomFilter == RoomCollectionFilter.hidden
                              ? 'Restore'
                              : 'Hide',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                children: [
                  if (chat.hasMoreMessages)
                    Center(
                      child: TextButton.icon(
                        onPressed: chat.loadingMessages
                            ? null
                            : chat.loadMoreMessages,
                        icon: chat.loadingMessages
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.expand_less_rounded),
                        label: const Text('Load older messages'),
                      ),
                    ),
                  ...chronological.map(
                    (message) => _MessageBubble(
                      key: messageKeyBuilder(message.id),
                      message: message,
                      isMine: message.senderId == currentUserId,
                      highlighted: highlightedMessageId == message.id,
                      onReplyTap: message.replyTo == null
                          ? null
                          : () => onReplyTap(message.replyTo!.id),
                      onLongPress: () => onShowMessageActions(
                        message,
                        message.senderId == currentUserId,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE5ECF6))),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (replyingMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7FAFF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFDCE6F5)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF316BFF),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    replyingMessage!.senderName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF316BFF),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _replySnippet(replyingMessage!),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF5E708A),
                                      height: 1.35,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Cancel reply',
                              onPressed: onClearReply,
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                    if (mentionResults.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        constraints: const BoxConstraints(maxHeight: 220),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7FAFF),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFDCE6F5)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x120E2F5A),
                              blurRadius: 16,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: mentionResults.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final user = mentionResults[index];
                            final title = user.mentionAll
                                ? '@ALL'
                                : (user.name.isNotEmpty
                                      ? user.name
                                      : user.username);
                            final subtitle = user.mentionAll
                                ? 'Everyone'
                                : '@${user.loginId.isNotEmpty ? user.loginId : (user.mentionKey.isNotEmpty ? user.mentionKey : user.username)}';
                            return InkWell(
                              onTap: () => unawaited(onPickMention(user)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    _Avatar(
                                      url: user.avatarUrl,
                                      name: title,
                                      radius: 18,
                                      fallbackIcon: user.mentionAll
                                          ? Icons.campaign_rounded
                                          : Icons.person_rounded,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF223553),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            subtitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF6A7C97),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: chat.sending ? null : onSendFile,
                          icon: const Icon(Icons.attach_file_rounded),
                        ),
                        Expanded(
                          child: TextField(
                            controller: messageController,
                            minLines: 1,
                            maxLines: 5,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => onSendText(),
                            decoration: const InputDecoration(
                              hintText: 'Type a message',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: chat.sending ? null : onSendText,
                          child: chat.sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.highlighted = false,
    this.onReplyTap,
    this.onLongPress,
  });

  final ChatMessage message;
  final bool isMine;
  final bool highlighted;
  final VoidCallback? onReplyTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final alignment = isMine
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final bgColor = isMine ? const Color(0xFF316BFF) : Colors.white;
    final fgColor = isMine ? Colors.white : const Color(0xFF223553);
    final plain = message.isFile
        ? ChatContentUtils.decodeFileContent(message.content)
        : ChatContentUtils.renderPlainText(message.content);

    final bubbleContent = Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          message.senderName,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF7F8DA5),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onLongPress: onLongPress,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(18),
              boxShadow: isMine
                  ? const []
                  : const [
                      BoxShadow(
                        color: Color(0x100E2F5A),
                        blurRadius: 12,
                        offset: Offset(0, 8),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.replyTo != null) ...[
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onReplyTap,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                        decoration: BoxDecoration(
                          color: isMine
                              ? const Color(0x1FFFFFFF)
                              : const Color(0xFFF3F7FE),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isMine
                                ? const Color(0x40FFFFFF)
                                : const Color(0xFFD6E3F8),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _Avatar(
                                  url: message.replyTo!.senderAvatar,
                                  name: message.replyTo!.senderName,
                                  radius: 11,
                                  fallbackIcon: Icons.person_rounded,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        message.replyTo!.senderName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: isMine
                                              ? Colors.white
                                              : const Color(0xFF316BFF),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _replySnippetFromReply(
                                          message.replyTo!,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          height: 1.3,
                                          color: isMine
                                              ? const Color(0xE6FFFFFF)
                                              : const Color(0xFF5E708A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                _MessageContent(
                  message: message,
                  plainText: plain,
                  foregroundColor: fgColor,
                ),
                if (message.isPinned || message.likeCount > 0) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (message.isPinned)
                        _MiniMessageBadge(
                          icon: Icons.push_pin_rounded,
                          label: 'Pin',
                          foregroundColor: isMine
                              ? Colors.white
                              : const Color(0xFF316BFF),
                          backgroundColor: isMine
                              ? const Color(0x1FFFFFFF)
                              : const Color(0xFFEAF2FF),
                        ),
                      if (message.likeCount > 0)
                        _MiniMessageBadge(
                          icon: Icons.thumb_up_rounded,
                          label: message.likeCount.toString(),
                          foregroundColor: isMine
                              ? Colors.white
                              : const Color(0xFF316BFF),
                          backgroundColor: isMine
                              ? const Color(0x1FFFFFFF)
                              : const Color(0xFFEAF2FF),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          AppDateUtils.formatFull(message.createdAt),
          style: const TextStyle(fontSize: 11, color: Color(0xFF91A0B5)),
        ),
      ],
    );

    final avatar = _Avatar(
      url: message.senderAvatar,
      name: message.senderName,
      radius: 18,
      fallbackIcon: Icons.person_rounded,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(top: 10),
      padding: EdgeInsets.symmetric(
        horizontal: highlighted ? 8 : 0,
        vertical: highlighted ? 6 : 0,
      ),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0x1F316BFF) : Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        border: highlighted
            ? Border.all(color: const Color(0x66316BFF), width: 1.4)
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (isMine) const Spacer(),
          if (!isMine) ...[avatar, const SizedBox(width: 10)],
          Flexible(child: bubbleContent),
          if (isMine) ...[const SizedBox(width: 10), avatar],
        ],
      ),
    );
  }
}

class _MiniMessageBadge extends StatelessWidget {
  const _MiniMessageBadge({
    required this.icon,
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  final IconData icon;
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: foregroundColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: foregroundColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

String _replySnippet(ChatMessage message) {
  if (message.isImage) return '[Image]';
  if (message.isFile) {
    final name = ChatContentUtils.decodeFileContent(message.content).trim();
    return name.isEmpty ? '[File]' : '[File] $name';
  }
  final text = ChatContentUtils.renderPlainText(message.content).trim();
  if (text.isEmpty) return '[Message]';
  return text.length > 80 ? '${text.substring(0, 80)}...' : text;
}

String _replySnippetFromReply(ChatMessageReply reply) {
  if (reply.type == 'image') return '[Image]';
  if (reply.type == 'file') {
    final name = ChatContentUtils.decodeFileContent(reply.content).trim();
    return name.isEmpty ? '[File]' : '[File] $name';
  }
  final text = ChatContentUtils.renderPlainText(reply.content).trim();
  if (text.isEmpty) return '[Message]';
  return text.length > 80 ? '${text.substring(0, 80)}...' : text;
}

class _MessageContent extends StatelessWidget {
  const _MessageContent({
    required this.message,
    required this.plainText,
    required this.foregroundColor,
  });

  final ChatMessage message;
  final String plainText;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    if (message.isImage && (message.filePath?.isNotEmpty ?? false)) {
      return InkWell(
        onTap: () => _openPreview(
          context,
          url: message.filePath!,
          title: _attachmentTitle(),
          isImage: true,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 220,
            height: 220,
            child: RemoteImage(
              url: message.filePath!,
              width: 220,
              height: 220,
              fit: BoxFit.cover,
              errorFallback: Text(
                plainText,
                style: TextStyle(color: foregroundColor, height: 1.45),
              ),
            ),
          ),
        ),
      );
    }

    if (message.isFile && (message.filePath?.isNotEmpty ?? false)) {
      return InkWell(
        onTap: () => _openFile(context),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insert_drive_file_rounded,
              color: foregroundColor,
              size: 18,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                plainText,
                style: TextStyle(
                  color: foregroundColor,
                  decoration: TextDecoration.underline,
                  decorationColor: foregroundColor,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Text(
      plainText,
      style: TextStyle(color: foregroundColor, height: 1.45),
    );
  }

  String _attachmentTitle() {
    final decoded = ChatContentUtils.decodeFileContent(message.content).trim();
    if (decoded.isNotEmpty) return decoded;
    if (plainText.trim().isNotEmpty) return plainText.trim();
    return message.isImage ? 'Image preview' : 'File preview';
  }

  Future<void> _openFile(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await openAttachmentExternally(
        url: message.filePath!,
        fileName: _attachmentTitle(),
      );
    } catch (_) {
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFFBF3A3A),
          content: Text(
            'Unable to open the file.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
    }
  }

  static Future<void> _openPreview(
    BuildContext context, {
    required String url,
    required String title,
    required bool isImage,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            AttachmentPreviewScreen(url: url, title: title, isImage: isImage),
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.url,
    required this.name,
    this.radius = 22,
    this.fallbackIcon,
  });

  final String url;
  final String name;
  final double radius;
  final IconData? fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final fallback = _AvatarFallback(
      name: name,
      radius: radius,
      fallbackIcon: fallbackIcon,
    );

    if (url.isEmpty) return fallback;

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1FB),
        borderRadius: BorderRadius.circular(999),
      ),
      clipBehavior: Clip.antiAlias,
      child: RemoteImage(
        url: url,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        borderRadius: BorderRadius.circular(999),
        errorFallback: fallback,
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({
    required this.name,
    required this.radius,
    this.fallbackIcon,
  });

  final String name;
  final double radius;
  final IconData? fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty
        ? '?'
        : name.trim().substring(0, 1).toUpperCase();

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFEAF1FB),
      child: fallbackIcon != null
          ? Icon(
              fallbackIcon,
              size: radius * 0.95,
              color: const Color(0xFF6A7C97),
            )
          : Text(
              letter,
              style: TextStyle(
                fontSize: radius * 0.9,
                color: const Color(0xFF4A6284),
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}
