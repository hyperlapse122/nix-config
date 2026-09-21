#!/usr/bin/env bash
set -euo pipefail

recover=${1:-}
prepare=${2:-}
if [[ $# -ne 2 || ! -f $recover || ! -f $prepare ]]; then
  printf 'usage: %s RECOVER_SCRIPT PREPARE_SCRIPT\n' "${0##*/}" >&2
  exit 2
fi

scratch=$(mktemp -d "${TMPDIR:-/tmp}/age-helpers.XXXXXX")
trap 'rm -rf -- "$scratch"' EXIT

fail() { printf 'age-identity-helpers: FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'age-identity-helpers: ok - %s\n' "$*"; }

# The helpers resolve their repository root from their own location, so give
# each a fake checkout rather than pointing them at the real secrets tree. No
# real key, card, sudo, or /var/lib is touched anywhere below.
fake_repo=$scratch/repo
mkdir -p "$fake_repo/scripts" "$fake_repo/secrets/bootstrap"
cp "$recover" "$fake_repo/scripts/recover-age-identity"
cp "$prepare" "$fake_repo/scripts/prepare-age-identity"
chmod +x "$fake_repo/scripts/"*
recover_bin=$fake_repo/scripts/recover-age-identity
prepare_bin=$fake_repo/scripts/prepare-age-identity

fake_recipient=age1faketestrecipientvaluenotarealkey000000000000000000000
host_dir=$fake_repo/secrets/bootstrap/testhost
mkdir -p "$host_dir"
printf 'not a real ciphertext\n' >"$host_dir/age-key.asc"
printf '%s\n' "$fake_recipient" >"$host_dir/recipient.txt"

# ---------------------------------------------------------------------------
# recover-age-identity
# ---------------------------------------------------------------------------

export RECOVER_AGE_DRY_RUN=1
export RECOVER_AGE_INSTALLER=/fake/restore-age-identity

out=$("$recover_bin" --host testhost)
[[ $out == gpg* ]] || fail "the pipeline does not start with gpg: $out"
[[ $out == *"--decrypt -- $host_dir/age-key.asc"* ]] ||
  fail "the resolved ciphertext path is wrong: $out"
[[ $out == *"| sudo -- /fake/restore-age-identity --recipient $fake_recipient"* ]] ||
  fail "sudo is not on the right-hand side with the resolved recipient: $out"
pass 'the emitted pipeline runs gpg as the user and crosses sudo once, on the right'

if "$recover_bin" --host nosuchhost >/dev/null 2>&1; then
  fail 'an unknown host should fail'
fi
err=$("$recover_bin" --host nosuchhost 2>&1 >/dev/null || true)
[[ $err == *testhost* ]] || fail "the failure does not list available hosts: $err"
[[ $err == *--host* ]] || fail "the failure does not name --host: $err"
pass 'an unknown host exits non-zero, lists the available hosts and names --host'

# In the rescue path the hostname is the installer image's, not a configuration
# name, so detection finds nothing and --host becomes mandatory.
err=$("$recover_bin" 2>&1 >/dev/null || true)
if [[ $err == *"no bootstrap material"* ]]; then
  [[ $err == *--host* ]] || fail "the rescue-path failure does not name --host: $err"
  pass 'an undetectable hostname fails and names --host'
else
  pass 'the running hostname happens to have material; rescue path covered by the unknown-host case'
fi

# ---------------------------------------------------------------------------
# prepare-age-identity
# ---------------------------------------------------------------------------

unset RECOVER_AGE_DRY_RUN RECOVER_AGE_INSTALLER

runtime=$scratch/runtime
mkdir -p "$runtime"
export PREPARE_AGE_RUNTIME_DIR=$runtime

stub_dir=$scratch/stubs
mkdir -p "$stub_dir"

# The Nix sandbox has no /usr/bin/env, so stubs get a resolved interpreter.
bash_bin=$(command -v bash) || fail 'bash is required'
stub() { printf '#!%s\n' "$bash_bin" >"$stub_dir/$1"; }

# A fake age-keygen: writes a deterministic "identity" and derives a recipient
# from it, so the round-trip comparison is meaningful without real crypto.
stub age-keygen
cat >>"$stub_dir/age-keygen" <<'STUB'
set -euo pipefail
if [[ ${1:-} == -o ]]; then
  printf 'FAKE-IDENTITY-%s\n' "${FAKE_IDENTITY_TAG:-default}" >"$2"
  exit 0
fi
if [[ ${1:-} == -y ]]; then
  printf 'age1fake%s\n' "$(tr -dc 'a-z0-9' <"$2" | tail -c 20)"
  exit 0
fi
exit 2
STUB
chmod +x "$stub_dir/age-keygen"

# A fake gpg. Encrypt base64-encodes and decrypt decodes, so the "ciphertext"
# is reversible without containing the plaintext -- a plain copy would make the
# no-plaintext-in-the-repository assertion below vacuous.
stub gpg-good
cat >>"$stub_dir/gpg-good" <<'STUB'
set -euo pipefail
out=; src=; mode=
while [[ $# -gt 0 ]]; do
  case $1 in
    --output) out=$2; shift 2 ;;
    --encrypt) mode=encrypt; shift ;;
    --decrypt) mode=decrypt; shift ;;
    --armor|--batch|--no-tty) shift ;;
    --recipient) shift 2 ;;
    *) src=$1; shift ;;
  esac
