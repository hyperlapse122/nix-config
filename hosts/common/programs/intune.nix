{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.system.programs.intune;
in
{
  options.my.system.programs.intune = {
    enable = lib.mkEnableOption "Microsoft Intune Portal with Microsoft Edge";
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [
      (_final: prev: {
        intune-portal = prev.intune-portal.overrideAttrs (old: {
          nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.makeWrapper ];
          postFixup = (old.postFixup or "") + ''
            wrapProgram $out/bin/intune-portal \
              --set WEBKIT_DISABLE_COMPOSITING_MODE 1 \
              --set WEBKIT_DISABLE_DMABUF_RENDERER 1 \
              --set WEBKIT_SKIA_ENABLE_CPU_RENDERING 1 \
              --set WEBKIT_SKIA_GPU_PAINTING_THREADS 0 \
              --set LIBGL_ALWAYS_SOFTWARE 1 \
              --prefix GIO_EXTRA_MODULES : ${prev.glib-networking}/lib/gio/modules \
              --prefix GST_PLUGIN_SYSTEM_PATH_1_0 : ${prev.gst_all_1.gst-plugins-base}/lib/gstreamer-1.0

            wrapProgram $out/bin/intune-agent \
              --set WEBKIT_DISABLE_COMPOSITING_MODE 1 \
              --set WEBKIT_DISABLE_DMABUF_RENDERER 1 \
              --set WEBKIT_SKIA_ENABLE_CPU_RENDERING 1 \
              --set WEBKIT_SKIA_GPU_PAINTING_THREADS 0 \
              --set LIBGL_ALWAYS_SOFTWARE 1 \
              --prefix GIO_EXTRA_MODULES : ${prev.glib-networking}/lib/gio/modules \
              --prefix GST_PLUGIN_SYSTEM_PATH_1_0 : ${prev.gst_all_1.gst-plugins-base}/lib/gstreamer-1.0

            wrapProgram $out/bin/intune-daemon \
              --set WEBKIT_DISABLE_COMPOSITING_MODE 1 \
              --set WEBKIT_DISABLE_DMABUF_RENDERER 1 \
              --set WEBKIT_SKIA_ENABLE_CPU_RENDERING 1 \
              --set WEBKIT_SKIA_GPU_PAINTING_THREADS 0 \
              --set LIBGL_ALWAYS_SOFTWARE 1 \
              --prefix GIO_EXTRA_MODULES : ${prev.glib-networking}/lib/gio/modules \
              --prefix GST_PLUGIN_SYSTEM_PATH_1_0 : ${prev.gst_all_1.gst-plugins-base}/lib/gstreamer-1.0
          '';
        });

        microsoft-identity-broker = prev.microsoft-identity-broker.overrideAttrs (old: {
          nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.makeWrapper ];
          postFixup = (old.postFixup or "") + ''
            wrapProgram $out/bin/microsoft-identity-broker \
              --set WEBKIT_DISABLE_COMPOSITING_MODE 1 \
              --set WEBKIT_DISABLE_DMABUF_RENDERER 1 \
              --set WEBKIT_SKIA_ENABLE_CPU_RENDERING 1 \
              --set WEBKIT_SKIA_GPU_PAINTING_THREADS 0 \
              --set LIBGL_ALWAYS_SOFTWARE 1 \
              --prefix GIO_EXTRA_MODULES : ${prev.glib-networking}/lib/gio/modules \
              --prefix GST_PLUGIN_SYSTEM_PATH_1_0 : ${prev.gst_all_1.gst-plugins-base}/lib/gstreamer-1.0

            wrapProgram $out/bin/microsoft-identity-device-broker \
              --set WEBKIT_DISABLE_COMPOSITING_MODE 1 \
              --set WEBKIT_DISABLE_DMABUF_RENDERER 1 \
              --set WEBKIT_SKIA_ENABLE_CPU_RENDERING 1 \
              --set WEBKIT_SKIA_GPU_PAINTING_THREADS 0 \
              --set LIBGL_ALWAYS_SOFTWARE 1 \
              --prefix GIO_EXTRA_MODULES : ${prev.glib-networking}/lib/gio/modules \
              --prefix GST_PLUGIN_SYSTEM_PATH_1_0 : ${prev.gst_all_1.gst-plugins-base}/lib/gstreamer-1.0

            wrapProgram $out/bin/dsreg \
              --set WEBKIT_DISABLE_COMPOSITING_MODE 1 \
              --set WEBKIT_DISABLE_DMABUF_RENDERER 1 \
              --set WEBKIT_SKIA_ENABLE_CPU_RENDERING 1 \
              --set WEBKIT_SKIA_GPU_PAINTING_THREADS 0 \
              --set LIBGL_ALWAYS_SOFTWARE 1 \
              --prefix GIO_EXTRA_MODULES : ${prev.glib-networking}/lib/gio/modules \
              --prefix GST_PLUGIN_SYSTEM_PATH_1_0 : ${prev.gst_all_1.gst-plugins-base}/lib/gstreamer-1.0
          '';
        });
      })
    ];

    services.intune.enable = true;

    systemd.sockets.intune-daemon.wantedBy = [ "sockets.target" ];
    systemd.user.timers.intune-agent.wantedBy = [ "graphical-session.target" ];

    systemd.tmpfiles.rules = [
      "d /etc/microsoft 0755 root root - -"
      "d /etc/microsoft/identity-broker 0755 root root - -"
      "d /etc/microsoft/identity-broker/private 0700 root root - -"
      "d /etc/microsoft/identity-broker/certs 0700 root root - -"
      "d /opt/microsoft/intune/bin 0755 root root - -"
      "L+ /opt/microsoft/intune/bin/intune-agent - - - - ${pkgs.intune-portal}/bin/intune-agent"
      "L+ /opt/microsoft/intune/bin/intune-daemon - - - - ${pkgs.intune-portal}/bin/intune-daemon"
      "L+ /opt/microsoft/intune/bin/intune-portal - - - - ${pkgs.intune-portal}/bin/intune-portal"
      "d /opt/microsoft/identity-broker/bin 0755 root root - -"
      "L+ /opt/microsoft/identity-broker/bin/microsoft-identity-broker - - - - ${pkgs.microsoft-identity-broker}/bin/microsoft-identity-broker"
      "L+ /opt/microsoft/identity-broker/bin/microsoft-identity-device-broker - - - - ${pkgs.microsoft-identity-broker}/bin/microsoft-identity-device-broker"
    ];

    environment.systemPackages = with pkgs; [
      epiphany
      microsoft-edge
    ];
  };
}
