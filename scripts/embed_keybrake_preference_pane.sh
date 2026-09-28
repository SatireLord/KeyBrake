#!/bin/sh
set -eu

: "${BUILT_PRODUCTS_DIR:?Xcode did not provide BUILT_PRODUCTS_DIR}"
: "${TARGET_BUILD_DIR:?Xcode did not provide TARGET_BUILD_DIR}"
: "${FULL_PRODUCT_NAME:?Xcode did not provide FULL_PRODUCT_NAME}"

app_bundle="${TARGET_BUILD_DIR}/${FULL_PRODUCT_NAME}"
pane_source="${BUILT_PRODUCTS_DIR}/KeyBrake.prefPane"
app_info="${app_bundle}/Contents/Info.plist"
pane_info="${pane_source}/Contents/Info.plist"

case "$app_bundle" in
    *.app) ;;
    *) echo "Refusing to embed the pane outside an app bundle: $app_bundle" >&2; exit 1 ;;
esac

if [ ! -d "$pane_source" ] || [ ! -f "$pane_info" ] || [ ! -f "$app_info" ]; then
    echo "The app or route-enabled preference pane build product is missing." >&2
    exit 1
fi

app_identifier=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_info")
pane_host_identifier=$(/usr/libexec/PlistBuddy -c 'Print :KeyBrakeHostBundleIdentifier' "$pane_info")
if [ "$app_identifier" != "$pane_host_identifier" ]; then
    echo "The preference pane host identifier does not match the app bundle." >&2
    exit 1
fi

preference_panes="${app_bundle}/Contents/Library/PreferencePanes"
destination="${preference_panes}/KeyBrake.prefPane"
staging="${preference_panes}/.KeyBrake.prefPane.stage.$$"
/bin/mkdir -p "$preference_panes"
if [ -e "$staging" ] || [ -L "$staging" ]; then
    echo "A stale pane staging path already exists: $staging" >&2
    exit 1
fi

cleanup() {
    if [ -e "$staging" ] || [ -L "$staging" ]; then
        /bin/rm -R "$staging"
    fi
}
trap cleanup EXIT HUP INT TERM

/usr/bin/ditto "$pane_source" "$staging"
staged_host_identifier=$(/usr/libexec/PlistBuddy -c 'Print :KeyBrakeHostBundleIdentifier' "$staging/Contents/Info.plist")
if [ "$staged_host_identifier" != "$app_identifier" ]; then
    echo "The staged preference pane does not match the app bundle." >&2
    exit 1
fi

if [ -e "$destination" ] || [ -L "$destination" ]; then
    /bin/rm -R "$destination"
fi
/bin/mv "$staging" "$destination"
