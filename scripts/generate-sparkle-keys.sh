#!/usr/bin/env bash
# One-time setup: generates the EdDSA key pair Sparkle uses to sign updates.
#
# After running this:
#   1. Copy the PRIVATE key → GitHub repo secret: SPARKLE_PRIVATE_KEY
#   2. Copy the PUBLIC key  → build-app.sh, replace the SPARKLE_PUBLIC_KEY value
#      (look for the line: SPARKLE_PUBLIC_KEY="${SPARKLE_PUBLIC_KEY:-}")
#
# Keep the private key safe — anyone with it can push malicious updates.
# Never commit the private key.
set -euo pipefail

SPARKLE_VERSION="2.6.4"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "Downloading Sparkle ${SPARKLE_VERSION} CLI tools…"
curl -fsSL \
  "https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz" \
  | tar -xJ -C "$TMP"

echo ""
echo "Generating EdDSA key pair…"
echo "========================================================"
"$TMP/bin/generate_keys"
echo "========================================================"
echo ""
echo "Done. See the instructions above — add keys before pushing a release tag."
