# world_vault -- Encrypted Payload Store

This directory holds ciphertext only. No plaintext. No key material.

## Contents

| File | Description |
|---|---|
| `manifest.json` | Payload index: IDs, algorithm, nonces, wrapped-key blobs, Ed25519 signatures. |
| `<id>.enc` | AES-256-GCM ciphertext blobs. Opaque filenames derived from payload IDs. |

## Rules

- Every file is `manifest.json` or a `*.enc`/`*.bin` ciphertext blob.
- No plaintext. No key material. No personal identifiers in cleartext.
- `.tritium_mirror/` (plaintext copies) is gitignored and never staged.

## Key operations

    tritium-crypt init          -- initialize manifest
    tritium-crypt status        -- vault and key status
    tritium-crypt list          -- list payloads
    tritium-crypt seal <id> <f> -- encrypt file into vault
    tritium-open <id>           -- decrypt to .tritium_mirror/ for editing
    tritium-close <id>          -- re-encrypt and shred mirror copy
    tritium-crypt verify        -- verify all signatures and hashes

## Cryptography

- Bulk: AES-256-GCM, 96-bit nonce per payload (os.urandom(12)).
- Key wrapping: ECDH(X25519) + HKDF-SHA-256 -> KEK -> AES-256-GCM wrap of payload key.
- Signing: Ed25519 over manifest entry (sorted-key JSON).
- Keys: ~/.tritium-team/keys/ -- hardware-bound, never committed.
- Requires Python cryptography package: pip install cryptography

## Security

See docs/SECURITY-tritium-crypt.md for full threat model and tritium-doctor checklist.
