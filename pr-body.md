## Automated Dependency Update (Reconciliation Required)

The dependency update job, which runs every 30 minutes, detected changes to flake inputs or packages, but pre-push verification failed.

### Failure Logs
#### nix flake check
```text
claude-desktop>     libxkbcommon.so.0 -> found: /nix/store/nvrv5w6rhc39h8snrsw03nqs679cf7rh-libxkbcommon-1.13.2/lib
claude-desktop>     libudev.so.1 -> found: /nix/store/gvhdvn542cwd3wr2978nh4ydzp89msq7-systemd-minimal-libs-261.3/lib
claude-desktop>     libasound.so.2 -> found: /nix/store/xlqm12gx3s3f7dc1a5pnfk4p2niw2lri-alsa-lib-1.2.16.1/lib
claude-desktop>     libatspi.so.0 -> found: /nix/store/4g39rajyrxqn3na1kd4pykdigsr82af5-at-spi2-core-2.60.6/lib
claude-desktop>     libgcc_s.so.1 -> found: /nix/store/q2mkz6ca1alqfqf750dygvakmq8kjrwz-gcc-16.2.0-libgcc/lib
claude-desktop> setting RPATH to: /nix/store/cfy30bkc7yhbgyvcswmhbwhzwiqk3rhb-claude-desktop-2.19675.1/lib/claude-desktop:/nix/store/3dkchpfn8r3ipsccl1001xhcl5smfjdx-glib-2.88.3/lib:/nix/store/8pcrdazxyw8b1n3i0v9d2r3g38hrgw63-nspr-4.40/lib:/nix/store/dzapcr7zrasyn3d0p007023wv2pdyrqf-nss-3.112.5/lib:/nix/store/4g39rajyrxqn3na1kd4pykdigsr82af5-at-spi2-core-2.60.6/lib:/nix/store/nkx77vqznw5sb8ybi698zcd73zwxmr4l-cups-2.4.19-lib/lib:/nix/store/d34lp4b2b0glnmwf7ij3ha8mrmb30l64-dbus-1.16.2-lib/lib:/nix/store/hlk27kiwy9zqwlk4pghb8gshs8s6akdy-cairo-1.18.4/lib:/nix/store/1fl4qsghsryd5f764m5v64vlxdz9d8qx-gtk+3-3.24.52/lib:/nix/store/jxvb2w9s84m7g7iy5zcf6a9nq73bxqc3-pango-1.57.1/lib:/nix/store/znrm90algr0fvnnnp130am1qfg59nl1f-libx11-1.8.13/lib:/nix/store/a3rbzlj5wzxwjpncc0q9p6l64sc52m3y-libxcomposite-0.4.7/lib:/nix/store/kg5wp6wavf5p7v6shcccyqxy2nlzsn5s-libxdamage-1.1.7/lib:/nix/store/firki6qp8l2y6jgpwvix2wd95bi572mi-libxext-1.3.7/lib:/nix/store/l5y7fz08zvrqiinb90j1r922ymncb0sj-libxfixes-6.0.2/lib:/nix/store/w8szff2i3dyf21v08j9yvpznfr7518wi-libxrandr-1.5.5/lib:/nix/store/knm96d081dl0mhbbdbmi2gwqj2sn0jbh-mesa-libgbm-26.1.3/lib:/nix/store/zrkqwk0989k5wa1gn3cjb76jfga3d8i3-expat-2.8.5/lib:/nix/store/cvr8yyrrqnjxgd7bs6lwgra4qma7kwl9-libxcb-1.17.0/lib:/nix/store/nvrv5w6rhc39h8snrsw03nqs679cf7rh-libxkbcommon-1.13.2/lib:/nix/store/gvhdvn542cwd3wr2978nh4ydzp89msq7-systemd-minimal-libs-261.3/lib:/nix/store/xlqm12gx3s3f7dc1a5pnfk4p2niw2lri-alsa-lib-1.2.16.1/lib:/nix/store/q2mkz6ca1alqfqf750dygvakmq8kjrwz-gcc-16.2.0-libgcc/lib:/nix/store/mj9klbkhzal0vc1aazsajrydkimhc0h2-libglvnd-1.7.0/lib:/nix/store/rssqiz9l5knlan7fy5knf43zsrdwmg5g-libpulseaudio-17.0/lib
userborn>    Compiling xcrypt-sys v0.2.1
claude-desktop> setting interpreter of /nix/store/cfy30bkc7yhbgyvcswmhbwhzwiqk3rhb-claude-desktop-2.19675.1/lib/claude-desktop/chrome_crashpad_handler
claude-desktop> searching for dependencies of /nix/store/cfy30bkc7yhbgyvcswmhbwhzwiqk3rhb-claude-desktop-2.19675.1/lib/claude-desktop/chrome_crashpad_handler
claude-desktop>     libglib-2.0.so.0 -> found: /nix/store/3dkchpfn8r3ipsccl1001xhcl5smfjdx-glib-2.88.3/lib
claude-desktop>     libgcc_s.so.1 -> found: /nix/store/q2mkz6ca1alqfqf750dygvakmq8kjrwz-gcc-16.2.0-libgcc/lib
claude-desktop> setting RPATH to: /nix/store/3dkchpfn8r3ipsccl1001xhcl5smfjdx-glib-2.88.3/lib:/nix/store/q2mkz6ca1alqfqf750dygvakmq8kjrwz-gcc-16.2.0-libgcc/lib:/nix/store/mj9klbkhzal0vc1aazsajrydkimhc0h2-libglvnd-1.7.0/lib:/nix/store/rssqiz9l5knlan7fy5knf43zsrdwmg5g-libpulseaudio-17.0/lib
claude-desktop> searching for dependencies of /nix/store/cfy30bkc7yhbgyvcswmhbwhzwiqk3rhb-claude-desktop-2.19675.1/lib/claude-desktop/libvk_swiftshader.so
claude-desktop>     libgcc_s.so.1 -> found: /nix/store/q2mkz6ca1alqfqf750dygvakmq8kjrwz-gcc-16.2.0-libgcc/lib
claude-desktop> setting RPATH to: /nix/store/q2mkz6ca1alqfqf750dygvakmq8kjrwz-gcc-16.2.0-libgcc/lib:/nix/store/mj9klbkhzal0vc1aazsajrydkimhc0h2-libglvnd-1.7.0/lib:/nix/store/rssqiz9l5knlan7fy5knf43zsrdwmg5g-libpulseaudio-17.0/lib
claude-desktop> searching for dependencies of /nix/store/cfy30bkc7yhbgyvcswmhbwhzwiqk3rhb-claude-desktop-2.19675.1/lib/claude-desktop/libffmpeg.so
claude-desktop>     libgcc_s.so.1 -> found: /nix/store/q2mkz6ca1alqfqf750dygvakmq8kjrwz-gcc-16.2.0-libgcc/lib
claude-desktop> setting RPATH to: /nix/store/q2mkz6ca1alqfqf750dygvakmq8kjrwz-gcc-16.2.0-libgcc/lib:/nix/store/mj9klbkhzal0vc1aazsajrydkimhc0h2-libglvnd-1.7.0/lib:/nix/store/rssqiz9l5knlan7fy5knf43zsrdwmg5g-libpulseaudio-17.0/lib
claude-desktop> searching for dependencies of /nix/store/cfy30bkc7yhbgyvcswmhbwhzwiqk3rhb-claude-desktop-2.19675.1/lib/claude-desktop/libvulkan.so.1
claude-desktop>     libgcc_s.so.1 -> found: /nix/store/q2mkz6ca1alqfqf750dygvakmq8kjrwz-gcc-16.2.0-libgcc/lib
claude-desktop> setting RPATH to: /nix/store/q2mkz6ca1alqfqf750dygvakmq8kjrwz-gcc-16.2.0-libgcc/lib:/nix/store/mj9klbkhzal0vc1aazsajrydkimhc0h2-libglvnd-1.7.0/lib:/nix/store/rssqiz9l5knlan7fy5knf43zsrdwmg5g-libpulseaudio-17.0/lib
claude-desktop> setting interpreter of /nix/store/cfy30bkc7yhbgyvcswmhbwhzwiqk3rhb-claude-desktop-2.19675.1/lib/claude-desktop/chrome-sandbox
claude-desktop> searching for dependencies of /nix/store/cfy30bkc7yhbgyvcswmhbwhzwiqk3rhb-claude-desktop-2.19675.1/lib/claude-desktop/chrome-sandbox
claude-desktop> setting RPATH to: /nix/store/mj9klbkhzal0vc1aazsajrydkimhc0h2-libglvnd-1.7.0/lib:/nix/store/rssqiz9l5knlan7fy5knf43zsrdwmg5g-libpulseaudio-17.0/lib
claude-desktop> setting interpreter of /nix/store/cfy30bkc7yhbgyvcswmhbwhzwiqk3rhb-claude-desktop-2.19675.1/lib/claude-desktop/resources/chrome-native-host
claude-desktop> searching for dependencies of /nix/store/cfy30bkc7yhbgyvcswmhbwhzwiqk3rhb-claude-desktop-2.19675.1/lib/claude-desktop/resources/chrome-native-host
claude-desktop>     libgcc_s.so.1 -> found: /nix/store/q2mkz6ca1alqfqf750dygvakmq8kjrwz-gcc-16.2.0-libgcc/lib
claude-desktop> setting RPATH to: /nix/store/q2mkz6ca1alqfqf750dygvakmq8kjrwz-gcc-16.2.0-libgcc/lib:/nix/store/mj9klbkhzal0vc1aazsajrydkimhc0h2-libglvnd-1.7.0/lib:/nix/store/rssqiz9l5knlan7fy5knf43zsrdwmg5g-libpulseaudio-17.0/lib
claude-desktop> setting interpreter of /nix/store/cfy30bkc7yhbgyvcswmhbwhzwiqk3rhb-claude-desktop-2.19675.1/lib/claude-desktop/resources/virtiofsd
claude-desktop> searching for dependencies of /nix/store/cfy30bkc7yhbgyvcswmhbwhzwiqk3rhb-claude-desktop-2.19675.1/lib/claude-desktop/resources/virtiofsd
claude-desktop>     libseccomp.so.2 -> found: /nix/store/k81akx4837d7ghz4mfkr7kwzinw4qhp6-libseccomp-2.6.1-lib/lib
claude-desktop>     libcap-ng.so.0 -> found: /nix/store/w0xkd23405sbslbfnbhzcwwclvrsnwcf-libcap-ng-0.9.6/lib
claude-desktop>     libgcc_s.so.1 -> found: /nix/store/q2mkz6ca1alqfqf750dygvakmq8kjrwz-gcc-16.2.0-libgcc/lib
claude-desktop> setting RPATH to: /nix/store/k81akx4837d7ghz4mfkr7kwzinw4qhp6-libseccomp-2.6.1-lib/lib:/nix/store/w0xkd23405sbslbfnbhzcwwclvrsnwcf-libcap-ng-0.9.6/lib:/nix/store/q2mkz6ca1alqfqf750dygvakmq8kjrwz-gcc-16.2.0-libgcc/lib:/nix/store/mj9klbkhzal0vc1aazsajrydkimhc0h2-libglvnd-1.7.0/lib:/nix/store/rssqiz9l5knlan7fy5knf43zsrdwmg5g-libpulseaudio-17.0/lib
claude-desktop> skipping /nix/store/cfy30bkc7yhbgyvcswmhbwhzwiqk3rhb-claude-desktop-2.19675.1/lib/claude-desktop/resources/cowork-linux-helper because it is statically linked
claude-desktop> skipping /nix/store/cfy30bkc7yhbgyvcswmhbwhzwiqk3rhb-claude-desktop-2.19675.1/lib/claude-desktop/resources/app.asar.unpacked/resources/github-mcp/github-mcp-server because it is statically linked
claude-desktop> searching for dependencies of /nix/store/cfy30bkc7yhbgyvcswmhbwhzwiqk3rhb-claude-desktop-2.19675.1/lib/claude-desktop/resources/app.asar.unpacked/node_modules/node-pty/prebuilds/linux-x64/pty.node
claude-desktop>     libstdc++.so.6 -> found: /nix/store/j7qx4s4mr17j1wqgvqdzj33lmrnzb387-gcc-16.2.0-lib/lib
claude-desktop>     libgcc_s.so.1 -> found: /nix/store/q2mkz6ca1alqfqf750dygvakmq8kjrwz-gcc-16.2.0-libgcc/lib
claude-desktop> setting RPATH to: /nix/store/j7qx4s4mr17j1wqgvqdzj33lmrnzb387-gcc-16.2.0-lib/lib:/nix/store/q2mkz6ca1alqfqf750dygvakmq8kjrwz-gcc-16.2.0-libgcc/lib:/nix/store/mj9klbkhzal0vc1aazsajrydkimhc0h2-libglvnd-1.7.0/lib:/nix/store/rssqiz9l5knlan7fy5knf43zsrdwmg5g-libpulseaudio-17.0/lib
claude-desktop> searching for dependencies of /nix/store/cfy30bkc7yhbgyvcswmhbwhzwiqk3rhb-claude-desktop-2.19675.1/lib/claude-desktop/resources/app.asar.unpacked/node_modules/@ant/claude-native/claude-native-binding.node
claude-desktop>     libpipewire-0.3.so.0 -> not found!
claude-desktop>     libgcc_s.so.1 -> found: /nix/store/q2mkz6ca1alqfqf750dygvakmq8kjrwz-gcc-16.2.0-libgcc/lib
claude-desktop> setting RPATH to: /nix/store/q2mkz6ca1alqfqf750dygvakmq8kjrwz-gcc-16.2.0-libgcc/lib:/nix/store/mj9klbkhzal0vc1aazsajrydkimhc0h2-libglvnd-1.7.0/lib:/nix/store/rssqiz9l5knlan7fy5knf43zsrdwmg5g-libpulseaudio-17.0/lib
claude-desktop> auto-patchelf: 1 dependencies could not be satisfied
claude-desktop> error: auto-patchelf could not satisfy dependency libpipewire-0.3.so.0 wanted by /nix/store/cfy30bkc7yhbgyvcswmhbwhzwiqk3rhb-claude-desktop-2.19675.1/lib/claude-desktop/resources/app.asar.unpacked/node_modules/@ant/claude-native/claude-native-binding.node
claude-desktop> auto-patchelf failed to find all the required dependencies.
claude-desktop> Add the missing dependencies to --libs or use `--ignore-missing="foo.so.1 bar.so etc.so"`.
error: build of '/nix/store/9fz2nkbsn0l0z466l5fhg05ddrda14ff-claude-desktop-2.19675.1.drv^*' failed: Cannot build '/nix/store/9fz2nkbsn0l0z466l5fhg05ddrda14ff-claude-desktop-2.19675.1.drv'.
       Reason: builder failed with exit code 1.
       Output paths:
         /nix/store/cfy30bkc7yhbgyvcswmhbwhzwiqk3rhb-claude-desktop-2.19675.1
       Last 25 log lines:
       > setting RPATH to: /nix/store/mj9klbkhzal0vc1aazsajrydkimhc0h2-libglvnd-1.7.0/lib:/nix/store/rssqiz9l5knlan7fy5knf43zsrdwmg5g-libpulseaudio-17.0/lib
       > setting interpreter of /nix/store/cfy30bkc7yhbgyvcswmhbwhzwiqk3rhb-claude-desktop-2.19675.1/lib/claude-desktop/resources/chrome-native-host
       > searching for dependencies of /nix/store/cfy30bkc7yhbgyvcswmhbwhzwiqk3rhb-claude-desktop-2.19675.1/lib/claude-desktop/resources/chrome-native-host
       >     libgcc_s.so.1 -> found: /nix/store/q2mkz6ca1alqfqf750dygvakmq8kjrwz-gcc-16.2.0-libgcc/lib
       > setting RPATH to: /nix/store/q2mkz6ca1alqfqf750dygvakmq8kjrwz-gcc-16.2.0-libgcc/lib:/nix/store/mj9klbkhzal0vc1aazsajrydkimhc0h2-libglvnd-1.7.0/lib:/nix/store/rssqiz9l5knlan7fy5knf43zsrdwmg5g-libpulseaudio-17.0/lib
       > setting interpreter of /nix/store/cfy30bkc7yhbgyvcswmhbwhzwiqk3rhb-claude-desktop-2.19675.1/lib/claude-desktop/resources/virtiofsd
       > searching for dependencies of /nix/store/cfy30bkc7yhbgyvcswmhbwhzwiqk3rhb-claude-desktop-2.19675.1/lib/claude-desktop/resources/virtiofsd
       >     libseccomp.so.2 -> found: /nix/store/k81akx4837d7ghz4mfkr7kwzinw4qhp6-libseccomp-2.6.1-lib/lib
       >     libcap-ng.so.0 -> found: /nix/store/w0xkd23405sbslbfnbhzcwwclvrsnwcf-libcap-ng-0.9.6/lib
       >     libgcc_s.so.1 -> found: /nix/store/q2mkz6ca1alqfqf750dygvakmq8kjrwz-gcc-16.2.0-libgcc/lib
       > setting RPATH to: /nix/store/k81akx4837d7ghz4mfkr7kwzinw4qhp6-libseccomp-2.6.1-lib/lib:/nix/store/w0xkd23405sbslbfnbhzcwwclvrsnwcf-libcap-ng-0.9.6/lib:/nix/store/q2mkz6ca1alqfqf750dygvakmq8kjrwz-gcc-16.2.0-libgcc/lib:/nix/store/mj9klbkhzal0vc1aazsajrydkimhc0h2-libglvnd-1.7.0/lib:/nix/store/rssqiz9l5knlan7fy5knf43zsrdwmg5g-libpulseaudio-17.0/lib
       > skipping /nix/store/cfy30bkc7yhbgyvcswmhbwhzwiqk3rhb-claude-desktop-2.19675.1/lib/claude-desktop/resources/cowork-linux-helper because it is statically linked
       > skipping /nix/store/cfy30bkc7yhbgyvcswmhbwhzwiqk3rhb-claude-desktop-2.19675.1/lib/claude-desktop/resources/app.asar.unpacked/resources/github-mcp/github-mcp-server because it is statically linked
       > searching for dependencies of /nix/store/cfy30bkc7yhbgyvcswmhbwhzwiqk3rhb-claude-desktop-2.19675.1/lib/claude-desktop/resources/app.asar.unpacked/node_modules/node-pty/prebuilds/linux-x64/pty.node
       >     libstdc++.so.6 -> found: /nix/store/j7qx4s4mr17j1wqgvqdzj33lmrnzb387-gcc-16.2.0-lib/lib
       >     libgcc_s.so.1 -> found: /nix/store/q2mkz6ca1alqfqf750dygvakmq8kjrwz-gcc-16.2.0-libgcc/lib
       > setting RPATH to: /nix/store/j7qx4s4mr17j1wqgvqdzj33lmrnzb387-gcc-16.2.0-lib/lib:/nix/store/q2mkz6ca1alqfqf750dygvakmq8kjrwz-gcc-16.2.0-libgcc/lib:/nix/store/mj9klbkhzal0vc1aazsajrydkimhc0h2-libglvnd-1.7.0/lib:/nix/store/rssqiz9l5knlan7fy5knf43zsrdwmg5g-libpulseaudio-17.0/lib
       > searching for dependencies of /nix/store/cfy30bkc7yhbgyvcswmhbwhzwiqk3rhb-claude-desktop-2.19675.1/lib/claude-desktop/resources/app.asar.unpacked/node_modules/@ant/claude-native/claude-native-binding.node
       >     libpipewire-0.3.so.0 -> not found!
       >     libgcc_s.so.1 -> found: /nix/store/q2mkz6ca1alqfqf750dygvakmq8kjrwz-gcc-16.2.0-libgcc/lib
       > setting RPATH to: /nix/store/q2mkz6ca1alqfqf750dygvakmq8kjrwz-gcc-16.2.0-libgcc/lib:/nix/store/mj9klbkhzal0vc1aazsajrydkimhc0h2-libglvnd-1.7.0/lib:/nix/store/rssqiz9l5knlan7fy5knf43zsrdwmg5g-libpulseaudio-17.0/lib
       > auto-patchelf: 1 dependencies could not be satisfied
       > error: auto-patchelf could not satisfy dependency libpipewire-0.3.so.0 wanted by /nix/store/cfy30bkc7yhbgyvcswmhbwhzwiqk3rhb-claude-desktop-2.19675.1/lib/claude-desktop/resources/app.asar.unpacked/node_modules/@ant/claude-native/claude-native-binding.node
       > auto-patchelf failed to find all the required dependencies.
       > Add the missing dependencies to --libs or use `--ignore-missing="foo.so.1 bar.so etc.so"`.
       For full logs, run:
         nix log /nix/store/9fz2nkbsn0l0z466l5fhg05ddrda14ff-claude-desktop-2.19675.1.drv
```
#### NixOS VM tests
```text
vm-test-ubuntu_24_04> vm: (finished: must succeed: test "$(readlink -f /nix/var/nix/profiles/system-manager-profiles/system-manager)" = /nix/store/6llcl1zm188cm8jxdyhr2ds33lg7fx9q-system-manager, in 0.01 seconds)
vm-test-ubuntu_24_04> vm: must succeed: sha256sum /etc/passwd /etc/group /etc/shadow /etc/gshadow /etc/subuid /etc/subgid /etc/shells
vm-test-ubuntu_24_04> vm: (finished: must succeed: sha256sum /etc/passwd /etc/group /etc/shadow /etc/gshadow /etc/subuid /etc/subgid /etc/shells, in 0.01 seconds)
vm-test-ubuntu_24_04> vm: must fail: runuser -u tester -- env 'HOME=/home/tester' 'USER=tester' 'XDG_RUNTIME_DIR=/run/user/1001' 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus' 'PATH=/nix/store/3lbxim6k1cpgl9bx17n5yay67s3ippgc-nr-linux-1/bin:/nix/store/cv7vd1i121mj84jb694gjc3xvr0da4xw-nix-2.34.8/bin:/usr/sbin:/usr/bin:/sbin:/bin' bash -c 'NR_SYSTEM_OUT=/nix/store/cr8iy4v7k852jfjm3anizxavmgsyvmm3-system-manager NR_HOME_OUT=/nix/store/ihrh60jvql5lk3b10rm6jmxc332jjhn1-home-manager-generation nr switch --host hollyhock' 2>&1
vm-test-ubuntu_24_04> vm: (finished: must fail: runuser -u tester -- env 'HOME=/home/tester' 'USER=tester' 'XDG_RUNTIME_DIR=/run/user/1001' 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus' 'PATH=/nix/store/3lbxim6k1cpgl9bx17n5yay67s3ippgc-nr-linux-1/bin:/nix/store/cv7vd1i121mj84jb694gjc3xvr0da4xw-nix-2.34.8/bin:/usr/sbin:/usr/bin:/sbin:/bin' bash -c 'NR_SYSTEM_OUT=/nix/store/cr8iy4v7k852jfjm3anizxavmgsyvmm3-system-manager NR_HOME_OUT=/nix/store/ihrh60jvql5lk3b10rm6jmxc332jjhn1-home-manager-generation nr switch --host hollyhock' 2>&1, in 0.04 seconds)
vm-test-ubuntu_24_04> vm: must fail: runuser -u tester -- env 'HOME=/home/tester' 'USER=tester' 'XDG_RUNTIME_DIR=/run/user/1001' 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus' 'PATH=/nix/store/3lbxim6k1cpgl9bx17n5yay67s3ippgc-nr-linux-1/bin:/nix/store/cv7vd1i121mj84jb694gjc3xvr0da4xw-nix-2.34.8/bin:/usr/sbin:/usr/bin:/sbin:/bin' bash -c '/nix/store/ihrh60jvql5lk3b10rm6jmxc332jjhn1-home-manager-generation/activate 2>&1'
vm-test-ubuntu_24_04> vm: (finished: must fail: runuser -u tester -- env 'HOME=/home/tester' 'USER=tester' 'XDG_RUNTIME_DIR=/run/user/1001' 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus' 'PATH=/nix/store/3lbxim6k1cpgl9bx17n5yay67s3ippgc-nr-linux-1/bin:/nix/store/cv7vd1i121mj84jb694gjc3xvr0da4xw-nix-2.34.8/bin:/usr/sbin:/usr/bin:/sbin:/bin' bash -c '/nix/store/ihrh60jvql5lk3b10rm6jmxc332jjhn1-home-manager-generation/activate 2>&1', in 0.58 seconds)
vm-test-ubuntu_24_04> vm: must succeed: runuser -u tester -- env 'HOME=/home/tester' 'USER=tester' 'XDG_RUNTIME_DIR=/run/user/1001' 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus' 'PATH=/nix/store/3lbxim6k1cpgl9bx17n5yay67s3ippgc-nr-linux-1/bin:/nix/store/cv7vd1i121mj84jb694gjc3xvr0da4xw-nix-2.34.8/bin:/usr/sbin:/usr/bin:/sbin:/bin' bash -c 'readlink -f /home/tester/.local/state/home-manager/gcroots/current-home'
vm-test-ubuntu_24_04> vm: (finished: must succeed: runuser -u tester -- env 'HOME=/home/tester' 'USER=tester' 'XDG_RUNTIME_DIR=/run/user/1001' 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus' 'PATH=/nix/store/3lbxim6k1cpgl9bx17n5yay67s3ippgc-nr-linux-1/bin:/nix/store/cv7vd1i121mj84jb694gjc3xvr0da4xw-nix-2.34.8/bin:/usr/sbin:/usr/bin:/sbin:/bin' bash -c 'readlink -f /home/tester/.local/state/home-manager/gcroots/current-home', in 0.01 seconds)
vm-test-ubuntu_24_04> vm: must succeed: runuser -u tester -- env 'HOME=/home/tester' 'USER=tester' 'XDG_RUNTIME_DIR=/run/user/1001' 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus' 'PATH=/nix/store/3lbxim6k1cpgl9bx17n5yay67s3ippgc-nr-linux-1/bin:/nix/store/cv7vd1i121mj84jb694gjc3xvr0da4xw-nix-2.34.8/bin:/usr/sbin:/usr/bin:/sbin:/bin' bash -c 'install -d -m 700 /home/tester/.config/nix-config/age && install -m 600 /nix/store/s517hisya20289bp35647ydb9nl8a07b-fake-non-nixos-secrets/other-key.txt /home/tester/.config/nix-config/age/key.txt'
vm-test-ubuntu_24_04> vm: (finished: must succeed: runuser -u tester -- env 'HOME=/home/tester' 'USER=tester' 'XDG_RUNTIME_DIR=/run/user/1001' 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus' 'PATH=/nix/store/3lbxim6k1cpgl9bx17n5yay67s3ippgc-nr-linux-1/bin:/nix/store/cv7vd1i121mj84jb694gjc3xvr0da4xw-nix-2.34.8/bin:/usr/sbin:/usr/bin:/sbin:/bin' bash -c 'install -d -m 700 /home/tester/.config/nix-config/age && install -m 600 /nix/store/s517hisya20289bp35647ydb9nl8a07b-fake-non-nixos-secrets/other-key.txt /home/tester/.config/nix-config/age/key.txt', in 0.02 seconds)
vm-test-ubuntu_24_04> vm: must fail: runuser -u tester -- env 'HOME=/home/tester' 'USER=tester' 'XDG_RUNTIME_DIR=/run/user/1001' 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus' 'PATH=/nix/store/3lbxim6k1cpgl9bx17n5yay67s3ippgc-nr-linux-1/bin:/nix/store/cv7vd1i121mj84jb694gjc3xvr0da4xw-nix-2.34.8/bin:/usr/sbin:/usr/bin:/sbin:/bin' bash -c 'NR_SYSTEM_OUT=/nix/store/cr8iy4v7k852jfjm3anizxavmgsyvmm3-system-manager NR_HOME_OUT=/nix/store/ihrh60jvql5lk3b10rm6jmxc332jjhn1-home-manager-generation nr switch --host hollyhock' 2>&1
vm-test-ubuntu_24_04> vm: (finished: must fail: runuser -u tester -- env 'HOME=/home/tester' 'USER=tester' 'XDG_RUNTIME_DIR=/run/user/1001' 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus' 'PATH=/nix/store/3lbxim6k1cpgl9bx17n5yay67s3ippgc-nr-linux-1/bin:/nix/store/cv7vd1i121mj84jb694gjc3xvr0da4xw-nix-2.34.8/bin:/usr/sbin:/usr/bin:/sbin:/bin' bash -c 'NR_SYSTEM_OUT=/nix/store/cr8iy4v7k852jfjm3anizxavmgsyvmm3-system-manager NR_HOME_OUT=/nix/store/ihrh60jvql5lk3b10rm6jmxc332jjhn1-home-manager-generation nr switch --host hollyhock' 2>&1, in 1.60 seconds)
vm-test-ubuntu_24_04> vm: must succeed: runuser -u tester -- env 'HOME=/home/tester' 'USER=tester' 'XDG_RUNTIME_DIR=/run/user/1001' 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus' 'PATH=/nix/store/3lbxim6k1cpgl9bx17n5yay67s3ippgc-nr-linux-1/bin:/nix/store/cv7vd1i121mj84jb694gjc3xvr0da4xw-nix-2.34.8/bin:/usr/sbin:/usr/bin:/sbin:/bin' bash -c 'readlink -f /home/tester/.local/state/home-manager/gcroots/current-home'
vm-test-ubuntu_24_04> vm: (finished: must succeed: runuser -u tester -- env 'HOME=/home/tester' 'USER=tester' 'XDG_RUNTIME_DIR=/run/user/1001' 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus' 'PATH=/nix/store/3lbxim6k1cpgl9bx17n5yay67s3ippgc-nr-linux-1/bin:/nix/store/cv7vd1i121mj84jb694gjc3xvr0da4xw-nix-2.34.8/bin:/usr/sbin:/usr/bin:/sbin:/bin' bash -c 'readlink -f /home/tester/.local/state/home-manager/gcroots/current-home', in 0.01 seconds)
vm-test-ubuntu_24_04> vm: must succeed: runuser -u tester -- env 'HOME=/home/tester' 'USER=tester' 'XDG_RUNTIME_DIR=/run/user/1001' 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus' 'PATH=/nix/store/3lbxim6k1cpgl9bx17n5yay67s3ippgc-nr-linux-1/bin:/nix/store/cv7vd1i121mj84jb694gjc3xvr0da4xw-nix-2.34.8/bin:/usr/sbin:/usr/bin:/sbin:/bin' bash -c 'rm /home/tester/.config/nix-config/age/key.txt && /nix/store/p2y037nmyix79dp71rqgrfilpzc2s8k2-install-user-age-identity-1/bin/install-user-age-identity --recipient $(cat /nix/store/s517hisya20289bp35647ydb9nl8a07b-fake-non-nixos-secrets/recipient.txt) < /nix/store/s517hisya20289bp35647ydb9nl8a07b-fake-non-nixos-secrets/key.txt'
vm-test-ubuntu_24_04> vm: (finished: must succeed: runuser -u tester -- env 'HOME=/home/tester' 'USER=tester' 'XDG_RUNTIME_DIR=/run/user/1001' 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus' 'PATH=/nix/store/3lbxim6k1cpgl9bx17n5yay67s3ippgc-nr-linux-1/bin:/nix/store/cv7vd1i121mj84jb694gjc3xvr0da4xw-nix-2.34.8/bin:/usr/sbin:/usr/bin:/sbin:/bin' bash -c 'rm /home/tester/.config/nix-config/age/key.txt && /nix/store/p2y037nmyix79dp71rqgrfilpzc2s8k2-install-user-age-identity-1/bin/install-user-age-identity --recipient $(cat /nix/store/s517hisya20289bp35647ydb9nl8a07b-fake-non-nixos-secrets/recipient.txt) < /nix/store/s517hisya20289bp35647ydb9nl8a07b-fake-non-nixos-secrets/key.txt', in 0.21 seconds)
vm-test-ubuntu_24_04> vm: must succeed: runuser -u tester -- env 'HOME=/home/tester' 'USER=tester' 'XDG_RUNTIME_DIR=/run/user/1001' 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus' 'PATH=/nix/store/3lbxim6k1cpgl9bx17n5yay67s3ippgc-nr-linux-1/bin:/nix/store/cv7vd1i121mj84jb694gjc3xvr0da4xw-nix-2.34.8/bin:/usr/sbin:/usr/bin:/sbin:/bin' bash -c 'NR_SYSTEM_OUT=/nix/store/cr8iy4v7k852jfjm3anizxavmgsyvmm3-system-manager NR_HOME_OUT=/nix/store/ihrh60jvql5lk3b10rm6jmxc332jjhn1-home-manager-generation nr switch --host hollyhock' 2>&1
vm-test-ubuntu_24_04> vm: (finished: must succeed: runuser -u tester -- env 'HOME=/home/tester' 'USER=tester' 'XDG_RUNTIME_DIR=/run/user/1001' 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus' 'PATH=/nix/store/3lbxim6k1cpgl9bx17n5yay67s3ippgc-nr-linux-1/bin:/nix/store/cv7vd1i121mj84jb694gjc3xvr0da4xw-nix-2.34.8/bin:/usr/sbin:/usr/bin:/sbin:/bin' bash -c 'NR_SYSTEM_OUT=/nix/store/cr8iy4v7k852jfjm3anizxavmgsyvmm3-system-manager NR_HOME_OUT=/nix/store/ihrh60jvql5lk3b10rm6jmxc332jjhn1-home-manager-generation nr switch --host hollyhock' 2>&1, in 7.83 seconds)
vm-test-ubuntu_24_04> vm: must succeed: stat -c '%a %U' /home/tester/.config/gh/hosts.yml
vm-test-ubuntu_24_04> vm: (finished: must succeed: stat -c '%a %U' /home/tester/.config/gh/hosts.yml, in 0.01 seconds)
vm-test-ubuntu_24_04> vm: must succeed: stat -c '%a %U' /home/tester/.config/glab-cli/config.yml
vm-test-ubuntu_24_04> vm: (finished: must succeed: stat -c '%a %U' /home/tester/.config/glab-cli/config.yml, in 0.00 seconds)
vm-test-ubuntu_24_04> vm: must succeed: stat -c '%a %U' /home/tester/.ssh/id_ed25519_nix_config
vm-test-ubuntu_24_04> vm: (finished: must succeed: stat -c '%a %U' /home/tester/.ssh/id_ed25519_nix_config, in 0.00 seconds)
vm-test-ubuntu_24_04> vm: must succeed: sha256sum /home/tester/.config/gh/hosts.yml /home/tester/.config/glab-cli/config.yml /home/tester/.ssh/id_ed25519_nix_config
vm-test-ubuntu_24_04> vm: (finished: must succeed: sha256sum /home/tester/.config/gh/hosts.yml /home/tester/.config/glab-cli/config.yml /home/tester/.ssh/id_ed25519_nix_config, in 0.00 seconds)
vm-test-ubuntu_24_04> vm: must succeed: sha256sum /etc/passwd /etc/group /etc/shadow /etc/gshadow /etc/subuid /etc/subgid /etc/shells
vm-test-ubuntu_24_04> vm: (finished: must succeed: sha256sum /etc/passwd /etc/group /etc/shadow /etc/gshadow /etc/subuid /etc/subgid /etc/shells, in 0.01 seconds)
vm-test-ubuntu_24_04> vm: must succeed: runuser -u tester -- env 'HOME=/home/tester' 'USER=tester' 'XDG_RUNTIME_DIR=/run/user/1001' 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus' 'PATH=/nix/store/3lbxim6k1cpgl9bx17n5yay67s3ippgc-nr-linux-1/bin:/nix/store/cv7vd1i121mj84jb694gjc3xvr0da4xw-nix-2.34.8/bin:/usr/sbin:/usr/bin:/sbin:/bin' bash -c 'NR_SYSTEM_OUT=/nix/store/cr8iy4v7k852jfjm3anizxavmgsyvmm3-system-manager NR_HOME_OUT=/nix/store/ihrh60jvql5lk3b10rm6jmxc332jjhn1-home-manager-generation nr switch --host hollyhock' 2>&1
vm-test-ubuntu_24_04> vm: (finished: must succeed: runuser -u tester -- env 'HOME=/home/tester' 'USER=tester' 'XDG_RUNTIME_DIR=/run/user/1001' 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus' 'PATH=/nix/store/3lbxim6k1cpgl9bx17n5yay67s3ippgc-nr-linux-1/bin:/nix/store/cv7vd1i121mj84jb694gjc3xvr0da4xw-nix-2.34.8/bin:/usr/sbin:/usr/bin:/sbin:/bin' bash -c 'NR_SYSTEM_OUT=/nix/store/cr8iy4v7k852jfjm3anizxavmgsyvmm3-system-manager NR_HOME_OUT=/nix/store/ihrh60jvql5lk3b10rm6jmxc332jjhn1-home-manager-generation nr switch --host hollyhock' 2>&1, in 7.21 seconds)
vm-test-ubuntu_24_04> vm: must succeed: stat -c '%a %U' /home/tester/.config/gh/hosts.yml
vm-test-ubuntu_24_04> vm: (finished: must succeed: stat -c '%a %U' /home/tester/.config/gh/hosts.yml, in 0.01 seconds)
vm-test-ubuntu_24_04> vm: must succeed: stat -c '%a %U' /home/tester/.config/glab-cli/config.yml
vm-test-ubuntu_24_04> vm: (finished: must succeed: stat -c '%a %U' /home/tester/.config/glab-cli/config.yml, in 0.00 seconds)
vm-test-ubuntu_24_04> vm: must succeed: stat -c '%a %U' /home/tester/.ssh/id_ed25519_nix_config
vm-test-ubuntu_24_04> vm: (finished: must succeed: stat -c '%a %U' /home/tester/.ssh/id_ed25519_nix_config, in 0.00 seconds)
vm-test-ubuntu_24_04> vm: must succeed: sha256sum /home/tester/.config/gh/hosts.yml /home/tester/.config/glab-cli/config.yml /home/tester/.ssh/id_ed25519_nix_config
vm-test-ubuntu_24_04> vm: (finished: must succeed: sha256sum /home/tester/.config/gh/hosts.yml /home/tester/.config/glab-cli/config.yml /home/tester/.ssh/id_ed25519_nix_config, in 0.01 seconds)
vm-test-ubuntu_24_04> vm: must succeed: sha256sum /etc/passwd /etc/group /etc/shadow /etc/gshadow /etc/subuid /etc/subgid /etc/shells
vm-test-ubuntu_24_04> vm: (finished: must succeed: sha256sum /etc/passwd /etc/group /etc/shadow /etc/gshadow /etc/subuid /etc/subgid /etc/shells, in 0.01 seconds)
vm-test-ubuntu_24_04> vm: must succeed: runuser -u tester -- env 'HOME=/home/tester' 'USER=tester' 'XDG_RUNTIME_DIR=/run/user/1001' 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus' 'PATH=/nix/store/3lbxim6k1cpgl9bx17n5yay67s3ippgc-nr-linux-1/bin:/nix/store/cv7vd1i121mj84jb694gjc3xvr0da4xw-nix-2.34.8/bin:/usr/sbin:/usr/bin:/sbin:/bin' bash -c 'NR_SYSTEM_OUT=/nix/store/6llcl1zm188cm8jxdyhr2ds33lg7fx9q-system-manager NR_HOME_OUT=/nix/store/3gil0mbfc75aplac0yqn60rlimpfxx2j-home-manager-generation nr switch --host hollyhock --bootstrap' 2>&1
vm-test-ubuntu_24_04> vm: (finished: must succeed: runuser -u tester -- env 'HOME=/home/tester' 'USER=tester' 'XDG_RUNTIME_DIR=/run/user/1001' 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus' 'PATH=/nix/store/3lbxim6k1cpgl9bx17n5yay67s3ippgc-nr-linux-1/bin:/nix/store/cv7vd1i121mj84jb694gjc3xvr0da4xw-nix-2.34.8/bin:/usr/sbin:/usr/bin:/sbin:/bin' bash -c 'NR_SYSTEM_OUT=/nix/store/6llcl1zm188cm8jxdyhr2ds33lg7fx9q-system-manager NR_HOME_OUT=/nix/store/3gil0mbfc75aplac0yqn60rlimpfxx2j-home-manager-generation nr switch --host hollyhock --bootstrap' 2>&1, in 6.31 seconds)
vm-test-ubuntu_24_04> vm: must succeed: stat -c '%a %U' /home/tester/.config/gh/hosts.yml
vm-test-ubuntu_24_04> vm: (finished: must succeed: stat -c '%a %U' /home/tester/.config/gh/hosts.yml, in 0.01 seconds)
vm-test-ubuntu_24_04> vm: must succeed: stat -c '%a %U' /home/tester/.config/glab-cli/config.yml
vm-test-ubuntu_24_04> vm: (finished: must succeed: stat -c '%a %U' /home/tester/.config/glab-cli/config.yml, in 0.00 seconds)
vm-test-ubuntu_24_04> vm: must succeed: stat -c '%a %U' /home/tester/.ssh/id_ed25519_nix_config
vm-test-ubuntu_24_04> vm: (finished: must succeed: stat -c '%a %U' /home/tester/.ssh/id_ed25519_nix_config, in 0.00 seconds)
vm-test-ubuntu_24_04> vm: must succeed: sha256sum /home/tester/.config/gh/hosts.yml /home/tester/.config/glab-cli/config.yml /home/tester/.ssh/id_ed25519_nix_config
vm-test-ubuntu_24_04> vm: (finished: must succeed: sha256sum /home/tester/.config/gh/hosts.yml /home/tester/.config/glab-cli/config.yml /home/tester/.ssh/id_ed25519_nix_config, in 0.01 seconds)
vm-test-ubuntu_24_04> vm: must succeed: sha256sum /etc/passwd /etc/group /etc/shadow /etc/gshadow /etc/subuid /etc/subgid /etc/shells
vm-test-ubuntu_24_04> vm: (finished: must succeed: sha256sum /etc/passwd /etc/group /etc/shadow /etc/gshadow /etc/subuid /etc/subgid /etc/shells, in 0.01 seconds)
vm-test-ubuntu_24_04> vm: must succeed: runuser -u tester -- env 'HOME=/home/tester' 'USER=tester' 'XDG_RUNTIME_DIR=/run/user/1001' 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus' 'PATH=/nix/store/3lbxim6k1cpgl9bx17n5yay67s3ippgc-nr-linux-1/bin:/nix/store/cv7vd1i121mj84jb694gjc3xvr0da4xw-nix-2.34.8/bin:/usr/sbin:/usr/bin:/sbin:/bin' bash -c 'NR_SYSTEM_OUT=/nix/store/cr8iy4v7k852jfjm3anizxavmgsyvmm3-system-manager NR_HOME_OUT=/nix/store/ihrh60jvql5lk3b10rm6jmxc332jjhn1-home-manager-generation nr switch --host hollyhock' 2>&1
vm-test-ubuntu_24_04> vm: (finished: must succeed: runuser -u tester -- env 'HOME=/home/tester' 'USER=tester' 'XDG_RUNTIME_DIR=/run/user/1001' 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus' 'PATH=/nix/store/3lbxim6k1cpgl9bx17n5yay67s3ippgc-nr-linux-1/bin:/nix/store/cv7vd1i121mj84jb694gjc3xvr0da4xw-nix-2.34.8/bin:/usr/sbin:/usr/bin:/sbin:/bin' bash -c 'NR_SYSTEM_OUT=/nix/store/cr8iy4v7k852jfjm3anizxavmgsyvmm3-system-manager NR_HOME_OUT=/nix/store/ihrh60jvql5lk3b10rm6jmxc332jjhn1-home-manager-generation nr switch --host hollyhock' 2>&1, in 7.44 seconds)
vm-test-ubuntu_24_04> vm: must succeed: stat -c '%a %U' /home/tester/.config/gh/hosts.yml
vm-test-ubuntu_24_04> vm: (finished: must succeed: stat -c '%a %U' /home/tester/.config/gh/hosts.yml, in 0.01 seconds)
vm-test-ubuntu_24_04> vm: must succeed: stat -c '%a %U' /home/tester/.config/glab-cli/config.yml
vm-test-ubuntu_24_04> vm: (finished: must succeed: stat -c '%a %U' /home/tester/.config/glab-cli/config.yml, in 0.00 seconds)
vm-test-ubuntu_24_04> vm: must succeed: stat -c '%a %U' /home/tester/.ssh/id_ed25519_nix_config
vm-test-ubuntu_24_04> vm: (finished: must succeed: stat -c '%a %U' /home/tester/.ssh/id_ed25519_nix_config, in 0.00 seconds)
vm-test-ubuntu_24_04> vm: must succeed: sha256sum /home/tester/.config/gh/hosts.yml /home/tester/.config/glab-cli/config.yml /home/tester/.ssh/id_ed25519_nix_config
vm-test-ubuntu_24_04> vm: (finished: must succeed: sha256sum /home/tester/.config/gh/hosts.yml /home/tester/.config/glab-cli/config.yml /home/tester/.ssh/id_ed25519_nix_config, in 0.01 seconds)
vm-test-ubuntu_24_04> vm: must succeed: sha256sum /etc/passwd /etc/group /etc/shadow /etc/gshadow /etc/subuid /etc/subgid /etc/shells
vm-test-ubuntu_24_04> vm: (finished: must succeed: sha256sum /etc/passwd /etc/group /etc/shadow /etc/gshadow /etc/subuid /etc/subgid /etc/shells, in 0.01 seconds)
vm-test-ubuntu_24_04> vm: must succeed: runuser -u tester -- env 'HOME=/home/tester' 'USER=tester' 'XDG_RUNTIME_DIR=/run/user/1001' 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus' 'PATH=/nix/store/3lbxim6k1cpgl9bx17n5yay67s3ippgc-nr-linux-1/bin:/nix/store/cv7vd1i121mj84jb694gjc3xvr0da4xw-nix-2.34.8/bin:/usr/sbin:/usr/bin:/sbin:/bin' bash -c 'grep -q FAKE-CANARY-github /home/tester/.config/gh/hosts.yml'
vm-test-ubuntu_24_04> vm: (finished: must succeed: runuser -u tester -- env 'HOME=/home/tester' 'USER=tester' 'XDG_RUNTIME_DIR=/run/user/1001' 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus' 'PATH=/nix/store/3lbxim6k1cpgl9bx17n5yay67s3ippgc-nr-linux-1/bin:/nix/store/cv7vd1i121mj84jb694gjc3xvr0da4xw-nix-2.34.8/bin:/usr/sbin:/usr/bin:/sbin:/bin' bash -c 'grep -q FAKE-CANARY-github /home/tester/.config/gh/hosts.yml', in 0.01 seconds)
vm-test-ubuntu_24_04> vm: must succeed: runuser -u tester -- env 'HOME=/home/tester' 'USER=tester' 'XDG_RUNTIME_DIR=/run/user/1001' 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus' 'PATH=/nix/store/3lbxim6k1cpgl9bx17n5yay67s3ippgc-nr-linux-1/bin:/nix/store/cv7vd1i121mj84jb694gjc3xvr0da4xw-nix-2.34.8/bin:/usr/sbin:/usr/bin:/sbin:/bin' bash -c 'ssh -G example.invalid | grep -qE '\''^identityfile (~|/home/tester)/.ssh/id_ed25519_nix_config$'\'''
vm-test-ubuntu_24_04> vm: (finished: must succeed: runuser -u tester -- env 'HOME=/home/tester' 'USER=tester' 'XDG_RUNTIME_DIR=/run/user/1001' 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus' 'PATH=/nix/store/3lbxim6k1cpgl9bx17n5yay67s3ippgc-nr-linux-1/bin:/nix/store/cv7vd1i121mj84jb694gjc3xvr0da4xw-nix-2.34.8/bin:/usr/sbin:/usr/bin:/sbin:/bin' bash -c 'ssh -G example.invalid | grep -qE '\''^identityfile (~|/home/tester)/.ssh/id_ed25519_nix_config$'\''', in 0.03 seconds)
vm-test-ubuntu_24_04> vm: must succeed: test "$(ssh-keygen -y -f /home/tester/.ssh/id_ed25519_nix_config | cut -d' ' -f1,2)" = "$(cut -d' ' -f1,2 /nix/store/s517hisya20289bp35647ydb9nl8a07b-fake-non-nixos-secrets/ssh.pub)"
vm-test-ubuntu_24_04> vm: (finished: must succeed: test "$(ssh-keygen -y -f /home/tester/.ssh/id_ed25519_nix_config | cut -d' ' -f1,2)" = "$(cut -d' ' -f1,2 /nix/store/s517hisya20289bp35647ydb9nl8a07b-fake-non-nixos-secrets/ssh.pub)", in 0.02 seconds)
vm-test-ubuntu_24_04> vm: must succeed: journalctl --no-pager
vm-test-ubuntu_24_04> vm: (finished: must succeed: journalctl --no-pager, in 0.02 seconds)
vm-test-ubuntu_24_04> (finished: run the VM test script, in 142.02 seconds)
vm-test-ubuntu_24_04> test script finished in 142.14s
vm-test-ubuntu_24_04> cleanup
vm-test-ubuntu_24_04> kill QemuMachine (pid 45)
vm-test-ubuntu_24_04> vm #                                                    qemu-kvm: terminating on signal 15 from pid 39 (/nix/store/lb41b0anx1f98y9y5s9mdv97gjgsq740-python3-3.14.7/bin/python3.14)
vm-test-ubuntu_24_04> (finished: cleanup, in 0.07 seconds)
building '/nix/store/3rrxgn5k1fr8mcb47wr546mpibyg9zp8-vm-checks.drv'...
```

Push a fix to this branch; CI runs on each push. This PR waits for you to review and merge it.
