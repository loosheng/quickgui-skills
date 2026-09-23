# Reactivity

Signals (Go/TypeScript) and view state (Rust): derived values, effects, cleanup, batching, retained bindings, and async data. Components construct once; updates patch native properties.

## Go

A component function runs once when its window (or parent) mounts.

```go
func TextExample() *ui.Element {
	count, setCount := ui.CreateSignal(0)
	return ui.View().Children(
		ui.Text("Count: ", count()).FontSize(20),
		ui.Button().Child("Increment").OnClick(func() { setCount(count() + 1) }),
	)
}
```

- `ui.CreateSignal` — getter + setter.
- Read in text and properties: `ui.Text("Count: ", count())`, `.Width(width())`.
- `ui.Text("Count: ", count)` keeps the prefix and updates only the number.
- `initial := count()` is a snapshot.
- Custom components take ordinary values; `LineItem(product, quantity())` stays subscribed to `quantity`.
- Event handlers batch writes automatically.

Derived:

```go
doubled := ui.CreateMemo(func() int { return count() * 2 })
ui.Text("Doubled: ", doubled())
```

Effects run after mount and again when a value they read changes. `ui.OnCleanup` runs before the next execution and when the component goes away. Do not rebuild UI inside an effect.

```go
ui.CreateEffect(func() {
	current := topic()
	log.Print("Subscribe: ", current)
	ui.OnCleanup(func() { log.Print("Unsubscribe: ", current) })
})
```

Batching and isolation:

```go
ui.Batch(func() {
	setFirst("Grace")
	setLast("Hopper")
})
```

`ui.Untrack` reads without subscribing. Read and write signals only on the UI goroutine. Deliver background results with `ui.Async` or `native.Dispatch`.

```go
func LoadingPanel(load func(context.Context) (string, error)) *ui.Element {
	result, setResult := ui.CreateSignal("Loading…")
	ui.Async(load, func(value string, err error) {
		if err != nil {
			setResult(err.Error())
			return
		}
		setResult(value)
	})
	return ui.Text(result())
}
```

`ui.Async` cancels when the component is disposed. Window closure disposes the tree and outstanding background work.

Also: `ui.CreateRenderEffect`, `ui.Flush()` (tests).

## TypeScript

Solid 2 signals. A read during setup is a snapshot; call the signal in JSX to stay live.

```tsx
const [count, setCount] = createSignal(0);
<Text>Count: {count()}</Text>
<Button onClick={() => setCount(count() + 1)}>Increment</Button>
```

```tsx
const doubled = createMemo(() => count() * 2);
<Text>{doubled()}</Text>
```

Keep memo functions pure; write from events or effects.

```tsx
import { createEffect, onCleanup } from "solid-js";

createEffect(() => count(), value => console.log(value));
const stop = watchProject();
onCleanup(stop);
```

Solid batches ordinary writes. Use `flush()` in tests when queued updates must settle. Each window has an independent Solid root.

`useParams`, `useLocation`, and `useSearchParams` return store-like objects (`params.id`, `location.pathname`) — not accessors. See [routing](routing.md).

## Rust

Store fields on the `View`. `render` reads them. Mutate from listeners, then `cx.invalidate()`.

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
            .child(text(format!("Count: {}", self.count)))
            .child(button().on_click(increment).child("Increment"))
    }
}
```

Compute cheap derived values in `render`. Store an expensive derivation on the view when several children need it in one frame.

Start external work from listeners or `Application` callbacks. Stop it when the view is dropped:

```rust
impl Drop for WatcherView {
    fn drop(&mut self) {
        self.stop.take().map(|stop| stop());
    }
}
```

Multiple `invalidate` calls in one event become one render. Do not timer-redraw when nothing changed.

## Conditional content and lists

Structural updates belong in [rendering](rendering.md): Go `ui.Show` / `ui.For` / `ui.KeyedFor` / `ui.Dynamic`; TypeScript Solid `Show` / `For`; Rust `if` in `render` plus stable `.id(...)`.

## Pitfalls

- Go/TypeScript: do not read or write signals off the UI thread/worker.
- Go: `ui.Async` and `native.Dispatch` are the way back onto the UI goroutine.
- Go: mutating a stored slice in place does not notify; pass a new slice.
- TypeScript: router hooks are objects, not functions.
- Rust: forgetting `cx.invalidate()` leaves the window unchanged.
