# Nova Video v20 signing setup

The workflow is consolidated in `.github/workflows/build-sign-ipa.yml`. It requires valid signing inputs and stops instead of silently producing an unsigned IPA.

## Local certificate converter

Use `tools/Convert-AppleSigningCertificate.ps1` on your own Windows PC. It converts a certificate plus its matching private key into a password-protected `.p12`, verifies that the certificate and key match, and checks that OpenSSL can read the resulting file.

**A certificate by itself is not enough.** A signing identity needs the matching private key. This script accepts a certificate file (`.cer`, `.crt`, or `.pem`) and a private-key file (`.key` or `.pem`). It does not create a missing private key, and it cannot turn a provisioning profile into a signing certificate. If you have a `.pfx` or `.p12` already, it is already in the PKCS#12 family and normally does not need conversion.

### Run on Windows

1. Install OpenSSL from a trusted source if `openssl.exe` is not already available in PowerShell.
2. Download the script from this repository and keep it on your trusted PC.
3. Open PowerShell in the folder containing the script and run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Convert-AppleSigningCertificate.ps1 -DeleteSourceFiles
```

4. Enter the certificate path and matching private-key path when prompted.
5. Enter and confirm a strong password for the output `.p12`.
6. The script verifies the pair and output before asking you to type `DELETE` to remove the two original files. If verification fails, the source files are not deleted. To keep the originals, omit `-DeleteSourceFiles`.

The script works locally and does not upload certificate files. Deleting a file is not guaranteed to erase all copies from SSD storage, backups, or cloud-sync history. Keep an encrypted backup of credentials somewhere safe before deleting the only original.

## Required GitHub Actions secrets

In GitHub, open **Settings → Secrets and variables → Actions → New repository secret** and add:

- `IOS_P12_BASE64`: Base64 text of the exported `.p12` file, including its private key.
- `IOS_P12_PASSWORD`: password used to protect the exported `.p12`.
- `IOS_PROVISION_PROFILE_BASE64`: Base64 text of the valid provisioning profile matching bundle ID `com.hr.videodownloader.x7k2`.

The provisioning profile must match the certificate and app identifier and authorize installation on the target device. For an Apple Development profile, the iPhone UDID normally needs to be included.

## PowerShell: prepare Base64 text files locally

After conversion, run this on your trusted Windows PC. This creates local Base64 copies; do not commit or share them.

```powershell
$p12 = (Resolve-Path ".\AppleSigningCertificate.p12").Path
$profile = (Resolve-Path ".\NovaVideo.mobileprovision").Path

[Convert]::ToBase64String([IO.File]::ReadAllBytes($p12)) |
  Set-Content -NoNewline ".\IOS_P12_BASE64.txt"

[Convert]::ToBase64String([IO.File]::ReadAllBytes($profile)) |
  Set-Content -NoNewline ".\IOS_PROVISION_PROFILE_BASE64.txt"

Write-Host "Add the contents as the matching GitHub Actions secrets, then delete these temporary Base64 text files."
```

Set `IOS_P12_PASSWORD` as a separate secret. Never put passwords, private keys, certificates, provisioning profiles, or Base64 copies in a commit or chat. Do not upload signing files as workflow artifacts.

## Run the workflow

1. Open **Actions → Build and Sign Nova Video v20 IPA**.
2. Choose **Run workflow** on branch `nova-video-v20-network-failsafes`.
3. Wait for every step to pass.
4. Download artifact `Nova-Video-v20-SIGNED-IPA` from the completed run.

The workflow sets the bundle short version to `20.0` and build number to `20`, signs with the supplied Apple Development identity, embeds the profile, verifies the signature, and packages the IPA. It does not upload the private certificate or password as artifacts.

## Important limitations

This repository cannot create an authentic Apple signing certificate, private key, or provisioning profile from scratch. These must come from an Apple Developer account authorized to sign the app. A new certificate will not reproduce the original signing identity unless the original credentials are available.

The repository contains a precompiled app binary and a separate SwiftUI recovery scaffold, not the original Xcode project. The workflow can re-sign and relabel the existing binary, but it does not integrate the recovery UI or repair the original YouTube resolver. A successful signing/package check is not proof that the school-Wi-Fi timeout is fixed or that v20 is a tested release.
