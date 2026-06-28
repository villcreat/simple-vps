"""Reads the encrypted export file produced by the VPS Simple app.

The format and crypto must match `lib/src/services/crypto/` in the Flutter app:
Argon2id (m=19456 KiB, t=2, p=1, len=32, v=19) derives the key, and AES-256-GCM
seals the payload. The app stores the GCM tag separately as ``mac``; Python's
AESGCM expects ``ciphertext + tag``, so we concatenate them on decrypt.
"""

import base64
import json

from argon2.low_level import Type, hash_secret_raw
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

_MAGIC = "vps-simple-export"
_KDF_MEMORY = 19456  # KiB
_KDF_ITERATIONS = 2
_KDF_PARALLELISM = 1
_KEY_LENGTH = 32
_ARGON2_VERSION = 19  # 0x13, matches the Dart `cryptography` package


def derive_key(password: str, salt: bytes) -> bytes:
    return hash_secret_raw(
        secret=password.encode("utf-8"),
        salt=salt,
        time_cost=_KDF_ITERATIONS,
        memory_cost=_KDF_MEMORY,
        parallelism=_KDF_PARALLELISM,
        hash_len=_KEY_LENGTH,
        type=Type.ID,
        version=_ARGON2_VERSION,
    )


def _open_box(key: bytes, box: dict) -> bytes:
    nonce = base64.b64decode(box["nonce"])
    cipher = base64.b64decode(box["cipher"])
    mac = base64.b64decode(box["mac"])
    return AESGCM(key).decrypt(nonce, cipher + mac, None)


def decrypt_export(path: str, password: str) -> dict:
    """Returns ``{"servers": [...], "secrets": {...}}`` or raises on failure."""
    with open(path, "r", encoding="utf-8") as handle:
        data = json.load(handle)

    if not isinstance(data, dict) or data.get("format") != _MAGIC:
        raise ValueError("Not a VPS Simple export file")
    if data.get("version") != 1:
        raise ValueError("Unsupported export file version")

    salt = base64.b64decode(data["salt"])
    key = derive_key(password, salt)
    plaintext = _open_box(key, data["payload"])
    payload = json.loads(plaintext.decode("utf-8"))

    return {
        "servers": payload.get("servers", []),
        "secrets": payload.get("secrets", {}),
    }
