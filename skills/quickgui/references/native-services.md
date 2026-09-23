# Native services

Windows, application lifecycle, clipboard, file dialogs, notifications, tray, menus, and other OS APIs. Call these after the app is ready. Operations that return a result are asynchronous (Go callbacks, TypeScript promises, Rust `cx` methods). Signals and UI stay on the UI goroutine / worker.

Tray artwork and template-image rules are here; the packaged app icon is in [resources](resources.md).

## Window lifetime

**Go** — `native.Run` once from `main`; `native.NewWindow(WindowOptions{Title, Width, Height, Component})`. Capture `native.CurrentWindow()` while constructing. `native.App.OnReopen` opens a window when the Dock icon is clicked and none are visible.

Window actions include `SetBounds`, `SetSize`, `Minimize`, `Maximize`, `Restore`, `Show`, `Hide`, `SetFullscreen`, `SetTitle`, `Close`, `Destroy`, `SetIcon` / `ClearIcon`, `SetAlwaysOnTop`, `SetMenu`, `PopupMenu`. `OnCloseRequested` can hold a close.

**TypeScript** — `await app.whenReady()` then `new Window({ title, width, height, renderer })`. `whenReady()` on the window resolves after the native window exists. `onClose` / `on("closed")` after teardown. `onCloseRequested` can hold a close. `app.on("reopen", ({ hasVisibleWindows }) => { ... })`.

**Rust** — `Application::new().run(|cx| { cx.open_window(WindowOptions::new("Title").size(w, h), view); })`. `on_reopen(|has_visible_windows, cx| ...)`. Capture `cx.window_handle()` in a listener when later work needs that window. `cx.close_window()`.

A command queued between `open_window` returning and the platform window’s creation waits for that window.

## Application

| | Go | TypeScript | Rust |
| --- | --- | --- | --- |
| Quit | `App.Quit(false, nil)` | `app.quit()` | `cx.exit()` |
| Paths | `App.GetPaths(cb)` → `AppPaths.ResourceDir` | `app.getPaths()` → `resourceDir` | `cx.app_paths()?.resource_dir()` |
| Reopen | `App.OnReopen` | `app.on("reopen")` | `Application::on_reopen` |

Also: activation, open URLs / deep links, `OnBeforeQuit` / `OnWillQuit`, `App.Exit`. Protocol registration: Go `Protocol` / `DeepLink`; config `protocols`. Auto-start: `AutoStart`.

## Dialogs, clipboard, shell

File and alert dialogs: [overlays-and-dialogs](overlays-and-dialogs.md).

**Clipboard**

- Go: `Clipboard.Read` / `ReadText` / `Write` / `WriteText` / `WriteImage` / `WriteFiles` / `ReadFind` / `WriteFind`. Entries: `"text"` | `"data"` | `"image"` | `"files"` | `"bookmark"`.
- TypeScript: `Clipboard` from `@quickgui/native` (`read`, `write`, `readText`, `writeText`, `clear`, …).
- Rust: `cx.write_to_clipboard` / `read_from_clipboard`. macOS Find pasteboard: `write_to_find_pasteboard` / `read_from_find_pasteboard`.

**Shell** — open/reveal paths and URLs: Go `Shell`; TypeScript `Shell`; Rust `open_url`, `open_path`, `reveal_path`.

## Menus

Native window and application menus (distinct from in-window `Menu` / `Menubar` components).

Go: `Window.SetMenu`, `PopupMenu`. TypeScript: `Menu` from `@quickgui/native`. A declared native `services` menu item on macOS registers a fresh services menu when Winit already owns one.

## Tray

Create after startup from a packaged PNG. At most 32 tray icons. Separate from the app icon.

**Go**

```go
native.App.GetPaths(func(paths *native.AppPaths, err error) {
	if err != nil || paths == nil { return }
	icon := filepath.Join(paths.ResourceDir, "trayTemplate.png")
	native.Tray.Create(native.TrayIconOptions{
		Icon:    native.TemplateImage(icon),
		Tooltip: "My App",
		Menu: []native.TrayMenuItem{
			{Label: "Show window", Click: showWindow},
			{Type: "separator"},
			{Label: "Quit", Click: func() { native.App.Quit(false, nil) }},
		},
	}, func(tray *native.TrayIcon, err error) {
		if err != nil { return }
		tray.OnEvent(func(event native.TrayEvent) {
			if event.Kind == "click" { showWindow() }
		})
	})
})
```

`tray.Update`, `tray.ShowMenu`, `tray.Destroy`. Events: `click`, `double-click`, `enter`, `move`, `leave`, `menu-item`, `scroll`.

**TypeScript**

```tsx
const paths = await app.getPaths();
const tray = await Tray.create({
  icon: join(paths!.resourceDir, "trayTemplate.png"),
  tooltip: "My App",
  menu: [
    { label: "Show window", click: showWindow },
    { type: "separator" },
    { label: "Quit", click: () => void app.quit() },
  ],
});
tray.on("click", showWindow);
```

