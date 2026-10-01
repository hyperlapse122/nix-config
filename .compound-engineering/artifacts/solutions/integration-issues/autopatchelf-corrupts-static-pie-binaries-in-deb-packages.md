---
title: "autoPatchelfHook corrupts static-pie binaries bundled in a .deb, and postFixup runs before the hook"
date: "2026-10-01"
category: integration-issues
module: "ChatGPT desktop package (packages/chatgpt.nix)"
problem_type: integration_issue
component: tooling
severity: medium
symptoms:
  - "The bundled resources/codex, rg, and codex-code-mode-host segfault (exit 139) even on --version after the build"
  - "readelf -d shows a RUNPATH on those files, although they are static-pie executables with no PT_INTERP"
  - "Restoring the set-aside originals from the derivation's postFixup attribute leaves the patched files in place, because the restore runs before the patching"
  - "A presence-only flake check passes, because the patched binary still exists and is executable"
root_cause: wrong_api
resolution_type: code_fix
related_components:
  - testing_framework
tags: ["autopatchelf", "static-pie", "nixpkgs", "stdenv", "postfixup", "postfixuphooks", "deb-package", "flake-checks"]
retire_when: "auto-patchelf in nixpkgs skips static-pie executables (ET_DYN with no PT_INTERP) in is_static_executable; check pkgs/by-name/au/auto-patchelf/source/auto-patchelf.py in the locked nixpkgs rev"
---

# autoPatchelf adds a runpath to static-pie binaries, and an implicit postFixup cannot undo it

## Problem

The ChatGPT desktop package (`packages/chatgpt.nix`, on branch `feat/add-codex-chatgpt`, unmerged as of this writing) repackages the upstream `.deb` with `autoPatchelfHook` and sets `appendRunpaths` to libGL and libpulseaudio so Chromium can `dlopen` them (`packages/chatgpt.nix:63-66`). The ChatGPT 26.928.31416 `.deb` also bundles three static-pie binaries under `lib/chatgpt` in the built package output: `resources/codex`, `resources/rg`, and `resources/codex-code-mode-host`. autoPatchelf gave each of them a `RUNPATH`, and they segfaulted.

autoPatchelf's static-binary skip does not cover static-pie, so the binaries have to be protected by hand. The first attempt at that also failed, because of the order in which stdenv runs a `postFixup` attribute and the `postFixupHooks` array.

## Symptoms

- `resources/codex --version` and `resources/rg --version` in the built package exit with status 139 (SIGSEGV).
- `readelf -d` on the bundled binaries shows a `RUNPATH` of `<libglvnd>/lib:<libpulseaudio>/lib`, the `appendRunpaths` value, on files that have no `DT_NEEDED` entries and no interpreter.
- `file -b` reports them as `static-pie linked`, which is ELF type `ET_DYN` with no `.interp`.
- The original `chatgpt` flake check stayed green the whole time. It asserted only that `bin/chatgpt` is executable, that the desktop entry exists, and that the wrapper has no ozone flag. Every bundled file was present and executable, so the check never noticed that the binaries crashed.

## What Didn't Work

**Trusting autoPatchelf to skip static binaries.** It does skip some. The `pkgs/...` paths cited below are files in the flake's locked nixpkgs input (`nix eval --raw --impure --expr '(builtins.getFlake (toString ./.)).inputs.nixpkgs.outPath'`), not in this repository. `is_static_executable` returns true only for `e_type == 'ET_EXEC'` with no `.interp` section (`pkgs/by-name/au/auto-patchelf/source/auto-patchelf.py:34-36`), and `auto_patchelf_file` skips only those files (`auto-patchelf.py:364-367`). A static-pie binary is `ET_DYN`, so it is not skipped. It gets no interpreter, because `is_dynamic_executable` checks for `.interp` (`auto-patchelf.py:40-44`, used at `:403`), but `append_rpaths` is still added to its rpath (`auto-patchelf.py:471`), and any non-empty rpath is written with `patchelf --set-rpath` (`auto-patchelf.py:485-489`). In this package that rpath is never empty, because `appendRunpaths` is always set.

**Setting the binaries aside in `installPhase` and restoring them in the `postFixup` attribute.** The idea was to copy each static-pie file to `$TMPDIR` before the hook ran and to copy it back in `postFixup`, assuming the automatic patching had already happened by then. The restored files still had the `RUNPATH`. The automatic hook does not run before `postFixup`. It is registered as an element of the array, `postFixupHooks+=(autoPatchelfPostFixup)` (`pkgs/by-name/au/autoPatchelfHook/auto-patchelf.sh:104`), and `fixupPhase` ends with `runHook postFixup` (`pkgs/stdenv/generic/setup.sh:1658`). `runHook` iterates `"_callImplicitHook 0 $hookName"` first and the `${hookName}Hooks` array after it (`setup.sh:203-217`, the loop at `:211`). `_callImplicitHook` evaluates the derivation's `postFixup` string (`setup.sh:246-259`). So the restore ran first, and `autoPatchelfPostFixup` then patched the restored originals.

