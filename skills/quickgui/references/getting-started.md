# Getting started

Prerequisites, project creation, CLI commands, generated layout, and how to run or package a QuickGUI app. Language-specific UI idioms live in [go](go.md), [typescript](typescript.md), and [rust](rust.md).

## Status and platforms

QuickGUI is experimental. Do not use it for production-critical work.

- **Supported development target:** macOS 14+ with Xcode Command Line Tools (`xcode-select --install`).
- **Toolchains:** Go 1.23+, Bun 1.4+, TypeScript 7 (TypeScript apps), Rust 1.90+ (Rust apps).
- **Published native assets:** macOS arm64/x64, Linux arm64/x64, Windows x64. Windows and Linux compile; native polish (IME, accessibility, clipboard, visuals) is still in progress.

Go and TypeScript load a prebuilt Rust shared library in-process (`CGO_ENABLED=0`, no IPC). Rust apps link the `quickgui` crate and do not load that library.

## Create a project

```sh
bunx @quickgui/cli init my-app --language go
bunx @quickgui/cli init my-app --language typescript
bunx @quickgui/cli init my-app --language rust
```

Omit `--language` to choose interactively. Non-interactive environments must pass `--language`. `--frontend` is accepted as an alias. `--no-install` skips dependency installation. Init refuses to overwrite a non-empty directory.

Optional: `--name <display name>` and `--identifier <reverse-DNS id>`.

## Generated files

**Go**

```text
my-app/
├── resources/icon.png
├── main.go
├── go.mod
├── go.sum
├── quickgui.config.ts
├── package.json
└── README.md
```

**TypeScript**

```text
my-app/
├── resources/icon.png
├── app.tsx
├── quickgui.config.ts
├── tsconfig.json
├── package.json
└── README.md
```

**Rust**

```text
my-app/
├── resources/icon.png
├── src/main.rs
├── Cargo.toml
├── Cargo.lock
├── quickgui.config.ts
├── package.json
└── README.md
```

Commit `go.sum` / `Cargo.lock` after the first resolve. Build output lives in `.quickgui`; packaged apps live in `dist/`.

## CLI commands

Install the CLI as a project dependency (`@quickgui/cli`) and run `quickgui …`, or use `bunx @quickgui/cli …`.

| Command | Effect |
| --- | --- |
| `quickgui init [dir]` | Scaffold a project |
| `quickgui init-extension [dir]` | Scaffold a Go, Zig, or Rust extension (`--type go\|zig\|rust`) |
| `quickgui dev` | Compile, launch, rebuild on change |
| `quickgui build` | Production package under `dist/` |
| `quickgui fmt` | Format (Go SDK formatter, TypeScript project formatter, rustfmt) |
| `quickgui check` | Type-check with the same pipeline as `dev`/`build` |
| `quickgui test` | Run tests with the same compiler as builds |
| `quickgui keygen` | Write Ed25519 update keys |
| `quickgui pack-languages` | Bundle Tree-sitter Wasm grammars for the editor |

Shared flags: `--project <dir>`, `--config <file>`. `dev` also has `--once`, `--no-launch`, `--target`, `--sign`. `fmt` has `--check`. `check`/`test` have `--release`.

### `dev`

```sh
quickgui dev
quickgui dev --project path/to/app
quickgui dev --once --no-launch
```

On macOS this writes an ad-hoc signed bundle under `.quickgui/dev/<target>/`. The CLI replaces the running process only after the candidate’s first native window is ready. Quitting the app stops the watcher. Config changes reload during `dev`.

### `build`

```sh
quickgui build
quickgui build --target darwin-arm64
quickgui build --target darwin-x64
quickgui build --target linux-x64
quickgui build --target windows-x64
quickgui build --sign "Developer ID Application: Example (TEAMID)" --notarize quickgui-notary
quickgui build --mas
quickgui build --update-manifest
quickgui build --upload
```

Targets: `darwin-arm64`, `darwin-x64`, `linux-arm64`, `linux-x64`, `windows-arm64`, `windows-x64`. macOS production builds write a versioned DMG (Finder window, Applications drop link). `--mas` signs for the Mac App Store. Linux and Windows packaging, signed updates, and `--upload` are in [updater](updater.md) and [resources](resources.md).

### `fmt` / `check` / `test`

```sh
quickgui fmt
quickgui fmt --check
quickgui check
quickgui test
```

Go `fmt` wraps long fluent UI chains one call per line, then runs standard Go formatting. TypeScript uses the project’s `oxfmt`. Rust uses `rustfmt`. `check`/`test` dispatch to the selected language (Go view compiler, TypeScript compiler, Cargo).

### `keygen`

```sh
quickgui keygen --out-dir ~/.config/my-app/update-keys
```

Writes `quickgui-update.pub` and `quickgui-update.key`. `--force` overwrites. See [updater](updater.md).

## Configuration

`dev` and `build` read `quickgui.toml` first, then `quickgui.config.ts`. Pass `--config path` to choose a file. Relative paths resolve from the project directory. Quote `version` and `buildVersion` in TOML.

```ts
import { defineConfig } from "@quickgui/cli";

export default defineConfig({
  language: "go", // "go" | "rust" | "typescript"; `frontend` is an alias
  name: "My App",
  identifier: "com.example.my-app",
  entry: ".", // Go/Rust crate dir, or TypeScript "app.tsx"
  version: "0.1.0",
  fonts: ["assets/Custom.ttf"],
  resources: ["legal/NOTICE.txt"],
  protocols: ["my-app"],
  native: { tags: ["production"] }, // Go build tags
  macos: {
    icon: "assets/AppIcon.icns",
    minimumSystemVersion: "14.0",
    signingIdentity: "Developer ID Application: Example (TEAMID)",
    notarization: { keychainProfile: "quickgui-notary" },
  },
});
```

Equivalent TOML uses the same option names. Nested options are tables; document types use `[[documentTypes]]`.

The project `resources/` directory is packaged automatically. Put the app icon at `resources/icon.png`. The `resources` array only adds extra files or folders. See [resources](resources.md).

- Go: `entry` is the Go package to build (for example `"."` or `"cmd/app"`). `native.tags` are Go build tags. `native.libraryPath` or `QUICKGUI_LIBRARY` selects a custom host library.
- TypeScript: `entry` defaults to `app.tsx`. Set `jsx: "preserve"` and `jsxImportSource: "@quickgui/solid"` in `tsconfig.json`.
- Rust: `entry` is the crate directory. Enable optional capabilities as Cargo features, not as an `extensions` list.

## Run and package

```sh
cd my-app
quickgui dev
quickgui fmt
quickgui check
quickgui build
```

`dev` rebuilds Go or TypeScript only; Rust apps rebuild the crate. `build` writes packaged artifacts under `dist/`.

## Pitfalls

- Init overwrites nothing: the destination must be empty.
- `--language` is required without a TTY.
- Development builds never offer updates (`disabled`). Test the updater with a production package.
- Do not introduce CGO or an IPC bridge. Go uses `purego`; TypeScript uses `bun:ffi`; both stay in-process.
- `quickgui.toml` wins over `quickgui.config.ts` when both exist.

Upstream: [CLI](https://github.com/egoist/quickgui/blob/v0.1.6/docs/cli.md), [Go getting started](https://github.com/egoist/quickgui/blob/v0.1.6/website/src/content/docs/go/en/getting-started.mdx).
