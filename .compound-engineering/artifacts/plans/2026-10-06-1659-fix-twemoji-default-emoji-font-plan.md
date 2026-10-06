---
title: Twemoji as the Effective Default Emoji Font - Plan
type: fix
date: 2026-10-06
topic: twemoji-default-emoji-font
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Twemoji as the Effective Default Emoji Font - Plan

## Goal Capsule

- **Objective:** On every NixOS host, emoji show as color Twemoji in Chromium/Electron, KDE/Qt, and GTK apps, both in plain text and where an app asks for the emoji font, instead of DejaVu's monochrome glyphs or Noto.
- **Means:** Install the color-bitmap Twemoji build instead of the OpenType-SVG one (KTD1), list it in every generic font family (KTD2), and add a check that reads the built fontconfig (KTD3).
- **Authority:** This plan's R-IDs govern behavior and its KTDs govern mechanism. `AGENTS.md` governs repository conventions, check rules, and ship verification.
- **Open blockers:** None.
- **Stop conditions:** Stop and report if `twitter-color-emoji` does not resolve as family `Twitter Color Emoji` with a color table that Chromium, Qt, or GTK can draw. Also stop if putting Twemoji in a generic family makes ASCII text resolve to it.
- **Execution profile:** Lightweight. One module edit, one new check with mutation testing, and one docs edit.
- **Finishing:** The implementer lands and verifies the change. The user confirms on hardware, after their own `nr switch`, that apps draw color emoji.

## Product Contract

### Summary

Replace `twemoji-color-font` with nixpkgs `twitter-color-emoji`, which keeps the family name `Twitter Color Emoji`. Put that family into the sans-serif, serif, and monospace defaults right after each primary font, so emoji codepoints reach it before DejaVu Sans. Noto Color Emoji stays as the last fallback. A new host-closure check runs fontconfig against each built configuration and fails unless every family's emoji fallback lands on the color Twemoji file.

### Problem Frame

`modules/nixos/desktop/fonts.nix` already lists `Twitter Color Emoji` first under `defaultFonts.emoji`, yet apps rarely show Twemoji. Two causes were confirmed on the running system:

1. The installed `twemoji-color-font` ships `TwitterColorEmoji-SVGinOT.ttf`, an OpenType-SVG font. Firefox draws it in color. Chromium/Electron, Qt 6.11, and GTK/Pango do not, so they fall back to the font's monochrome glyphs or to another font.
2. `defaultFonts.emoji` only takes effect when an app asks for the `emoji` family. For ordinary text, fontconfig's fallback picks DejaVu Sans, which has monochrome emoji glyphs. The first font that covers U+1F600 in the sorted fallback list is DejaVu Sans for `sans-serif`, `serif`, `monospace`, `Pretendard`, `Noto Sans`, and `Arial`. DejaVu arrives through `fonts.enableDefaultPackages`.

`docs/verification.md` already records the symptom: an agent-browser headless smoke drew emoji as monochrome glyphs.

### Requirements

**Rendering**

- R1. Emoji render as color Twemoji in Chromium/Electron, Qt/KDE, and GTK apps on NixOS hosts.
- R2. An emoji codepoint in sans-serif, serif, or monospace text falls back to Twemoji before any monochrome font such as DejaVu Sans.
- R3. An app that asks for the `emoji` family gets Twemoji first and Noto Color Emoji second.
- R4. Noto Color Emoji stays installed as the fallback for codepoints Twemoji lacks.
- R5. ASCII text and Korean text keep resolving to their current primary fonts.

**Coverage and proof**

- R6. Every NixOS configuration, production and bootstrap, carries the change, because `modules/nixos/desktop/fonts.nix` is not gated on `my.bootstrap`.
- R7. A repository check fails when any NixOS configuration's built fontconfig resolves an emoji codepoint to anything other than the color Twemoji font.

### Key Decisions

