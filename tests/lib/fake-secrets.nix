/*
  Fake secrets for the non-NixOS fixture hosts, generated at build time. Every
  value here is deliberately public test material; production never embeds a
  real key or token in the store.

    fakeSecrets = import ./lib/fake-secrets.nix { inherit pkgs; };

  Outputs:
  - key.txt: the fixture's age identity; tokens.yaml and ssh.yaml are
    encrypted to it alone.
  - other-key.txt: a valid age identity that is not a recipient of either file.
  - recipient.txt: the public recipient of key.txt.
  - tokens.yaml: the token schema from secrets/README.md. The Tokscale token
    carries a space and the canary FAKE-CANARY, so a publisher that starts
    reading it fails, and any log that prints a token is caught.
  - ssh.yaml: `ssh_private_key`, a fresh ed25519 key; ssh.pub is its public
    half, for asserting what was published.
*/
{ pkgs }:
pkgs.runCommand "fake-non-nixos-secrets"
  {
    nativeBuildInputs = [
      pkgs.age
      pkgs.sops
      pkgs.openssh
      pkgs.yq-go
    ];
  }
  ''
    mkdir -p $out
    age-keygen -o $out/key.txt 2>/dev/null
    age-keygen -o $out/other-key.txt 2>/dev/null
    recipient=$(age-keygen -y $out/key.txt)
    printf '%s\n' "$recipient" > $out/recipient.txt

    printf 'github_token: FAKE-CANARY-github\ngitlab_token: FAKE-CANARY-gitlab\njpi_token: FAKE-CANARY-jpi\ntokscale_token: FAKE-CANARY tokscale\n' > tokens.yaml
    sops --encrypt --age "$recipient" --input-type yaml --output-type yaml tokens.yaml > $out/tokens.yaml

    ssh-keygen -q -t ed25519 -N "" -C fake-non-nixos-host -f ssh_key
    cp ssh_key.pub $out/ssh.pub
    key="$(cat ssh_key)" yq -n '.ssh_private_key = strenv(key) + "\n"' > ssh.yaml
    sops --encrypt --age "$recipient" --input-type yaml --output-type yaml ssh.yaml > $out/ssh.yaml

    # Failure fixtures: the same SSH key encrypted to the other identity only,
    # tokens whose github_token publish-cli-auth rejects, and an SSH key field
    # that is not a private key.
    other=$(age-keygen -y $out/other-key.txt)
    sops --encrypt --age "$other" --input-type yaml --output-type yaml ssh.yaml > $out/ssh-other.yaml
    printf 'github_token: FAKE-CANARY has spaces\ngitlab_token: FAKE-CANARY-gitlab\njpi_token: FAKE-CANARY-jpi\ntokscale_token: FAKE-CANARY tokscale\n' > bad-tokens.yaml
    sops --encrypt --age "$recipient" --input-type yaml --output-type yaml bad-tokens.yaml > $out/tokens-invalid.yaml
    printf 'ssh_private_key: not a key\n' > bad-ssh.yaml
    sops --encrypt --age "$recipient" --input-type yaml --output-type yaml bad-ssh.yaml > $out/ssh-invalid.yaml
  ''
