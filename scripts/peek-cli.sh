#!/bin/sh
# Shim installed as the Homebrew cask's `binary` target. We route through
# `open -a` so that:
#   1. the GUI app is properly detached from the invoking shell (no tty
#      inheritance, so Ctrl+C in the shell doesn't kill the window, and
#      the shell returns to the prompt immediately),
#   2. Launch Services locates peek.app via LSBundleIdentifier and
#      delivers file args via application:openFile: — which means
#      Bundle.main resolves to /Applications/peek.app regardless of how
#      this shim was invoked (symlink, direct path, etc.).
set -e

case "${1:-}" in
    --version|-v)
        # Resolve the symlink chain (brew installs us as
        # /opt/homebrew/bin/peek -> .../peek.app/Contents/MacOS/peek-cli),
        # then read CFBundleShortVersionString from the adjacent Info.plist.
        self="$0"
        while [ -L "$self" ]; do
            link=$(readlink "$self")
            case "$link" in
                /*) self="$link" ;;
                *)  self="$(dirname "$self")/$link" ;;
            esac
        done
        plist="$(dirname "$(dirname "$self")")/Info.plist"
        version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$plist")
        echo "peek $version"
        exit 0
        ;;
esac

# Pass through whatever the user gave us: a file, a folder, or nothing.
# `open` accepts relative paths and expands them against the caller's cwd.
exec /usr/bin/open -a "peek" "$@"