- **Swap the Twemoji build rather than add a second one.** Both packages claim the family `Twitter Color Emoji`, so installing both would let fontconfig pick either file. Governs R1, R3. (session-settled: user-approved — chosen over keeping `twemoji-color-font`: its OpenType-SVG glyphs are drawn in color only by Firefox.)
- **Fix fallback order through the generic families.** Governs R2, R5. (session-settled: user-approved — chosen over leaving emoji to the `emoji` alias alone: that alias never applies to the plain text where DejaVu Sans wins today.)

### Scope Boundaries

- Non-NixOS hosts are out of scope. They have no desktop configuration in this repository.
- Ghostty's own `font-family` list and the `ghostty-font` check are unchanged. Ghostty falls back through fontconfig for codepoints it lacks, so it gets the new order without edits.
- Removing DejaVu or turning off `fonts.enableDefaultPackages` is not done. The generic-family order already puts Twemoji ahead of DejaVu. Dropping the default packages would also remove fallback coverage that other checks, such as `agent-browser-deps`, rely on.
- A hand-written fontconfig rule that rejects DejaVu's emoji ranges was considered and not built. The `defaultFonts` lists already produce the order. A planned config built from a copy of the live `conf.d` gave Twemoji as the first U+1F600-covering font for named families too: `Noto Sans`, `Arial`, `Liberation Sans`, `Noto Sans CJK KR`, Pretendard, Hack, and `system-ui`. Their sorted fallback reaches the generic aliases. Revisit only if a hardware check finds an app still drawing DejaVu emoji.
- Removing emoji-presentation glyphs such as `☕` and `⚡` from the primary monospace fonts was considered and not built. Those Nerd Font glyphs show up in terminal prompts. Apps that segment emoji (Chromium/Skia, Pango, Qt 6.9+, Ghostty) send emoji-presentation characters to the `emoji` family, which resolves to Twemoji. Revisit if the hardware step shows them monochrome in one of those apps.

### Success Criteria

- On a host after `nr switch`, an emoji in a Chromium page, a KDE app, and a GTK app is drawn as color Twemoji. This is a hardware step in `docs/verification.md`.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Install `twitter-color-emoji` (17.0.2) and remove `twemoji-color-font`.** The nixpkgs package builds Twemoji as a CBDT color-bitmap font named `TwitterColorEmoji.ttf` with family `Twitter Color Emoji`. FreeType draws CBDT, and Chromium, Qt, and GTK all render through it. Because the family name is unchanged, `defaultFonts.emoji` needs no rename. Implements the first Key Decision, so it governs R1 and R3. (session-settled: user-approved — chosen over keeping `twemoji-color-font`: its OpenType-SVG glyphs are drawn in color only by Firefox.)
- KTD2. **Add `Twitter Color Emoji` to `defaultFonts.sansSerif`, `serif`, and `monospace`, right after each list's primary font or fonts.** For monospace, that means after the three JetBrains/D2Coding entries. Serif is unset today and renders as `Noto Serif`, so this plan sets it explicitly with `Noto Serif` first. nixpkgs merges its own defaults into these lists (the rendered sans-serif alias today is `Pretendard, Noto Sans`), so the implementer confirms the order in the built `52-nixos-default-fonts.conf`, not in the option value. Twemoji also covers the ASCII digits, `#`, `*`, and space, which is why it must come after a primary font that already has ASCII (R5). Implements the second Key Decision, so it governs R2 and R5. (session-settled: user-approved — chosen over leaving emoji to the `emoji` alias alone: that alias never applies to the plain text where DejaVu Sans wins today.)
- KTD3. **Prove the result with a new `emoji-font` host-closure check that runs fontconfig against each configuration's built `/etc/fonts`.** `agent-browser-deps` loads only the `00-nixos-cache.conf` fragment, and that fragment has no default-family aliases, so it cannot see the fallback order. The new check loads the built `fonts.conf`, with its absolute `/etc/fonts/conf.d` include redirected to the built tree. This follows the rule against [reading an option value instead of the materialized output](../solutions/best-practices/nix-check-reads-option-value-not-materialized-output.md). The color format is read from the resolved font file's own tables, not inferred from its package name.

