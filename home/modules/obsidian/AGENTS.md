# Obsidian Home Module

This directory owns `my.obsidian.enable`, the default vault path, and declarative community plugin installation for Obsidian.

## Plugin Updates

When updating Obsidian community plugins:

1. Use the official upstream release artifacts, not source archives or files copied from a local Obsidian profile.
2. Verify the plugin id in the release `manifest.json`; the plugin directory under `.obsidian/plugins/` must match that id.
3. Update the plugin version binding in `default.nix`.
4. Refresh hashes for every managed runtime file with `nix store prefetch-file --json <release-url>`.
5. Keep generated plugin state such as `data.json` unmanaged unless defaults are explicitly required.
6. Keep `community-plugins.json` aligned with the declaratively installed plugin ids.
7. Run `nixfmt home/modules/obsidian/default.nix` after edits.
8. Verify with `nix eval` for the generated Home Manager file entries and `nixos-rebuild build --flake .#h82-t14-gen2`.

For Obsidian Git, the managed runtime files are `main.js`, `manifest.json`, and `styles.css` from `https://github.com/Vinzent03/obsidian-git/releases`.

## Constraints

- Keep the vault path based on `config.home.homeDirectory`; do not hard-code `/home/h82`.
- Do not install plugins through the Obsidian UI and then copy mutable results into this repo.
- Do not manage plugin cache files, logs, or local repository contents.
