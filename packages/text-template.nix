# The renderer of the shared agent instructions: Go's text/template over a JSON
# document, with only Go's builtin functions, failing on a missing key or a
# printed null. Stdlib only, so the module has no vendored dependencies.
{ pkgs }:
pkgs.buildGoModule {
  pname = "text-template";
  version = "1";
  src = ./text-template;
  vendorHash = null;
  meta.mainProgram = "text-template";
}
