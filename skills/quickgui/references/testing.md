# Testing

How to type-check and test QuickGUI applications. `quickgui check` and `quickgui test` use the same view compiler as `dev` and `build`. Prefer them over raw `go test` / `tsc` / `cargo test` when the app uses retained bindings or JSX.

## CLI

```sh
quickgui check
quickgui test
quickgui fmt --check
quickgui check --release
```

| Language | `check` | `test` | `fmt` |
| --- | --- | --- | --- |
| Go | view compiler | compiled tests, `CGO_ENABLED=0` | SDK formatter then gofmt |
| TypeScript | project TypeScript compiler | same Solid compiler and client runtime as builds | project `oxfmt` |
| Rust | Cargo | Cargo (`--release` optional) | rustfmt |

`--project <dir>` selects another app. Go formatting also: `go run github.com/egoist/quickgui/go/cmd/quickguifmt`.

The app is a native executable: ordinary Go/Rust/TypeScript debuggers and stack traces apply.

## Go

`quickgui test` from the app module. Components remain ordinary functions returning `*ui.Element`, so table-driven tests can build UI and assert on returned nodes.

`host` is a replaceable host interface for tests. Direct `go test` without the CLI bypasses the view compiler and needs explicit accessors.

Gallery: `examples/components`. Larger app: `examples/quick-git`.

## TypeScript

```sh
quickgui check
quickgui test
```

`test` preloads the Solid universal compiler and reactive client runtime. Capture `Window.getCurrentWindow()` during setup in component tests that close or retitle. Use `flush()` when queued signal updates must settle before an assertion.

Gallery: `examples/components-typescript`. Larger app: `examples/quick-git-typescript`.

## Rust: `test-support`

Enable only in dev-dependencies so production builds stay clean:

```toml
[dev-dependencies]
quickgui = { version = "...", features = ["test-support"] }
```

`TestAppContext` reuses production views, identity, focus, form/input state, listeners, keymap, and window ownership. Ordinary semantic tests create **no** Winit event loop, native window, WGPU adapter, background worker, accessibility service, or timer thread.

```rust
let (mut cx, counter) = Application::new().into_test_context(
    WindowOptions::default(),
    Counter { count: 0 },
)?;
let window = counter.window_handle();

cx.click(window, "increment")?;
assert_eq!(cx.read(counter, |view| view.count)?, 1);

cx.simulate_keystrokes(window, "ctrl-s")?;
cx.advance_time(Duration::from_millis(500))?;
```

### Visual frames

Geometry and screenshot calls lazily create one windowless WGPU renderer (production Taffy, paint tree, Cosmic Text, offscreen RGBA8). No native window or presentation loop.

```rust
let mut visual = cx.visual(window)?;
visual.assert_element_bounds("card", Rect::new(24.0, 18.0, 320.0, 96.0), 0.01)?;
let actual = visual.capture_screenshot()?;
actual.assert_matches_png("tests/snapshots/counter.png", VisualTolerance::new(1, 0))?;
```

Screenshots use the deterministic window scale factor, capped at 4,096 physical pixels per axis and 64 MiB RGBA. Tests never update goldens implicitly; `write_png` creates a baseline on purpose. Raw `NSView` pixels cannot exist in the windowless target — capture rejects that frame; the QuickGUI host element can still use `element_bounds`.

Variable-height lists settle before returning (at most eight layout passes). An app that changes an item’s height every render fails deterministically.

### Simulation helpers

Semantic clicks focus and activate a stable element ID. Also: `simulate_keystroke` / `simulate_key_up` / `simulate_keystrokes`, `simulate_scroll_wheel`, `simulate_retained_scroll`, scrollbar press/drag/release, `simulate_touch`, `simulate_mouse_pressure`, `simulate_pinch`, `simulate_rotation`, `simulate_smart_magnify`, `simulate_appearance_change`, `simulate_keyboard_layout_change`.

Clipboard is in-memory (`write_to_clipboard` / `read_from_clipboard`). `advance_time` / `advance_frame` drive animations. `inspector` + `test-support` yields `inspector_snapshot`.

`focus_visible` follows production rules: pointer focus does not show focus styles; keyboard (Tab, arrows, Enter) does.

Gallery: `examples/base_ui_components.rs`. Enable `inspector` for the in-app inspector.

## Pitfalls

- Do not skip `quickgui test` for Go/TS apps that rely on the view/JSX compiler.
- Visual tests are offscreen WGPU, not AppKit pixels.
- Do not update screenshot goldens as a side effect of a passing test.
- Updater tests need a production package; development builds are `disabled`.
