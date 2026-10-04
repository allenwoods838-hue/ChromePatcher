# ChromePatcher

ChromePatcher is an early-stage project exploring how to run newer Chrome on
unsupported macOS releases, including Monterey, Big Sur, Catalina, and older
versions.

## Read-only compatibility checker

The command-line tool reports the installed macOS version and detects the
Google Chrome app in `/Applications` or `~/Applications`, including its
version, location, and executable CPU architectures. It also reports the Mac
model identifier and CPU architecture, then gives an overall readiness summary
based on whether macOS meets the supplied minimum and Chrome includes a native
slice for the Mac's architecture. On Apple silicon, an x86_64-only Chrome build
may also run through Rosetta if it is installed. Chrome's minimum supported
macOS version changes over time, so the tool deliberately does not guess or
bundle a stale minimum.

Build and run on macOS with Swift:

```sh
swift run ChromePatcher --minimum-macos 12.0
```

### Named Chrome build profiles

For repeat checks, create a JSON file at
`~/Library/Application Support/ChromePatcher/profiles.json`:

```json
{
  "profiles": {
    "chrome-126": {
      "minimumMacOS": "10.15",
      "description": "Example profile; verify this minimum for the exact build."
    },
    "my-chrome-build": {
      "minimumMacOS": "12.0"
    }
  }
}
```

Profile requirements are local configuration, not automatically verified
against Google. Confirm the minimum for the exact Chrome build before adding a
profile. Then list and use profiles by name:

```sh
swift run ChromePatcher --list-profiles
swift run ChromePatcher --profile my-chrome-build
swift run ChromePatcher --profile my-chrome-build --json
```

To generate a JSON profile template without guessing the schema, print one from the CLI:

```sh
swift run ChromePatcher --profile-template my-chrome-build
```

If you want to create a starter profile file at the default location, initialize it once:

```sh
swift run ChromePatcher --init-profiles-file
swift run ChromePatcher --init-profiles-file ~/Library/Application\ Support/ChromePatcher/custom-profiles.json
```

To validate an existing profile file before using it:

```sh
swift run ChromePatcher --validate-profiles-file ~/Library/Application\ Support/ChromePatcher/profiles.json
```

Pass `--profiles-file PATH` with `--profile` or `--list-profiles` to use another
configuration file. The original `--minimum-macos VERSION` command remains
available for one-off checks.

For scripts, add `--json` to emit a JSON report instead:

```sh
swift run ChromePatcher --minimum-macos 12.0 --json
```

Replace `12.0` with the minimum required by the Chrome build you intend to use.
The checker searches the standard system and user Applications folders. It
exits with status `0` when macOS meets the supplied minimum, `1` when it does
not, and `2` for invalid usage or unreadable Chrome metadata/executable. The
exit status reflects the macOS minimum check only; architecture availability
and the overall readiness summary are reported separately. If Chrome is not
installed, the tool reports that readiness cannot be assessed. Use `--help`
for command help. JSON output is written alone to standard output; diagnostics
and errors go to standard error. Its schema is versioned with `schemaVersion`;
`profileName` identifies the selected profile when using `--profile`.

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
