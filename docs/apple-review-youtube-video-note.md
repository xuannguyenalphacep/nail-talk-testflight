# App Review note - controlled Video availability

Use this note in App Store Connect Review Notes or as a reply to App Review. Before submission, make sure the note and store metadata describe the actual server-side configuration for the submitted app, account, and region.

The `Enable Video tab` and `Enable Game bài / card game` settings are controlled-rollout and compliance controls. They must not vary based on reviewer identity or review status. Reviewers and production users in the same rollout scope receive the same feature state.

## Suggested reply when Video is enabled

Hello App Review Team,

The submitted configuration enables the Video tab in a limited YouTube-embed-only mode for all users in its rollout scope.

Copyright / third-party content clarification:

- Nails Talk does not host, upload, store, download, convert, cache, redistribute, sell, or unlock video files.
- This app configuration only displays public YouTube videos through the official YouTube embedded player inside a WebView.
- Hosted/private/direct video playback is disabled in this configuration.
- The app does not bypass YouTube playback, branding, ads, availability, region limits, age restrictions, takedowns, or copyright enforcement.
- If YouTube or a rights holder removes, restricts, blocks, or disables embedding for a video, it will not play in Nails Talk.
- Video access is currently free. There are no in-app purchases, subscriptions, external checkout, paid video unlocks, or pay-per-view flows in this configuration.

Moderation and data-filtering clarification:

- Admin video entries are reviewed before publishing and must match the playback capabilities enabled for this app.
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

## Suggested reply when Video or the card game is disabled

State which feature is disabled and the rollout scope that receives that same state. Explain that the feature is unavailable to reviewers and production users alike in that scope, and make sure screenshots, descriptions, age rating, and Review Notes all match. Do not tie future enablement to a store-review outcome; enable it only through a documented rollout after content, age-rating, regional-policy, and operational checks are complete.

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
