# iOS 1.0.2 — resubmission after 2.5.19 / 5.6 rejection (2026-10-23)

Submission `a363098f-97c5-4d9d-91b9-7501c808cf21`, build 37 rejected twice:

1. 2026-10-13 — 2.3.1(a): hidden card game / gambling-style game.
2. 2026-10-23 — 2.5.19 + 5.6: hidden, dormant or misleading functionality that differs from
   review and metadata.

## Root causes found in build 37

| # | Problem in build 37 | Fix in the new build |
|---|---|---|
| 1 | Movies/video screens, YouTube/hosted playback and movie-plan purchase code shipped in the binary but were switched off by the server flag `video_enabled` (dormant feature). | Movies are excluded at compile time (`MOVIES_FEATURE_ENABLED=false`, default). Verified on a release build: `MoviesScreen`, `MovieDetailScreen`, `/movies` API and plan subscription code are absent from the AOT binary. The server flag can no longer bring them back. |
| 2 | The card game tile was shown or hidden by the server flag `card_game_enabled`, and the app hid every feature on any network error. | The card game entry is always visible in Home and More. If the server pauses the game, the entry stays and shows a maintenance message. Network errors keep the last known state instead of hiding features. |
| 3 | Review notes said the game was US-IP-only, but production removed that rule on 2026-10-13. | Notes rewritten to match production: no IP or region gate at runtime, same behaviour for every account. |
| 4 | Automated players had human-looking Vietnamese names and looked exactly like real people. | Every automated player shows "(BOT)" after the name in seats, turn text, results and logs. The waiting room shows "Người chơi tự động". The lobby notice states that seats may be filled by players labelled BOT. |
| 5 | The home banner said the game space was "coming soon / when this space launches" while it was live. | Banner text now describes the live game: virtual coins, wins/losses change the balance, BOT players may fill seats. |
| 6 | Info.plist asked for location for a "find nearby" feature that does not exist; camera text described features that do not exist. | Location key removed. Camera / photo-add texts rewritten to describe actual use only. `CFBundleShortVersionString` now follows `--build-name`. |

## App Review notes (replace the current Notes field)

```text
Hello App Review Team,

This build (1.0.2, new build number) addresses Guidelines 2.5.19, 5.6 and 2.3.1(a).

What changed in this binary:
- Removed the video/movies feature from the app binary entirely. It is not hidden behind a server switch; the code is not in the build.
- The Tiến Lên Miền Nam card game is a permanent, always-visible part of the app: Home > "Tiến Lên Miền Nam" banner, and More > "Game bài". Visibility does not depend on a server flag, IP address, region, account or review status.
- There is no runtime region or IP rule. Every account gets the same functionality, including App Review.
- Automated players are always labelled "(BOT)" next to their name at the table, in the waiting room ("Người chơi tự động"), in turn messages and in results. The game lobby states that empty seats may be filled by BOT players.
- If our game server is under maintenance, the game entry stays visible and shows a maintenance message; it is never hidden.

How the game works (also stated in the description and inside the game lobby):
- Players use free virtual coins only. Winning or losing a round increases or decreases the player's virtual coin balance, and a 10% in-game fee is deducted from winnings.
- Coins cannot be purchased, cashed out, transferred for money, or redeemed for goods or prizes. There are no in-app purchases, subscriptions or external payment flows in the app.
- The age rating is 18+ (frequent simulated gambling).

To test: sign in with the demo account in Sign-In Information, open More > Game bài (or the Tiến Lên banner on Home), create a room, tap "Sẵn sàng" and start. After about 15 seconds a BOT player joins if no other person joins.

Other features: jobs, housing, marketplace and beauty-service listings, public/private chat, report and block. Nails Talk does not process payments for listings or services.
```

## Reply to App Review (send with the resubmission)

```text
Hello App Review Team,

Thank you for the detailed feedback. We reviewed the whole app against Guidelines 2.5.19 and 5.6 and found the causes:

1. Build 37 still contained a video/movies feature that was switched off from our server. We removed that feature from the app binary completely in the new build; it cannot be switched on remotely.
2. The card game entry in build 37 could be shown or hidden by a server setting, and our previous notes described an IP/region rule that no longer matched production. In the new build the game is always visible to every user, with no server, region, account or reviewer-dependent visibility. The review notes now describe the production behaviour exactly.
3. Automated players previously looked like real people. Every automated player is now clearly labelled "(BOT)" wherever its name appears, and the game lobby explains this.
4. We removed a location permission description for a feature the app does not have and corrected other permission texts.

The game uses free virtual coins only, with wins and losses changing the virtual balance and a 10% in-game fee; coins cannot be bought, cashed out or redeemed. This is disclosed in the description, in the app and in the 18+ age rating.

We have submitted the new build for review. Please let us know if anything else needs clarification.
```

## Metadata to update before resubmitting

- Description bullet for the game: change "Automated players may fill empty seats." to "Automated players labelled BOT may fill empty seats."
- Screenshots: make sure no screenshot shows a Video tab or movie screen, and at least one shows the card game with BOT labels.
- Keep the age rating 18+ (frequent simulated gambling) and US-only availability unless the release plan changes.

## Resubmission steps

1. Push to `main`. The workflow `.github/workflows/testflight.yml` builds 1.0.2 with a new build
   number and uploads it (movies stay excluded because `MOVIES_FEATURE_ENABLED` defaults to false).
   The workflow runs `flutter analyze` and `flutter test` before building, and builds with
   `--dart-define=MOVIES_FEATURE_ENABLED=false`.
2. In App Store Connect, open iOS 1.0.2, replace build 37 with the new build.
3. Replace the Notes field and the description bullet above; check screenshots.
4. Reply to the rejection message with the reply text, then **Resubmit to App Review**.
5. Production server: keep `card_game_enabled=1`; leave `video_enabled=0` (the new build ignores it).
