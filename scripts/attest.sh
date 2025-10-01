#!/usr/bin/env bash
set -euo pipefail

TSA_URL="https://freetsa.org/tsr"
ROOT_CERT_URL="https://freetsa.org/files/cacert.pem"
ROOT_CERT="freetsa-root.pem"

usage() {
    echo "Usage:"
    echo "  $0 --attest <gpg-key-id> \"message text\""
    echo "  $0 --verify <attestation.tgz>"
    exit 1
}

fetch_root_cert() {
    if [ ! -f "$ROOT_CERT" ]; then
        echo "[*] Fetching FreeTSA root certificate..."
        curl -sS "$ROOT_CERT_URL" -o "$ROOT_CERT"
    fi
}

attest() {
    local keyid="$1"
    local message="$2"

    tmpdir=$(mktemp -d)
    echo "$message" >"$tmpdir/message.txt"

    echo "[*] Signing message with GPG key $keyid..."
    gpg --batch --yes --local-user "$keyid" \
        --output "$tmpdir/message.sig" \
        --detach-sign "$tmpdir/message.txt"

    echo "[*] Creating timestamp request..."
    openssl ts -query -data "$tmpdir/message.sig" -sha256 -no_nonce -cert \
        -out "$tmpdir/request.tsq"

    echo "[*] Sending to TSA ($TSA_URL)..."
    curl -sS --data-binary @"$tmpdir/request.tsq" \
        -H "Content-Type: application/timestamp-query" \
        "$TSA_URL" -o "$tmpdir/response.tsr"

    out="attestation-$(date -u +%Y%m%dT%H%M%SZ).tgz"
    tar czf "$out" -C "$tmpdir" message.txt message.sig response.tsr
    echo "[+] Created attestation: $out"
    rm -rf "$tmpdir"
}

verify() {
    local archive="$1"

    tmpdir=$(mktemp -d)
    tar xzf "$archive" -C "$tmpdir"

    echo "[*] Extracted attestation:"
    echo "    - message.txt"
    echo "    - message.sig"
    echo "    - response.tsr"

    # --- Verify GPG ---
    echo "[*] Verifying GPG signature..."
    signer=$(gpg --status-fd 1 --verify "$tmpdir/message.sig" "$tmpdir/message.txt" 2>/dev/null \
        | awk -F'[][]' '/^\[GNUPG:\] GOODSIG/ {print $3}')
    if [ -n "$signer" ]; then
        echo "[+] GPG signature valid."
        echo "    Signed by: $signer"
    else
        echo "[!] GPG signature verification failed."
        exit 1
    fi

    # --- Verify TSA ---
    fetch_root_cert
    echo "[*] Verifying TSA timestamp..."
    if openssl ts -verify -data "$tmpdir/message.sig" \
        -in "$tmpdir/response.tsr" -CAfile "$ROOT_CERT" >/dev/null 2>&1; then
        echo "[+] Timestamp token valid."
    else
        echo "[!] Timestamp verification failed."
        exit 1
    fi

    # Extract timestamp details
    ts_time=$(openssl ts -reply -in "$tmpdir/response.tsr" -text \
        | awk -F': ' '/Time stamp:/ {print $2; exit}')
    tsa_subject=$(openssl ts -reply -in "$tmpdir/response.tsr" -text \
        | awk -F': ' '/TSA:/ {print $2; exit}')

    echo "    TSA subject: $tsa_subject"
    echo "    Timestamp:   $ts_time"

    # --- Final summary ---
    statement=$(cat "$tmpdir/message.txt")
    echo
    echo "✅ Statement: \"$statement\""
    echo "   was attested by $signer at $ts_time (TSA: $tsa_subject)."

    rm -rf "$tmpdir"
}

# --- main ---
if [ $# -lt 2 ]; then
    usage
fi

case "$1" in
    --attest)
        [ $# -ge 3 ] || usage
        attest "$2" "$3"
        ;;
    --verify)
        [ $# -eq 2 ] || usage
        verify "$2"
        ;;
    *)
        usage
        ;;
esac

