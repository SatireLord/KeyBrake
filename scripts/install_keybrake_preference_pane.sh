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

if [ -L "$app_bundle" ] || [ ! -d "$app_bundle" ] || [ ! -f "$app_info" ]; then
    echo "Provide an existing KeyBrake.app bundle, not a symlink or another file." >&2
    exit 1
fi
if [ ! -d "$pane_source" ] || [ ! -f "$pane_info" ]; then
    echo "This app does not contain the built KeyBrake preference pane." >&2
    exit 1
fi

app_identifier=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_info")
pane_identifier=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$pane_info")
pane_host_identifier=$(/usr/libexec/PlistBuddy -c 'Print :KeyBrakeHostBundleIdentifier' "$pane_info")
pane_package_type=$(/usr/libexec/PlistBuddy -c 'Print :CFBundlePackageType' "$pane_info")
pane_executable=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$pane_info")

if [ -z "$app_identifier" ] || [ "$app_identifier" != "$pane_host_identifier" ] || [ "$pane_package_type" != "BNDL" ] || [ ! -x "${pane_source}/Contents/MacOS/${pane_executable}" ]; then
    echo "The embedded pane metadata or executable does not match its host app." >&2
    exit 1
fi

url_types_xml=$(/usr/bin/plutil -extract CFBundleURLTypes xml1 -o - "$app_info") || {
    echo "The app does not register a URL scheme for the pane handoff." >&2
    exit 1
}
if ! printf '%s\n' "$url_types_xml" | /usr/bin/awk '
    /<key>CFBundleURLSchemes<\/key>/ { in_schemes = 1; next }
    in_schemes && /<\/array>/ { in_schemes = 0 }
    in_schemes && /<string>keybrake<\/string>/ { found = 1 }
    END { exit(found ? 0 : 1) }
'; then
    echo "The app does not register the keybrake settings URL scheme." >&2
    exit 1
fi

if [ -z "${HOME:-}" ] || [ "$HOME" = "/" ]; then
    echo "HOME must identify a non-root user home directory." >&2
    exit 1
fi
case "$HOME" in
    /*) ;;
    *) echo "HOME must identify an absolute user home directory." >&2; exit 1 ;;
esac

preference_panes="${HOME}/Library/PreferencePanes"
if [ -L "$preference_panes" ]; then
    echo "Refusing to install through a symlinked PreferencePanes directory." >&2
    exit 1
fi
/bin/mkdir -p "$preference_panes"
destination="${preference_panes}/KeyBrake.prefPane"
if [ -L "$destination" ]; then
    echo "Refusing to replace a symlink at $destination." >&2
    exit 1
fi

staging_directory=$(/usr/bin/mktemp -d "${preference_panes}/.keybrake-install.XXXXXX")
staging_bundle="${staging_directory}/KeyBrake.prefPane"
backup=""

cleanup() {
    if [ -d "$staging_directory" ]; then
        /bin/rm -R "$staging_directory"
    fi
    if [ -n "$backup" ] && [ -e "$backup" ] && [ ! -e "$destination" ]; then
        /bin/mv "$backup" "$destination"
    fi
}
trap cleanup EXIT HUP INT TERM

/usr/bin/ditto "$pane_source" "$staging_bundle"
staged_identifier=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$staging_bundle/Contents/Info.plist")
staged_host_identifier=$(/usr/libexec/PlistBuddy -c 'Print :KeyBrakeHostBundleIdentifier' "$staging_bundle/Contents/Info.plist")
if [ "$staged_identifier" != "$pane_identifier" ] || [ "$staged_host_identifier" != "$app_identifier" ]; then
    echo "The staged pane metadata changed during installation." >&2
    exit 1
fi

if [ -e "$destination" ]; then
    if [ ! -d "$destination" ] || [ ! -f "$destination/Contents/Info.plist" ]; then
        echo "Refusing to replace a non-pane item at $destination." >&2
        exit 1
    fi
    existing_identifier=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$destination/Contents/Info.plist") || {
        echo "Refusing to replace a pane with unreadable metadata at $destination." >&2
        exit 1
    }
    if [ "$existing_identifier" != "$pane_identifier" ]; then
        echo "Refusing to replace a different preference pane at $destination." >&2
        exit 1
    fi
    backup="${preference_panes}/.KeyBrake.prefPane.backup.$(/bin/date -u '+%Y%m%dT%H%M%SZ').$$"
    /bin/mv "$destination" "$backup"
fi

if ! /bin/mv "$staging_bundle" "$destination"; then
    echo "Could not move the verified pane into $destination." >&2
    exit 1
fi
/bin/rmdir "$staging_directory"
printf 'Installed %s for %s.\n' "$destination" "$app_identifier"
if [ -n "$backup" ]; then
    printf 'Previous matching pane preserved at %s.\n' "$backup"
    backup=""
fi
