/*
  Check interface:

    import ./tests/repo-clones-provisioning.nix { pkgs, inputs }

  Boots a client with modules/nixos/services/repo-clones.nix and a fake
  sops-encrypted repository list, next to an HTTPS git server serving bare
  repositories over git's dumb HTTP protocol with a test CA the client trusts.
  The client's specialisations differ only in the encrypted list, so a switch
  between them proves the clone unit runs when nothing but the secret changed.
  The real ghq and git from the packaged helper do the cloning.
*/
{ pkgs, inputs }:
let
  inherit (pkgs) lib;
  host = "gitserver";

  certs = pkgs.runCommand "repo-clones-test-certs" { nativeBuildInputs = [ pkgs.openssl ]; } ''
    mkdir -p $out
    openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -subj /CN=repo-clones-test-ca \
      -keyout ca.key -out $out/ca.pem
    openssl req -newkey rsa:2048 -nodes -subj /CN=${host} \
      -keyout $out/server.key -out server.csr
    printf 'subjectAltName=DNS:${host}\n' > san.ext
    openssl x509 -req -in server.csr -CA $out/ca.pem -CAkey ca.key -CAcreateserial \
      -days 3650 -extfile san.ext -out $out/server.pem
  '';

  # Bare repositories under owner/ and group/sub/. update-server-info makes
  # them clonable from a static web root, and HEAD is pinned so a clone checks
  # out main without relying on init.defaultBranch.
  repos = pkgs.runCommand "repo-clones-test-repos" { nativeBuildInputs = [ pkgs.git ]; } ''
    export HOME=$TMPDIR
    git config --global user.email t@example.invalid
    git config --global user.name Test
    git config --global commit.gpgsign false
    mkdir -p $out
    make() {
      local path=$1 work=$TMPDIR/work/$1
      git init -q -b main "$work"
      printf '%s\n' "$path" > "$work/README"
      git -C "$work" add README
      if [ "$path" = owner/withsub ]; then
        # A gitlink to an ssh:// submodule: cloning recursively would need ssh.
        printf '[submodule "sub"]\n\tpath = sub\n\turl = ssh://${host}/owner/sub.git\n' > "$work/.gitmodules"
        git -C "$work" add .gitmodules
        git -C "$work" update-index --add --cacheinfo 160000,0123456789abcdef0123456789abcdef01234567,sub
      fi
      git -C "$work" commit -qm init
      git init -q --bare "$out/$path.git"
      git -C "$out/$path.git" symbolic-ref HEAD refs/heads/main
      git -C "$work" push -q "$out/$path.git" main
      git -C "$out/$path.git" update-server-info
    }
    for path in owner/alpha owner/beta owner/delta owner/epsilon owner/withsub group/sub/gamma; do
      make "$path"
    done
  '';

  fixtures =
    pkgs.runCommand "repo-clones-test-lists"
      {
        nativeBuildInputs = [
          pkgs.age
          pkgs.sops
        ];
      }
      ''
        mkdir -p $out
        age-keygen -o $out/key.txt
        recipient=$(age-keygen -y $out/key.txt)
        encrypt() {
          local name=$1
          shift
          {
            printf 'repos: |\n'
            printf '  %s\n' "$@"
          } > $name.plain.yaml
          sops --encrypt --age "$recipient" --input-type yaml --output-type yaml \
            $name.plain.yaml > $out/$name.yaml
        }
        base=(
          "# fixture list"
          https://${host}/owner/alpha.git
          https://${host}/owner/missing.git
          https://${host}/group/sub/gamma.git
          https://${host}/owner/withsub.git
        )
        encrypt base "''${base[@]}"
        encrypt more "''${base[@]}" https://${host}/owner/beta.git https://${host}/owner/delta.git
        encrypt most "''${base[@]}" https://${host}/owner/beta.git https://${host}/owner/delta.git \
          https://${host}/owner/epsilon.git
      '';

  client =
    { ... }:
    {
      imports = [
        inputs.sops-nix.nixosModules.sops
        ../modules/nixos/system/secrets.nix
        ../modules/nixos/services/repo-clones.nix
      ];
      system.switch.enable = true;
      boot.loader.grub.enable = lib.mkForce false;
      users.users.h82.isNormalUser = true;
      security.pki.certificateFiles = [ "${certs}/ca.pem" ];
      my.repoClones.enable = true;
      # Deliberately public fake key. Production never embeds a real key in the store.
      system.activationScripts.fixture = ''
        install -d -m 0700 /var/lib/sops-nix
        if [ ! -e /var/lib/sops-nix/fixture-initialized ]; then
          install -m 0600 ${fixtures}/key.txt /var/lib/sops-nix/key.txt
          touch /var/lib/sops-nix/fixture-initialized
        fi
      '';
    };
