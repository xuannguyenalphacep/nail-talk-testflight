import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../controllers/session_controller.dart';
import '../../../../../services/chat_socket_service.dart';
import '../../../../core/audio/game_audio.dart';
import '../../../../core/theme/game_theme.dart';
import '../../../../core/widgets/game_stage.dart';
import '../../../../core/widgets/gpt_button.dart';
import '../../../../core/widgets/profile_chip.dart';
import '../../data/game_data.dart';
import '../../data/realtime_game_models.dart';
import 'home_screen.dart';
import 'lobby_screen.dart';
import 'table_screen.dart';
import 'waiting_room_screen.dart';

class ActiveTablesScreen extends StatefulWidget {
  const ActiveTablesScreen({super.key});

  @override
  State<ActiveTablesScreen> createState() => _ActiveTablesScreenState();
}

class _ActiveTablesScreenState extends State<ActiveTablesScreen> {
  List<ActiveDemoTable> _tables = const <ActiveDemoTable>[];
  bool _loading = true;
  String? _loadError;
  bool _loadedOnce = false;
  bool _openingTable = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedOnce) return;
    _loadedOnce = true;
    unawaited(_refreshTables());
  }

  Future<void> _refreshTables() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final socket = context.read<ChatSocketService>();
      final session = context.read<SessionController>();
      final app = session.selectedApp;
      final user = session.user;
      final token = session.token;
      if (!socket.isConnected && app != null && user != null && token != null) {
        await socket.connect(
          socketUrl: app.socketUrl,
          user: user,
          notifyApiUrl: session.notifyApiUrl,
          accessToken: token,
        );
      }
      final rooms = await socket.listTienLenRooms();
      if (!mounted) return;
      setState(() {
        _tables = rooms
            .where((room) => _roomIndexForBaseBet(room.baseBet) != null)
            .map(_tableFromSummary)
            .toList(growable: false);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  ActiveDemoTable _tableFromSummary(TienLenRoomSummary room) {
    final roomIndex = _roomIndexForBaseBet(room.baseBet)!;
    return ActiveDemoTable(
      roomId: room.roomId,
      name: room.title.isEmpty ? room.roomId : room.title,
      roomIndex: roomIndex,
      currentPlayers: room.playerCount,
      activePlayers: room.activePlayerCount,
      waitingPlayers: room.waitingPlayerCount,
      maxPlayers: room.maxPlayers,
      wager: '${room.baseBet} xu',
      host: 'Phòng ${room.roomId}',
      state: switch (room.phase) {
        'waiting' => 'Chờ người chơi',
        'round-ended' => 'Đang chờ ván mới',
        _ when room.waitingPlayerCount > 0 =>
          'Đang chơi · ${room.waitingPlayerCount} chờ ván sau',
        _ => 'Đang chơi · Có thể vào xem',
      },
      phase: room.phase,
    );
  }

  int? _roomIndexForBaseBet(int baseBet) {
    if (baseBet <= 0) return null;
    final index = demoRooms.indexWhere((room) => room.baseBet == baseBet);
    return index < 0 ? null : index;
  }

  Future<void> _openTable(BuildContext context, ActiveDemoTable table) async {
    if (_openingTable) return;
    if (!table.canJoin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            table.isFull
                ? '${table.name} đã đủ ${table.playersLabel}.'
                : '${table.name} hiện chưa thể nhận thêm người chơi.',
          ),
        ),
      );
      return;
    }
    setState(() => _openingTable = true);
    try {
      final room = demoRooms[table.roomIndex];
      if (table.joinsAsSpectator) {
        final session = context.read<SessionController>();
        final socket = context.read<ChatSocketService>();
        final user = session.user;
        final app = session.selectedApp;
        final token = session.token;
        if (user == null || app == null || token == null) {
          throw StateError('Bạn cần đăng nhập để vào bàn.');
        }
        if (!socket.isConnected) {
          await socket.connect(
            socketUrl: app.socketUrl,
            user: user,
            notifyApiUrl: session.notifyApiUrl,
            accessToken: token,
          );
        }
        final state = await socket.joinTienLenRoom(
          roomId: table.roomId,
          title: table.name,
          baseBet: room.baseBet,
          userId: user.id,
          name: user.name.trim().isNotEmpty ? user.name : user.username,
          coins: user.gameCoins,
        );
        if (!context.mounted) return;
        GameAudio.enterRoom();
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                RealtimeTableScreen(room: room, initialState: state),
          ),
        );
      } else {
        GameAudio.enterRoom();
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => WaitingRoomScreen(
              room: room,
              initialOpponentCount: table.currentPlayers.clamp(0, 3).toInt(),
              hostName: table.host,
              entryLabel: '${table.name} · ${table.state}',
              roomId: table.roomId,
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không vào được bàn: ${_joinError(error)}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _openingTable = false);
        unawaited(_refreshTables());
      }
    }
  }

  String _joinError(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('room-full')) return 'phòng đã đủ người';
    if (raw.contains('room-not-found')) return 'phòng không còn tồn tại';
    if (raw.contains('round-start-pending')) {
      return 'ván mới đang bắt đầu, vui lòng thử lại';
    }
    if (raw.contains('unauthorized')) return 'phiên đăng nhập đã hết hạn';
    return 'kết nối bàn chưa sẵn sàng, vui lòng thử lại';
  }

  void _openRoomList(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const LobbyScreen()));
  }

  Future<void> _joinByRoomId(BuildContext context) async {
    final TextEditingController controller = TextEditingController();
    final String? roomId = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xF20A2C27),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: GameTheme.gold.withValues(alpha: 0.65)),
          ),
          title: const Text(
            'Nhập ID phòng',
            style: TextStyle(
              color: GameTheme.ivory,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(
              color: GameTheme.ivory,
              fontWeight: FontWeight.w800,
            ),
            decoration: InputDecoration(
              hintText: 'VD: NT12345',
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: const Color(0xAA071B1B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: GameTheme.mint.withValues(alpha: 0.45),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: GameTheme.mint.withValues(alpha: 0.45),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: GameTheme.gold, width: 1.4),
              ),
            ),
            onSubmitted: (String value) {
              Navigator.of(dialogContext).pop(value.trim());
            },
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(controller.text.trim());
              },
              child: const Text('Vào phòng'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (!context.mounted) {
      return;
    }
    if (roomId == null) {
      return;
    }
    final String cleanRoomId = roomId.trim().toUpperCase();
    if (cleanRoomId.length < 4) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ID phòng chưa hợp lệ.')));
      return;
    }

    final int roomSeed = cleanRoomId.codeUnits.fold<int>(
      0,
      (int total, int codeUnit) => total + codeUnit,
    );
    final DemoRoom room = demoRooms[roomSeed % demoRooms.length];
    GameAudio.enterRoom();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WaitingRoomScreen(
          room: room,
          initialOpponentCount: 1,
          hostName: 'Chủ phòng $cleanRoomId',
          entryLabel: 'ID $cleanRoomId',
          roomId: cleanRoomId,
        ),
      ),
    );
  }

  void _backToHome(BuildContext context) {
    final NavigatorState navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.popUntil((Route<dynamic> route) => route.isFirst);
      return;
    }
    navigator.pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
    );
  }

  Widget _buildTableList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Không tải được danh sách bàn: $_loadError',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _refreshTables,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }
    if (_tables.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Chưa có bàn mở. Hãy chọn phòng để tạo bàn mới.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _refreshTables,
              icon: const Icon(Icons.refresh),
              label: const Text('Làm mới'),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: _tables.length,
      separatorBuilder: (_, _) => const SizedBox(height: 9),
      itemBuilder: (context, index) {
        final table = _tables[index];
        return SizedBox(
          height: 105,
          child: _ActiveTableRow(
            table: table,
            onEnter: () => _openTable(context, table),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final playerName = session.user?.name.trim().isNotEmpty == true
        ? session.user!.name
        : 'Người chơi';
    final playerCoins = session.user?.gameCoins ?? 0;
    return GameStage(
      backgroundAsset:
          'assets/game_tien_len/backgrounds/login_stage_clean_v2.png',
      stageWidth: 1672,
      stageHeight: 941,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(44, 26, 44, 32),
        child: Column(
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ProfileChip(name: playerName, balance: playerCoins),
                SizedBox(
                  width: 355,
                  height: 100,
                  child: Image.asset(
                    'assets/game_tien_len/branding/title.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 215),
              ],
            ),
            SizedBox(
              width: 700,
              height: 134,
              child: Image.asset(
                'assets/game_tien_len/branding/active_tables_heading.png',
                fit: BoxFit.contain,
              ),
            ),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xD90A2C27),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: GameTheme.gold.withValues(alpha: 0.72),
                  ),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x99000000),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Icon(
                            Icons.table_restaurant,
                            color: GameTheme.gold,
                            size: 24,
                          ),
                          const SizedBox(width: 9),
                          const Expanded(
                            child: Text(
                              'Các bàn đang có người chơi',
                              style: TextStyle(
                                color: GameTheme.ivory,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xC9085C4F),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: GameTheme.mint.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 13,
                                vertical: 7,
                              ),
                              child: Text(
                                '${_tables.length} bàn đang mở',
                                style: const TextStyle(
                                  color: GameTheme.ivory,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(child: _buildTableList()),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 78,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  SizedBox(
                    width: 285,
                    child: GptButton(
                      assetPath: 'assets/game_tien_len/buttons/choose_room.png',
                      semanticLabel: 'Chọn phòng',
                      onPressed: () => _openRoomList(context),
                    ),
                  ),
                  const SizedBox(width: 20),
                  SizedBox(
                    width: 285,
                    child: _JoinRoomIdButton(
                      onPressed: () => _joinByRoomId(context),
                    ),
                  ),
                  const SizedBox(width: 20),
                  SizedBox(
                    width: 285,
                    child: GptButton(
                      assetPath:
                          'assets/game_tien_len/buttons/back_lobby_v2.png',
                      semanticLabel: 'Quay lại sảnh',
                      onPressed: () => _backToHome(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ActiveDemoTable {
  const ActiveDemoTable({
    required this.roomId,
    required this.name,
    required this.roomIndex,
    required this.currentPlayers,
    required this.activePlayers,
    required this.waitingPlayers,
    required this.maxPlayers,
    required this.wager,
    required this.host,
    required this.state,
    required this.phase,
  });

  final String roomId;
  final String name;
  final int roomIndex;
  final int currentPlayers;
  final int activePlayers;
  final int waitingPlayers;
  final int maxPlayers;
  final String wager;
  final String host;
  final String state;
  final String phase;

  bool get isFull => currentPlayers >= maxPlayers;
  bool get canJoin =>
      const <String>{'waiting', 'playing', 'round-ended'}.contains(phase) &&
      !isFull;
  String get playersLabel => '$currentPlayers/$maxPlayers người chơi';
  bool get joinsAsSpectator => phase == 'playing' || phase == 'round-ended';
}

class _JoinRoomIdButton extends StatelessWidget {
  const _JoinRoomIdButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFE9B44C),
            Color(0xFFB96D18),
            Color(0xFF6F2D0A),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFE3A1), width: 1.4),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0xAA000000), blurRadius: 14),
          BoxShadow(color: Color(0x77F2C05A), blurRadius: 16),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onPressed,
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.tag_rounded, color: Color(0xFF2D1304), size: 22),
                SizedBox(width: 8),
                Text(
                  'Nhập ID phòng',
                  style: TextStyle(
                    color: Color(0xFF2D1304),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    shadows: <Shadow>[
                      Shadow(color: Color(0x66FFFFFF), blurRadius: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveTableRow extends StatelessWidget {
  const _ActiveTableRow({required this.table, required this.onEnter});

  final ActiveDemoTable table;
  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    final bool isWaiting = table.phase == 'waiting';
    final bool isFull = table.isFull;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isFull ? const Color(0xA91D2524) : const Color(0xB50C3A33),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isFull
              ? const Color(0xAAE05D4F)
              : isWaiting
              ? GameTheme.gold.withValues(alpha: 0.48)
              : GameTheme.mint.withValues(alpha: 0.38),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 150,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    table.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: GameTheme.ivory,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    isFull ? 'Bàn đã đủ người' : table.state,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isFull
                          ? const Color(0xFFFF8F7B)
                          : isWaiting
                          ? GameTheme.gold
                          : GameTheme.mint,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 45,
              color: GameTheme.gold.withValues(alpha: 0.25),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Wrap(
                spacing: 26,
                runSpacing: 4,
                children: <Widget>[
                  _TableDetail(
                    label: 'Phòng',
                    value: demoRooms[table.roomIndex].title,
                  ),
                  _TableDetail(label: 'Mức cược', value: table.wager),
                  _TableDetail(label: 'Chủ bàn', value: table.host),
                  _TableDetail(label: 'Chỗ ngồi', value: table.playersLabel),
                ],
              ),
            ),
            const SizedBox(width: 18),
            SizedBox(
              width: 210,
              height: 82,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  GptButton(
                    assetPath: 'assets/game_tien_len/buttons/enter_table.png',
                    semanticLabel: table.joinsAsSpectator
                        ? 'Xem bàn ${table.name} và chờ ván sau'
                        : 'Vào bàn ${table.name}',
                    onPressed: table.canJoin ? onEnter : null,
                  ),
                  if (table.canJoin && table.joinsAsSpectator)
                    Positioned(
                      bottom: 4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xE2073B36),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: GameTheme.mint),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          child: Text(
                            'XEM · CHỜ VÁN SAU',
                            style: TextStyle(
                              color: Color(0xFFD8FFF8),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (!table.canJoin)
                    Positioned(
                      bottom: 4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xDD2E0C09),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFFFB199)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          child: Text(
                            isFull
                                ? 'ĐÃ ĐỦ ${table.playersLabel}'
                                : 'ĐANG CHƠI',
                            style: const TextStyle(
                              color: Color(0xFFFFD2C6),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableDetail extends StatelessWidget {
  const _TableDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 185,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: GameTheme.ivory,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
