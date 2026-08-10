#!/usr/bin/env bash
#
# setup_macos.sh — prepare this project to run as a macOS desktop app.
#
# The repository ships lib/, android/ and ios/Info.plist only, so the macOS
# runner has to be generated once. This script does that and then applies the
# two things `flutter create` cannot know about:
#
#   1. NSLocationWhenInUseUsageDescription in Runner/Info.plist — without it
#      macOS kills the process the moment CoreLocation is touched.
#   2. The location entitlement in both entitlement files — without it the
#      sandbox denies the location request and the app silently falls back to
#      the Makkah coordinates.
#
# Safe to re-run: `flutter create` only fills in what is missing, and each
# plist edit is add-or-update.
#
# Usage:
#   cd arabic_temporal_watch
#   ./tool/setup_macos.sh
#   flutter run -d macos

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

PLIST_BUDDY=/usr/libexec/PlistBuddy
INFO_PLIST="macos/Runner/Info.plist"
DEBUG_ENT="macos/Runner/DebugProfile.entitlements"
RELEASE_ENT="macos/Runner/Release.entitlements"

LOCATION_USAGE="تحتاج الساعة العربية إلى موقعك لحساب أوقات الشروق والغروب والصلوات بدقة فلكية. يُستخدم الموقع محلياً فقط."

info()  { printf '\033[0;36m==>\033[0m %s\n' "$1"; }
warn()  { printf '\033[0;33m warning:\033[0m %s\n' "$1"; }
fail()  { printf '\033[0;31m error:\033[0m %s\n' "$1" >&2; exit 1; }

# ── Preconditions ─────────────────────────────────────────────────────────────

[[ "$(uname -s)" == "Darwin" ]] || fail "This script only runs on macOS."
command -v flutter >/dev/null 2>&1 || fail "flutter not found in PATH. Install it first: brew install --cask flutter"
[[ -x "$PLIST_BUDDY" ]] || fail "PlistBuddy not found at $PLIST_BUDDY (install Xcode command line tools)."

# ── 1. Enable desktop support and generate the runner ────────────────────────

info "Enabling macOS desktop support"
flutter config --enable-macos-desktop >/dev/null

info "Generating the macOS runner (existing files are left untouched)"
flutter create --platforms=macos .

[[ -f "$INFO_PLIST" ]] || fail "$INFO_PLIST was not generated — check the flutter create output above."

# `flutter create` also drops its default counter-app widget test, which
# references a MyApp class this project does not have and would break
# `flutter test`. The real tests live alongside it in test/.
if [[ -f test/widget_test.dart ]] && grep -q "MyApp" test/widget_test.dart; then
  info "Removing the generated placeholder test (test/widget_test.dart)"
  rm -f test/widget_test.dart
fi

# ── 2. Location usage description ─────────────────────────────────────────────

set_string() {
  local plist="$1" key="$2" value="$3"
  if "$PLIST_BUDDY" -c "Print :$key" "$plist" >/dev/null 2>&1; then
    "$PLIST_BUDDY" -c "Set :$key $value" "$plist"
  else
    "$PLIST_BUDDY" -c "Add :$key string $value" "$plist"
  fi
}

info "Adding location usage descriptions to Info.plist"
set_string "$INFO_PLIST" "NSLocationWhenInUseUsageDescription" "$LOCATION_USAGE"
set_string "$INFO_PLIST" "NSLocationUsageDescription" "$LOCATION_USAGE"

# ── 3. Sandbox entitlements ───────────────────────────────────────────────────

set_bool() {
  local plist="$1" key="$2" value="$3"
  [[ -f "$plist" ]] || { warn "$plist not found — skipped."; return; }
  if "$PLIST_BUDDY" -c "Print :$key" "$plist" >/dev/null 2>&1; then
    "$PLIST_BUDDY" -c "Set :$key $value" "$plist"
  else
    "$PLIST_BUDDY" -c "Add :$key bool $value" "$plist"
  fi
}

info "Granting the location entitlement to the sandbox"
for ent in "$DEBUG_ENT" "$RELEASE_ENT"; do
  set_bool "$ent" "com.apple.security.personal-information.location" true
done

# ── 4. Dependencies ───────────────────────────────────────────────────────────

info "Resolving packages"
flutter pub get

# ── Done ──────────────────────────────────────────────────────────────────────

cat <<'EOF'

macOS setup complete.

  Run it:      flutter run -d macos
  Build it:    flutter build macos --release
  App bundle:  build/macos/Build/Products/Release/arabic_temporal_watch.app
               (drag it into /Applications to install)

Note: shake-to-silence needs an accelerometer, so it is inactive on a Mac —
tap the watch face to silence the adhan instead.
EOF
