#!/usr/bin/env python3
"""Talk to the App Store Connect API.

The API wants a JSON Web Token signed with the private key of an App Store
Connect API key (the `.p8` file). The signature is ES256, which in JWS is the
raw `r||s` form — not the DER encoding OpenSSL produces — so this mints the
token with the OpenSSL command line and converts the signature.

    python3 scripts/asc_api.py GET /v1/apps/6826903678/builds
    python3 scripts/asc_api.py PATCH /v1/appStoreVersions/123 -d '{"appReviewNotes":"…"}'

Credentials come from the environment:
    ASC_KEY_ID       the key id (e.g. MU26W8YJGR)
    ASC_ISSUER_ID    the issuer id
    ASC_KEY_PATH     the private key (default: ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8)
"""

from __future__ import annotations

import base64
import json
import os
import pathlib
import subprocess
import sys
import time

API = "https://api.appstoreconnect.apple.com"


def base64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def der_signature_to_raw(der: bytes, size: int = 32) -> bytes:
    """Turns a DER ECDSA signature into the raw `r||s` form JWS wants."""
    if der[0] != 0x30:
        raise ValueError("not a DER sequence")
    index = 2 if der[1] < 0x80 else 2 + (der[1] & 0x7F)

    def read_integer(at: int) -> tuple[int, int]:
        if der[at] != 0x02:
            raise ValueError("not a DER integer")
        length = der[at + 1]
        value = der[at + 2:at + 2 + length]
        if value[0] & 0x80:  # ASN.1 marks negatives with a leading zero
            value = value[1:]
        return int.from_bytes(value, "big"), at + 2 + length

    r, index = read_integer(index)
    s, index = read_integer(index)
    return r.to_bytes(size, "big") + s.to_bytes(size, "big")


def make_token(key_id: str, issuer_id: str, key_path: pathlib.Path) -> str:
    header = base64url(json.dumps({"alg": "ES256", "kid": key_id, "typ": "JWT"}).encode())
    payload = base64url(json.dumps({
        "iss": issuer_id,
        "iat": int(time.time()),
        "exp": int(time.time()) + 1200,
        "aud": "appstoreconnect-v1",
    }).encode())
    signing_input = f"{header}.{payload}".encode()
    der = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", str(key_path)],
        input=signing_input,
        capture_output=True,
        check=True,
    ).stdout
    signature = base64url(der_signature_to_raw(der))
    return f"{header}.{payload}.{signature}"


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 64
    method, path = sys.argv[1], sys.argv[2]
    body = sys.argv[3] if len(sys.argv) > 3 else None

    key_id = os.environ.get("ASC_KEY_ID", "MU26W8YJGR")
    issuer_id = os.environ.get("ASC_ISSUER_ID", "7bfcb655-045e-47c4-88e2-43e0c3988c44")
    key_path = pathlib.Path(os.environ.get(
        "ASC_KEY_PATH",
        f"~/.appstoreconnect/private_keys/AuthKey_{key_id}.p8",
    )).expanduser()
    if not key_path.exists():
        print(f"error: no API key at {key_path}", file=sys.stderr)
        return 1

    token = make_token(key_id, issuer_id, key_path)
    url = path if path.startswith("http") else API + path
    result = subprocess.run(
        # -g: curl would otherwise read the brackets of a filter[...] query
        # parameter as a glob range and refuse the URL.
        ["curl", "-sS", "-g", "-X", method, url,
         "-H", f"Authorization: Bearer {token}",
         "-H", "Content-Type: application/json",
         *(["-d", body] if body else [])],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print(result.stderr, file=sys.stderr)
        return result.returncode
    try:
        print(json.dumps(json.loads(result.stdout), indent=1))
    except json.JSONDecodeError:
        print(result.stdout)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
