# Encrypted migration material

This directory is deliberately empty of plaintext credentials.  The machine
age identity and the service tokens are created during migration, encrypted
before they enter this repository, and are only decrypted on the target
machine.  Do not add an age private key, GPG private key, PIN, or token in
plain text.

Bootstrap material is scoped per host under
`secrets/bootstrap/<hostname>/`, which holds `age-key.asc` (the age identity
encrypted to the OpenPGP card's encryption subkey) and `recipient.txt` (that
identity's single public `age1...` recipient).  `ThinkPad-X1-Carbon-Gen-11`
currently has both.  `scripts/prepare-age-identity` creates them for a new
host; do not write either file by hand.

`.sops.yaml` carries one creation rule per encrypted file, each listing every
recipient host that may decrypt it:

```yaml
creation_rules:
  - path_regex: secrets/tokens\.yaml$
    age: <comma-separated recipients of every host that shares this file>
  - path_regex: secrets/wifi\.yaml$
    age: <comma-separated recipients of every host that shares this file>
  - path_regex: secrets/tailscale\.yaml$
    age: <comma-separated recipients of every host that shares this file>
  - path_regex: secrets/repos\.yaml$
    age: <comma-separated recipients of every host that shares this file>
```

Only a host whose recipient appears in a file's rule can decrypt it.
`secrets/tokens.yaml`, `secrets/wifi.yaml`, `secrets/tailscale.yaml`, and
`secrets/repos.yaml` currently list both `ThinkPad-X1-Carbon-Gen-11`'s and
`MS-7D91`'s recipients, so either host can decrypt any of them. Adding a new host's bootstrap material does not by
itself give it access to an existing file: re-encrypt that file to the new
recipient first, or split the rule per host.

The encrypted token document (`secrets/tokens.yaml`) is a flat YAML mapping
with exactly these string fields (the service usernames are public
configuration and are not secret):

```yaml
github_token: <GitHub token>
gitlab_token: <GitLab.com token>
jpi_token: <git.jpi.app token>
```

The intended public accounts are `hyperlapse122` on GitHub and `hyperlapse` on
GitLab.com and `git.jpi.app`.

The encrypted Wi-Fi document (`secrets/wifi.yaml`) nests one SSID/PSK pair per
network label under a top-level `wifi` key (the label is an arbitrary local
name, never the literal SSID — see `modules/nixos/wifi.nix`), matching
sops-nix's `/`-separated key lookup (`sops.secrets."wifi/<label>/ssid"`):

```yaml
wifi:
  <label>:
    ssid: <network SSID>
    psk: <network passphrase>
```

The encrypted repository list (`secrets/repos.yaml`) holds one `repos` key
whose value is a block string with one HTTPS clone URL per line. Blank lines
and `#` comments are ignored. The whole list is encrypted because this
repository is public and the list names private repositories
(`modules/nixos/services/repo-clones.nix` decrypts it for `h82` only):

```yaml
repos: |
  https://github.com/<owner>/<repo>.git
  https://gitlab.com/<group>/<subgroup>/<repo>.git
```

Only `https://host/path` entries are cloned. Do not embed credentials in a
URL; `repo-clones` skips such an entry and authenticates through the
published gh/glab tokens instead.

Keep each encrypted document at its path above; do not pass SSID, PSK, or
token values as command arguments or print decrypted output when populating
any of them. Each host's bootstrap age identity is encrypted with the
public OpenPGP encryption subkey from `keys/signing.asc`.  Verify that it
decrypts with the real card before installing NixOS;
`scripts/prepare-age-identity` enforces that round trip as it writes the file
and refuses to keep a ciphertext it cannot open again.

To restore the identity after installation, run the recovery helper from the
clone.  It resolves the running host, or takes `--host NAME`:

```sh
./scripts/recover-age-identity
```

It runs exactly the pipeline below with the paths resolved for that host,
decrypting as the normal user and crossing sudo exactly once into the fixed
root installer:

```sh
gpg --batch --no-tty --decrypt -- secrets/bootstrap/<hostname>/age-key.asc \
  | sudo -- /run/current-system/sw/bin/restore-age-identity \
      --recipient "$(cat secrets/bootstrap/<hostname>/recipient.txt)"
```

The helper refuses to run as root, because GPG has to reach the invoking
user's own agent and card pinentry.

GPG runs as the invoking user and uses that user's `gpg-agent` and card
pinentry. The fixed root installer accepts only stdin and the public
`--recipient` argument. It validates the derived age recipient before it
atomically replaces `/var/lib/sops-nix/key.txt` (root:root, mode 0600). The
temporary plaintext exists only briefly on the encrypted runtime filesystem;
it is never put in the Nix store, argv, or logs. The recipient is public, so
passing it as an argument is safe; the age identity itself remains on stdin.
