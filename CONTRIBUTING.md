# Contributing

Follow [community standards](https://github.com/SyntraChat/.github/blob/main/CONTRIBUTING.md).
Run cargo fmt --check, cargo clippy --all-targets -- -D warnings and cargo test.
Every installation mutation needs failure/recovery tests. Never introduce unrestricted
recursive deletion, unsigned downloads, shell scripts or private release keys.
