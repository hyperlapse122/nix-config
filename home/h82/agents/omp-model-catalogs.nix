let
  synthetic = builtins.fromJSON (builtins.readFile ./synthetic-catalog.json);
  openrouter = builtins.fromJSON (builtins.readFile ./openrouter-catalog.json);
  openrouterAllow = [ "^openrouter/.*$" ];
  openrouterExclude = [ "openrouter/bodybuilder" ];
in
{
  inherit synthetic;
  openrouter = openrouter // {
    data = builtins.filter (
      row:
      builtins.any (pattern: builtins.match pattern row.id != null) openrouterAllow
      && !(builtins.elem row.id openrouterExclude)
    ) openrouter.data;
  };
}
