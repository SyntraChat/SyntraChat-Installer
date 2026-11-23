//! Shared release contract v1. Verify exact bytes before parsing or using any paths.
use ed25519_dalek::{Signature, VerifyingKey};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::io::Read;

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("Release manifest signature is invalid")]
    Signature,
    #[error("Release metadata is invalid: {0}")]
    Metadata(String),
    #[error("Artifact size or SHA-256 does not match the signed manifest")]
    Integrity,
    #[error("I/O failed: {0}")]
    Io(#[from] std::io::Error),
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Manifest {
    pub schema: u32,
    pub application: String,
    pub version: String,
    pub channel: String,
    pub target: String,
    pub artifact: String,
    pub sha256: String,
    pub size: u64,
}

pub fn safe_artifact_name(name: &str) -> bool {
    if name.is_empty()
        || name.len() > 128
        || name == "."
        || name == ".."
        || name.starts_with('.')
        || name.ends_with('.')
        || !name
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b"-_.".contains(&b))
    {
        return false;
    }
    let stem = name
        .split('.')
        .next()
        .unwrap_or_default()
        .to_ascii_uppercase();
    ![
        "CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8",
        "COM9", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9",
    ]
    .contains(&stem.as_str())
}

pub fn verify_manifest(
    bytes: &[u8],
    signature: &[u8],
    key: &[u8; 32],
    target: &str,
    channel: &str,
    current: &str,
) -> Result<Manifest, Error> {
    if bytes.len() > 64 * 1024 {
        return Err(Error::Metadata("Manifest exceeds 64 KiB".into()));
    }
    let key = VerifyingKey::from_bytes(key).map_err(|_| Error::Signature)?;
    let signature = Signature::from_slice(signature).map_err(|_| Error::Signature)?;
    key.verify_strict(bytes, &signature)
        .map_err(|_| Error::Signature)?;
    let manifest: Manifest =
        serde_json::from_slice(bytes).map_err(|e| Error::Metadata(e.to_string()))?;
    let version =
        semver::Version::parse(&manifest.version).map_err(|e| Error::Metadata(e.to_string()))?;
    let current = semver::Version::parse(current).map_err(|e| Error::Metadata(e.to_string()))?;
    let digest = hex::decode(&manifest.sha256).map_err(|e| Error::Metadata(e.to_string()))?;
    if manifest.schema != 1
        || manifest.application != "org.syntrachat.desktop"
        || manifest.target != target
        || manifest.channel != channel
        || !["stable", "beta", "nightly"].contains(&channel)
        || (channel == "stable" && !version.pre.is_empty())
        || version < current
        || !safe_artifact_name(&manifest.artifact)
        || digest.len() != 32
        || manifest.size == 0
        || manifest.size > 2 * 1024 * 1024 * 1024
    {
        return Err(Error::Metadata(
            "Wrong schema, application, channel, target, version, artifact path, hash or size"
                .into(),
        ));
    }
    Ok(manifest)
}