done
if [[ $mode == decrypt ]]; then
  base64 -d <"$src" >"$out"
else
  base64 <"$src" >"$out"
fi
STUB
chmod +x "$stub_dir/gpg-good"

# A fake gpg that encrypts to something that decrypts back to a different key.
stub gpg-corrupt
cat >>"$stub_dir/gpg-corrupt" <<'STUB'
set -euo pipefail
out=; src=; mode=
while [[ $# -gt 0 ]]; do
  case $1 in
    --output) out=$2; shift 2 ;;
    --encrypt) mode=encrypt; shift ;;
    --decrypt) mode=decrypt; shift ;;
    --armor|--batch|--no-tty) shift ;;
    --recipient) shift 2 ;;
    *) src=$1; shift ;;
  esac
done
if [[ $mode == decrypt ]]; then
  printf 'FAKE-IDENTITY-tampered\n' >"$out"
else
  base64 <"$src" >"$out"
fi
STUB
chmod +x "$stub_dir/gpg-corrupt"

export PREPARE_AGE_KEYGEN=$stub_dir/age-keygen

# Happy path
export PREPARE_AGE_GPG=$stub_dir/gpg-good
"$prepare_bin" --host newhost --recipient DEADBEEF >/dev/null
new_dir=$fake_repo/secrets/bootstrap/newhost
[[ -f $new_dir/age-key.asc ]] || fail 'the ciphertext was not written'
[[ -f $new_dir/recipient.txt ]] || fail 'the recipient was not recorded'
[[ -s $new_dir/recipient.txt ]] || fail 'the recorded recipient is empty'
pass 'a successful run writes both files under the per-host directory'

[[ -z $(ls -A "$runtime") ]] || fail "plaintext survived in $runtime: $(ls -A "$runtime")"
pass 'the runtime directory is left empty, so no plaintext survives'

if grep -rqF 'FAKE-IDENTITY' "$fake_repo/secrets"; then
  fail 'plaintext identity material was written into the repository'
fi
pass 'no plaintext identity material reaches the repository'

# Refuses to overwrite
if "$prepare_bin" --host newhost --recipient DEADBEEF >/dev/null 2>&1; then
  fail 'an existing host directory should not be overwritten'
fi
pass 'an existing host directory is refused rather than overwritten'

# Round-trip verification
export PREPARE_AGE_GPG=$stub_dir/gpg-corrupt
if "$prepare_bin" --host badhost --recipient DEADBEEF >/dev/null 2>&1; then
  fail 'a ciphertext that decrypts to a different identity should fail'
fi
bad_dir=$fake_repo/secrets/bootstrap/badhost
[[ ! -f $bad_dir/age-key.asc ]] || fail 'a failed round trip left the ciphertext behind'
[[ ! -f $bad_dir/recipient.txt ]] || fail 'a failed round trip left the recipient behind'
pass 'a ciphertext that does not decrypt back fails and leaves no files behind'

[[ -z $(ls -A "$runtime") ]] || fail 'the trap did not clean the runtime directory after failure'
pass 'the trap clears the runtime directory on the failure path too'

# ---------------------------------------------------------------------------
# root refusal
# ---------------------------------------------------------------------------

# Simulate an effective uid of 0 by shadowing id(1) on PATH.
real_id=$(command -v id) || fail 'id is required'
stub id
cat >>"$stub_dir/id" <<STUB
if [[ \${1:-} == -u ]]; then printf '0\n'; exit 0; fi
exec $real_id "\$@"
STUB
chmod +x "$stub_dir/id"

for bin in "$recover_bin" "$prepare_bin"; do
  name=${bin##*/}
  if PATH=$stub_dir:$PATH "$bin" --host testhost >/dev/null 2>&1; then
    fail "$name should refuse to run as root"
  fi
  err=$(PATH=$stub_dir:$PATH "$bin" --host testhost 2>&1 >/dev/null || true)
  [[ $err == *root* ]] || fail "$name refusal does not mention root: $err"
done
pass 'both helpers refuse to run as root, naming the boundary'

# ---------------------------------------------------------------------------
# no key material in output
# ---------------------------------------------------------------------------

export PREPARE_AGE_GPG=$stub_dir/gpg-good
combined=$("$prepare_bin" --host quiethost --recipient DEADBEEF 2>&1)
[[ $combined != *FAKE-IDENTITY* ]] || fail 'the helper printed identity material'
pass 'the helper prints the public recipient but never identity material'

printf 'age-identity-helpers: all checks passed\n'