in
pkgs.testers.nixosTest {
  name = "repo-clones";

  nodes.${host} =
    { ... }:
    {
      networking.firewall.allowedTCPPorts = [ 443 ];
      services.nginx = {
        enable = true;
        virtualHosts.${host} = {
          onlySSL = true;
          sslCertificate = "${certs}/server.pem";
          sslCertificateKey = "${certs}/server.key";
          root = repos;
        };
      };
    };

  nodes.machine =
    { ... }:
    {
      imports = [ client ];
      my.repoClones.sopsFile = "${fixtures}/base.yaml";
      specialisation.more.configuration.my.repoClones.sopsFile = lib.mkForce "${fixtures}/more.yaml";
      specialisation.most.configuration.my.repoClones.sopsFile = lib.mkForce "${fixtures}/most.yaml";
    };

  nodes.nolist =
    { ... }:
    {
      imports = [ client ];
      my.repoClones.sopsFile = null;
    };

  testScript =
    { nodes, ... }:
    let
      base = "${nodes.machine.system.build.toplevel}";
    in
    ''
      src = "/home/h82/src/${host}"
      base = "${base}"
      more = base + "/specialisation/more"
      most = base + "/specialisation/most"

      def invocation():
          return machine.succeed("systemctl show -p InvocationID --value repo-clones.service").strip()

      def switch_and_wait(toplevel):
          before = invocation()
          machine.succeed(toplevel + "/bin/switch-to-configuration switch")
          machine.wait_until_succeeds(
              f"test \"$(systemctl show -p InvocationID --value repo-clones.service)\" != '{before}'"
              " && systemctl show -p ActiveState --value repo-clones.service | grep -qx inactive"
          )
          result = machine.succeed("systemctl show -p Result --value repo-clones.service").strip()
          assert result == "success", f"repo-clones.service result is {result}"

      ${host}.start()
      ${host}.wait_for_unit("nginx.service")
      ${host}.wait_for_open_port(443)

      with subtest("the missing-list host installs the command but no unit"):
          nolist.start()
          nolist.wait_for_unit("multi-user.target")
          nolist.succeed("test -x /run/current-system/sw/bin/repo-clones")
          nolist.fail("systemctl cat repo-clones.service")
          nolist.succeed("/run/current-system/bin/switch-to-configuration switch")

      machine.start()
      machine.wait_for_unit("multi-user.target")

      with subtest("the decrypted list is readable by h82"):
          machine.succeed("runuser -u h82 -- cat /run/secrets/repo-clones/list | grep -q owner/alpha")

      with subtest("boot clones the declared repositories"):
          machine.wait_until_succeeds(f"test -f {src}/owner/alpha/README", timeout=120)
          machine.wait_until_succeeds(
              "systemctl show -p ActiveState --value repo-clones.service | grep -qx inactive"
          )
          machine.succeed(f"test -f {src}/group/sub/gamma/README")
          machine.succeed(f"test $(stat -c %U {src}/owner/alpha) = h82")
          machine.succeed(f"test \"$(runuser -u h82 -- ${pkgs.git}/bin/git -C {src}/owner/alpha remote get-url origin)\" = https://${host}/owner/alpha.git")
          machine.fail(f"test -e {src}/owner/missing")
          machine.succeed("systemctl show -p Result --value repo-clones.service | grep -qx success")

      with subtest("submodules are not fetched"):
          machine.succeed(f"test -f {src}/owner/withsub/README")
          machine.succeed(f"test -z \"$(ls -A {src}/owner/withsub/sub 2>/dev/null)\"")

      with subtest("an unreachable server fails entries without failing the switch"):
          machine.succeed(f"runuser -u h82 -- mkdir -p {src}/owner/beta")
          machine.succeed(f"runuser -u h82 -- sh -c 'echo local > {src}/owner/beta/keep'")
          ${host}.succeed("systemctl stop nginx.service")
          switch_and_wait(more)
          machine.fail(f"test -e {src}/owner/delta")

      with subtest("an existing target is left untouched"):
          machine.succeed(f"test \"$(cat {src}/owner/beta/keep)\" = local")
          machine.fail(f"test -e {src}/owner/beta/README")

      with subtest("the manual command retries the failed entry"):
          ${host}.succeed("systemctl start nginx.service")
          ${host}.wait_for_open_port(443)
          machine.succeed("runuser -u h82 -- repo-clones /run/secrets/repo-clones/list")
          machine.succeed(f"test -f {src}/owner/delta/README")

      with subtest("a switch that only changes the list clones the new entry"):
          switch_and_wait(most)
          machine.succeed(f"test -f {src}/owner/epsilon/README")

      with subtest("an unchanged switch runs the unit again"):
          machine.succeed(f"rm -rf {src}/owner/epsilon")
          switch_and_wait(most)
          machine.succeed(f"test -f {src}/owner/epsilon/README")

      with subtest("removing entries never deletes clones"):
          switch_and_wait(base)
          machine.succeed(f"test -f {src}/owner/delta/README")
          machine.succeed(f"test -f {src}/owner/epsilon/README")

      with subtest("the repository list never reaches the store in plaintext"):
          leaked = machine.execute(
              "nix-store -qR /run/current-system | xargs grep -rl '${host}/owner/alpha' 2>/dev/null || true"
          )[1]
          assert leaked.strip() == "", "repository URL leaked into the system closure: " + leaked
    '';
}
