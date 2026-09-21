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

`.sops.yaml` carries one creation rule with one recipient:

```yaml
creation_rules:
  - path_regex: secrets/tokens\.yaml$
    age: <the recipient of the host that owns the identity>
```

That means only the host whose recipient appears there can decrypt
`secrets/tokens.yaml`.  Adding a second host's bootstrap material does not
give it access: `secrets/tokens.yaml` has to be re-encrypted to that host's
recipient first, or the rule split per host.  Per-host token files are not set
up today.

The encrypted token document is a flat YAML mapping with exactly these string
fields (the service usernames are public configuration and are not secret):

```yaml
github_token: <GitHub token>
gitlab_token: <GitLab.com token>
jpi_token: <git.jpi.app token>
```

The intended public accounts are `hyperlapse122` on GitHub and `hyperlapse` on
GitLab.com and `git.jpi.app`.  Keep the encrypted document at
`secrets/tokens.yaml`; do not pass token values as command arguments or print
decrypted output.  Each host's bootstrap age identity is encrypted with the
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
