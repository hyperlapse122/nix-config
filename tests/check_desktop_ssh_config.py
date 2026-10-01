"""Inspect public source metadata and the files Home Manager/systemd materialize."""
import argparse
import json
from pathlib import Path
import re
import sys

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey
import yaml


def sources(root):
    errors = []
    seen = set()
    rules = yaml.safe_load((root / ".sops.yaml").read_text())["creation_rules"]
    for directory in sorted((root / "hosts").iterdir()):
        if not directory.is_dir() or (directory / "host.nix").exists():
            continue
        relative = f"secrets/hosts/{directory.name}/ssh.yaml"
        try:
            recipient = (root / "secrets/bootstrap" / directory.name / "recipient.txt").read_text().strip()
            document = yaml.safe_load((root / relative).read_text())
            if set(document) != {"ssh_private_key", "sops"}:
                errors.append(f"{directory.name}: unexpected source fields")
            if not isinstance(document.get("ssh_private_key"), str) or not document["ssh_private_key"].startswith("ENC[AES256_GCM,"):
                errors.append(f"{directory.name}: missing SSH ciphertext")
            metadata = document.get("sops", {})
            if [item.get("recipient") for item in metadata.get("age", [])] != [recipient]:
                errors.append(f"{directory.name}: wrong recipient")
            if any(metadata.get(provider) for provider in ("pgp", "kms", "gcp_kms", "azure_kv", "hc_vault", "key_groups")):
                errors.append(f"{directory.name}: additional SOPS provider")
            matching = [rule for rule in rules if re.search(rule["path_regex"], relative)]
            if not matching or matching[0].get("age") != recipient:
                errors.append(f"{directory.name}: wrong creation-rule recipient")
            if matching and any(matching[0].get(provider) for provider in ("pgp", "kms", "gcp_kms", "azure_kv", "hc_vault", "key_groups")):
                errors.append(f"{directory.name}: additional creation-rule provider")
            public = (root / "secrets/hosts" / directory.name / "ssh.pub").read_bytes()
            key = serialization.load_ssh_public_key(public)
            if not isinstance(key, Ed25519PublicKey):
                errors.append(f"{directory.name}: public key is not Ed25519")
            canonical = key.public_bytes(serialization.Encoding.OpenSSH, serialization.PublicFormat.OpenSSH)
            if canonical in seen:
                errors.append(f"{directory.name}: duplicate public key")
            seen.add(canonical)
        except (OSError, ValueError, KeyError, TypeError, yaml.YAMLError) as error:
            errors.append(f"{directory.name}: missing or invalid source metadata ({type(error).__name__})")
    if not seen:
        errors.append("no headed SSH sources covered")
    return errors


def configuration(entry):
    errors = []
    def require(condition, message):
        if not condition:
            errors.append(f"{entry['name']}: {message}")
    files = Path(entry["files"]) if entry["files"] else None
    config_path = files / ".ssh/config" if files else Path("/absent-home-files")
    require(config_path.is_file(), "missing materialized SSH configuration")
    text = config_path.read_text() if config_path.is_file() else ""
    if entry["kind"] == "nixos":
        fallback_config = files / ".config/1Password/ssh/agent.toml" if files else Path("/absent-fallback-config")
        require(fallback_config.is_file() and fallback_config.read_text() == entry["fallbackConfig"], "1Password key selection changed")
    headed = entry["kind"] == "nixos" and not entry["bootstrap"]
    agent_path = files / ".config/systemd/user/desktop-ssh-agent.service" if files else Path("/absent-agent")
    json_path = files / ".config/desktop-ssh/config.json" if files else Path("/absent-config")
    system_path = Path(entry["systemUnit"]) / "desktop-ssh-provision.service" if entry["systemUnit"] else Path("/absent-system-unit")
    if not headed:
        require(not agent_path.exists() and not agent_path.is_symlink(), "bootstrap/non-NixOS session unit leaked")
        require(not json_path.exists(), "bootstrap/non-NixOS desktop config leaked")
        require(not system_path.exists() and not system_path.is_symlink(), "bootstrap provisioning unit leaked")
        if entry["kind"] == "nixos":
            require("IdentityAgent ~/.1password/agent.sock" in text, "bootstrap lost legacy agent")
        else:
            require(f"IdentityFile {entry['legacyKey']}" in text, "non-NixOS SSH path changed")
        return errors
    require("IdentityAgent /run/user/%i/desktop-ssh/agent.sock" in text, "incorrect primary IdentityAgent")
    require("IdentityFile /nix/store/" in text, "missing declared public identity")
    require(json_path.is_file(), "missing desktop configuration")
    if json_path.is_file():
        try:
            config = json.loads(json_path.read_text())
            require(config.get("key_file") == entry["home"] + "/.ssh/id_ed25519_nix_config", "incorrect working key")
            require(config.get("fallback_socket") == entry["home"] + "/.1password/agent.sock", "incorrect fallback socket")
            require(Path(config.get("public_key", "")).is_file(), "missing public metadata")
        except (ValueError, TypeError):
            require(False, "invalid desktop configuration")
    for tool in ("ssh", "scp", "sftp"):
        executable = Path(entry["path"]) / "bin" / tool if entry["path"] else Path("/absent-tool")
        require(executable.is_file() and executable.resolve() == Path(entry["package"]) / "bin/desktop-ssh", f"{tool} does not select packaged launcher")
    require(agent_path.is_file(), "missing or masked primary service")
    if agent_path.is_file():
        unit = agent_path.read_text()
        for fragment in ("BindsTo=graphical-session.target", "PartOf=graphical-session.target", "After=graphical-session.target", "RuntimeDirectory=desktop-ssh", "RuntimeDirectoryMode=0700", "LimitCORE=0", "KillMode=control-group", "ExecCondition=", "ExecStopPost="):
            require(fragment in unit, "primary unit missing " + fragment)
        require(re.search(r"^ExecStart=.*?/bin/desktop-ssh[ '\"]+agent(?: |['\"])", unit, re.M), "primary unit does not run packaged agent")
        wanted = agent_path.parent / "graphical-session.target.wants/desktop-ssh-agent.service"
        require(wanted.is_symlink() and wanted.resolve() == agent_path.resolve(), "primary service missing graphical target installation")
    require(not (agent_path.parent / "desktop-ssh-agent.socket").exists(), "unexpected socket activation")
    require(system_path.is_file(), "missing or masked provisioning service")
    if system_path.is_file():
        unit = system_path.read_text()
        for fragment in ("User=" + entry["user"], "LoadCredential=", "%d/source", "LimitCORE=0"):
            require(fragment in unit, "provisioning unit missing " + fragment)
        require(re.search(r"^ExecStart=.*?/bin/desktop-ssh[ '\"]+provision(?: |['\"])", unit, re.M), "provisioning unit does not run packaged provisioner")
        installed_targets = list(system_path.parent.glob("*.wants/desktop-ssh-provision.service"))
        installed_targets += list(system_path.parent.glob("*.requires/desktop-ssh-provision.service"))
        require(not installed_targets, "provisioning attempts boot-time wallet access through target installation")
    return errors


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--entries", type=Path)
    args = parser.parse_args()
    failures = sources(args.root)
    if args.entries is not None:
        for entry in json.loads(args.entries.read_text()):
            failures.extend(configuration(entry))
    if failures:
        print("\n".join("desktop-ssh: " + failure for failure in failures), file=sys.stderr)
        sys.exit(1)
