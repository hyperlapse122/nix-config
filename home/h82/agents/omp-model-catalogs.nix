let
  synthetic = builtins.fromJSON (builtins.readFile ./synthetic-catalog.json);
  openrouter = builtins.fromJSON (builtins.readFile ./openrouter-catalog.json);
  openrouterAllow = [ "^openrouter/.*$" ];
  openrouterExclude = [ "openrouter/bodybuilder" ];
  openrouterData = builtins.filter (
    row:
    builtins.any (pattern: builtins.match pattern row.id != null) openrouterAllow
    && !(builtins.elem row.id openrouterExclude)
  ) openrouter.data;
in
{
  inherit synthetic;
  openrouter = openrouter // {
    data = openrouterData;
  };
  # OMP uses path globs: model IDs themselves contain slashes.
  patterns = [
    "synthetic/**"
    "google-antigravity/gemini-*"
    "google-antigravity/claude-*"
    "google-antigravity/gpt-*"
  ]
  ++ map (row: "openrouter/${row.id}") openrouterData
  ++ [ "openai-codex/*" ];
}
