# Nova Video v20 signing setup

The workflow is consolidated in `.github/workflows/build-sign-ipa.yml`. It **requires valid signing inputs** and stops instead of silently producing an unsigned IPA.

## Important boundary

This repository cannot create an authentic Apple signing certificate, its private key, or a provisioning profile from scratch. Those must come from the Apple Developer account that owns or is authorized to sign the app. A newly created certificate also will not reproduce the original signing identity unless the original credentials are available.

Never commit `.p12`, `.mobileprovision`, passwords, API keys, or private keys to the repository. GitHub Actions secrets are used instead.

## Required repository secrets

In GitHub, open **Settings → Secrets and variables → Actions → New repository secret** and add:

- `IOS_P12_BASE64`: Base64 text of your exported Apple signing `.p12` file (including its private key).
- `IOS_P12_PASSWORD`: password used to export/protect that `.p12`.
- `IOS_PROVISION_PROFILE_BASE64`: Base64 text of the provisioning profile matching bundle ID `com.hr.videodownloader.x7k2`.

The provisioning profile must be valid for the certificate and app identifier, and must authorize installation on the target device. For an Apple Development profile, the iPhone UDID normally needs to be included.

## PowerShell: prepare Base64 text files locally

Run on a trusted Windows PC after obtaining the real files from the Apple Developer account. This writes Base64 copies locally; do not commit or share them.

```powershell
$p12 = (Resolve-Path ".\AppleSigningCertificate.p12").Path
$profile = (Resolve-Path ".\NovaVideo.mobileprovision").Path

[Convert]::ToBase64String([IO.File]::ReadAllBytes($p12)) |
  Set-Content -NoNewline ".\IOS_P12_BASE64.txt"

[Convert]::ToBase64String([IO.File]::ReadAllBytes($profile)) |
  Set-Content -NoNewline ".\IOS_PROVISION_PROFILE_BASE64.txt"

Write-Host "Created local Base64 files. Add their contents as the matching GitHub Actions secrets, then securely delete the local Base64 copies."
```

Set the `IOS_P12_PASSWORD` secret separately. Do not put the password in a script, commit, or chat. Delete the temporary Base64 text files after the secrets are added.

## Run the workflow

1. Open **Actions → Build and Sign Nova Video v20 IPA**.
2. Choose **Run workflow** on branch `nova-video-v20-network-failsafes`.
3. Wait for every step to pass.
4. Download artifact `Nova-Video-v20-SIGNED-IPA` from the completed run.

The workflow sets the bundle's short version to `20.0` and build number to `20`, signs with the supplied Apple Development identity, embeds the profile, verifies the signature, and packages the IPA. It does not upload the private certificate or password as artifacts.

## What this does not fix

The repository currently contains a precompiled app binary and a separate SwiftUI recovery scaffold, not the original Xcode project. This workflow can re-sign and relabel the existing binary, but it **does not integrate the recovery UI or repair the original YouTube resolver**. Do not treat a successful signing/package check as proof that the school-Wi-Fi timeout is fixed or that the IPA is a tested release.