- KTD4. **Model app fallback as "the first font in `fc-match -s <family>` order whose charset covers the codepoint".** Skia, Pango, and Qt take a fontconfig sort and pick the first font that has the glyph. `fc-match "<family>:charset=…"` scores charset as one weak element, so it returns fonts no app would pick. Coverage can be read from the `fc-list ":charset=<hex>" file` set.

### Risks

- Text in a monospace font that segments no emoji still draws `☕` (U+2615) from D2Coding and `⚡` (U+26A1) from JetBrainsMono, in monochrome. Both are emoji-presentation characters that the primary fonts already carry. Scope Boundaries records why the primary fonts keep them.

- Symbols that default to text presentation and that the primary font lacks, such as `☀` or `✔`, may now draw as color Twemoji instead of DejaVu's monochrome glyphs. This is the expected effect of making Twemoji the default. The hardware step looks at a terminal and a KDE app so a jarring case surfaces.
- Qt 6.9 and later pick a dedicated emoji font through the `emoji` family. If KDE apps still show Noto after the change, `defaultFonts.emoji` order is the place to look, not the generic lists.

---

## Implementation Units

### U1. Switch the Twemoji package and fallback order

- **Goal:** The built fontconfig installs only the CBDT Twemoji and sends emoji in every generic family to it.
- **Requirements:** R1, R2, R3, R4, R5, R6. KTD1, KTD2.
- **Dependencies:** None.
- **Files:** `modules/nixos/desktop/fonts.nix`
- **Approach:**
  1. Replace `twemoji-color-font` with `twitter-color-emoji` in `fonts.packages` (KTD1).
  2. Add `Twitter Color Emoji` after the primary entries of `sansSerif` and `monospace`, and set `serif` to `Noto Serif` followed by it (KTD2).
  3. Leave `defaultFonts.emoji` as `Twitter Color Emoji`, then `Noto Color Emoji`.
- **Patterns to follow:** The existing `defaultFonts` block in the same file.
- **Test expectation:** none here. U2 owns the proof and mutates this unit's edits.
- **Verification:** Every NixOS configuration builds. Its built `52-nixos-default-fonts.conf` lists Twemoji right after the primary fonts in each generic alias. No built font directory holds `TwitterColorEmoji-SVGinOT.ttf`.

### U2. Add the `emoji-font` check

- **Goal:** A check fails when any configuration's built fontconfig sends an emoji codepoint anywhere other than the color Twemoji font.
- **Requirements:** R7, and it proves R2, R3, R4, R5, R6. KTD3, KTD4.
- **Dependencies:** U1.
- **Files:**
  - `tests/emoji-font.nix` (new)
  - `flake.nix`: register it under `checks` and add `"emoji-font"` to `hostClosureChecks` so the `hosts` shard builds it and `check-shards-guard` stays green.
- **Approach:**
  1. Iterate `configurations.entries` from `tests/lib/configurations.nix`, and splice `configurations.guard` first.
  2. For each entry, write a sandbox `fonts.conf` from the built `etc/fonts/fonts.conf`, with its `/etc/fonts/conf.d` include redirected to the built `etc/fonts/conf.d`. Point `FONTCONFIG_FILE` at it, and point `HOME` and `XDG_CACHE_HOME` into `$TMPDIR`.
  3. Run the assertions below, and collect every failure in one build before exiting.
- **Patterns to follow:**
  - `tests/agent-browser-deps.nix`: sandbox fontconfig environment, header comment shape, failure collection.
  - `tests/kde-dark-theme.nix`: per-entry assertions over the materialized `/etc`.
