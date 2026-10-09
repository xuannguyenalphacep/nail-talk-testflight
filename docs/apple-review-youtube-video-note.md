# Apple Review note - YouTube-only video mode

Use this note in App Store Connect Review Notes or as a reply to App Review when reopening the Video tab.

If the admin `Enable Video tab` toggle is off for review, use the shorter clarification below instead:

Hello App Review Team,

This build keeps the Video tab and community card-game preview disabled through our server-side admin feature settings while the app is under review. The visible app experience includes community feed, marketplace, jobs/housing, spa/beauty service directory, account safety, reporting/blocking, and chat. No in-app purchases, subscriptions, paid video unlocks, external checkout, hosted/direct movie playback, gambling, real-money gaming, prizes, or betting flows are available in this review build.

## Suggested reply to Apple

Hello App Review Team,

This update re-enables the Video tab in a limited YouTube-embed-only mode.

Copyright / third-party content clarification:

- Nails Talk does not host, upload, store, download, convert, cache, redistribute, sell, or unlock video files.
- The iOS build only displays public YouTube videos through the official YouTube embedded player inside a WebView.
- Hosted/private/direct video playback is disabled in this iOS build.
- The app does not bypass YouTube playback, branding, ads, availability, region limits, age restrictions, takedowns, or copyright enforcement.
- If YouTube or a rights holder removes, restricts, blocks, or disables embedding for a video, it will not play in Nails Talk.
- Video access is free. There are no in-app purchases, subscriptions, external checkout, paid video unlocks, or pay-per-view flows in this build.

Moderation and data-filtering clarification:

- Admin video entries are reviewed before publishing and must use YouTube URLs only for this iOS build.
- Community posts, listings, and chat text are filtered before being posted.
- Users can report objectionable content and block abusive users.
- Blocking removes that user's content from the current feed/chat view, and safety reports are reviewed by the moderation team within 24 hours.

Review steps:

1. Open Nails Talk.
2. Open the Video tab.
3. Open any video detail page.
4. Tap Watch now.
5. Confirm playback uses a YouTube embedded player and that no download, payment, subscription, or external purchase flow is present.
6. Open community feed/chat/listing screens to confirm report, block, and content-filtering behavior.

## Implementation notes

- Flutter defaults:
  - `YOUTUBE_VIDEO_FEATURE_ENABLED=true`
  - `MOVIE_PAYMENTS_ENABLED=false`
  - `HOSTED_MOVIE_PLAYBACK_ENABLED=false`
- Backend defaults:
  - `MOVIE_PAYMENTS_ENABLED=false`
  - `HOSTED_MOVIE_PLAYBACK_ENABLED=false`
- `/api/movies` returns published YouTube entries only while hosted playback is disabled.
- Direct hosted movie detail requests return 404 while hosted playback is disabled.
