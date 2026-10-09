enum CardSuit { clubs, diamonds, hearts, spades }

extension CardSuitLabel on CardSuit {
  String get symbol {
    switch (this) {
      case CardSuit.clubs:
        return '♣';
      case CardSuit.diamonds:
        return '♦';
      case CardSuit.hearts:
        return '♥';
      case CardSuit.spades:
        return '♠';
    }
  }

  bool get isRed => this == CardSuit.diamonds || this == CardSuit.hearts;
}

class PlayingCardData {
  const PlayingCardData(this.rank, this.suit);

  final String rank;
  final CardSuit suit;
}

class DemoRoom {
  const DemoRoom({
    required this.title,
    required this.detail,
    required this.buttonAsset,
    required this.baseBet,
  });

  final String title;
  final String detail;
  final String buttonAsset;
  final int baseBet;

  String get stakeLabel => baseBet == 0 ? 'Không tính xu' : '$baseBet xu';
}

const List<DemoRoom> demoRooms = <DemoRoom>[
  DemoRoom(
    title: 'Phòng Thường',
    detail: 'Mức cược 100 xu · 4 chỗ',
    buttonAsset: 'assets/game_tien_len/buttons/room_regular_v2.png',
    baseBet: 100,
  ),
  DemoRoom(
    title: 'Phòng VIP',
    detail: 'Mức cược 1.000 xu · 4 chỗ',
    buttonAsset: 'assets/game_tien_len/buttons/room_vip_v2.png',
    baseBet: 1000,
  ),
  DemoRoom(
    title: 'Phòng Cao Thủ',
    detail: 'Mức cược 5.000 xu · 4 chỗ',
    buttonAsset: 'assets/game_tien_len/buttons/room_master_v2.png',
    baseBet: 5000,
  ),
  DemoRoom(
    title: 'Phòng Solo',
    detail: 'Đấu với máy · Mức cược 50 xu',
    buttonAsset: 'assets/game_tien_len/buttons/room_solo_v2.png',
    baseBet: 50,
  ),
];

const List<PlayingCardData> demoHand = <PlayingCardData>[
  PlayingCardData('3', CardSuit.spades),
  PlayingCardData('3', CardSuit.hearts),
  PlayingCardData('4', CardSuit.diamonds),
  PlayingCardData('4', CardSuit.clubs),
  PlayingCardData('5', CardSuit.hearts),
  PlayingCardData('5', CardSuit.clubs),
  PlayingCardData('6', CardSuit.diamonds),
  PlayingCardData('6', CardSuit.spades),
  PlayingCardData('7', CardSuit.clubs),
  PlayingCardData('8', CardSuit.diamonds),
  PlayingCardData('9', CardSuit.hearts),
  PlayingCardData('10', CardSuit.spades),
  PlayingCardData('2', CardSuit.hearts),
];

const List<PlayingCardData> demoTableCards = <PlayingCardData>[];