- **Test scenarios:** All resolution uses the KTD4 fallback model.
  - Happy path: U+1F600 resolves to family `Twitter Color Emoji` for `sans-serif`, `serif`, `monospace`, and `emoji`, and for the named families `Noto Sans` and `Liberation Sans`.
  - Happy path: `emoji` also resolves U+2615 (`☕`) to `Twitter Color Emoji`. This is the path apps that segment emoji take.
  - Happy path: the resolved file carries a `CBDT` or `COLR` table. Read the table list with fonttools (`ttx -l`, so `python3Packages.fonttools` goes in `nativeBuildInputs`). fontconfig's `color` property is not enough, because it is true for the OpenType-SVG build as well.
  - Happy path: `fc-match -a emoji` lists `Noto Color Emoji` after `Twitter Color Emoji` (R3, R4). Use `-a` because `-s` trims Noto out of the list.
  - Edge case (R5): for each of `sans-serif`, `serif`, and `monospace`, space (U+0020), `1` (U+0031), and `#` (U+0023) resolve to the same primary font as `A`, not to Twemoji. Twemoji covers these characters, so they catch a misordering that `A` alone cannot.
  - Edge case (R5): `sans-serif` resolves `한` to its current CJK font.
  - Coverage: the check runs on bootstrap configurations as well as production ones (R6). The configurations guard fails an empty list.
- **Execution note:** Mutation-test each assertion in a scratch copy, following [mutation testing for check assertions](../solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md) and [a copied git worktree still writes the real index](../solutions/best-practices/copied-git-worktree-writes-the-real-index.md). Each of these mutations must turn the check red:
  - Restoring `twemoji-color-font`.
  - Dropping Twemoji from each generic list in turn.
  - Moving Twemoji ahead of a primary font.
  - Removing `noto-fonts-color-emoji` from the installed fonts. Deleting `Noto Color Emoji` from `defaultFonts.emoji` is not a usable mutation: fontconfig's own `60-generic.conf` already lists Noto in the `emoji` alias, so the order does not change.
- **Verification:** The check builds green on the edited tree and red on each mutation, and `check-shards-guard` passes.

### U3. Document the check and the hardware step

- **Goal:** `docs/verification.md` describes the new check and replaces the stale monochrome-emoji note with a color-emoji hardware step.
- **Requirements:** Success Criteria. R1.
- **Dependencies:** U2.
- **Files:** `docs/verification.md`
- **Approach:**
  1. Add an `emoji-font` description beside `agent-browser-deps` in the check catalogue paragraph, including what it cannot see: whether a running app actually draws in color.
  2. Rewrite the agent-browser step's emoji sentence to expect color Twemoji.
  3. Add a hardware step: after `nr switch`, confirm color Twemoji in Chromium, a KDE app, a GTK app, and Ghostty. Include `😀` and `☕`, and note any text-presentation symbol that turned into color emoji.
- **Test expectation:** none -- documentation only.
- **Verification:** The doc names the check and the hardware step, and no sentence still expects monochrome emoji.

---

## Verification Contract

| Gate | Command or evidence |
|---|---|
| Format | `nix fmt -- --ci` |
| New check | `nix build --no-link .#checks.x86_64-linux.emoji-font`, plus a red build for each U2 mutation |
| Host shard | `nix build --no-link .#checkShards.hosts` |
| Flake checks | `nix flake check` |
| Every output | The `AGENTS.md` ship loop over `nixosConfigurations`, `homeConfigurations`, and `systemConfigs`, plus `nix build --no-link .#vmChecks.all` |
| Hardware | The U3 step, reported separately from build evidence |

## Definition of Done

- U1 through U3 are landed, and every Verification Contract gate except Hardware has passed.
- Each U2 mutation was observed to turn the check red, and the mutated scratch copy was discarded.
- No `twemoji-color-font` reference remains outside `.compound-engineering/artifacts/`.
- No abandoned experiment code is left in the diff.
