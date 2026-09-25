{ pkgs, ... }:
let
  # The SDDM greeter runs as the sddm user and cannot enter the mode-700 home
  # directory, so ~/.face.icon never reaches it. SDDM checks
  # <FacesDir>/<user>.face.icon first, and FacesDir is the system profile's
  # share/sddm/faces on NixOS.
  sddmFace = pkgs.runCommand "h82-sddm-face" { } ''
    install -Dm444 ${../../../home/h82/assets/face.png} $out/share/sddm/faces/h82.face.icon
  '';
in
{
  environment.systemPackages = [ sddmFace ];
}
