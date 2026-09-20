{ pkgs, ... }:

let
  gpgTools = import ../../packages/gpg-tools.nix { inherit pkgs; };
in
{
  programs.gpg = {
    enable = true;
    publicKeys = [
      {
        source = ../../keys/signing.asc;
        trust = "ultimate";
      }
    ];
    settings = {
      cert-digest-algo = "SHA512";
      default-preference-list = "SHA512 SHA384 SHA256 AES256 AES192 AES ZLIB BZIP2 ZIP Uncompressed";
      display-charset = "utf-8";
      keyid-format = "0xlong";
      list-options = "show-uid-validity";
      no-comments = true;
      no-emit-version = true;
      no-symkey-cache = true;
      personal-cipher-preferences = "AES256 AES192 AES";
      personal-compress-preferences = "ZLIB BZIP2 ZIP Uncompressed";
      personal-digest-preferences = "SHA512 SHA384 SHA256";
      require-cross-certification = true;
      s2k-cipher-algo = "AES256";
      s2k-digest-algo = "SHA512";
      verify-options = "show-uid-validity";
      with-fingerprint = true;
    };
  };

  services.gpg-agent = {
    enable = true;
    pinentry.package = gpgTools.pinentryCard;
    extraConfig = ''
      allow-loopback-pinentry
      default-cache-ttl 0
      max-cache-ttl 0
    '';
  };

  home.file.".gnupg/scdaemon.conf".text = ''
    disable-ccid
    pcsc-shared
  '';
}
