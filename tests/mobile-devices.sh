#!/usr/bin/env bash
# Usage: bash tests/mobile-devices.sh <mobile-devices executable>
#
# Drives the device helper against a stub xcrun and a stub avdmanager. It
# downloads the newest iOS runtime only when it is missing, creates only the
# declared devices whose versioned names do not exist yet, keeps devices of an
# older version, a hand-made device, and an undeclared one, skips a platform
# whose tool is missing with one message, reports a device it cannot create,
# and always exits 0. No scenario may delete, erase, rename, or move anything.
set -euo pipefail

helper=$1
fail=0
bad() { echo "mobile-devices: $*" >&2; fail=1; }

# State the stubs read and write, under $STUB:
#   sdk        the iOS Simulator SDK version xcodebuild reports
#   no-xcode   present when xcrun cannot find xcodebuild or simctl
#   runtimes   one installed runtime version per line
#   sims       one simulator per line: <runtime id>|<name>
#   avds       one AVD name per line
#   calls      every call, its arguments joined with |
#   stdin      what avdmanager create read from stdin
stub=$(mktemp -d)
mkdir -p "$stub/sdk/cmdline-tools/latest/bin" "$stub/no-avdmanager"
# The build sandbox has no /usr/bin/env, so the stubs name this bash.
printf '#!%s\n' "$BASH" > "$stub/xcrun"
cat >> "$stub/xcrun" <<'EOF'
(IFS='|'; echo "xcrun|$*") >> "$STUB/calls"
if [ -e "$STUB/no-xcode" ]; then
  echo "xcrun: error: unable to find utility \"$1\", not a developer tool or in PATH" >&2
  exit 72
fi
runtime_id() { echo "com.apple.CoreSimulator.SimRuntime.iOS-${1//./-}"; }
case "$1 $2" in
  "xcodebuild -showsdks")
    printf '[{"platform":"iphoneos","platformVersion":"%s"},' "$(cat "$STUB/sdk")"
    printf '{"platform":"iphonesimulator","platformVersion":"%s"},' "$(cat "$STUB/sdk")"
    printf '{"platform":"macosx","platformVersion":"99.0"}]\n'
    ;;
  "xcodebuild -downloadPlatform")
    cat "$STUB/sdk" >> "$STUB/runtimes"
    ;;
  "simctl list")
    case "$3" in
      runtimes)
        sep=
        printf '{"runtimes":['
        while read -r v; do
          printf '%s{"platform":"iOS","version":"%s","identifier":"%s","isAvailable":true}' "$sep" "$v" "$(runtime_id "$v")"
          sep=,
        done < "$STUB/runtimes"
        printf ']}\n'
        ;;
      devicetypes)
        printf '{"devicetypes":['
        printf '{"name":"iPhone 18","identifier":"com.apple.CoreSimulator.SimDeviceType.iPhone-18"},'
        printf '{"name":"iPhone 18 Pro","identifier":"com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro"},'
        printf '{"name":"iPhone 18 Pro Max","identifier":"com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro-Max"}'
        printf ']}\n'
        ;;
      devices)
        sep=
        printf '{"devices":{'
        while IFS='|' read -r rt name; do
          printf '%s"%s":[{"name":"%s","udid":"0000","state":"Shutdown"}]' "$sep" "$rt" "$name"
          sep=,
        done < "$STUB/sims"
        printf '}}\n'
        ;;
    esac
    ;;
  "simctl create")
    echo "$5|$3" >> "$STUB/sims"
    echo "1111-2222"
    ;;
esac
EOF
printf '#!%s\n' "$BASH" > "$stub/sdk/cmdline-tools/latest/bin/avdmanager"
cat >> "$stub/sdk/cmdline-tools/latest/bin/avdmanager" <<'EOF'
(IFS='|'; echo "avdmanager|$*") >> "$STUB/calls"
case "$1 $2" in
  "list avd") cat "$STUB/avds" ;;
  "create avd")
    cat >> "$STUB/stdin"
    # A device id avdmanager does not know.
    if [ "$8" = broken ]; then
      echo "Error: No device found matching --device broken" >&2
      exit 1
    fi
    echo "$4" >> "$STUB/avds"
    ;;
esac
EOF
chmod +x "$stub/xcrun" "$stub/sdk/cmdline-tools/latest/bin/avdmanager"

