# Encrypted migration material

This directory is deliberately empty of plaintext credentials.  The machine
age identity and the service tokens are created during migration, encrypted
before they enter this repository, and are only decrypted on the target
machine.  Do not add an age private key, GPG private key, PIN, or token in
plain text.

`recipient.txt` is intentionally absent until the target machine's dedicated
age identity has been generated.  When preparing the migration, create it in
a private temporary directory and copy only its single public `age1...`
recipient here.  Add the same recipient to `.sops.yaml`:

```yaml
creation_rules:
  - path_regex: secrets/tokens\.yaml$
    age: age1REPLACE_WITH_THE_GENERATED_RECIPIENT
```

The placeholder above is documentation only and must not be committed as a
rule.  The repository has no production recipient until the migration operator
replaces it with the generated value.

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
decrypted output.  The bootstrap age identity belongs at
`secrets/bootstrap/thinkpad-age-key.asc`, encrypted with the public OpenPGP
encryption subkey from `keys/signing.asc`.  That file is also absent until the
operator has a real card and has verified a decrypt before installing NixOS.

To restore the identity after installation, decrypt as the normal user and
cross sudo exactly once into the fixed root installer:

```sh
gpg --batch --no-tty --decrypt -- secrets/bootstrap/thinkpad-age-key.asc \
  | sudo -- /run/current-system/sw/bin/restore-age-identity \
      --recipient "$(cat secrets/recipient.txt)"
```

GPG runs as the invoking user and uses that user's `gpg-agent` and card
pinentry. The fixed root installer accepts only stdin and the public
`--recipient` argument. It validates the derived age recipient before it
atomically replaces `/var/lib/sops-nix/key.txt` (root:root, mode 0600). The
temporary plaintext exists only briefly on the encrypted runtime filesystem;
it is never put in the Nix store, argv, or logs. The recipient is public, so
passing it as an argument is safe; the age identity itself remains on stdin.
