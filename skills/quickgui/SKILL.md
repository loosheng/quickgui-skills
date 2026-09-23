---
name: quickgui
description: QuickGUI is an experimental native desktop GUI framework for Go, TypeScript, and Rust. Use this skill to scaffold, structure, and implement GPU-rendered desktop apps (no webview) with the current v0.1.6 API.
metadata:
  upstream-version: v0.1.6
---

# QuickGUI

## What it is

QuickGUI is a native desktop GUI framework. You write windows and components in **Go**, **TypeScript** (Bun + Solid 2), or **Rust**. The same Rust renderer, layout, and controls run in-process: Go via `purego` (`CGO_ENABLED=0`), TypeScript via `bun:ffi`, Rust by linking the `quickgui` crate. There is no WebView and no application IPC bridge.

**Status:** experimental. Do not use it for anything serious.

**Platforms:** macOS 14+ is the supported development target (Xcode Command Line Tools). Published native assets also cover Linux arm64/x64 and Windows x64; those hosts compile, with native polish still in progress.

## When to use this skill

Use this skill whenever you are creating or editing a QuickGUI application: `bunx @quickgui/cli init`, `quickgui dev` / `build`, fluent Go UI, Solid JSX, or a `quickgui` crate `View`. Read a reference file below before inventing component names, CLI flags, or native APIs.

## Choosing a language

Pick one language per app. Go and TypeScript reuse a prebuilt host library and rebuild only that language. Rust apps `cargo build` the crate on each change.

### Go

Requires Go 1.23+. Components return `*ui.Element`.

```go
package main

import (
	"log"

	"github.com/egoist/quickgui/go/native"
	"github.com/egoist/quickgui/go/ui"
)

func Counter() *ui.Element {
	count, setCount := ui.CreateSignal(0)
	return ui.View().
		FlexCol().
		SizeFull().
		ItemsCenter().
		JustifyCenter().
		Gap(20).
		Bg("#090d16").
		TextColor("#e2e8f0").
		Child(ui.Text("Count: ", count()).FontSize(28).FontWeight(700)).
		Child(ui.Button().
			OnClick(func() { setCount(count() + 1) }).
			Padding(12).
			RoundedLg().
			Bg("#2563eb").
			Hover(func(s ui.StyleBuilder) ui.StyleBuilder { return s.BackgroundColor("#3b82f6") }).
			Child("Increment"))
}

func main() {
	if err := native.Run(func() {
		open := func() {
			native.NewWindow(native.WindowOptions{
				Title:     "My App",
				Width:     720,
				Height:    480,
				Component: Counter,
			})
		}
		native.App.OnReopen(func(event native.ReopenEvent) {
			if !event.HasVisibleWindows {
				open()
			}
		})
		open()
	}); err != nil {
		log.Fatal(err)
	}
}
```

### TypeScript

Requires Bun 1.4+ and TypeScript 7. Styles only through the `style` prop.

```tsx
import { app, Window } from "@quickgui/native";
import { Button, Text, View, createRenderer } from "@quickgui/solid";
import { createSignal } from "solid-js";

function Counter() {
  const [count, setCount] = createSignal(0);
  return (
    <View style={{ padding: 24, display: "flex", flexDirection: "column", gap: 12 }}>
      <Text>Count: {count()}</Text>
      <Button onClick={() => setCount(count() + 1)}>Increment</Button>
    </View>
  );
}

function openWindow() {
  new Window({ title: "Counter", width: 720, height: 480, renderer: createRenderer(Counter) });
}

app.on("reopen", ({ hasVisibleWindows }) => {
  if (!hasVisibleWindows) openWindow();
});
await app.whenReady();
openWindow();
```

### Rust

Requires Rust 1.90+. Store state on a `View` and call `cx.invalidate()` after mutations.

```rust
use quickgui::{
    App, AppInfo, Application, Color, EventContext, IntoElement, View, ViewContext, WindowOptions,
    div, text,
};

fn main() -> Result<(), quickgui::AppError> {
    Application::new()
        .app_info(AppInfo::new("My App", "0.1.0", "com.example.my-app").expect("valid identity"))
        .on_reopen(|has_visible_windows, cx| {
            if !has_visible_windows {
                open_window(cx);
            }
        })
        .run(open_window)
}

fn open_window(cx: &mut App) {
    cx.open_window(WindowOptions::new("My App").size(760.0, 520.0), Counter { count: 0 });
}

struct Counter {
    count: usize,
}

impl View for Counter {
    fn render(&mut self, cx: &mut ViewContext<'_, Self>) -> impl IntoElement {
        let increment = cx.listener("increment", |this, cx: &mut EventContext| {
            this.count += 1;
            cx.invalidate();
        });
        div()
            .size_full()
            .flex_col()
            .items_center()
            .justify_center()
            .gap_3()
            .child(text(format!("Count: {}", self.count)))
            .child(
                div()
                    .on_click(increment)
                    .px_4()
                    .py_2()
                    .rounded_lg()
                    .bg(Color::rgb8(37, 99, 235))
                    .child("Increment"),
            )
    }
}
```

