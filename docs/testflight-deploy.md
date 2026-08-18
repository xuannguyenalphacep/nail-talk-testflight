# Nail Talk TestFlight Deploy

## Recommended path

For this project, the safest deploy path is GitHub Actions, not local Xcode archive.

The workflow file is:

`.github/workflows/testflight.yml`

It already:

- checks out source
- pins Flutter to revision `ff37bef603469fb030f2b72995ab929ccfc227f0`
- installs Codemagic CLI tools
- fetches signing files from App Store Connect
- builds the IPA
- uploads the IPA to App Store Connect

## iOS app settings

- App name: `Nail Talk`
- Bundle ID: `com.kantek.nailtalk`
- Marketing version: `1.0.0`
- iOS deployment target: `15.0`
- Build number source: `GITHUB_RUN_NUMBER`

## Required GitHub secrets

Add these secrets in the GitHub repository before deploying:

- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_KEY_IDENTIFIER`
- `APP_STORE_CONNECT_PRIVATE_KEY`
- `CERTIFICATE_PRIVATE_KEY`

Notes:

- `APP_STORE_CONNECT_PRIVATE_KEY` is the full `.p8` key content from App Store Connect API key.
- `CERTIFICATE_PRIVATE_KEY` is the private key used to let Codemagic CLI create or fetch the App Store signing certificate.
- Do not commit any of these values into the repo.

## First-time setup

1. Create the app in App Store Connect with bundle ID `com.kantek.nailtalk`.
2. Make sure the Apple Developer account can create certificates and provisioning profiles.
3. Add the 4 GitHub secrets above.
4. Confirm the workflow file exists in `.github/workflows/testflight.yml`.

## Normal deploy flow

### Option 1: Push to `main`

Any push to `main` will trigger the `iOS TestFlight` workflow automatically.

```bash
git push origin main
```

### Option 2: Run manually

Use this when you want to rebuild without a new code change.

1. Open GitHub repository.
2. Go to `Actions`.
3. Open workflow `iOS TestFlight`.
4. Click `Run workflow`.

## What the workflow does

1. Checks out the repo.
2. Downloads the exact Flutter revision from `.metadata`.
3. Runs `flutter pub get`.
4. Runs `flutter precache --ios`.
5. Runs `pod install` in `ios/`.
6. Initializes a temporary signing keychain.
7. Fetches signing files from App Store Connect using Codemagic CLI.
8. Applies provisioning profiles to `ios/Runner.xcodeproj`.
9. Builds the IPA with:

```bash
flutter build ipa --release --build-name=1.0.0 --build-number="${GITHUB_RUN_NUMBER}"
```

10. Uploads the IPA artifact to GitHub Actions.
11. Publishes the IPA to App Store Connect.

## After upload

After the workflow succeeds:

1. Open App Store Connect.
2. Go to `TestFlight`.
3. Wait for the new build to move from `Processing` to `Complete`.
4. Add the build to internal or external groups if needed.
5. For external testing, fill `What to Test` and submit for beta review.

## Current proven result

This flow was verified successfully on `August 18, 2026`.

Successful path:

- GitHub Actions workflow: `iOS TestFlight`
- successful run uploaded build `1.0.0 (11)`
- build `1.0.0 (11)` reached TestFlight and moved to `Testing`

## Important notes

### 1. If you edit workflow files

If you push changes to `.github/workflows/testflight.yml` by HTTPS token, that token must include GitHub `workflow` permission.

If the token does not have that permission, GitHub can reject the push even if normal code pushes work.

### 2. If local Mac build fails

On this machine, local Xcode archive was not the reliable path. GitHub Actions was the working path.

If local `xcodebuild` or Flutter iOS commands act strangely, use the workflow route first.

### 3. Build numbers

Because build number uses `GITHUB_RUN_NUMBER`, every workflow run creates a new iOS build number automatically.

## Quick checklist

- Secrets exist in GitHub
- Bundle ID is still `com.kantek.nailtalk`
- Push code to `main` or run workflow manually
- Wait for GitHub Actions success
- Wait for App Store Connect processing
- Add build to TestFlight groups
- Submit beta review if external testing is needed
