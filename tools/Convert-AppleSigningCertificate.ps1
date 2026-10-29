# Convert-AppleSigningCertificate.ps1
# Local-only converter. Never upload certificates or private keys to GitHub.
[CmdletBinding()]
param(
    [string]$CertificatePath,
    [string]$PrivateKeyPath,
    [string]$OutputPath = (Join-Path (Get-Location) "AppleSigningCertificate.p12"),
    [switch]$DeleteSourceFiles
)

$ErrorActionPreference = "Stop"

function Read-SecretText([string]$Prompt) {
    $secure = Read-Host $Prompt -AsSecureString
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
}

$openssl = Get-Command openssl -ErrorAction SilentlyContinue
if (-not $openssl) {
    throw "OpenSSL was not found. Install OpenSSL on this PC, reopen PowerShell, and try again."
}

if (-not $CertificatePath) {
    $CertificatePath = Read-Host "Path to certificate file (.cer, .crt, or .pem)"
}
if (-not $PrivateKeyPath) {
    $PrivateKeyPath = Read-Host "Path to matching private key file (.key or .pem)"
}
$CertificatePath = (Resolve-Path -LiteralPath $CertificatePath).Path
$PrivateKeyPath = (Resolve-Path -LiteralPath $PrivateKeyPath).Path
$OutputPath = [IO.Path]::GetFullPath($OutputPath)

if ($CertificatePath -eq $PrivateKeyPath) {
    throw "Certificate and private key must be supplied as separate files for this script."
}
if ($OutputPath -eq $CertificatePath -or $OutputPath -eq $PrivateKeyPath) {
    throw "Output path must be different from both source paths."
}
if (Test-Path -LiteralPath $OutputPath) {
    throw "Output already exists: $OutputPath . Rename or move it first; this script will not overwrite it."
}

$temp = Join-Path ([IO.Path]::GetTempPath()) ("nova-p12-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $temp | Out-Null
$certPem = Join-Path $temp "certificate.pem"
$keyPem = Join-Path $temp "private-key.pem"
$createdOutput = $false

try {
    # Normalize the certificate to PEM. Try PEM input first, then DER/ASN.1 input.
    & $openssl.Source x509 -in $CertificatePath -out $certPem 2>$null
    if ($LASTEXITCODE -ne 0) {
        & $openssl.Source x509 -inform DER -in $CertificatePath -out $certPem
        if ($LASTEXITCODE -ne 0) { throw "Could not read certificate as PEM or DER. Verify the certificate file." }
    }

    # Normalize the private key to unencrypted PEM only inside a temporary folder.
    # OpenSSL may prompt securely for a source-key password if it is encrypted.
    & $openssl.Source pkey -in $PrivateKeyPath -out $keyPem
    if ($LASTEXITCODE -ne 0) { throw "Could not read/decrypt the private key. Check the key file and its password." }

    # Verify certificate and key are a matching pair by comparing public-key hashes.
    $certPub = & $openssl.Source x509 -in $certPem -pubkey -noout
    if ($LASTEXITCODE -ne 0) { throw "Could not extract certificate public key." }
    $keyPub = & $openssl.Source pkey -in $keyPem -pubout
    if ($LASTEXITCODE -ne 0) { throw "Could not extract private-key public key." }
    $certPubText = ($certPub -join "`n").Trim()
    $keyPubText = ($keyPub -join "`n").Trim()
    if ($certPubText -ne $keyPubText) {
        throw "The certificate and private key do not match. No source files were deleted."
    }

    $password = Read-SecretText "Create a password for the output .p12 (required)"
    if ([string]::IsNullOrWhiteSpace($password)) { throw "A non-empty output password is required." }
    $passwordConfirm = Read-SecretText "Confirm the output .p12 password"
    if ($password -cne $passwordConfirm) { throw "Passwords did not match." }

    # Use a process environment variable rather than placing the password in command-line arguments.
    $env:NOVA_P12_EXPORT_PASSWORD = $password
    & $openssl.Source pkcs12 -export -out $OutputPath -in $certPem -inkey $keyPem -passout env:NOVA_P12_EXPORT_PASSWORD
    if ($LASTEXITCODE -ne 0) { throw "OpenSSL could not export the .p12 file." }
    $createdOutput = $true

    # Verify the resulting PKCS#12 can be parsed with the chosen password.
    & $openssl.Source pkcs12 -in $OutputPath -noout -passin env:NOVA_P12_EXPORT_PASSWORD
    if ($LASTEXITCODE -ne 0) { throw "The generated .p12 failed verification." }

    Write-Host ""
    Write-Host "Conversion successful: $OutputPath" -ForegroundColor Green
    Write-Host "The certificate and private key matched, and the .p12 passed a parse check."

    if ($DeleteSourceFiles) {
        $answer = Read-Host "Delete the original certificate AND private-key files now? Type DELETE to confirm"
        if ($answer -ceq "DELETE") {
            Remove-Item -LiteralPath $CertificatePath -Force
            Remove-Item -LiteralPath $PrivateKeyPath -Force
            Write-Host "Original source files deleted. Note: SSD/cloud backups may retain recoverable copies." -ForegroundColor Yellow
        } else {
            Write-Host "Source files kept; deletion was not confirmed."
        }
    } else {
        Write-Host "Source files were kept. To request deletion after successful verification, rerun with -DeleteSourceFiles."
    }
}
catch {
    if ($createdOutput -and (Test-Path -LiteralPath $OutputPath)) {
        Remove-Item -LiteralPath $OutputPath -Force -ErrorAction SilentlyContinue
    }
    throw
}
finally {
    Remove-Item Env:\NOVA_P12_EXPORT_PASSWORD -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
