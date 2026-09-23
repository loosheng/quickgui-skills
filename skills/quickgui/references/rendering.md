# Rendering

How views mount, conditional content, lists, images, SVG, shaders, virtualization, and performance rules for apps. Website “rendering” guides cover the view model; graphics live in the Image/SVG/Shader components.

## View model

A component builds UI when it mounts. Each window has its own root. Closing the window disposes that UI and its effects.

**Go** — every component returns `*ui.Element`. `.Child` / `.Children` append. `ui.Fragment(...)` groups siblings. A plain `if` or `for` runs only during construction.

**TypeScript** — a component function runs once. Solid updates properties and child slots that read changing values. JSX produces retained native nodes, not HTML.

**Rust** — `View::render` returns `impl IntoElement` after `invalidate` or a platform event. The window sleeps until then.

## Conditional content

**Go** — `ui.Show` mounts or removes children from state. Content is created lazily and disposed when hidden. `ui.Dynamic(func() ui.Component { ... })` selects a component reactively; return `nil` to render nothing.

```go
ui.Show(open, func() *ui.Element { return ui.Text("Details") })
```

**TypeScript**

```tsx
<Show when={expanded()} fallback={<Text>Collapsed</Text>}>
  <Text>Expanded content</Text>
</Show>
```

**Rust** — omit a branch to drop those nodes:

```rust
if self.expanded { text("Expanded content") } else { text("Collapsed") }
```

Removing a branch disposes its effects. Sibling content is left alone. `Show` does not wait for a fade-out.

## Lists

Give each row a stable unique key (a database ID, not its index). For long lists use `VirtualList`, `Table`, or `Tree`.

**Go** — `ui.For` reuses unchanged rows by key. `ui.KeyedFor` also gives the row an item accessor so changing that row’s data preserves local state. Pass a new slice when you edit; in-place mutation does not notify.

```go
type ListPerson struct {
	ID   int
	Name string
}

func KeyedListExample() *ui.Element {
	people, setPeople := ui.CreateSignal([]ListPerson{{1, "Ada"}, {2, "Grace"}})
	return ui.KeyedFor(
		people,
		func(person ListPerson) any { return person.ID },
		func(person func() ListPerson, index func() int) *ui.Element {
			return ui.Text(index(), ": ", person().Name)
		},
		func() *ui.Element { return ui.Text("No people") },
	)
}
```

`For(each, children, key, fallback)` takes `each func() []T`. Removed rows release effects and listeners.

**TypeScript**

```tsx
<For each={items()}>{item => <Text>{item.name}</Text>}</For>
```

**Rust** — map children and set `.id(...)`:

```rust
div().children(self.items.iter().map(|item| {
    text(item.name.as_str()).id(item.id)
}))
```

## VirtualList

Lays out only the visible slice plus overscan.

```go
ui.VirtualList().Child(func() *native.Node {
	var children []*native.Node
	for _, row := range rows {
		children = append(children, ui.Text(row).Height(36).Node)
	}
	return ui.Fragment(children)
}).Height(320).EstimatedItemHeight(36).Overscan(6).
	OverscanPixels(240).ItemHeights(rowHeights).FollowMode("normal")
```

Go: `OverscanPixels`, `ItemHeights`. TypeScript: `overscanPixels`, `itemHeights`. Rust: `with_overscan_pixels`, `set_item_heights`.

## Current window

**Go** — capture `native.CurrentWindow()` while mounting.

```go
window := native.CurrentWindow()
return ui.Button().Child("Close window").OnClick(func() { window.Close() })
```

**TypeScript**

```tsx
const window = Window.getCurrentWindow();
return <Button onClick={() => window.close()}>Close</Button>;
```

**Rust**

```rust
let close = cx.listener("close", |_this, cx: &mut EventContext| {
    let _ = cx.close_window();
});
button().on_click(close).child("Close")
```

## Images

Filesystem path, file URL, or base64 data URL. Relative paths are **not** resolved against the resource directory; join `ResourceDir` yourself ([resources](resources.md)).

```go
ui.Image().Value(path).ObjectFit("cover").Width(160).Height(120)
```

```tsx
<Image source="assets/hero.png" fit="cover" style={{ width: 240, height: 160, borderRadius: 12 }} />
```

```rust
img(Image::from_rgba(128, 128, pixels).expect("image"))
    .size(160.0, 160.0)
    .rounded(12.0)
```

Rust `img` takes `impl Into<ImageSource>` (including `Image::open` paths). Formats: PNG, JPEG, TIFF, WebP, GIF. A stem ending in `Template` (optionally `@2x`) is a macOS template image. Go/TS `ImageSource` also accept an explicit `template` flag.

GIF/WebP animate from the file; see [animations](animations.md).

## SVG

Complete inline document. External SVG resources are not loaded. App fonts are not injected into SVG `<text>`.

```go
ui.SVG().Width(20).Height(20).TextColor("#2563eb").
	Value(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="currentColor" d="M11 4h2v7h7v2h-7v7h-2v-7H4v-2h7z"/></svg>`)
```

TypeScript: `<Svg source={markup} />`. Rust: `svg(Svg::from_bytes(...))`.

## Shaders

Validated WGSL on a rectangle. Up to 16 numeric parameters.

```go
ui.Shader().Value(source).ShaderParameters(parameters).Width(320).Height(180)
```

TypeScript: `<Shader source={wgsl} shaderParameters={[...]} />`. Rust: `custom_shader(CustomShader::new(...))`.

## Performance

- Clean windows sleep. Do not poll or timer-redraw when nothing changed.
- Batch signal writes (Go events already batch; `ui.Batch` elsewhere).
- Prefer retained bindings over remounting (`Show`/`For` only when structure changes).
- Virtualize long collections. Supply `ItemHeights` when you already know row heights.
- Hover group styles run natively without rerunning components.
- `ui.Async` / worker I/O for slow work; keep the UI goroutine/worker free.
- Opacity 0 still layouts and hits; unmount if you need it gone.

## Pitfalls

- Go: construction-time `if`/`for` will not update later.
- Relative image paths ≠ resource dir.
- SVG is inline only.
- Shader parameters are bounded (16 floats).