scenario() {
  STUB=$(mktemp -d)
  export STUB
  printf '%s\n' "$1" > "$STUB/sdk"
  touch "$STUB/runtimes" "$STUB/sims" "$STUB/avds" "$STUB/calls" "$STUB/stdin"
}
# Clears the call log and keeps the state, for a second apply.
again() { : > "$STUB/calls"; }
run() {
  local status=0
  "$helper" --xcrun "$stub/xcrun" --sdk-root "$stub/sdk" "$@" > "$STUB/out" 2> "$STUB/err" || status=$?
  [ "$status" = 0 ] || bad "$label: the helper exited $status: $(cat "$STUB/err")"
}
count() {
  local n
  n=$(grep -cFx "$1" "$STUB/calls") || true
  echo "${n:-0}"
}
creates() {
  local n
  n=$(grep -cE '^(xcrun\|simctl|avdmanager)\|create\|' "$STUB/calls") || true
  echo "${n:-0}"
}
downloads() { count 'xcrun|xcodebuild|-downloadPlatform|iOS'; }
sim_create() { echo "xcrun|simctl|create|$1|com.apple.CoreSimulator.SimDeviceType.${2}|com.apple.CoreSimulator.SimRuntime.iOS-${3//./-}"; }
avd_create() { echo "avdmanager|create|avd|-n|${1}_API_$2|-k|system-images;android-$2;google_apis;arm64-v8a|-d|$1"; }
has_line() { grep -qFx "$1" "$STUB/$2"; }
said() { grep -qF "$1" "$STUB/err"; }
nothing_removed() {
  if grep -qE '\|(delete|erase|rename|move|unpair)(\||$)' "$STUB/calls"; then
    bad "$label: the helper removed or changed a device: $(grep -E '\|(delete|erase|rename|move|unpair)(\||$)' "$STUB/calls")"
  fi
}

label="first apply"
scenario 27.0
run --android-api 37.0 --device "ios:iPhone 18 Pro" --device android:pixel_9
[ "$(downloads)" = 1 ] || bad "$label: the missing iOS 27.0 runtime was downloaded $(downloads) times, not once"
[ "$(count "$(sim_create "iPhone 18 Pro (iOS 27.0)" iPhone-18-Pro 27.0)")" = 1 ] \
  || bad "$label: iPhone 18 Pro (iOS 27.0) was not created once on the iOS 27.0 runtime: $(cat "$STUB/calls")"
[ "$(count "$(avd_create pixel_9 37.0)")" = 1 ] \
  || bad "$label: pixel_9_API_37.0 was not created once from the arm64 37.0 image: $(cat "$STUB/calls")"
[ "$(creates)" = 2 ] || bad "$label: $(creates) devices were created, not 2"
has_line no stdin || bad "$label: avdmanager's custom hardware prompt was not answered no"
nothing_removed

label="second apply (AE1)"
again
run --android-api 37.0 --device "ios:iPhone 18 Pro" --device android:pixel_9
[ "$(downloads)" = 0 ] || bad "$label: an installed runtime was downloaded again"
[ "$(creates)" = 0 ] || bad "$label: existing devices were created again: $(cat "$STUB/calls")"
nothing_removed

label="newer versions (AE2)"
scenario 27.1
echo 27.0 > "$STUB/runtimes"
echo "com.apple.CoreSimulator.SimRuntime.iOS-27-0|iPhone 18 Pro (iOS 27.0)" > "$STUB/sims"
echo pixel_9_API_36.0 > "$STUB/avds"
run --android-api 37.0 --device "ios:iPhone 18 Pro" --device android:pixel_9
[ "$(downloads)" = 1 ] || bad "$label: the iOS 27.1 runtime was downloaded $(downloads) times, not once"
[ "$(count "$(sim_create "iPhone 18 Pro (iOS 27.1)" iPhone-18-Pro 27.1)")" = 1 ] \
  || bad "$label: iPhone 18 Pro (iOS 27.1) was not created on the iOS 27.1 runtime: $(cat "$STUB/calls")"
[ "$(count "$(avd_create pixel_9 37.0)")" = 1 ] || bad "$label: pixel_9_API_37.0 was not created beside pixel_9_API_36.0"
has_line "com.apple.CoreSimulator.SimRuntime.iOS-27-0|iPhone 18 Pro (iOS 27.0)" sims || bad "$label: the iOS 27.0 device is gone"
has_line 27.0 runtimes || bad "$label: the iOS 27.0 runtime is gone"
has_line pixel_9_API_36.0 avds || bad "$label: pixel_9_API_36.0 is gone"
nothing_removed

