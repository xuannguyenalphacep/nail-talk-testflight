# Live Environment Notes

Last checked: 2026-10-07, Asia/Ho_Chi_Minh.

This note is the quick source of truth before changing Flutter API URLs or building for Store/TestFlight.

## Project layout

- `admin-api/` is the Laravel admin/API backend.
- `chat-socket/` is the Socket.IO server for this Social Hub workspace. It is part of this project, not a separate outside socket project.
- `flutter-app/` is the Nails Talk Flutter app.

## AWS console check

AWS Console account shown during the check: `nail_talk`.

Checked EC2 in `Asia Pacific (Singapore) / ap-southeast-1` from the open AWS Console tab:

- EC2 `Instances` page showed: `No instances`.
- EC2 Global View showed `ap-southeast-1` has `0` EC2 instances.

Global View showed EC2 instances in other regions:

- `us-east-1`: 4 instances
- `ap-southeast-2`: 2 instances
- `us-west-1`: 1 instance
- `us-west-2`: 1 instance

So do not assume the live EC2 server is in `ap-southeast-1` without checking the actual instance details again.

The local machine does not currently have the AWS CLI installed (`aws` command not found), so instance names and public IPs were checked only through the AWS Console UI.

## Current live endpoint

The live IP confirmed by the project owner is:

- API: `http://54.205.74.122/api`
- Socket: `http://54.205.74.122`

Use this IP for the current Flutter live build unless the EC2 instance detail or DNS is updated.

Because AWS Global View shows the EC2 instances are not in `ap-southeast-1`, re-check the actual EC2 instance details before changing to a different host/domain.

## Current live server

Confirmed on 2026-09-16:

- AWS region: `us-east-1` / N. Virginia.
- EC2 instance name: `nail-talk-demo`.
- EC2 instance id: `i-0d40575496d1426d9`.
- Public IP: `54.205.74.122`.
- Public DNS: `ec2-54-205-74-122.compute-1.amazonaws.com`.
- SSH user: `ubuntu`.
- Server project root: `/var/www/nail-talk`.
- Laravel API path: `/var/www/nail-talk/admin-api`.
- Socket path: `/var/www/nail-talk/chat-socket`.
- Socket service: `nail-talk-socket.service`.
- Web stack: nginx + PHP 8.4 FPM + local MySQL.

No matching private SSH key was found on the local Mac during the 2026-09-16 check. Access was done through AWS CloudShell + EC2 Instance Connect, then a temporary local SSH key was used only for the deployment session.

## 2026-09-16 manual live sync

Temporary manual upload was used because `admin-api/` and `chat-socket/` are not currently git repositories in this workspace.

Server upload folder:

```text
/home/ubuntu/live-sync-20260916-1349
```

Server backup folder before overwrite/import:

```text
/home/ubuntu/backups/20260916-1407
```

Backups created:

- Current live code: `/home/ubuntu/backups/20260916-1407/nail-talk-current-code.tgz`
- Current live database: `/home/ubuntu/backups/20260916-1407/live-db-before-import.sql.gz`
- Previous live `public/demo`: moved under the same backup folder before extracting the new image set.

Uploaded from local:

- `admin-api-code.tgz`
- `chat-socket-code.tgz`
- `social_hub_local.sql`
- `admin-api-public-demo.tgz`

Deploy notes:

- Kept server `.env`, Laravel `vendor/`, socket `node_modules/`, `chat_uploads/`, and `recordings/`.
- Imported the latest local `social_hub_local` dump into the live MySQL database.
- Replaced movie image URLs in the live DB from local asset host `127.0.0.1:8010` to `http://54.205.74.122`.
- Restarted `php8.4-fpm`, `nginx`, and `nail-talk-socket`.

## 2026-09-23 App Review fix deploy

Deployed the App Store review fixes to the same live EC2 server with AWS Console EC2 Instance Connect as user `ubuntu`.

What changed on live:

- Synced `admin-api/` code from local tarball, keeping server `.env`, `vendor/`, `public/demo`, storage/runtime files, and uploads.
- Synced `chat-socket/` code from local tarball, keeping server `.env`, `node_modules`, `chat_uploads`, and `recordings`.
- Ran `php artisan migrate --force` and `php artisan optimize:clear`.
- Restarted `php8.4-fpm`, `nginx`, and `nail-talk-socket.service`.
- Updated the live `em_chat_apps` display name from `Nail Talk` to `Nails Talk`.

App Review route checks confirmed after deploy:

- `POST /api/blocks` exists and returns `401` when unauthenticated.
- `DELETE /api/me` exists and returns `401` when unauthenticated.
- Authenticated smoke test passed for register, profile load, report user, block user, and delete the same smoke-test account.
- Socket.IO handshake passed at `http://54.205.74.122/socket.io/?EIO=4&transport=polling`.

Important note: GitHub clone from the live server failed because the backend repos require credentials and the old token was rejected by GitHub. For this deploy, code was transferred by a lightweight tar/base64 paste through EC2 Instance Connect.

## Socket note

The current Social Hub socket source lives in:

```text
chat-socket/
```

Do not treat `chat-socket/HUONG_DAN_DEPLOY_SOCKETIO_CHAT_ERP_FREEBSD_VI.md` as the current Social Hub live endpoint by default. That file documents an older FreeBSD / `socket.ginosan.com` deployment path and must be manually reconfirmed before reuse.

Previous local development defaults:

