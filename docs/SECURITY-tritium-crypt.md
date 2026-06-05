# SECURITY -- tritium-crypt

Tritium Team v4.1 encrypted vault specification.
Author: Rook (QA/Release Engineer)

---

## 1. Threat model

The vault protects plaintext payloads at rest on Android shared storage,
where POSIX permissions are unreliable (setgid group, no per-file ACLs).
Goals: confidentiality, integrity, authenticity. Non-goal: hiding that
encrypted blobs exist.

## 2. Algorithms

| Purpose          | Algorithm                                | Parameters          |
|------------------|------------------------------------------|---------------------|
| Bulk encryption  | AES-256-GCM                              | 96-bit nonce, 128-bit tag |
| Key wrap         | X25519 ECDH + HKDF-SHA-256 -> AES-256-GCM | salt=nonce_kek, info="tritium-crypt v1" |
| Signing          | Ed25519                                  | over sorted-key JSON digest |

Nonces are generated via `os.urandom(12)`. Never reuse nonces.

## 3. Key management

Keys live at `~/.tritium-team/keys/` (outside the repo, never staged):

- `id.ed25519`    -- raw 32-byte Ed25519 seed. Used for signing manifests.
- `wrap.x25519`   -- raw 32-byte X25519 private key. Used for KEK derivation.

These are SEPARATE keys. Do not convert Ed25519 to X25519 (different curves).

Generate with: `tritium-crypt init-keys`

Key rotation: generate new keys, re-seal all payloads with the new keys,
then delete the old key files. No automated rotation is implemented in v4.1.

## 4. Seal / Open / Close lifecycle

```
Seal:
  1. Generate K_p = os.urandom(32), nonce_p = os.urandom(12)
  2. ct = AES-256-GCM(K_p, nonce_p).encrypt(plaintext)
  3. Derive KEK via X25519 self-exchange + HKDF
  4. wrapped_key = AES-256-GCM(KEK, nonce_wrap).encrypt(K_p)
  5. Sign manifest entry with Ed25519
  6. Write ct to world/vault/<id>.enc
  7. Update world/vault/manifest.json

Open:
  1. Verify Ed25519 signature on manifest entry
  2. Verify SHA-256(ct) == ct_hash
  3. Derive KEK, unwrap K_p
  4. Decrypt ct -> plaintext
  5. Write plaintext to .tritium_mirror/<id>/payload
  6. Update manifest status = "open"

Close:
  1. Read from .tritium_mirror/<id>/payload
  2. Re-seal (new K_p, new nonces) -> new ct
  3. Shred mirror: 3-pass random overwrite, unlink
  4. Update manifest status = "sealed"
```

## 5. Gitignore boundary

The following MUST be in .gitignore and never staged:

```
.tritium_mirror/
world/vault/*.plain
**/*.x25519
**/*.ed25519
**/*.pem
**/*.key
~/.tritium-team/
```

## 6. Dependency

Python `cryptography` package (PyCA). Must be installed.
`tritium-crypt` will exit 1 with a clear error if not present.
Never silently degrade to a weaker algorithm.

## 7. Diagnostics (tritium-doctor checks)

1. Agent files present
2. Scout availability (python3 on PATH)
3. data/registry/models.json valid JSON
4. world/vault/manifest.json valid JSON
5. No open mirror payloads (warn on open)
6. `cryptography` importable
7. Ed25519 and X25519 keys present
8. .tritium_mirror not tracked by git
9. shield.ok freshness (< 24h)
10. ledger.db accessible (warn if absent)
11. tier-auto script present

## 8. Threat notes

- Android shared storage does not enforce file permissions.
  All security relies on the cryptographic layer.
- Do not store plaintext adjacent to ciphertext.
- Do not log plaintext content in ledger events.
- Mirror directory (.tritium_mirror/) is ephemeral and gitignored.
  Never run `git add .` -- always specify paths explicitly.
