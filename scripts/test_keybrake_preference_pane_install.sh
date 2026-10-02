#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 /path/to/KeyBrake.app" >&2
    exit 64
fi

input_app=$1
case "$input_app" in
    /*) ;;
    *) input_app="${PWD}/${input_app}" ;;
esac
app_parent=$(cd "$(/usr/bin/dirname "$input_app")" && /bin/pwd -P)
app_bundle="${app_parent}/$(/usr/bin/basename "$input_app")"
pane_source="${app_bundle}/Contents/Library/PreferencePanes/KeyBrake.prefPane"
app_info="${app_bundle}/Contents/Info.plist"
pane_info="${pane_source}/Contents/Info.plist"

if [ ! -d "$app_bundle" ] || [ ! -f "$app_info" ] || [ ! -d "$pane_source" ] || [ ! -f "$pane_info" ]; then
    echo "The app bundle must contain KeyBrake.prefPane before installer tests can run." >&2
    exit 1
fi
pane_identifier=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$pane_info")
pane_host_identifier=$(/usr/libexec/PlistBuddy -c 'Print :KeyBrakeHostBundleIdentifier' "$pane_info")
pane_executable=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$pane_info")
app_identifier=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_info")

script_directory=$(cd "$(/usr/bin/dirname "$0")" && /bin/pwd -P)
installer="${script_directory}/install_keybrake_preference_pane.sh"
test_root=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/KeyBrakePaneInstallerTests.XXXXXX")

cleanup() {
    if [ -d "$test_root" ]; then
        /bin/rm -R "$test_root"
    fi
}
trap cleanup EXIT HUP INT TERM

matching_home="${test_root}/matching-home"
matching_destination="${matching_home}/Library/PreferencePanes/KeyBrake.prefPane"
/bin/mkdir -p "$(/usr/bin/dirname "$matching_destination")"
/usr/bin/ditto "$pane_source" "$matching_destination"
/usr/bin/touch "${matching_destination}/Contents/previous-install-marker"
env HOME="$matching_home" "$installer" "$app_bundle" > "${test_root}/matching.log"
backup=$(/usr/bin/find "${matching_home}/Library/PreferencePanes" -maxdepth 1 -type d -name '.KeyBrake.prefPane.backup.*' -print -quit)
if [ -z "$backup" ] || [ ! -f "${backup}/Contents/previous-install-marker" ]; then
    echo "The previous matching pane was not preserved as a backup." >&2
    exit 1
fi
if [ ! -x "${matching_destination}/Contents/MacOS/${pane_executable}" ]; then
    echo "The new matching pane was not installed." >&2
    exit 1
fi
installed_identifier=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${matching_destination}/Contents/Info.plist")
installed_host_identifier=$(/usr/libexec/PlistBuddy -c 'Print :KeyBrakeHostBundleIdentifier' "${matching_destination}/Contents/Info.plist")
if [ "$installed_identifier" != "$pane_identifier" ] || [ "$installed_host_identifier" != "$app_identifier" ] || [ "$pane_host_identifier" != "$app_identifier" ]; then
    echo "The installed pane metadata does not match its app." >&2
    exit 1
fi

unrelated_home="${test_root}/unrelated-home"
unrelated_destination="${unrelated_home}/Library/PreferencePanes/KeyBrake.prefPane"
/bin/mkdir -p "$(/usr/bin/dirname "$unrelated_destination")"
/usr/bin/ditto "$pane_source" "$unrelated_destination"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier org.example.UnrelatedPane' "${unrelated_destination}/Contents/Info.plist"
/usr/bin/touch "${unrelated_destination}/Contents/unrelated-pane-marker"
unrelated_before=$(/usr/bin/shasum -a 256 "${unrelated_destination}/Contents/Info.plist")
if env HOME="$unrelated_home" "$installer" "$app_bundle" > "${test_root}/unrelated.log" 2>&1; then
    echo "The installer replaced a different preference pane." >&2
    exit 1
fi
unrelated_after=$(/usr/bin/shasum -a 256 "${unrelated_destination}/Contents/Info.plist")
if [ "$unrelated_before" != "$unrelated_after" ] || [ ! -f "${unrelated_destination}/Contents/unrelated-pane-marker" ]; then
    echo "The unrelated preference pane changed after the installer refused it." >&2
    exit 1
fi

symlink_home="${test_root}/symlink-home"
symlink_destination="${symlink_home}/Library/PreferencePanes/KeyBrake.prefPane"
/bin/mkdir -p "${symlink_home}/Library/PreferencePanes/target"
/usr/bin/touch "${symlink_home}/Library/PreferencePanes/target/preserved-marker"
/bin/ln -s "${symlink_home}/Library/PreferencePanes/target" "$symlink_destination"
if env HOME="$symlink_home" "$installer" "$app_bundle" > "${test_root}/symlink.log" 2>&1; then
    echo "The installer followed a symlink at the destination." >&2
    exit 1
fi
if [ ! -L "$symlink_destination" ] || [ ! -f "${symlink_home}/Library/PreferencePanes/target/preserved-marker" ]; then
    echo "The installer changed the symlink or its target." >&2
    exit 1
fi

linked_parent_home="${test_root}/linked-parent-home"
linked_parent_target="${test_root}/linked-parent-target"
/bin/mkdir -p "${linked_parent_home}/Library" "$linked_parent_target"
/usr/bin/touch "${linked_parent_target}/preserved-marker"
/bin/ln -s "$linked_parent_target" "${linked_parent_home}/Library/PreferencePanes"
if env HOME="$linked_parent_home" "$installer" "$app_bundle" > "${test_root}/linked-parent.log" 2>&1; then
    echo "The installer followed a symlinked PreferencePanes directory." >&2
    exit 1
fi
if [ ! -L "${linked_parent_home}/Library/PreferencePanes" ] || [ ! -f "${linked_parent_target}/preserved-marker" ]; then
    echo "The installer changed the symlinked PreferencePanes target." >&2
    exit 1
fi

if env HOME="" "$installer" "$app_bundle" > "${test_root}/empty-home.log" 2>&1; then
    echo "The installer accepted an empty HOME value." >&2
    exit 1
fi
if ! /usr/bin/grep -q 'HOME must identify a non-root user home directory' "${test_root}/empty-home.log"; then
    echo "The installer did not reject an empty HOME before resolving its destination." >&2
    exit 1
fi

bad_app="${test_root}/BadScheme.app"
/bin/mkdir -p "${bad_app}/Contents/Library/PreferencePanes"
/bin/cp "$app_info" "${bad_app}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleURLTypes:0:CFBundleURLName keybrake' "${bad_app}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleURLTypes:0:CFBundleURLSchemes:0 other-scheme' "${bad_app}/Contents/Info.plist"
/usr/bin/ditto "$pane_source" "${bad_app}/Contents/Library/PreferencePanes/KeyBrake.prefPane"
bad_scheme_home="${test_root}/bad-scheme-home"
if env HOME="$bad_scheme_home" "$installer" "$bad_app" > "${test_root}/bad-scheme.log" 2>&1; then
    echo "The installer accepted keybrake outside CFBundleURLSchemes." >&2
    exit 1
fi
if [ -e "${bad_scheme_home}/Library/PreferencePanes" ]; then
    echo "The invalid app created an install destination before validation." >&2
    exit 1
fi

printf 'Preference pane installer tests passed: matching upgrade, unrelated pane refusal, destination and parent symlink refusal, empty HOME rejection, and exact URL-scheme validation.\n'
