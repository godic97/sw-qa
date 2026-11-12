# Domain checklists: clients, tools and libraries

Checks for user interfaces, command-line tools and libraries. Each line names a failure and how to provoke and observe it.
Use the sections whose "Applies when" line matches the software under test. Turn each relevant line into a QA case and take its expected result from the requirements.

## Web front ends

Applies when: `package.json` depends on react, vue, svelte, @angular/core, next, nuxt or vite, and the tree has an `index.html` mount element, a client-side router, a bundler config (`vite.config.*`, `webpack.config.*`) or a service worker.

- Access rules live only in the client → sign in as a low-privilege user, open an admin route URL directly, then replay its API requests with curl; expect 403 from the server.
- Stored user text runs as script → save `<img src=x onerror=alert(1)>` in each free-text field of an isolated instance, reload the page that displays it in Playwright, assert no dialog event fires.
- Secrets or source maps ship in the public bundle → curl every built JavaScript file and grep for `sk_live`, `AKIA` and `BEGIN PRIVATE KEY`; request each `.js.map` URL and expect 404.
- The Back button restores private data after logout → launch Chromium without Playwright's default `--disable-back-forward-cache`, log in, view private data, log out, call `page.goBack()`; assert the data is not shown.
- A double click or repeated Enter submits the form twice → delay the submit response three seconds with `page.route`, click submit twice quickly, and count the POST requests and the records created.
- Token expiry loses form input or logs the user out → fill a form, expire the access token server-side, submit while three other requests fire; assert one refresh call and intact input.
- A deploy deletes chunks that open tabs still need → load a local build, deploy a new build over it, open a lazy-loaded route in the old tab; expect no blank page.

## Mobile apps

Applies when: the tree has `AndroidManifest.xml` with Gradle files, an `ios/` folder with an `.xcodeproj`, `Info.plist` or `Podfile`, a Flutter `pubspec.yaml`, `react-native` or `expo` in `package.json`, `capacitor.config.*` or a `fastlane/` directory.

- An in-place update crashes or wipes local data → install the previous release, create data, run `adb install -r new.apk`; assert the data is intact and logcat shows no migration exception.
- A retry after a network drop duplicates the order or payment → tap submit, run `adb shell "svc wifi disable; svc data disable"`, re-enable both after ten seconds; count the server-side records.
- Tokens or passwords leak to logcat, preferences or backups → log in while capturing `adb logcat`, dump `shared_prefs` with `adb shell run-as <package>`, grep both for the token and password; check `android:allowBackup`.
- A deep link bypasses login or crashes → while logged out, run `adb shell am start -a android.intent.action.VIEW -d "myapp://orders/abc"` (iOS: `xcrun simctl openurl booted`); expect the login screen and no crash.
- Pushes for the previous account arrive after logout → log in as user A, log out, push to user A from the backend; assert nothing appears and the token mapping is gone.
- Old app versions crash on new server responses → run the oldest supported build through a mitmproxy script that injects an unknown enum value and drops an optional field; expect no crash.
- Background process death loses typed input → fill a form, press Home, run `adb shell am kill <package>`, reopen from Recents; assert the screen and typed input are restored.

## Desktop GUI apps

Applies when: the project builds a windowed program: `electron` or `@tauri-apps/api` in `package.json`, Qt or GTK sources (`*.ui`, `*.qml`), a `.csproj` with `UseWPF` or `UseWindowsForms`, JavaFX, PyQt, PySide or Tkinter imports, or installer files (`*.wxs`, `*.nsi`, `*.iss`, `.desktop`).

