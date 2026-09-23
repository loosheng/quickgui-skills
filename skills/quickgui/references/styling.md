# Styling

Style builders, flex/grid layout, typography, paint, interaction states, and (Rust) container queries. Lengths are logical pixels. Compound parts are unstyled until you paint them.

## Go

Chain methods on the element or on `ui.Style()`. Apply a shared builder with `.Style(shared)`. Later values override the same property.

```go
return ui.View().Children(ui.Text("hello"), ui.Input().Value("xxx")).
	FlexCol().PaddingLeft(20).RoundedLg().TextAlign("center")
```

Reusable builders are immutable; methods return a new value. `.Merge(...)` combines builders.

```go
card := ui.Style().Padding(20).BorderRadius(12)
emphasized := card.PaddingLeft(28).Bg("#1e293b")
return ui.View().Child("Hello").Style(card).Bg("#111827")
```

`.When(condition, style)` applies extra styles while true. Pass a getter to stay live: `.When(selected, ui.Style().Bg("#2563eb"))`. Passing `width()` during setup snapshots the number; pass `width` (the getter) to keep it live.

Helpers such as `.FlexCol()`, `.P4()`, `.GridCols(3)`, and `.RoundedLg()` match TypeScript presets. `.Flex()` sets flex display; `.Flex1()` sets grow 1, shrink 1, zero basis.

## TypeScript

Every visual declaration goes in `style` with camelCase keys. No `class` / `className`.

```tsx
<View style={{ padding: 16, gap: 12, bg: "#18181b", color: "#fafafa" }} />
<View style={{ flexCol: true, p3: true, gap2: true, roundedLg: true }}>
  <Text style={{ textLg: true, fontSemibold: true }}>Panel title</Text>
</View>
```

`roundedLg` is 8px; `p3` is 12px. Custom values: `borderRadius`, `padding`, `gridTemplateColumns`, `width`. A falsey preset turns that preset off.

Arrays merge left to right. Falsy entries are ignored. Removing a field from a reactive object clears the property.

```tsx
<View style={[base, selected() && selectedStyle, { padding: 20 }]} />
```

```tsx
import type { JSX } from "@quickgui/solid";
const panel = { p3: true, roundedXl: true, bg: "#20242c" } satisfies JSX.Style;
```

## Rust

```rust
div()
    .p(16.0)
    .gap(12.0)
    .bg(Color::rgb8(24, 24, 27))
    .text_color(Color::rgb8(250, 250, 250))
```

Presets: `flex_col`, `p_3`, `rounded_lg`, `text_lg`. Custom: `rounded(10.0)`, `p(14.0)`, `w` / `h`. Later calls override the same property. `when` applies a branch only if true.

```rust
div().p(12.0).when(self.selected, |style| style.bg(Color::rgb8(37, 99, 235)))
```

Reusable styles are functions that take and return `Element`.

## Flexbox

Start with flex display, then gap and alignment. Give scrolling children a zero min size so they can shrink.

**Go:** `.Flex()`, `.FlexRow()`, or `.FlexCol()`; `.MinHeight(0)` / `.MinWidth(0)`; `.Flex1()` / `.FlexShrink(0)`.

```go
ui.View().Children(
	ui.Text("Flexible content").Flex1().MinWidth(0),
	ui.Button().Child("Action").FlexShrink(0),
).Flex().Gap(12).ItemsCenter()
```

**TypeScript:** `display`, `flexDirection`, `flexGrow`, `flexShrink`, `flexBasis`, alignment, gap; `minWidth: 0` / `minHeight: 0`.

**Rust:** `flex`, `flex_col`, `flex_grow`, `gap`; `min_w(0.0)` / `min_h(0.0)`.

## Grid

**Go**

```go
ui.View().Children(ui.Text("Sidebar"), ui.Text("Content")).
	Display("grid").GridTemplateColumns("220px 1fr").Gap(16)
```

`.GridCols(3)` and `.ColSpanFull()` are also available.

**TypeScript:** `display: "grid"` plus track, placement, and span fields.

**Rust:** `grid` plus track, placement, and span methods (`grid_cols`, spans, auto-flow).

## Typography and color

Typography inherits to children. Padding and borders do not. Colors accept hex, `rgb()` / `rgba()`, or packed RGBA. Rust uses `Color::rgb8`, `Color::rgba8`, and packed values. TypeScript also accepts `0xAABBGGRR`.

```go
ui.View().Children(
	ui.Text("Inbox").FontSize(24).FontWeight(600),
	ui.Text("All caught up."),
).TextColor("#334155").FontSize(14).Padding(20)
```

Use the font family name of a bundled font in styles. See [resources](resources.md).

## Interaction states

| State | Go | TypeScript | Rust |
| --- | --- | --- | --- |
| Hover | `.Hover(...)` | `hover: { ... }` | `.hover(\|s\| ...)` |
| Pressed | `.Active(...)` | `active` | `.active` |
| Focus | `.FocusStyle(...)` | `focusVisible` | focus style methods |
| Disabled | `.DisabledStyle(...)` | `disabled` | disabled style |
| Selected | `.SelectedStyle(...)` | selected style | `selected_style` (paint-only; follows `selected`) |

Selected sits above pointer states and beneath disabled, so a selected list row keeps its selection color while hovered.

```go
ui.Button().Child("Save").
	Bg("#2563eb").
	Hover(func(s ui.StyleBuilder) ui.StyleBuilder { return s.BackgroundColor("#3b82f6") })
```

```tsx
<Button style={{
  bg: "#2563eb",
  hover: { bg: "#1d4ed8" },
  active: { opacity: 0.8 },
  focusVisible: { outlineColor: "#93c5fd", outlineWidth: 2 },
}}>Save</Button>
```

```rust
button()
    .bg(Color::rgb8(37, 99, 235))
    .hover(|style| style.bg(Color::rgb8(29, 78, 216)))
    .child("Save")
```

Add a transition on the base style to animate paint. See [animations](animations.md).

## Groups and named group hover

Mark an ancestor as a group; descendants react to that hover/press without rerunning components.

**Go:** `.Group(true)` or `.Group("card")`. `.GroupHover(...)` follows the nearest ancestor group. `.GroupHoverNamed("card", ...)` follows that name. Also `.GroupActive` / `.GroupActiveNamed` and `.FocusWithin`. These accept paint properties and cannot set the cursor. The node’s own `.Hover(...)` wins for overlapping properties.

```go
ui.View().Child(
	ui.Text("Changes when the card is hovered").
		TextColor("#64748b").
		GroupHoverNamed("card", func(s ui.StyleBuilder) ui.StyleBuilder {
			return s.TextColor("#2563eb")
		}),
).Group("card").Padding(20)
```

**TypeScript:** name `group` on an ancestor; use `groupHover` / `groupActive` on descendants.

**Rust:** `group` on an ancestor; `group_hover` on descendants.

## Container queries (Rust only)

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

The query fills its parent (refine with `.w`, `.flex_1`, `.max_w`). Contents cannot change the query’s size. Do not call `.child` on the query itself. Caps: 1,024 queries per window, 16 nested levels.

## Layout rounding

`Element::layout_rounding(false)` on a window root keeps fractional layout coordinates through painting and hit testing (Rust). Intrinsic text width is rounded once in logical pixels.

## Pitfalls

- TypeScript: styles only through `style`; camelCase keys.
- Go style builders are immutable; assign the result of `.Merge` / modifiers.
- Group hover is paint-only; it does not change layout.
- Flex children that scroll need `minWidth`/`minHeight` 0.
- Width/height/padding do not interpolate; see [animations](animations.md).
