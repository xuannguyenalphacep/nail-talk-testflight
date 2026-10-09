import 'package:flutter/material.dart';

import '../../../../core/audio/game_audio.dart';
import '../../../../core/theme/game_theme.dart';
import '../../../../core/widgets/game_stage.dart';
import '../../../../core/widgets/gpt_button.dart';
import '../../../../core/widgets/profile_chip.dart';
import '../../data/game_data.dart';
import 'home_screen.dart';
import 'lobby_screen.dart';
import 'waiting_room_screen.dart';

class ActiveTablesScreen extends StatelessWidget {
  const ActiveTablesScreen({super.key});

  static const List<ActiveDemoTable> _tables = <ActiveDemoTable>[
    ActiveDemoTable(
      name: 'Bàn 01',
      roomIndex: 2,
      currentPlayers: 3,
      maxPlayers: 4,
      wager: '5.000 - 10.000 xu',
      host: 'Hắc Long',
      state: 'Đang chơi',
    ),
    ActiveDemoTable(
      name: 'Bàn 07',
      roomIndex: 1,
      currentPlayers: 4,
      maxPlayers: 4,
      wager: '1.000 xu',
      host: 'Ngọc Lan',
      state: 'Đang chơi',
    ),
    ActiveDemoTable(
      name: 'Bàn 12',
      roomIndex: 0,
      currentPlayers: 2,
      maxPlayers: 4,
      wager: '100 xu',
      host: 'Tây Bích 88',
      state: 'Chờ người chơi',
    ),
  ];

  void _openTable(BuildContext context, ActiveDemoTable table) {
    if (table.isFull) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${table.name} đã đủ ${table.playersLabel}.')),
      );
      return;
    }
    GameAudio.enterRoom();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WaitingRoomScreen(
          room: demoRooms[table.roomIndex],
          initialOpponentCount: table.currentPlayers.clamp(0, 3).toInt(),
          hostName: table.host,
          entryLabel: '${table.name} · ${table.state}',
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
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
                const ProfileChip(name: 'Tây Bích 88', balance: 12500),
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
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 13,
                                vertical: 7,
                              ),
                              child: Text(
                                '3 bàn đang mở',
                                style: TextStyle(
                                  color: GameTheme.ivory,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Column(
                          children: _tables
                              .map(
                                (ActiveDemoTable table) => Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 9),
                                    child: _ActiveTableRow(
                                      table: table,
                                      onEnter: () => _openTable(context, table),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
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
    required this.name,
    required this.roomIndex,
    required this.currentPlayers,
    required this.maxPlayers,
    required this.wager,
    required this.host,
    required this.state,
  });

  final String name;
  final int roomIndex;
  final int currentPlayers;
  final int maxPlayers;
  final String wager;
  final String host;
  final String state;

  bool get isFull => currentPlayers >= maxPlayers;
  String get playersLabel => '$currentPlayers/$maxPlayers người chơi';
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
    final bool isWaiting = table.state == 'Chờ người chơi';
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
                    style: const TextStyle(
                      color: GameTheme.ivory,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    isFull ? 'Bàn đã đủ người' : table.state,
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
                    semanticLabel: 'Vào bàn ${table.name}',
                    onPressed: isFull ? null : onEnter,
                  ),
                  if (isFull)
                    Positioned(
                      bottom: 4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xDD2E0C09),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFFFB199)),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          child: Text(
                            'ĐÃ ĐỦ 4/4',
                            style: TextStyle(
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