- A crash or full disk mid-save truncates the document → `kill -9` the app while saving a large document; save onto a 1 MB tmpfs; expect the complete old or new file.
- Unsaved edits vanish on close, logout or crash → edit without saving; in separate runs use `wmctrl -c`, SIGTERM and `kill -9`; assert each time the edits were prompted for or recovered.
- Untrusted web-view content runs native commands → open a document containing `<img src=x onerror="require('child_process').exec('touch /tmp/pwned')">` and a link to `file:///etc/passwd`; assert `/tmp/pwned` is absent and the link is refused.
- The auto-updater applies a tampered or truncated package → serve a byte-flipped update from a local feed, then one cut off mid-download; assert both are rejected and the app still starts.
- Upgrades reset settings or uninstall leaves files behind → install the previous release, fill its profile, install the new one over it, diff the settings; uninstall and diff file-system and registry snapshots.
- Two instances corrupt settings or a stale lock blocks launch → run two instances on one profile, change settings in both, `kill -9` one, relaunch; expect valid config and a normal start.
- Spaces, Hangul or 260+ characters break saving → set `HOME` and `XDG_CONFIG_HOME` (Windows: `APPDATA`) under a path with spaces and Hangul; assert a Hangul-named file in a 300-character path saves and reopens.

## Accessibility

Applies when: any user-facing interface is present (HTML templates, JSX, Vue or Svelte components, Android layouts, storyboards, SwiftUI views); required when the repository names `axe-core`, `pa11y`, `eslint-plugin-jsx-a11y`, ARIA, WCAG, Section 508, EN 301 549 or KWCAG.

- A primary flow cannot be completed by keyboard → complete login and the main transaction in Playwright using only Tab, Shift+Tab, Enter, Space and arrow keys, logging `document.activeElement` after each key.
- A modal dialog leaks focus or never returns it → open each dialog, press Tab thirty times, assert `document.activeElement` stays inside; press Escape, assert focus returns to the opening button.
- Controls lack accessible names or contrast is below 4.5:1 → run `@axe-core/playwright` on every route and opened state in light and dark schemes; fail on `label`, `button-name`, `link-name`, `image-alt` and `color-contrast` violations.
- Errors, toasts and route changes are never announced → submit an invalid form and navigate client-side; assert errors are in `role=alert` or `aria-live` regions, and focus and `document.title` change on navigation.
- The focus indicator is missing or hidden under sticky elements → Tab through each page; compare each element's focused and unfocused outline or box-shadow, and assert `document.elementFromPoint` at its centre returns it.
- Content clips or scrolls sideways at 400% zoom → at a 320 by 256 CSS pixel viewport, assert `scrollWidth <= clientWidth`; add line-height 1.5, letter-spacing 0.12em and word-spacing 0.16em, screenshot for clipping.

## Internationalisation, non-ASCII text, time zones

Applies when: the tree has locale resources (`locales/*.json`, `messages_*.properties`, `*.po`, `*.xliff`, `*.arb`, `values-ko/strings.xml`), an i18n or date library (`i18next`, `react-intl`, `gettext`, `date-fns-tz`, `pytz`, `zoneinfo`), timestamp columns, cron schedules, `TZ` or `LANG` settings, or user text and file names that may be Korean or other non-ASCII scripts.

- KRW is multiplied by 100 or a decimal comma is misread → pay 1000 KRW and inspect the amount the sandbox gateway receives; enter `1,5` under `de-DE` and `en-US`, compare stored values.
- Non-ASCII text returns as mojibake or is cut mid-character → send a maximum-length field of Hangul plus an emoji (U+1F600) through create, read, search, CSV export and download; compare bytes with `xxd`.
- Time-zone mismatches shift dates by a day → run the server on `TZ=UTC`, clients on `TZ=Asia/Seoul` and `TZ=America/Los_Angeles`; save a 00:30 local-time record and a date-only birthday; compare stored and displayed dates.
- Scheduled jobs skip or repeat across a daylight-saving change → with `TZ=America/New_York`, use `faketime` to cross 02:00 on 14 March 2027 and 01:00 on 7 November 2027; assert each job fires once.
- Composed and decomposed Hangul fail to match → submit one name as NFC (U+D55C) and NFD (U+1112 U+1161 U+11AB) for sign-up, search and file upload; assert both resolve to the same record.
- Enter during Hangul composition submits early or doubles a syllable → compose with CDP `Input.imeSetComposition`, dispatch Enter `keydown` with `isComposing: true` and `keyCode` 229, commit; assert one submit and no repeated character.

## Command-line tools

