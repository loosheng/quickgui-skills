# Animations

Paint transitions on existing nodes. The component or view does not rerun each frame. Keep the node mounted while it animates.

## Hover and state

Put the transition on the **base** style so it applies when the pointer enters and leaves.

**Go**

```go
ui.Button().Child("Continue").
	Padding(12).
	BorderRadius(8).
	BackgroundColor("#334155").
	TextColor("white").
	Opacity(0.85).
	Transition("background-color 160ms ease-out, opacity 160ms ease-out").
	Hover(func(s ui.StyleBuilder) ui.StyleBuilder { return s.BackgroundColor("#2563eb").Opacity(1) })
```

The same declaration works with `Active`, `Focus`, `Expanded`, and `DragOver`. Drive the target with a signal or `.When`; reversing mid-transition continues from the current visible value.

```go
ui.View().Child("Your selection").
	BackgroundColor("#334155").
	Opacity(0.6).
	Transition("background-color 180ms ease-out, opacity 180ms ease-out").
	When(selected, ui.Style().BackgroundColor("#2563eb"), ui.Style().Opacity(1))
```

**TypeScript**

```tsx
<Button style={{
  bg: "#2563eb",
  transition: { property: "bg", duration: 160 },
  hover: { bg: "#1d4ed8" },
}}>Hover</Button>
```

```tsx
<View style={{
  bg: selected() ? "#2563eb" : "#334155",
  opacity: selected() ? 1 : 0.6,
  transition: { property: ["bg", "opacity"], duration: 180 },
}} />
```

**Rust**

```rust
button()
    .bg(Color::rgb8(37, 99, 235))
    .transition(Transition::colors(Duration::from_millis(160)))
    .hover(|style| style.bg(Color::rgb8(29, 78, 216)))
    .child("Hover")
```

Change a style field from view state and `invalidate`. Keep the element mounted.

## Timing

| | Go | TypeScript | Rust |
| --- | --- | --- | --- |
| Shorthand | `.Transition(string \| TransitionDeclaration)` | `transition: { property, duration, easing?, maxFps? }` | `Transition::new` / `Transition::colors` |
| Duration | ms, `time.Duration`, `"180ms"` / `"0.18s"`; clamp **0–10s** | ms or `"180ms"` | `Duration` |
| Easing | `linear`, `ease`, `ease-in`, `ease-out`, `ease-in-out` | same idea | `with_easing`; default ease-in-out |
| Frame cap | `.TransitionMaxFps` | `maxFps` | `max_fps` (Rust stages also cap at 240) |

A node has one duration, easing, and frame-rate cap for all selected properties. Delays, `cubic-bezier()`, and per-property timings are not supported.

Go: `ui.Style().Transition(180 * time.Millisecond)` animates background, border, and text colors. `"all"` includes every supported paint property. `"none"` removes the shorthand.

```go
ui.TransitionDeclaration{
	Properties: []string{"background-color", "opacity"},
	Duration:   180 * time.Millisecond,
	Easing:     "ease-out",
	MaxFps:     30,
}
```

Rust also has staged animations (`with_animation` / `with_animations`, ≤64 stages), `with_spring(SpringConfig)`, and `repeat` / `repeat_synced`.

## Interpolated properties

| Transition name | Style |
| --- | --- |
| `background-color` / `background` | solid background |
| `border-color`, `border-width`, `border-radius` | border |
| `color` | text color |
| `opacity` | opacity |
| `transform` | transform |
| `box-shadow` | shadow |

Width, height, padding, and gradient stops do **not** interpolate. Slide with `transform: translateX(...)` and transition `transform`.

## Mounting and reduced motion

- `Show` / omitting a branch removes children immediately; no wait for fade.
- Opacity 0 still lays out and hits.
- Dialogs: `EnterDuration` / `ExitDuration` keep closing content mounted.
- Transitions follow the system Reduce Motion setting.
  - Go: `native.WindowOptions.ReduceMotion`
  - TypeScript: `reduceMotion` on the window
  - Rust: `WindowOptions::reduce_motion`

## Animated images

GIF and WebP playback follows the file. No timer.

```go
ui.Image().Value(path).Width(96).Height(96).ObjectFit("contain")
```

```tsx
<Image source={path} style={{ width: 96, height: 96, objectFit: "contain" }} />
```

Rust: `img(...)` with the same path. Package files via `resources/`; see [resources](resources.md).

## Pitfalls

- Do not rebuild the tree each frame.
- Keep the node mounted for the duration of the transition.
- Layout size changes are not animated; use transform.