label="undeclared devices (AE3)"
scenario 27.0
echo 27.0 > "$STUB/runtimes"
echo "com.apple.CoreSimulator.SimRuntime.iOS-27-0|My Hand-Made Phone" > "$STUB/sims"
printf '%s\n' pixel_8_API_37.0 pixel_9_API_37.0 > "$STUB/avds"
run --android-api 37.0 --device "ios:iPhone 18 Pro" --device android:pixel_9
[ "$(count "$(sim_create "iPhone 18 Pro (iOS 27.0)" iPhone-18-Pro 27.0)")" = 1 ] || bad "$label: the declared iPhone was not created"
[ "$(downloads)" = 0 ] || bad "$label: the installed iOS 27.0 runtime was downloaded again"
[ "$(creates)" = 1 ] || bad "$label: $(creates) devices were created, not 1"
has_line "com.apple.CoreSimulator.SimRuntime.iOS-27-0|My Hand-Made Phone" sims || bad "$label: the hand-made simulator is gone"
has_line pixel_8_API_37.0 avds || bad "$label: the undeclared AVD is gone"
nothing_removed

for broken_xcode in failing missing; do
  label="no Xcode, xcrun $broken_xcode (AE4)"
  scenario 27.0
  xcrun=$stub/xcrun
  if [ "$broken_xcode" = failing ]; then touch "$STUB/no-xcode"; else xcrun=$STUB/no-such-xcrun; fi
  status=0
  "$helper" --xcrun "$xcrun" --sdk-root "$stub/sdk" --android-api 37.0 \
    --device "ios:iPhone 18 Pro" --device android:pixel_9 > "$STUB/out" 2> "$STUB/err" || status=$?
  [ "$status" = 0 ] || bad "$label: the helper exited $status"
  [ "$(count "$(avd_create pixel_9 37.0)")" = 1 ] || bad "$label: the Android device was not created"
  [ "$(creates)" = 1 ] || bad "$label: $(creates) devices were created, not 1"
  said "App Store" || bad "$label: the message does not name the App Store sign-in: $(cat "$STUB/err")"
  [ "$(grep -c 'App Store' "$STUB/err")" = 1 ] || bad "$label: the sign-in message was printed $(grep -c "App Store" "$STUB/err") times, not once"
  nothing_removed
done

label="no avdmanager"
scenario 27.0
status=0
"$helper" --xcrun "$stub/xcrun" --sdk-root "$stub/no-avdmanager" --android-api 37.0 \
  --device "ios:iPhone 18 Pro" --device android:pixel_9 --device android:pixel_8 > "$STUB/out" 2> "$STUB/err" || status=$?
[ "$status" = 0 ] || bad "$label: the helper exited $status"
[ "$(count "$(sim_create "iPhone 18 Pro (iOS 27.0)" iPhone-18-Pro 27.0)")" = 1 ] || bad "$label: the iOS device was not created"
said avdmanager || bad "$label: the message does not name avdmanager: $(cat "$STUB/err")"
[ "$(grep -c avdmanager "$STUB/err")" = 1 ] || bad "$label: the missing avdmanager was reported $(grep -c avdmanager "$STUB/err") times, not once"
nothing_removed

label="unknown model and a failing create"
scenario 27.0
run --android-api 37.0 --device "ios:iPhone 99" --device "ios:iPhone 18 Pro" \
  --device android:broken --device android:pixel_9
said "iPhone 99" || bad "$label: the unknown iOS model was not reported by name: $(cat "$STUB/err")"
said broken_API_37.0 || bad "$label: the failed AVD was not reported by name: $(cat "$STUB/err")"
[ "$(count "$(sim_create "iPhone 18 Pro (iOS 27.0)" iPhone-18-Pro 27.0)")" = 1 ] || bad "$label: the known iPhone was not created"
[ "$(count "$(avd_create pixel_9 37.0)")" = 1 ] || bad "$label: pixel_9 was not created after the failed AVD"
if grep -qF 'iPhone 99' "$STUB/calls"; then bad "$label: the unknown model reached simctl create"; fi
nothing_removed

label="explicit versions"
scenario 27.0
printf '%s\n' 26.0 27.0 > "$STUB/runtimes"
run --android-api 37.0 --device "ios:iPhone 18 Pro:26.0" --device android:pixel_9:36.0
[ "$(count "$(sim_create "iPhone 18 Pro (iOS 26.0)" iPhone-18-Pro 26.0)")" = 1 ] \
  || bad "$label: iPhone 18 Pro (iOS 26.0) was not created on the iOS 26.0 runtime: $(cat "$STUB/calls")"
[ "$(count "$(avd_create pixel_9 36.0)")" = 1 ] || bad "$label: pixel_9_API_36.0 was not created from the 36.0 image"
[ "$(creates)" = 2 ] || bad "$label: $(creates) devices were created, not 2"
nothing_removed

[ "$fail" = 0 ] || exit 1
echo "mobile-devices: all scenarios passed"
