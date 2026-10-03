# ChromePatcher

ChromePatcher is an early-stage project exploring how to run newer Chrome on
unsupported macOS releases, including Monterey, Big Sur, Catalina, and older
versions.

## First milestone: read-only compatibility checker

The initial command-line tool detects the installed macOS version and compares
it with a minimum version you provide for a specific Chrome build. Chrome's
minimum supported macOS version changes over time, so the tool deliberately
does not guess or bundle a stale minimum.

Build and run on macOS with Swift:

```sh
swift run ChromePatcher --minimum-macos 12.0
```

Replace `12.0` with the minimum required by the Chrome build you intend to use.
The checker exits with status `0` when the Mac meets the minimum, `1` when it
does not, and `2` for invalid usage. Use `--help` for command help.

This milestone is diagnostic only. It does not download, install, modify, or
launch Chrome, and it does not change system files.

Run the unit tests with:

```sh
swift test
```
