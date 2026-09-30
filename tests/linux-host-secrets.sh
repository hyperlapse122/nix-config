#!/usr/bin/env bash
# Checks the secret layout of every non-NixOS host (a hosts/<host> directory
# with host.nix) in the tree at ROOT:
#
# - secrets/hosts/<host>/ssh.yaml exists and is encrypted to that host's
#   recorded recipient alone, read from the encrypted file itself: a rule in
#   .sops.yaml only applies when a file is created or re-keyed, so the file is
#   the authority on who can decrypt it.
# - the host's recipient is in the tokens.yaml rule and among the recipients
#   secrets/tokens.yaml is actually encrypted to, so production can decrypt
#   the tokens it publishes. The rule alone is not enough: a recipient added to
#   it without `sops updatekeys` passes the rule and fails at the first apply.
# - the recipient is in neither the rule nor the encrypted file of wifi.yaml
#   and tailscale.yaml, so a non-NixOS host, whose identity rests on the
#   distribution's disk encryption, never decrypts the Wi-Fi or Tailscale
#   material only NixOS hosts use.
#
# usage: linux-host-secrets.sh ROOT
set -euo pipefail

root=${1:?usage: linux-host-secrets.sh ROOT}
status=0

fail() {
  printf 'linux-host-secrets: %s\n' "$*" >&2
  status=1
}

# The comma-separated age recipients of the .sops.yaml rule whose path_regex
# names FILE.
rule_recipients() {
  yq -r ".creation_rules[] | select(.path_regex | test(\"$1\")) | .age" "$root/.sops.yaml" | tr ',' '\n' | sed '/^$/d'
}

# The age recipients secrets/NAME.yaml is encrypted to, read from the file;
# nothing when the file does not exist.
file_recipients() {
  local file=$root/secrets/$1.yaml
  [[ -f $file ]] || return 0
  yq -r '.sops.age[].recipient' "$file"
}

checked=0
for dir in "$root"/hosts/*/; do
  host=$(basename -- "$dir")
  [[ -f $dir/host.nix ]] || continue
  checked=$((checked + 1))

  recipient_file=$root/secrets/bootstrap/$host/recipient.txt
  if [[ ! -f $recipient_file ]]; then
    fail "$host: secrets/bootstrap/$host/recipient.txt is missing"
    continue
  fi
  recipient=$(tr -d '[:space:]' <"$recipient_file")

  ssh_file=$root/secrets/hosts/$host/ssh.yaml
  if [[ ! -f $ssh_file ]]; then
    fail "$host: secrets/hosts/$host/ssh.yaml is missing"
  else
    actual=$(yq -r '.sops.age[].recipient' "$ssh_file" | sort -u)
    if [[ $actual != "$recipient" ]]; then
      fail "$host: secrets/hosts/$host/ssh.yaml must be encrypted to this host's recipient alone, but lists: $(tr '\n' ' ' <<<"$actual")"
    fi
  fi

  if ! rule_recipients 'tokens' | grep -qxF -- "$recipient"; then
    fail "$host: its recipient is not in the tokens.yaml rule of .sops.yaml"
  fi
  if ! file_recipients tokens | grep -qxF -- "$recipient"; then
    fail "$host: secrets/tokens.yaml is not encrypted to its recipient; run sops updatekeys secrets/tokens.yaml"
  fi
  for other in wifi tailscale; do
    if rule_recipients "$other" | grep -qxF -- "$recipient"; then
      fail "$host: its recipient is in the $other.yaml rule of .sops.yaml; non-NixOS hosts must not decrypt it"
    fi
    if file_recipients "$other" | grep -qxF -- "$recipient"; then
      fail "$host: secrets/$other.yaml is encrypted to its recipient; non-NixOS hosts must not decrypt it"
    fi
  done
done

printf 'linux-host-secrets: checked %d non-NixOS host(s) under %s\n' "$checked" "$root"
exit "$status"