`tray.update` / `showMenu` / `destroy`. `Tray.isSupported()`.

**Rust** — `EventContext` can create, replace, remove, and (macOS/Windows) pop a tray menu from `Application::run` without `AppRunner`.

```rust
Application::new()
    .on_tray_event(|event, cx| {
        if event.kind == TrayEventKind::Click { /* show window */ }
        if event.kind == TrayEventKind::MenuItem && event.menu_item_id == Some(2) {
            cx.exit();
        }
    })
    .run(|cx| {
        let icon = TrayIconImage::from_path(
            cx.app_paths().unwrap().resource_dir().join("trayTemplate.png"),
        ).expect("tray icon");
        cx.set_tray_icon(
            TrayIconOptions::new(1, icon)
                .tooltip("My App")
                .menu([
                    TrayMenuItem::action(1, "Show window"),
                    TrayMenuItem::separator(),
                    TrayMenuItem::action(2, "Quit"),
                ]),
        ).expect("tray icon");
        cx.open_window(WindowOptions::new("My App").size(760.0, 520.0), App);
    })
```

`remove_tray_icon`, `show_tray_menu`. Kinds: `Click`, `DoubleClick`, `Enter`, `Move`, `Leave`, `Scroll`, `MenuItem`.

### Template images (macOS)

A filename stem ending in `Template`, optionally `@2x` / `@3x`, is a monochrome mask AppKit recolors. `trayTemplate.png` matches; `emailTemplateIcon.png` does not.

- Go: `TemplateImage(path)` or `ImageSource.Template`
- TypeScript: `{ path, template: true }` or `iconIsTemplate`
- Rust: `Image::open` / `TrayIconImage::from_path` infer the name; `.template(true|false)` overrides. `quickgui::is_template_image_path` is the same check.

Other platforms keep the flag and ignore it. A 22×22 PNG is a good 1× source; add `trayTemplate@2x.png` for retina.

`ShowMenu` / `showMenu` / `show_tray_menu` works on macOS and Windows. Linux StatusNotifierItem hosts own menu presentation and reject it.

Do not destroy an app-level tray when a window closes.

## Notifications, shortcuts, appearance

| | Go | TypeScript | Rust |
| --- | --- | --- | --- |
| Notifications | `Notifications` | `Notifications` | `show_system_notification` / `dismiss_system_notification` |
| Global shortcuts | `GlobalShortcut` | `GlobalShortcut.register(accelerator, listener)` | application key bindings |
| Displays | `Screen` | `Screen.getAllDisplays()` | display events |
| Appearance | `Appearance` | `Appearance` | `simulate_appearance_change` in tests; system snapshot |
| Preferences | `SystemPreferences` | `SystemPreferences` | `SystemPreferences::snapshot()` / `cx.system_preferences()` |
| Keyboard | `Keyboard` | `Keyboard` | keyboard layout snapshot |

macOS notifications need a real `.app` and `CFBundleIdentifier`.

## Permissions, power, storage

Go/TS: `Permissions` (`status` / `request`), `PowerMonitor`, `PowerAssertion`, `SecureStorage`. Rust: `PermissionManager::status` / `request`; `PermissionKind::{Camera, Microphone, …}`.

## Desktop extras (platform-specific)

Go `Desktop`, TypeScript `app.dock` / `Desktop`, Rust `DesktopIntegrationSupport::current()`:

| Capability | Platforms |
| --- | --- |
| Dock icon / badge | macOS |
| Taskbar progress / Jump List | Windows |
| Recent documents, About, file icon | macOS + Windows |
| Quick Look, color/font panel, share, biometrics | **macOS only** |

Go: `Desktop.SetDockIcon(&ImageSource{Path})`; `nil` restores the bundled icon. TypeScript: `app.dock.setIcon(...)`. Rust: `cx.set_dock_icon`. macOS windows have no per-window icon.

## File watching

Go: `native.WatchFiles(paths, changed, ready)` returns a stop function; register it with `ui.OnCleanup`. TypeScript: Bun file watching; stop in `onCleanup`. Rust: crate feature `file-watcher`; drop with the view. Prefer OS notifications over polling.

## Other

Go also exposes `SpellChecker`, `CrashReporter`, `Metrics`, `InvokeExtension`, `OpenExtension`. TypeScript: `CrashReporter`, `Metrics`, `invokeExtension`, `ExtensionSession`. Rust: `on_system_wake`, `on_open_urls`, `on_system_notification_response`, `on_color_panel_change`, `on_font_panel_change`, `crash-reporter` (default feature).

## Pitfalls

- Never block waiting for the native main thread.
- Join resource paths from `GetPaths` / `getPaths` / `app_paths`, not cwd.
- Keep process-level tray and updater alive when windows close.
- Linux tray cannot `ShowMenu`.
- SwiftUI and several desktop panels are macOS-only.
