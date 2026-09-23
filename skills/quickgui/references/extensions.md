# Extensions

Native extensions and first-party packages (editor, markdown, terminal, updater). Extensions register by name through a public ABI; they are not compiled into `libquickgui_host`. Language grammars stay out of the default editor bundle.

## First-party packages

| Capability | Go | TypeScript | Rust |
| --- | --- | --- | --- |
| Editor, CodeBlock, DiffView | `go get github.com/egoist/quickgui/extensions/editor` | `bun add @quickgui/extension-editor` | `features = ["editor"]` |
| Markdown | `…/extensions/markdown` | `@quickgui/extension-markdown` | `features = ["markdown"]` |
| Terminal | `…/extensions/terminal` → `terminal.View(terminal.Props{…})` | `@quickgui/extension-terminal` + `extensions` in config | `features = ["terminal"]` |
| Updater | `…/extensions/updater` | `@quickgui/extension-updater` + `extensions` in config | `features = ["updater"]` (`quickgui::updater`) |

Importing or enabling the package opts the app in; omitting it leaves the capability out of the binary.

TypeScript `extensions` lists native libraries the CLI must bundle, for example `["@quickgui/extension-terminal"]`. Editor surfaces do not need a second native image. Markdown code fences can use CodeBlock when the editor package is present.

Rust apps enable Cargo features instead of an `extensions` list. Optional editor grammars: `language-packs` / `bundled-languages`, or `quickgui pack-languages`.

Updater usage is in [updater](updater.md).

## Author a reusable component (no native library)

**Go** — export functions that return `*ui.Element`. Publish with Go version tags. `go get` is enough.

```go
func Notice(message string, styles ...ui.StyleBuilder) *ui.Element {
	return ui.Text(message).
		Padding(12).
		BackgroundColor("#eff6ff").
		TextColor("#1e40af").
		BorderRadius(8).
		Style(ui.Style().Merge(styles...))
}
```

Keep optional native integrations in separate packages so importing UI does not pull Terminal or Updater.

**TypeScript** — publish a Solid component package.

```tsx
export function PrimaryButton(props: JSX.NativeProps) {
  return (
    <Button
      {...props}
      style={[props.style, { bg: "#2563eb", color: "#ffffff", roundedLg: true, p3: true }]}
    />
  );
}
```

**Rust** — export functions that return `Element` and use them as children. Keep process-wide services outside `View::render`.

## Scaffold a native extension

```sh
quickgui init-extension my-components --type go
quickgui init-extension my-service --type zig
quickgui init-extension my-service --type rust
```

`--type go` (default) scaffolds a reusable component. `zig` and `rust` scaffold a native service with a typed Go wrapper, a manifest, and an npm artifact package. Flags: `--name`, `--module`, `--npm-package`, `--no-install`. Zig templates need Zig 0.16.x. Each template includes `cmd/demo` and `quickgui.toml`.

## Manifest

Place `quickgui.extension.json` beside the imported Go package source:

```json
{
  "schema": 1,
  "name": "acme-echo",
  "abi": 1,
  "package": "@acme/extension-echo",
  "version": "1.0.0",
  "library": "quickgui_acme_echo"
}
```

Names start with a lowercase letter and contain at most 64 lowercase letters, digits, or hyphens. `host` is reserved. `library` is `quickgui_` plus the name with hyphens replaced by underscores.

Go apps: `host.RequireExtension("acme-echo", "1.0.0")` plus the manifest. The CLI discovers manifests through `go list -deps`. Both are required: the manifest controls bundling; `RequireExtension` controls loading.

## Native contract

Export `quickgui_extension_v1` with C linkage, ABI version `1`, and one table:

- **Component:** `create`, `update`, `render`, `event`, `destroy`
- **Service:** `invoke`, `shutdown`

Rust component libraries depend on `quickgui-extension-sdk` (`Component`, `ComponentFactory`, `ComponentRuntime`), not on the renderer. Stable node keys preserve focus and scroll. Virtual lists request visible rows plus overscan. Calls on an instance are serialized on the native UI thread. Move slow work to a worker. Component frames ≤ 16 MiB; property JSON ≤ 12 MiB. Service request/reply payloads ≤ 64 KiB. Copy borrowed bytes before keeping them.

**Go mount**

```go
func init() { host.RequireExtension("acme-badge", "1.0.0") }

func View(label string) *ui.Element {
	return ui.ExtensionComponent("acme-badge", "badge", map[string]any{
		"label": label,
	}, ui.Props{})
}
```

**Go service**

```go
native.InvokeExtension("acme-echo", "echo", message, func(raw string, err error) { ... })
session := native.OpenExtension(name, options, changed, ready) // close on the UI goroutine
```

**TypeScript**

```ts
import { ExtensionComponent } from "@quickgui/solid";

export function Badge(props: { label: string }) {
  return ExtensionComponent({
    package: "acme-badge",
    component: "badge",
    properties: { label: props.label },
  });
}
```

Also `invokeExtension` and `ExtensionSession` from `@quickgui/native`.

## Artifacts

Stage libraries under `lib/<platform>-<arch>/` and publish as an npm package whose `version` matches the manifest. Helper files go next to the library; declare basenames in a manifest `resources` object keyed by `darwin`, `linux`, or `windows`.

During development set `QUICKGUI_EXTENSION_DIR` to a local artifact directory. Conflicting versions of the same name fail at load. Images stay loaded for the process lifetime.

## Pitfalls

- Apps that do not import/enable an extension must not bundle it.
- Close sessions when the owner is disposed; shutdown must cancel remaining sessions.
- TypeScript Terminal and Updater need an `extensions` config entry; Editor often does not.
- Rust apps link features; they do not `invokeExtension` for first-party capabilities.
