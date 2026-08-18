# Nail Talk Flutter App

Nail Talk is the Flutter mobile app for chat, movies, marketplace, jobs, and room-share flows.

## Project docs

- TestFlight deploy guide: [docs/testflight-deploy.md](docs/testflight-deploy.md)

## iOS release

This project already has a working GitHub Actions pipeline for TestFlight upload.

Workflow file:

- `.github/workflows/testflight.yml`

Recommended release path:

1. Push to `main`, or run the `iOS TestFlight` workflow manually from GitHub Actions.
2. Wait for GitHub Actions to finish successfully.
3. Open App Store Connect `TestFlight` and wait for build processing to finish.
4. Add the build to the needed tester groups.

For the full deploy notes, use:

- [docs/testflight-deploy.md](docs/testflight-deploy.md)
