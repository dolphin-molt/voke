#!/bin/zsh

set -euo pipefail

CERTIFICATE_NAME="Voke Local Development"
LOGIN_KEYCHAIN="$(security default-keychain -d user | sed -E 's/^[[:space:]]*\"//; s/\"[[:space:]]*$//')"

identity_hash() {
  security find-identity -v -p codesigning "$LOGIN_KEYCHAIN" \
    | awk -v name="$CERTIFICATE_NAME" 'index($0, "\"" name "\"") { print $2; exit }'
}

EXISTING_IDENTITY="$(identity_hash)"
if [[ -n "$EXISTING_IDENTITY" ]]; then
  print "$EXISTING_IDENTITY"
  exit 0
fi

CERTIFICATE_ROOT="$(mktemp -d /tmp/voke-signing.XXXXXX)"
trap 'rm -rf "$CERTIFICATE_ROOT"' EXIT
PRIVATE_KEY="$CERTIFICATE_ROOT/voke-local.key"
CERTIFICATE="$CERTIFICATE_ROOT/voke-local.crt"
ARCHIVE="$CERTIFICATE_ROOT/voke-local.p12"
ARCHIVE_PASSWORD="$(uuidgen)-$(uuidgen)"

openssl req \
  -newkey rsa:2048 \
  -nodes \
  -x509 \
  -sha256 \
  -days 3650 \
  -subj "/CN=$CERTIFICATE_NAME/O=Dolphin Local Development" \
  -addext "basicConstraints=critical,CA:TRUE" \
  -addext "keyUsage=critical,digitalSignature,keyCertSign" \
  -addext "extendedKeyUsage=codeSigning" \
  -keyout "$PRIVATE_KEY" \
  -out "$CERTIFICATE" \
  >/dev/null 2>&1

openssl pkcs12 \
  -export \
  -legacy \
  -name "$CERTIFICATE_NAME" \
  -inkey "$PRIVATE_KEY" \
  -in "$CERTIFICATE" \
  -passout "pass:$ARCHIVE_PASSWORD" \
  -out "$ARCHIVE" \
  >/dev/null 2>&1

security import "$ARCHIVE" \
  -k "$LOGIN_KEYCHAIN" \
  -t agg \
  -f pkcs12 \
  -P "$ARCHIVE_PASSWORD" \
  -A \
  >/dev/null
security add-trusted-cert \
  -d \
  -r trustRoot \
  -k "$LOGIN_KEYCHAIN" \
  "$CERTIFICATE" \
  >/dev/null

NEW_IDENTITY="$(identity_hash)"
if [[ -z "$NEW_IDENTITY" ]]; then
  print -u2 "Created the Voke certificate, but macOS did not expose a valid signing identity."
  exit 1
fi

print "$NEW_IDENTITY"
