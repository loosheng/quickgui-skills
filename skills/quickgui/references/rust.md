# Rust

Rust idioms: the `quickgui` crate, `View`/`Element` builders, parts without `_part` suffixes, Cargo workflow, and optional features.

## Crate and features

A Rust app links `quickgui` and does not load `libquickgui_host`. Enable optional capabilities in `Cargo.toml`:

```toml
[dependencies]
quickgui = { version = "...", features = ["updater"] }
```

| Feature | Capability |
| --- | --- |
| `updater` | `quickgui::updater` |
| `editor` | Editor, CodeBlock, DiffView |
| `markdown` | Markdown |
| `terminal` | Terminal |
| `swift-ui` | macOS SwiftUI hosting |
| `file-watcher` | Filesystem events |
| `test-support` | `into_test_context` (dev-dependency) |
| `inspector` | In-app inspector |
| `language-packs` / `bundled-languages` | Editor grammars (not in the default bundle) |

Keep the crate version already in the project. Packaged identity and fonts are written to `quickgui.json` beside the executable, or in `Contents/Resources` on macOS.

## Startup

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
```

`Application::run` owns startup. Each window owns a `View`. Closing a window drops that view.

## Views and elements

Screens that keep state implement `View`. Stateless pieces can be functions that return `Element`.

```rust
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
                    .hover(|style| style.bg(Color::rgb8(59, 130, 246)))
                    .child("Increment"),
            )
    }
}
```

Store state on the view. Register listeners with `cx.listener`. After a mutation call `cx.invalidate()`. Multiple invalidations in one event become one render. Do not install a timer to redraw when nothing changed.

A value copied in `render` is the current frame’s snapshot. Give stateful rows a stable `.id(...)`.

## Primitives

| Factory | Role |
| --- | --- |
| `div()` | Container |
| `text(...)` | Text |
| `button()` | Button |
| `text_input(...)` / `text_area(...)` | Editors |
| `submit_button` | Submits the nearest `form` |
| `img(...)` | Image (`ImageSource`) |
| `svg(...)` | Inline SVG |
| `custom_shader(...)` | WGSL |
| `VirtualList` | Virtualized collection |

Fluent style methods set layout, paint, typography, and interaction. Lengths are logical pixels. Presets such as `flex_col`, `p_3`, `rounded_lg`, and `text_lg` match Go/TypeScript helpers (`p_3` is 12px). Custom values use `rounded(10.0)`, `p(14.0)`, `w` / `h`.

`when` applies a branch only if the condition is true:

```rust
div().p(12.0).when(self.selected, |style| style.bg(Color::rgb8(37, 99, 235)))
```

Reusable styles are functions that take and return `Element`.

## Compound parts

Parts use `.root()` / `.trigger()` (and `*_with` when supplying a child element). No `_part` suffixes.

```rust
let checkbox = Checkbox::new(self.checked);
checkbox
    .root()
    .flex_row()
    .gap(8.0)
    .on_click(toggle)
    .child(checkbox.indicator_with(div().size(16.0, 16.0)))
    .child(text("Remember this device"))
```

Keep parts under the root they belong to. Types such as `TabsState` and `SelectState` expose current state. Store values on the view, pass them into constructors, and update them from listeners.

For overlays, mount popup/positioner content only while open. Closed content must leave the tree. See [overlays](overlays-and-dialogs.md).

## Cargo workflow

```sh
quickgui check
quickgui test
quickgui fmt
quickgui dev
quickgui build
```

`dev` streams Cargo progress, warnings, and compiler diagnostics. `fmt` runs `rustfmt`. Production builds use `cargo build --release`. Ordinary app edits rebuild the crate (unlike Go/TypeScript, which reuse the prebuilt host library).

`quickgui build` embeds `[updates]` into the executable when the `updater` feature is enabled, and stages the install helper or `Sparkle.framework`.

## Async and background work

Spawn work from listeners or `Application` callbacks with `cx.spawn`. Stop it when the view is dropped (`Drop`). Capture `cx.window_handle()` during a listener when later work needs that window.

File watching requires the `file-watcher` feature. Drop watchers with the owning view.

## Container queries

Rust-only. Use `container_query` when a subtree must follow the box its parent assigned, not the window size:

```rust
use quickgui::{container_query, div, text};

container_query(|size| {
    if size.width < 480.0 {
        div().flex_col().child(text("Compact layout"))
    } else {
        div().grid().grid_cols(3).child(text("Wide layout"))
    }
})
```

The query is a layout leaf; the callback cannot change the query’s intrinsic size. Limit: 1,024 mounted queries per window, 16 nested levels. `.child(...)` on the query itself is rejected.

## Pitfalls

- Call `cx.invalidate()` after mutating view state, including after `router.push`.
- Do not rebuild every frame for animation; set a transition on the element.
- Development `cargo run` does not embed updater config; status is `Disabled`.
- Enable features in `Cargo.toml`; do not list `extensions` in app config.
- SwiftUI requires `features = ["swift-ui"]` and macOS.

Upstream: [Rust getting started](https://github.com/egoist/quickgui/blob/v0.1.6/website/src/content/docs/rust/en/getting-started.mdx), [view API](https://github.com/egoist/quickgui/blob/v0.1.6/docs/view-api.md).
