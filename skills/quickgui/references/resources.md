# Resources

Application icon, the packaged `resources/` directory, extra resource files, and custom fonts. Runtime paths come from the host, not the process working directory.

## App icon

Put a square PNG at `resources/icon.png` (at least 256×256, at most 16 MiB; 1024×1024 is a good source). `quickgui build` resizes it to every platform size:

| Target | Sizes |
| --- | --- |
| macOS `.icns` | 32, 64, 128, 256, 512, 1024 |
| Windows `.ico` | 16, 24, 32, 48, 64, 128, 256 |
| Linux `hicolor` | 16, 32, 48, 64, 128, 256, 512 |

Optional overrides in `resources/`: `icon.icns`, `icon.ico`. Optional `resources/icon.iconset/icon_<n>x<n>.png` replaces a generated size (build input only; not copied into the app).

Config overrides (must be the matching container type):

```ts
export default defineConfig({
  name: "My App",
  identifier: "com.example.my-app",
  entry: ".",
  macos: { icon: "packaging/AppIcon.icns" },
  windows: { icon: "packaging/AppIcon.ico" },
  linux: { icon: "assets/linux.png" }, // used only when resources/icon.png and `icon` are absent
});
```

Set top-level `icon` only when the source PNG is not `resources/icon.png`. Linux builds without an icon get a gray placeholder in the AppImage and tarball; the build notes that none is configured.

## Window and Dock icons

The packaged icon is application identity. A window can show a different image on **Windows and X11**:

```go
native.NewWindow(native.WindowOptions{
	Title: "My App",
	Icon:  &native.ImageSource{Path: iconPath},
	Component: App,
})
```

`iconPath` is an absolute filesystem path. After creation: Go `window.SetIcon` / `ClearIcon`; TypeScript `setIcon` / `clearIcon`; Rust `WindowOptions::icon` / `set_window_icon` / `clear_window_icon`.

On **macOS**, windows have no per-window icon. Use the Dock:

- Go: `native.Desktop.SetDockIcon(&native.ImageSource{Path: iconPath})`; `nil` restores the bundle icon
- TypeScript: `app.dock.setIcon(...)`
- Rust: `cx.set_dock_icon`

Template-image rules (stem ending in `Template`) apply; see [native-services](native-services.md). Menu-bar / notification-area artwork is a tray icon, not this file.

## Bundled `resources/`

The CLI copies the project `resources/` directory into the packaged app. Paths stay relative to that folder: `resources/hero.png` installs as `hero.png`.

```text
my-app/
├── resources/
│   ├── icon.png
│   ├── hero.png
│   └── copy/template.txt
```

Destination names must not replace reserved names: `fonts`, `AppIcon.icns`, `quickgui.json`, the host shared library, generated packaging names (`*.AppDir`, `*-setup.exe`, and similar).

The directory is optional. `quickgui dev` and `quickgui build` both stage it.

## Extra files

The `resources` config array merges additional files or folders by **basename**. Do not list the project `resources/` folder; it is included automatically.

```ts
export default defineConfig({
  name: "My App",
  identifier: "com.example.my-app",
  entry: ".",
  resources: ["legal/NOTICE.txt", "vendor/data"],
  fonts: ["assets/MyFont.ttf"],
});
```

`legal/NOTICE.txt` → `NOTICE.txt`. `vendor/data` → `data/`. A missing listed path fails the build. Directory payloads are copied recursively.

## Install locations

| Platform | Resource directory |
| --- | --- |
| macOS `.app` | `Contents/Resources` |
| Linux AppDir, AppImage, `.deb` | Next to the executable |
| Linux `install.sh` tarball | Next to the executable (`~/.local/<package>.app/bin`) |
| Windows installer / development | Next to the executable |

Rust apps keep `quickgui.json` with the resources (in `Contents/Resources` on macOS).

## Loading files

Ask the host for paths after the app is ready, then join the packaged name. Relative image paths are not resolved against the resource directory.

**Go**

```go
native.Run(func() {
	native.App.GetPaths(func(paths *native.AppPaths, err error) {
		if err != nil || paths == nil { return }
		hero = filepath.Join(paths.ResourceDir, "hero.png")
		native.NewWindow(native.WindowOptions{Title: "My App", Component: App})
	})
})
```

**TypeScript** — `const paths = await app.getPaths(); join(paths.resourceDir, "hero.png")`.

**Rust** — `cx.app_paths()?.resource_dir().join("hero.png")`. Optional `BundledAssets` + `Application::assets` / `.font(...)`. Asset paths reject `..`, absolute paths, and backslashes.

Open other files with the language’s ordinary file APIs (`os.ReadFile`, `Bun.file`, `std::fs`).

## Fonts

`fonts` lists OpenType files. The CLI copies them into `fonts/` inside the resource directory and registers them before the first window opens. Use the font family name in styles. Fonts are not a substitute for `resources/` (images and JSON still belong there).

Rust can also call `Application::font(bytes | asset_path)`. Staging is capped (on the order of 64 files / 64 MiB; see upstream `docs/assets-and-fonts.md`).

## Pitfalls

- Never read packaged files from cwd or the source tree at runtime.
- Reserved destination names are rejected so a resource cannot overwrite packaging outputs.
- Linux without `resources/icon.png` still builds; AppImage gets a placeholder.
- `BundledAssets` paths are tightly validated (Rust).
