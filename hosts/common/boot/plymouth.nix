{ config, lib, ... }:
{
  config = lib.mkIf config.boot.plymouth.enable {
    boot.kernelParams = lib.mkBefore [ "quiet" ];
  };
}