## Solution

Turn off the automatic hook and call `autoPatchelf` from the `postFixup` attribute, followed by the restore. The phase then controls the order itself.

Before (the failed attempt, never committed; `installPhase` already set the files aside):

```nix
  postFixup = ''
    # Runs before autoPatchelfPostFixup, so the restored files get patched anyway.
    (cd "$TMPDIR/static-pie" && find . -type f -print0 | while IFS= read -r -d "" file; do
      install -Dm755 "$file" "$out/lib/chatgpt/$file"
    done)
  '';
```

After (`packages/chatgpt.nix:95-104` and `:125-134`):

```nix
  installPhase = ''
    ...
    (cd usr/lib/chatgpt && find . -type f -print0 | while IFS= read -r -d "" file; do
      if file -b "$file" | grep -q 'static-pie linked'; then
        install -Dm755 "$file" "$TMPDIR/static-pie/$file"
      fi
    done)
    mv usr/lib/chatgpt $out/lib/
    ...
  '';

  dontAutoPatchelf = true;
  postFixup = ''
    autoPatchelf -- "$out"
    (cd "$TMPDIR/static-pie" && find . -type f -print0 | while IFS= read -r -d "" file; do
      install -Dm755 "$file" "$out/lib/chatgpt/$file"
    done)
  '';
```

`pkgs.file` is added to `nativeBuildInputs` (`packages/chatgpt.nix:20`) for the detection. The files are found by `file -b … | grep 'static-pie linked'` rather than by a fixed list of names, so a static binary added in a later release is protected too.

The `chatgpt` flake check now runs the bundled binaries instead of only checking that they exist: `HOME="$TMPDIR" …/lib/chatgpt/resources/$binary --version` for `codex` and `rg` (`flake.nix:928-936`).

Verified after the fix: the bundled binaries report `codex-cli 0.159.2` and `ripgrep 15.2.0`, and the ChatGPT Electron binary still has its `RUNPATH`, so the libGL and libpulseaudio `dlopen` path is unchanged. As a mutation test in this session, re-enabling the automatic hook turned the `chatgpt` check red.

## Why This Works

`dontAutoPatchelf` makes `autoPatchelfPostFixup` return without doing anything (`auto-patchelf.sh:95`), but the hook still defines the `autoPatchelf` shell function (`auto-patchelf.sh:42-84`). That function reads the same `appendRunpaths` and `autoPatchelfIgnoreMissingDeps` attributes (`auto-patchelf.sh:56-57`), so calling it from `postFixup` patches the same way the automatic hook would. Because the call and the restore are in one string, they run in the order they are written. The static-pie files are patched along with everything else and then overwritten with the unpatched copies saved before `$out` existed. Every other ELF file, the Electron binary included, keeps its patched interpreter and runpath.

A static-pie binary relocates itself at startup and has no dynamic loader that would read a `RUNPATH`, so the entry does nothing useful. Rewriting the file with `patchelf --set-rpath` is what left these binaries segfaulting (exit 139). This session did not establish the exact mechanism inside the binary, only that the patched files crash and the unpatched ones run. Leaving them byte-for-byte as shipped avoids the problem.

## Prevention

- When a package uses `autoPatchelfHook` with `appendRunpaths` or `runtimeDependencies`, run `file` over the unpacked tree and look for `static-pie linked`. autoPatchelf skips only `ET_EXEC` static binaries (`auto-patchelf.py:34-36`), so a static-pie binary will be patched.
- Do not try to undo the hook's work in the `postFixup` attribute. A derivation's own `pre*`/`post*` string runs before that hook's `*Hooks` array (`setup.sh:211`), so it cannot run after `autoPatchelfPostFixup`. Set `dontAutoPatchelf = true` and call `autoPatchelf` yourself where the order matters.
- When a check covers a binary that patching or wrapping can break, run it (`--version` is enough). Checking that the file exists and is executable passes on a binary that segfaults. Mutation-test the check by re-enabling the breaking step, as described in [mutation testing for check assertions](../best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md).
- Before removing this workaround, confirm that nixpkgs' `is_static_executable` also covers `ET_DYN` files without `.interp`, or that `autoPatchelfPostFixup` skips them. Then rebuild with the automatic hook re-enabled and confirm that the `chatgpt` check stays green.
