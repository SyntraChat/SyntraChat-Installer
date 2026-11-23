use std::{fs::File, io::Read, path::Path, process::ExitCode};
use syntrachat_installer::{verify_artifact, verify_manifest};

fn read_bounded(path: &str, cap: u64) -> Result<Vec<u8>, Box<dyn std::error::Error>> {
    let mut bytes = Vec::new();
    File::open(path)?.take(cap + 1).read_to_end(&mut bytes)?;
    if bytes.len() as u64 > cap {
        return Err("Input exceeds size limit".into());
    }
    Ok(bytes)
}

fn run() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<_> = std::env::args().skip(1).collect();
    if args.is_empty() || args == ["--help"] {
        println!(
            "SyntraChat installer verification preview\n\nverify <manifest.json> <manifest.sig> <artifact> <target> <channel> <installed-version>\n\nVerifies only. Installation, download and uninstall are not yet available.\nBuild with SYNTRACHAT_RELEASE_PUBLIC_KEY_HEX set to your trusted Ed25519 public key."
        );
        return Ok(());
    }
    if args.len() != 7 || args[0] != "verify" {
        return Err("Invalid arguments; use --help".into());
    }
    let raw_key = option_env!("SYNTRACHAT_RELEASE_PUBLIC_KEY_HEX")
        .ok_or("No release trust key embedded at build time; verification is disabled")?;
    let key: [u8; 32] = hex::decode(raw_key)?
        .try_into()
        .map_err(|_| "Public key must be 32 bytes")?;
    let bytes = read_bounded(&args[1], 64 * 1024)?;
    let signature = read_bounded(&args[2], 64)?;
    let manifest = verify_manifest(&bytes, &signature, &key, &args[4], &args[5], &args[6])?;
    if Path::new(&args[3]).file_name().and_then(|s| s.to_str()) != Some(&manifest.artifact) {
        return Err("Artifact filename differs from signed manifest".into());
    }
    verify_artifact(File::open(&args[3])?, &manifest)?;
    println!(
        "Verified SyntraChat {} for {} ({}). No files installed.",
        manifest.version, manifest.target, manifest.channel
    );
    Ok(())
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("Verification failed: {error}");
            ExitCode::FAILURE
        }
    }
}
