/*
  Check interface:

    import ./tests/linux-host-secrets.nix { inherit pkgs self; }

  Runs tests/linux-host-secrets.sh over the repository, then over fixture
  trees built here with fake keys, so the rules it enforces are proven to
  fail when broken even while hosts/ holds no non-NixOS host:

  - a well-formed tree passes;
  - a host SSH file encrypted to a second recipient fails;
  - a host recipient missing from the tokens.yaml rule fails;
  - a host recipient added to the wifi.yaml rule fails.
*/
{ pkgs, self }:
pkgs.runCommand "linux-host-secrets-tests"
  {
    nativeBuildInputs = [
      pkgs.age
      pkgs.sops
      pkgs.yq-go
      pkgs.gnugrep
      pkgs.gnused
    ];
  }
  ''
    check=${./linux-host-secrets.sh}

    bash "$check" ${self}

    age-keygen -o host.key 2>/dev/null
    age-keygen -o nixos.key 2>/dev/null
    host=$(age-keygen -y host.key)
    nixos=$(age-keygen -y nixos.key)

    # A tree with one non-NixOS host, plus the single mutation named by $1.
    make_tree() {
      local tree=$TMPDIR/tree-$1
      mkdir -p "$tree/hosts/fakehost" "$tree/secrets/bootstrap/fakehost" "$tree/secrets/hosts/fakehost"
      printf '{ kind = "linux"; system = "x86_64-linux"; }\n' >"$tree/hosts/fakehost/host.nix"
      printf '%s\n' "$host" >"$tree/secrets/bootstrap/fakehost/recipient.txt"
      local tokens="$nixos,$host" wifi=$nixos ssh_recipients=$host
      case $1 in
        second-recipient) ssh_recipients="$host,$nixos" ;;
        not-in-tokens) tokens=$nixos ;;
        in-wifi) wifi="$nixos,$host" ;;
      esac
      printf 'creation_rules:\n  - path_regex: secrets/tokens\\.yaml$\n    age: %s\n  - path_regex: secrets/wifi\\.yaml$\n    age: %s\n  - path_regex: secrets/tailscale\\.yaml$\n    age: %s\n' \
        "$tokens" "$wifi" "$nixos" >"$tree/.sops.yaml"
      printf 'ssh_private_key: fake\n' >plain.yaml
      sops --encrypt --age "$ssh_recipients" --input-type yaml --output-type yaml plain.yaml \
        >"$tree/secrets/hosts/fakehost/ssh.yaml"
      printf '%s\n' "$tree"
    }

    bash "$check" "$(make_tree valid)" || { echo 'a well-formed tree failed' >&2; exit 1; }

    for mutation in second-recipient not-in-tokens in-wifi; do
      if bash "$check" "$(make_tree "$mutation")" 2>err; then
        echo "linux-host-secrets passed a tree with mutation $mutation" >&2
        exit 1
      fi
      cat err
    done

    touch $out
  ''