/// Streams bytes with a signed size cap; never loads a whole release into memory.
pub fn verify_artifact(mut reader: impl Read, manifest: &Manifest) -> Result<(), Error> {
    let mut hash = Sha256::new();
    let mut total = 0u64;
    let mut buffer = [0u8; 64 * 1024];
    loop {
        let count = reader.read(&mut buffer)?;
        if count == 0 {
            break;
        }
        total = total.checked_add(count as u64).ok_or(Error::Integrity)?;
        if total > manifest.size {
            return Err(Error::Integrity);
        }
        hash.update(&buffer[..count]);
    }
    let actual = hex::encode(hash.finalize());
    if total != manifest.size || !actual.eq_ignore_ascii_case(&manifest.sha256) {
        return Err(Error::Integrity);
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use ed25519_dalek::{Signer, SigningKey};
    // Public test fixture only. Never use this deterministic key for distribution.
    fn fixture() -> (SigningKey, Vec<u8>, Vec<u8>) {
        let key = SigningKey::from_bytes(&[7; 32]);
        let artifact = b"test-only application bytes".to_vec();
        let manifest = Manifest {
            schema: 1,
            application: "org.syntrachat.desktop".into(),
            version: "0.1.0".into(),
            channel: "stable".into(),
            target: "x86_64-pc-windows-msvc".into(),
            artifact: "SyntraChat-0.1.0.exe".into(),
            sha256: hex::encode(Sha256::digest(&artifact)),
            size: artifact.len() as u64,
        };
        (key, serde_json::to_vec(&manifest).unwrap(), artifact)
    }
    fn verify(key: &SigningKey, bytes: &[u8]) -> Result<Manifest, Error> {
        verify_manifest(
            bytes,
            &key.sign(bytes).to_bytes(),
            &key.verifying_key().to_bytes(),
            "x86_64-pc-windows-msvc",
            "stable",
            "0.0.0",
        )
    }
    #[test]
    fn valid_signed_release_and_artifact() {
        let (key, bytes, artifact) = fixture();
        let manifest = verify(&key, &bytes).unwrap();
        verify_artifact(artifact.as_slice(), &manifest).unwrap();
    }
    #[test]
    fn tampered_manifest_rejected_before_parse() {
        let (key, mut bytes, _) = fixture();
        let signature = key.sign(&bytes).to_bytes();
        bytes[0] ^= 1;
        assert!(matches!(
            verify_manifest(
                &bytes,
                &signature,
                &key.verifying_key().to_bytes(),
                "x86_64-pc-windows-msvc",
                "stable",
                "0.0.0"
            ),
            Err(Error::Signature)
        ));
    }
    #[test]
    fn wrong_signer_and_truncated_signature_rejected() {
        let (key, bytes, _) = fixture();
        let wrong = SigningKey::from_bytes(&[8; 32]);
        for sig in [wrong.sign(&bytes).to_bytes().to_vec(), vec![0; 63]] {
            assert!(
                verify_manifest(
                    &bytes,
                    &sig,
                    &key.verifying_key().to_bytes(),
                    "x86_64-pc-windows-msvc",
                    "stable",
                    "0.0.0"
                )
                .is_err()
            );
        }
    }
    #[test]
    fn tampered_truncated_and_oversized_artifacts_rejected() {
        let (key, bytes, mut artifact) = fixture();
        let manifest = verify(&key, &bytes).unwrap();
        artifact[0] ^= 1;
        assert!(verify_artifact(artifact.as_slice(), &manifest).is_err());
        assert!(verify_artifact(&artifact[..3], &manifest).is_err());
        artifact.push(0);
        assert!(verify_artifact(artifact.as_slice(), &manifest).is_err());
    }
    #[test]
    fn traversal_windows_devices_and_stream_paths_rejected() {
        for path in [
            "../app.exe",
            "a/b",
            "a\\b",
            "C:app.exe",
            "app.exe:stream",
            "/tmp/app",
            "CON.exe",
            "lpt1",
            ".hidden",
            "a.",
            "a ",
            "",
            "é.exe",
        ] {
            assert!(!safe_artifact_name(path), "{path}");
        }
        assert!(safe_artifact_name("SyntraChat-0.1.0.exe"));
    }
    #[test]
    fn authentic_but_invalid_metadata_rejected() {
        let (key, bytes, _) = fixture();
        for (field, value) in [
            ("schema", serde_json::json!(2)),
            ("application", serde_json::json!("evil")),
            ("target", serde_json::json!("other")),
            ("channel", serde_json::json!("beta")),
            ("version", serde_json::json!("0.1.0-beta.1")),
            ("artifact", serde_json::json!("../escape")),
            ("size", serde_json::json!(0)),
            ("sha256", serde_json::json!("ff")),
        ] {
            let mut value_json: serde_json::Value = serde_json::from_slice(&bytes).unwrap();
            value_json[field] = value;
            assert!(
                verify(&key, &serde_json::to_vec(&value_json).unwrap()).is_err(),
                "{field}"
            );
        }
    }
    #[test]
    fn downgrade_rejected() {
        let (key, bytes, _) = fixture();
        assert!(
            verify_manifest(
                &bytes,
                &key.sign(&bytes).to_bytes(),
                &key.verifying_key().to_bytes(),
                "x86_64-pc-windows-msvc",
                "stable",
                "1.0.0"
            )
            .is_err()
        );
    }
}