- API: `http://127.0.0.1:8010/api`
- Socket: `http://127.0.0.1:3000`

Current Flutter defaults:

- API: `http://54.205.74.122/api`
- Socket: `http://54.205.74.122`

## Flutter build rule

Flutter endpoint defaults are in:

```text
flutter-app/lib/src/core/constants/app_constants.dart
```

Before a Store/TestFlight build:

1. Confirm the live IP/domain is still `54.205.74.122`, or update this note first.
2. Confirm the Laravel API and Socket.IO server are deployed from this workspace (`admin-api/` and `chat-socket/`).
3. Smoke test:

```bash
curl "http://54.205.74.122/api/mobile-chat/apps"
curl "http://54.205.74.122/api/movies"
curl "http://54.205.74.122/socket.io/?EIO=4&transport=polling"
```

4. For local API/socket testing, override the defaults with `--dart-define=BOOTSTRAP_API_BASE=http://127.0.0.1:8010/api` and `--dart-define=CHAT_CALL_BASE_URL=http://127.0.0.1:3000`.

## iOS App Review YouTube-only video mode

As of 2026-10-08, the Flutter app shows the Video section on iOS, but defaults to YouTube-embed-only playback for Apple review.

- Flag location: `flutter-app/lib/src/core/constants/app_constants.dart`
- Default behavior: `YOUTUBE_VIDEO_FEATURE_ENABLED=true`, `MOVIE_PAYMENTS_ENABLED=false`, and `HOSTED_MOVIE_PLAYBACK_ENABLED=false`.
- Flutter filters video data to YouTube embeds unless hosted playback is intentionally enabled.
- The Laravel API also filters `/api/movies` to published YouTube entries only while `HOSTED_MOVIE_PLAYBACK_ENABLED=false`.

## Admin feature toggles for App Review

As of 2026-10-09, the live app can hide or show the Video and community card-game areas from the Laravel admin dashboard without rebuilding the mobile app.

- Admin location: `/admin/resources/chat-apps` → edit the `social-hub` / `Nails Talk` chat app.
- `Enable Video tab` controls the mobile Video tab and the `/api/movies` API. When off, the app hides Video and the API returns no movie records / 404 for movie detail.
- `Enable Game bài / card game` controls the community card-game preview/banner in the app.
- Both toggles default to off for Apple review safety. After Apple approval, turn on only the features that should be visible in production.
- Hosted/direct movie playback remains separately blocked unless `HOSTED_MOVIE_PLAYBACK_ENABLED=true` is intentionally set on the server.

## Smoke test result

Checked from local machine on 2026-09-16:

- `http://54.205.74.122/api/mobile-chat/apps`: HTTP 200
- `http://54.205.74.122/api/movies`: HTTP 200
- `http://54.205.74.122/api/movies/categories`: HTTP 200
- `http://54.205.74.122/api/jobs`: HTTP 200
- `http://54.205.74.122/api/marketplace/categories`: HTTP 200
- `http://54.205.74.122/api/properties`: HTTP 200
- `http://54.205.74.122/socket.io/?EIO=4&transport=polling`: HTTP 200 with Socket.IO handshake

Checked again from local machine on 2026-09-28 after syncing the new local database to live:

- Imported the current local Laravel database dump into the live server database.
- Rewrote local URL values in the live database to the live base URL `http://54.205.74.122`.
- Confirmed `em_chat_apps` returns `Nails Talk` with live API and socket URLs.
- `http://54.205.74.122/api/mobile-chat/apps`: HTTP 200
- `http://54.205.74.122/api/clinics`: HTTP 200 with the new service directory data.
- `http://54.205.74.122/api/clinics/specialties`: HTTP 200
- `http://54.205.74.122/socket.io/?EIO=4&transport=polling`: HTTP 200 with Socket.IO handshake

Checked again from local machine on 2026-10-07 for App Review cleanup:

- Removed live medical service booking data from the admin dashboard/API.
- Deleted the live `clinic` service category and the medical provider `Phòng khám Đa khoa Sài Gòn Care`.
- Updated the remaining live service category to `Đặt spa & beauty`.
- Confirmed `http://54.205.74.122/api/services` only returns the `spa` service.
- Confirmed `http://54.205.74.122/api/clinics` only returns `Spa Thảo Mộc Sài Gòn`.
- Confirmed `http://54.205.74.122/api/clinics/specialties` only returns non-medical spa/beauty specialties: chăm sóc da, gội đầu dưỡng sinh, massage thư giãn.

Checked again on 2026-10-07 after AWS login and local data sync:

- EC2 Console region: `us-east-1`.
- Running instance: `nail-talk-demo`, public IP `54.205.74.122`.
- Synced current local `admin-api/` and `chat-socket/` source to `/var/www/nail-talk`, keeping server `.env`, dependencies, uploads, recordings, and runtime storage.
- Imported the current local `social_hub_local` MySQL dump into the live database.
- Rewrote local API/socket URLs in the live database to `http://54.205.74.122`.
- Restarted `php8.4-fpm`, `nginx`, and `nail-talk-socket.service`.
- Confirmed live API app bootstrap, services, spa/beauty provider list, specialties, and Socket.IO handshake all return successfully.
- Flutter iOS App Review hardening added after the live sync: service UI is rewritten as spa/beauty instead of medical/clinic, Account has a visible Sign out button, listing detail screens expose Report + Block actions, and the Video section is YouTube-embed-only with hosted/direct playback disabled.
