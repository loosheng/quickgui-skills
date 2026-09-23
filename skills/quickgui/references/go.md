# Go

Go idioms for QuickGUI applications: packages, element construction, retained bindings, formatting, and concurrency. Components, styling, and native services have their own reference files.

## Packages

| Package | Role |
| --- | --- |
| `github.com/egoist/quickgui/go/native` | App/window lifecycle, nodes, events, dialogs, menus, clipboard, tray, watchers |
| `github.com/egoist/quickgui/go/ui` | Fluent styles, primitives, compound controls, `Show`/`For`, routing, SwiftUI |
| `github.com/egoist/quickgui/go/reactive` | Signals, memos, batching, effects, owners, contexts |
| `github.com/egoist/quickgui/go/host` | purego C ABI adapter; `RequireExtension` for native extensions |

`purego` loads the prebuilt Rust library with `CGO_ENABLED=0`. Do not add CGO or an IPC bridge.

## Startup

Call `native.Run` once from `main`. It reserves the process main thread for AppKit/Winit. Components and events run on one Go goroutine pinned to an OS thread.

```go
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

Pass a component function as `WindowOptions.Component`. Capture `native.CurrentWindow()` while the component is mounting if a later callback needs the window.

## Components return `*ui.Element`

Every component and UI construction callback returns `*ui.Element` or `*native.Node`. Return, assign, or pass constructed nodes as children. Discarded construction calls and void callbacks are rejected.

```go
func Hello() *ui.Element {
	return ui.View().Padding(20).Gap(12).Children(
		ui.Text("Hello from Go"),
		ui.Button().Child("Continue").OnClick(func() {}),
	)
}
```

`View` takes no arguments. Start empty, then append:

- `.Child(value)` — one child
- `.Children(first, second)` — several; also accepts `[]*ui.Element`, `[]*native.Node`, or `[]any`

Strings are valid children. `ui.Text(value)` / `ui.Text("Count: ", count())` are the text factories. `ui.Fragment(...)` groups siblings without a wrapper.

Plain `if`/`for` run only during construction. Use `ui.Show`, `ui.For`, and `ui.KeyedFor` for reactive structure.

## Compound controls

Create an instance, then compose named parts. No `_part` suffixes.

```go
func TabsExample() *ui.Element {
	tabs := ui.NewTabs().DefaultValue("account")
	return tabs.Root().Children(
		tabs.List().Children(
			tabs.Tab("account").Child("Account"),
			tabs.Tab("security").Child("Security"),
		),
		tabs.Panel("account").Child("Account settings"),
		tabs.Panel("security").Child("Security settings"),
	)
}
```

Configure behavior on the instance; style the parts. Create each instance inside the component that owns it.

## Retained bindings

Components run once when mounted. Reading a signal inside a property or child subscribes that binding. No annotations are required.

```go
func CounterLabel(count int) *ui.Element {
	return ui.Text("Count: ", count).FontSize(20)
}

func ComponentExample() *ui.Element {
	count, setCount := ui.CreateSignal(0)
	return ui.View().Children(
		CounterLabel(count()),
		ui.Button().Child("Increment").OnClick(func() { setCount(count() + 1) }),
	)
}
```

- `ui.Text("Count: ", count)` keeps the prefix and updates only the number.
- `initial := count()` is a snapshot.
- Use `strconv` and concatenation when a property needs one combined string.

`.Value`, `.Width`, `.OnClick`, and other modifiers return the same retained element. Later declarations replace earlier values without remounting children.

- `.OnClick(func() { ... })` — click
- `.OnInput(func(value string) { ... })` — text
- `.OnClickEvent` / `.OnInputEvent` / `.OnSubmitEvent` — full `*native.Event`

`.Ref(func(node *native.Node) { ... })` runs once in chain order. Pass `element.Node` to low-level APIs.

## Styles

Use fluent methods on the element, or `ui.Style()` for reusable builders. Apply with `.Style(shared)`. `.Merge(other)` returns a new builder; builders are never mutated.

```go
card := ui.Style().Padding(20).RoundedLg().
	Hover(func(s ui.StyleBuilder) ui.StyleBuilder { return s.Bg("#1e293b") })
return ui.View().Child("Hello").Style(card)
```

Layout helpers match Rust names in Go case: `.FlexCol()`, `.FlexRowReverse()`, `.Flex1()`, `.ItemsCenter()`, `.JustifyBetween()`, `.GridCols(3)`, `.ColSpanFull()`, `.P4()`, `.MxAuto()`, `.SizeFull()`, `.RoundedLg()`, `.TextSm()`. `.Flex()` sets display flex; `.Flex1()` sets grow 1, shrink 1, zero basis.

`.When(condition, style…)` applies extra styles while true. Pass a getter for a live condition: `.When(selected, ui.Style().Bg("#2563eb"))`.

## Formatting

Run `quickgui fmt`. Long UI calls (over 100 columns), multiline calls, and calls with callbacks use one argument per line. Long fluent chains put each method on its own line. Then `gofmt` handles ordinary spacing. `quickgui fmt --check` is for CI.

Editor integration: `go run github.com/egoist/quickgui/go/cmd/quickguifmt`.

## Background work

Do not read or write signals from worker goroutines.

- `native.Dispatch(func() { … })` queues work onto the UI goroutine.
- `ui.Async(work, done)` runs a context-aware worker and dispatches completion; it cancels when the component is disposed.
- `ui.OnCleanup` releases component resources.
- Native dialogs and services use completion callbacks; none wait synchronously for the main thread.

Event handlers batch writes automatically. Use `ui.Batch` outside events. `ui.Untrack` reads without subscribing.

## Optional extensions

Import a package to opt in; apps that do not import it do not ship it.

| Capability | Import |
| --- | --- |
| Editor, CodeBlock, DiffView | `github.com/egoist/quickgui/extensions/editor` |
| Markdown | `github.com/egoist/quickgui/extensions/markdown` |
| Terminal | `github.com/egoist/quickgui/extensions/terminal` → `terminal.View(terminal.Props{…})` |
| Updater | `github.com/egoist/quickgui/extensions/updater` |

See [extensions](extensions.md) and [updater](updater.md).

## Pitfalls

- Containers start empty: `ui.View()`, `ui.Button()` — never pass children as constructor args.
- Always return the node you build.
- Signals only on the UI goroutine.
- Do not rebuild UI inside an effect; update text and properties directly.
- Direct `go build` bypasses the view compiler and needs explicit accessors. Prefer `quickgui check` / `quickgui test`.
- There is no Drawer in the Go SDK.

Upstream: [Go guide](https://github.com/egoist/quickgui/blob/v0.1.6/docs/go.md), [Go getting started](https://github.com/egoist/quickgui/blob/v0.1.6/website/src/content/docs/go/en/getting-started.mdx).