Applies when: the project ships an executable entry point: `bin` in `package.json`, `[project.scripts]` or `console_scripts`, `cmd/<name>/main.go`, a `[[bin]]` target or `src/main.rs`, an argument parser dependency (argparse, click, typer, cobra, clap, commander, yargs, oclif), `getopts` shell scripts, man pages or completion files.

- Mistyped flags are ignored and the action runs → run a destructive subcommand on scratch data with `--dry-rn`, then `--dry-run`; expect an unknown-option error for the first and unchanged files after both.
- A failed command exits 0 → run each subcommand with a missing input file, an unreachable server and a read-only output directory; assert non-zero `$?` and the error on stderr.
- An interrupt or full disk leaves truncated output → send `kill -INT`, then `kill -TERM`, mid-write, and redirect output to `/dev/full`; assert non-zero exit, no partial target file and a successful rerun.
- File names are parsed as options or executed → in a scratch directory create `-rf`, `a b.txt` and `$(touch pwned).txt`, pass them after `--`; assert literal handling and no `pwned` file.
- Flag, environment and config precedence is wrong → give one option three values via config file, environment variable and flag; print the effective value; expect flag, then environment, then file.
- Parallel runs corrupt shared state → run `seq 20 | xargs -P 20 -I{} tool update` on one scratch state directory; assert parseable state, no lost update and no leftover lock.
- Without a terminal the command hangs on a prompt → run `timeout 10 tool delete scratch-target </dev/null`; expect a fast non-zero exit whose message names `--yes` or `--no-input`, not timeout status 124.

## Libraries and SDKs

Applies when: the repository publishes a package instead of running a service: `pyproject.toml` or `setup.py` without an application entry point, `package.json` with `main`, `exports` or `types`, a `[lib]` crate, a Go module without `main` packages, a Maven or Gradle publishing block, a `.gemspec` or `.nuspec`, or a release workflow running `npm publish`, `twine upload` or `cargo publish`.

- Calls hang or retries duplicate a POST → a fake server that never answers must cause a timeout; one dropping the connection after a POST must receive one idempotency key across retries.
- API keys leak into logs, exceptions or the printed client → set the key `sk_test_CANARY123`, enable debug logging, fail a call, print the client and the exception; grep all output for `CANARY123`.
- Minor or patch releases break public symbols → diff the API against the last tag with `cargo semver-checks`, `griffe check`, `japicmp` or `api-extractor`; run the previous release's tests on the new build.
- The published artifact lacks files, types or entry points → pack it, install into an empty environment, run the README example via `require` and `import`; for npm run `publint` and `attw --pack`.
- Clients share state across threads or instances → against a fake server, call one client from 50 threads, use two clients with different keys; assert each response matches its request and key.
- New response fields break parsing or large IDs lose precision → replay a response with an added field, unknown enum value and id `9007199254740993`; assert parsing succeeds and the id round-trips.

## Browser extensions and host plugins

Applies when: the code targets a host program's extension API: `manifest.json` with `manifest_version`, `permissions`, `content_scripts` or `background`; `package.json` with `engines.vscode` and `contributes`; a JetBrains `plugin.xml`; a WordPress plugin header; `.claude-plugin/plugin.json`; an Obsidian or Figma `manifest.json`; `.vscodeignore` or `web-ext-config.*`.

- Web pages forge messages that trigger privileged APIs → from a test page, send `window.postMessage` and `chrome.runtime.sendMessage(extensionId, ...)` payloads in the extension's message format; assert no privileged action runs.
- The package lacks runtime files or ships secrets → grep the unzipped `.vsix` or `.zip` for keys and remote script URLs; install it into a clean profile and assert each command runs.
- An added permission disables the extension on update → diff `permissions` and `host_permissions` against the last release tag; for any addition, update a packed previous build and check whether it is disabled.
- Updates lose settings or orphan content scripts → in a persistent profile on the previous release, save settings and keep a matching tab open; load the new build; assert both still work.
- The plugin fails on its declared minimum host version → install it on the host version named in `engines.vscode`, `minimum_chrome_version` or `since-build`; run every contributed command and expect an error-free host log.
- Idle service worker shutdown loses in-memory state → in Puppeteer, set state through the extension, stop the worker with `worker.close()`, send a message; assert it restarts and answers with the state restored.
