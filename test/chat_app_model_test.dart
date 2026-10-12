import 'package:flutter_test/flutter_test.dart';
import 'package:social_hub_flutter/src/models/chat_app_model.dart';

void main() {
  group('ChatAppModel feature flags', () {
    test('reads flags from the nested admin payload', () {
      final app = ChatAppModel.fromJson(<String, dynamic>{
        'uuid': 'app-1',
        'code': 'nails-talk',
        'name': 'Nails Talk',
        'feature_flags': <String, dynamic>{
          'video_enabled': true,
          'card_game_enabled': false,
        },
      });

      expect(app.videoEnabled, isTrue);
      expect(app.cardGameEnabled, isFalse);
    });

    test('top-level flags take precedence and accept API scalar values', () {
      final app = ChatAppModel.fromJson(<String, dynamic>{
        'uuid': 'app-1',
        'code': 'nails-talk',
        'name': 'Nails Talk',
        'video_enabled': 0,
        'card_game_enabled': 'on',
        'feature_flags': <String, dynamic>{
          'video_enabled': true,
          'card_game_enabled': false,
        },
      });

      expect(app.videoEnabled, isFalse);
      expect(app.cardGameEnabled, isTrue);
      expect(
        (app.toJson()['feature_flags'] as Map)['card_game_enabled'],
        isTrue,
      );
    });

    test('copyWith can fail both sensitive features closed', () {
      final enabled = ChatAppModel.fromJson(<String, dynamic>{
        'uuid': 'app-1',
        'code': 'nails-talk',
        'name': 'Nails Talk',
        'video_enabled': true,
        'card_game_enabled': true,
      });

      final disabled = enabled.copyWith(
        videoEnabled: false,
        cardGameEnabled: false,
      );

      expect(disabled.videoEnabled, isFalse);
      expect(disabled.cardGameEnabled, isFalse);
      expect(disabled.apiBaseUrl, enabled.apiBaseUrl);
    });
  });
}
