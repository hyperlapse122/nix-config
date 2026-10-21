# Transitional: the OpenCode default model from synthetic-models.nix, until
# opencode.nix and its check read that source directly.
let
  models = import ./synthetic-models.nix;
in
"synthetic/" + models.${models.opencodeDefault}.id
