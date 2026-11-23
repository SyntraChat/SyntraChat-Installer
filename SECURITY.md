# Security

Follow [private reporting](https://github.com/SyntraChat/.github/blob/main/SECURITY.md).
Verification is the only implemented lifecycle operation. There is no production public
trust key. Do not use deterministic test signing keys for releases. Authenticity, replay,
rollback and filesystem ownership are separate boundaries and must each be tested before
installation or automatic updates are shipped.