## Core rules

1. **In-process only.** No CGO, no IPC bridge, no extra host process.
2. **Go containers start empty.** `ui.View()`, `ui.Button()` then `.Child(...)` / `.Children(...)`. `ui.Text(value)` is the text factory.
3. **Go components return `*ui.Element` or `*native.Node`.** Consume constructed nodes; void construction callbacks are unsupported.
4. **Go compound controls use instances.** `ui.NewPopover()` then `.Root()` / `.Trigger()` — no `_part` suffixes. Rust parts use `.root()` / `.trigger()` the same way.
5. **Go styles are fluent.** `ui.Style()` + `.Merge(other)`; apply with `.Style(shared)`. No style-option or style-record APIs.
6. **TypeScript styles only through `style`.** CamelCase keys and boolean presets. No `class`, `className`, or loose style attributes. `<div>` / `<span>` alias `View` / `Text`.
7. **Components construct once.** Go/TS signals and Solid track bindings; Rust invalidates a `View`. Do not rebuild the tree every frame.
8. **Signals stay on the UI thread.** Go: one pinned goroutine; use `ui.Async` / `native.Dispatch`. TypeScript: Solid lives in a worker. Rust: mutate on the view, then `cx.invalidate()`.
9. **`native.Run` / `app.whenReady()` / `Application::run` once from startup.** Handle Dock reopen when no windows are visible.
10. **Parts are unstyled.** You supply padding, color, and layout. The core owns focus, keyboard, and placement.
11. **In-window popovers cannot paint outside the window.** Use `SystemPopover` to cross the edge. Drawer exists in TypeScript and Rust only.
12. **Package files via `resources/`.** Join `ResourceDir` / `resourceDir` / `resource_dir()` at runtime; relative image paths are not resolved for you.
13. **Optional capabilities are opt-in.** Import Go `extensions/*`, add `@quickgui/extension-*` (and `extensions` in config when required), or enable Rust crate features. Editor grammars are not in the default bundle.
14. **Document only the current API.** Do not invent names. If unsure, omit it.

## Common workflows

```sh
bunx @quickgui/cli init my-app --language go          # or typescript | rust
cd my-app
quickgui dev
quickgui fmt
quickgui check
quickgui test
quickgui build
```

`init` writes the project and installs dependencies (`--no-install` skips that). Omit `--language` to choose interactively; non-interactive runs must pass it. Config is `quickgui.toml` or `quickgui.config.ts` (`language`, `name`, `identifier`, `entry`). Icon: `resources/icon.png`.

`dev` rebuilds and relaunches after the candidate window is ready. `build` writes `dist/` (macOS DMG, Linux AppImage/deb/tarball, Windows NSIS). Signed updates: `quickgui keygen`, `[updates]` in config, `quickgui build --upload`. See [getting-started](references/getting-started.md) and [updater](references/updater.md).

## Reference index

| File | Read when… |
| --- | --- |
| [getting-started](references/getting-started.md) | Creating a project, CLI flags, config, run/build |
| [go](references/go.md) | Go packages, fluent construction, formatting, goroutines |
| [typescript](references/typescript.md) | Solid JSX, `style` prop, worker model |
| [rust](references/rust.md) | `View`, builders, Cargo features, container queries |
| [components](references/components.md) | Catalog, parts, key props per language |
| [styling](references/styling.md) | Flex/grid, presets, hover groups, paint |
| [reactivity](references/reactivity.md) | Signals, effects, batching, async data |
| [routing](references/routing.md) | Router, layouts, params, navigation |
| [forms-and-input](references/forms-and-input.md) | Inputs, fields, select, dates, focus |
| [overlays-and-dialogs](references/overlays-and-dialogs.md) | Popover, dialog, toast, menus, native dialogs |
| [animations](references/animations.md) | Transitions, reduced motion, GIF/WebP |
| [rendering](references/rendering.md) | Show/For, images, SVG, shaders, virtual lists |
| [native-services](references/native-services.md) | Windows, tray, clipboard, notifications |
| [resources](references/resources.md) | App icon, bundled files, fonts |
| [extensions](references/extensions.md) | Editor, markdown, terminal, authoring extensions |
| [swift-ui](references/swift-ui.md) | macOS SwiftUI controls and hosting |
| [updater](references/updater.md) | Signed updates, GitHub/S3, Linux `install.sh` |
| [testing](references/testing.md) | `quickgui test`, Rust `test-support` |

Upstream docs: [https://github.com/egoist/quickgui/blob/v0.1.6/AGENTS.md](https://github.com/egoist/quickgui/blob/v0.1.6/AGENTS.md), website guides under `website/src/content/docs/{go,typescript,rust}/en/`.
