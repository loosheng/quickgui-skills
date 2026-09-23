# Updater

Signed automatic updates. One implementation in the Rust core: Rust apps enable the `updater` feature; Go and TypeScript load the same sources as an extension. Development builds report `disabled`. Feeds are HTTPS Sparkle RSS appcasts with Ed25519 signatures; there is no unsigned fallback.

## Enable the binary

| Language | How |
| --- | --- |
| Go | `import "github.com/egoist/quickgui/extensions/updater"` |
| TypeScript | `bun add @quickgui/extension-updater` and `extensions: ["@quickgui/extension-updater"]` |
| Rust | `quickgui = { features = ["updater"] }` — call `quickgui::updater` |

Apps that omit the import/feature do not ship the updater. App Store / sandboxed Go builds should exclude the import with a build tag.

TypeScript apps acknowledge startup to the install helper when the app becomes ready. Without that, a Windows or Linux TypeScript update is rolled back.

## Keys

```sh
quickgui keygen --out-dir ~/.config/my-app/update-keys
```

Writes `quickgui-update.pub` and `quickgui-update.key`. Put the public key in config. Keep the private key out of the repository. Losing it means existing installs can never update. `--force` overwrites.

Build signing reads `QUICKGUI_UPDATER_PRIVATE_KEY` (or `SPARKLE_PRIVATE_KEY`), else `updates.ed25519SecretKey`.

## Configuration

Set `updates.target` to `"github"` or `"s3"` and fill the matching section. The target decides publish URLs and check URLs; do not write feed or download URLs yourself.

```toml
[updates]
target = "github"
publicKey = "CONTENTS_OF_quickgui-update.pub"
automaticChecks = true
changelog = "CHANGELOG.md"

[updates.github]
repository = "example/my-app"
# tagPrefix = "v"
```

```toml
[updates]
target = "s3"
publicKey = "CONTENTS_OF_quickgui-update.pub"

[updates.s3]
bucket = "my-app-releases"
region = "us-east-1"
publicUrl = "https://my-app-releases.s3.us-east-1.amazonaws.com"
# endpoint = "https://ACCOUNT_ID.r2.cloudflarestorage.com"
# prefix = "stable"
```

TypeScript/Rust scaffolds typically `readFileSync` the public key into `defineConfig({ updates: { ... } })`.

| Option | Required | Meaning |
| --- | --- | --- |
| `publicKey` | yes | Contents of `.pub`; embedded and used to verify |
| `target` | yes | `"github"` or `"s3"` |
| `github.repository` | with github | Public `owner/name` |
| `github.tagPrefix` | no | Default `"v"` |
| `s3.bucket` / `s3.publicUrl` | with s3 | Bucket and public HTTPS origin |
| `s3.endpoint` / `region` / `prefix` | no | Non-AWS API, region (`"auto"` for R2), folder |
| `automaticChecks` | no | Default `true` for new installs; user preference wins |
| `changelog` | no | Default `CHANGELOG.md` when that file exists |
| `ed25519SecretKey` | no | Path to the private key for local builds |
| `manifest` | no | `true` signs the feed on every production build |

GitHub repositories must be public (installs download without credentials). S3/R2 buckets must allow public reads.

## Application API

Start once per process, outside window components. Status: `idle` | `checking` | `available` | `downloading` | `installing` | `disabled`.

**Go**

```go
updates = updater.Start(updater.Options{}, func(event updater.Event) {
	if event.Error != "" { log.Print(event.Error) }
	if event.QuitRequired { native.App.Quit(false, nil) }
}, func(err error) {
	if err != nil { log.Print(err) }
})
```

`Check(done)`, `Install(done)`, `SetAutomaticChecks(enabled, done)`, `State()`. `AllowDevelopment: true` only with a test feed.

**TypeScript**

```ts
import Updater from "@quickgui/extension-updater";

export const updater = new Updater({}, event => {
  if (event.error) console.error(event.error);
  if (event.quitRequired) void app.quit().catch(console.error);
});
await updater.ready;
```

`check()`, `install()`, `setAutomaticChecks(enabled)`, `state`, `close()`. `{ allowDevelopment: true }` only for disposable test bundles.

**Rust**

```rust
let Ok((updater, mut events)) = Updater::start(quickgui::updater_options!()).await else {
    return Ok(());
};
```

`quickgui::updater_options!()` expands to settings `quickgui build` embedded. Plain `cargo run` is empty → `Disabled`. `check().await`, `install().await`, `set_automatic_checks(enabled).await`, `state()`. On `quit_required` call `cx.exit()`.

Keep the updater for process lifetime. Dropping it cancels checks. If quit is cancelled, the helper times out and leaves the current app in place.

## Platforms

| Platform | Payload | Install |
| --- | --- | --- |
| macOS | ZIP of the signed `.app` | Sparkle (only with updater) |
| Windows | NSIS `.exe` | Helper `/S`, then relaunch |
| Linux | Type-2 AppImage **or** `install.sh` tarball | Atomic replace; rollback if startup is not acknowledged |

Linux `.deb`, system binaries, and root-owned installs report `disabled`. Use the package manager there.

`quickgui build` also writes `<Name>-<version>-linux-<arch>.tar.gz`, `install.sh`, and `latest-linux-<arch>.txt` (a `bin/` + `share/` prefix). `install.sh` installs into `~/.local/<package>.app` without root, links `~/.local/bin`, and registers desktop entry, icon, and MIME types with absolute paths. Set `linux.tarball = false` to skip.

Appcasts list AppImage and tarball as enclosures of one item. A tarball alone is enough when `appimagetool` is missing.

```sh
curl -fsSL https://github.com/<repo>/releases/latest/download/install.sh | sh
# uninstall: | sh -s -- --uninstall
MY_APP_BUNDLE_PATH=dist/linux-x64/My-App-1.0.0-linux-x64.tar.gz sh dist/linux-x64/install.sh
```

## Changelog

One Markdown file for all versions. The section under `## x.y.z` matching config `version` is published (optional date: `## x.y.z - 2026-09-19`). Max 16 KiB. Missing section on a present changelog file **fails the release**. No changelog file at all publishes without notes.

Notes appear as Markdown in the appcast (`sparkle:format="markdown"`), as `event.notes` / `event.Notes`, and as the GitHub release description.

## Publish

```sh
export QUICKGUI_UPDATER_PRIVATE_KEY="$(cat ~/.config/my-app/update-keys/quickgui-update.key)"
quickgui build --update-manifest   # sign feed, no upload
quickgui build --upload            # implies --update-manifest; publish to target
```

GitHub uses `gh` (`GH_TOKEN` or `gh auth login`). S3 uses `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` (or `S3_*`). GitHub releases are **drafts**; publish when every target has uploaded: `gh release edit <tag> --draft=false`. Raise `version` first; apps only install a higher version.

## Pitfalls

- Dev builds never update. Test with a production package.
- GitHub drafts and pre-releases are never “latest”.
- Changelog heading must match `version` exactly.
- Closing a window must not close the process updater.
- TypeScript must become ready after a Windows/Linux update or the helper rolls back.
