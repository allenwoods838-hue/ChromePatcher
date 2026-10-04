# ChromePatcher

ChromePatcher is an early-stage project exploring how to run newer Chrome on
unsupported macOS releases, including Monterey, Big Sur, Catalina, and older
versions.

## Read-only compatibility checker

The command-line tool reports the installed macOS version and detects the
Google Chrome app in `/Applications` or `~/Applications`, including its version
location, and executable CPU architectures. It reports whether Chrome includes
a native slice for the Mac's architecture; on Apple silicon, an x86_64-only
Chrome build may also run through Rosetta if it is installed. It compares macOS
with the minimum version you provide for a specific Chrome build. Chrome's
minimum supported macOS version changes over time, so the tool deliberately
does not guess or bundle a stale minimum.

Build and run on macOS with Swift:

```sh
swift run ChromePatcher --minimum-macos 12.0
```

Replace `12.0` with the minimum required by the Chrome build you intend to use.
The checker searches the standard system and user Applications folders. It
exits with status `0` when macOS meets the supplied minimum, `1` when it does
not, and `2` for invalid usage or unreadable Chrome metadata/executable. The
exit status reflects the macOS minimum check only; architecture availability
is reported separately. Use `--help` for command help.

This tool is diagnostic only. It does not download, install, modify, or launch
Chrome, and it does not change system files. The Chrome version is reported for
reference; compatibility is determined by comparing macOS against the minimum
you supplied, not by inferring a requirement from the installed Chrome version.
Architecture reporting indicates whether a native CPU slice is present; it
does not verify Rosetta availability or guarantee that the app will launch.

Run the unit tests with:

```sh
swift test
```
