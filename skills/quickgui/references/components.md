# Components

Catalog of QuickGUI UI components with Go, TypeScript, and Rust names, compound parts, and key props. Parts are unstyled: the app owns paint; the core owns semantics, keyboard, focus, and placement.

Full per-component pages: `https://github.com/egoist/quickgui/blob/v0.1.6/website/src/content/docs/{go,typescript,rust}/components/ui/<slug>.mdx`.

## Naming

| | Go | TypeScript | Rust |
| --- | --- | --- | --- |
| Primitive | `ui.View()`, `ui.Text(...)`, `ui.Button()` | `<View>`, `<Text>`, `<Button>` | `div()`, `text(...)`, `button()` |
| Compound | `ui.NewX(...)` then `x.Root()` / `x.Trigger()` | `<X.Root>` / `<X.Trigger>` | `X::new` then `.root()` / `.trigger()` (`*_with` for a child element) |
| Text input | `ui.Input()` / `ui.TextArea()` | `<Input>` / `<TextInput>` / `<TextArea>` | `text_input` / `text_area` |
| Image / SVG / shader | `ui.Image()` / `ui.SVG()` / `ui.Shader()` | `<Image>` / `<Svg>` / `<Shader>` | `img` / `svg` / `custom_shader` |

Go constructors take no children. Append with `.Child` / `.Children`. TypeScript nests JSX. Rust chains `.child` / `.children`.

Create each Go compound instance inside the component that owns it. Keep TypeScript/Rust parts under their root.

## Primitives

| Component | Go | TypeScript | Rust | Key props |
| --- | --- | --- | --- | --- |
| View | `ui.View()` | `<View>` (`<div>`) | `div()` | layout, paint, `OnClick` / `onClick` / `on_click` |
| Text | `ui.Text(...)` | `<Text>` (`<span>`) | `text(...)` | children |
| Button | `ui.Button()` | `<Button>` | `button()` | `Disabled`, click handler |
| Input | `ui.Input()` | `<Input>` / `<TextInput>` | `text_input(...)` | `Value`, `Placeholder`, `OnInput` |
| TextArea | `ui.TextArea()` | `<TextArea>` | `text_area(...)` | same as Input; multiline |
| Image | `ui.Image().Value(path)` | `<Image source fit />` | `img(...)` | `ObjectFit` / `fit`; path, file URL, or data URL |
| SVG | `ui.SVG().Value(markup)` | `<Svg source />` | `svg(...)` | complete inline document; no external loads |
| Shader | `ui.Shader().Value(wgsl)` | `<Shader source shaderParameters />` | `custom_shader(...)` | up to 16 numeric parameters |
| VirtualList | `ui.VirtualList()` | `<VirtualList>` | `VirtualList` | `EstimatedItemHeight`, `Overscan`, `OverscanPixels`, `ItemHeights`, `FollowMode` |

Optional (see [extensions](extensions.md)):

| Component | Go | TypeScript | Rust feature |
| --- | --- | --- | --- |
| Editor / CodeBlock / DiffView | `extensions/editor` | `@quickgui/extension-editor` | `editor` |
| Markdown | `extensions/markdown` | `@quickgui/extension-markdown` | `markdown` |
| Terminal | `terminal.View(Props{…})` | `<Terminal>` | `terminal` |

Editor key props: `Value`, `Language`, `LineNumbers`, `TabSize`, `ReadOnly`, `OnChange`. Language grammars are not in the default bundle; register a grammar or load a language pack (`quickgui pack-languages`).

## Forms and controls

| Component | Parts | Key props |
| --- | --- | --- |
| Checkbox | Root, Indicator | `Checked`, `DefaultChecked`, `OnCheckedChange`, `ReadOnly`, `Disabled` |
| CheckboxGroup | Root | `AllValues`, `Value`, `OnValueChange`, `Disabled` |
| Radio | Root, Indicator | `Value`, `Checked`, `OnCheckedChange` |
| RadioGroup | Root | `Value`, `OnValueChange`, `ReadOnly`, `Required` |
| Switch | Root, Thumb | `Checked`, `OnCheckedChange` |
| Toggle | Root, Indicator | `Pressed`, `OnPressedChange` |
| ToggleGroup | Root, Item | `Items`, `Value`, `Multiple`, `OnValueChange` |
| Slider | Root, Label, Value, Control, Track, Range, Indicator, Thumb | `Value`, `Min`, `Max`, `Step`, `OnValueChange` |
| NumberField | Root, Group, Input, Increment, Decrement, ScrubArea, ScrubAreaCursor | `Value`, `Min`, `Max`, `Step`, `OnValueChange` |
| Select | Root, Trigger, Value, Icon, Item, List, Popup, … | `Items`, `Value`, `Multiple`, `OnValueChange` |
| Combobox | Root, Input, Chips, List, Empty, Status, … | `Items`, `Value`, `InputValue`, `FilterMode` |
| Autocomplete | Root, Input, List, Empty, Status, … | `Items`, `InputValue`, `OnInputValueChange`, `OnCommit` |
| Field | Root, Item, Label, Control, Validity, Description, Error | `Invalid`, `Required`, `ValidationMessage`, `ValidationMode` |
| Fieldset | Root, Legend, Description, Control | `Disabled` |
| DateField | Root, Segment | `Value`, `Min`, `Max`, `OnValueChange` |
| TimeField | Root, Segment | `Value`, `Hour12`, `ShowSeconds` |
| Calendar | Root, Week, Day | `Value`, `Min`, `Max`, `FirstWeekday` |
| OtpField | Root, Input, Separator | `Value`, `Length` (max 12), `OnValueChange` |

Select/Combobox option lists open in a `SystemPopover` (can leave the owner window).

## Layout and data

| Component | Parts | Key props |
| --- | --- | --- |
| Tabs | Root, List, Tab, Indicator, Panel | `Value`, `Orientation`, `Activation` |
| Accordion | Root, Item, Header, Trigger, Panel | `Value`, `Multiple`, `KeepMounted` |
| Collapsible | Root, Trigger, Panel | `Open`, `KeepMounted` |
| Splitter | Root, Pane, Handle | `Value`, `Panes`, `Orientation`, `OnSizesChange` |
| ScrollArea | Root, Viewport, Content, Scrollbar, Thumb, Corner | `ViewportSize`, `ContentSize`, `OnScrollStateChange` |
| Table | Root, Header, Row, Cell | `Columns`, `RowCount`, `RowHeight`, `SelectionMode` |
| Tree | Root, Row | `Nodes`, `Expanded`, `Value` |
| Separator | Root | `Orientation` |
| Avatar | Root, Image, Fallback | `Src`, `Delay`, `OnLoadingStatusChange` |
| Progress | Root, Track, Indicator, Label, Value | `Value`, `Max`, `Indeterminate` |
| Meter | Root, Track, Indicator, Label, Value | `Value`, `Min`, `Max`, `Low`, `High`, `Optimum` |
| Toolbar | Root, Item, Button, Link, Input, Group, Separator | `Items`, `Active`, `Orientation` |

Rust `TableState::element_with_rows` hands a `TableRowState` per mounted row so the row can set background, hover, and `selected_style`. A header height of zero mounts no header row.

Inactive tab panels unmount by default; keep them with `keep_mounted` / `KeepMounted`.

## Overlays

| Component | Parts | Key props | Availability |
| --- | --- | --- | --- |
| Popover | Root, Trigger, Portal, Positioner, Popup, Arrow, Title, Description, Close | `Open`, `Side`, `Align`, `Modal` | all |
| SystemPopover | Root, Trigger, Content | `Open`, `Width`, `Height`, `Placement` | all |
| Dialog | Root, Trigger, Portal, Backdrop, Viewport, Popup, Title, Description, Close | `Open`, `DismissOnEscape`, `ExitDuration` | all |
| AlertDialog | same as Dialog | stricter backdrop defaults | all |
| Tooltip | Provider, Root, Trigger, Portal, Positioner, Popup, Arrow | `Delay`, `CloseDelay`, `Side`, `Hoverable` | all |
| PreviewCard | Root, Trigger, Portal, Positioner, Popup, Arrow | `Delay`, `CloseDelay`, `Placement` | all |
| Toast | Provider, Portal, Viewport, Positioner, Root, Content, Title, Description, Action, Close | `Timeout`, `Limit` | all |
| Drawer | Root, Trigger, Portal, Backdrop, Viewport, Popup, Content, Title, Close, SwipeArea | `open`, `snapPoints` | **TypeScript and Rust only** |

In-window Popover cannot paint outside the window; use SystemPopover to cross the edge.

## Menus and navigation

| Component | Parts | Key props |
| --- | --- | --- |
| Menu | Root, Trigger, Item, LinkItem, SubmenuRoot, SubmenuTrigger, Group, RadioItem, CheckboxItem, Separator, … | `Open`, `Orientation`, `LoopFocus` |
| PopoverMenu | Root, Trigger, Popup | `Items`, `Appearance`, `OnSelect` |
| ContextMenu | Root, Trigger | `Items`, `OnSelect` |
| Menubar | Root, Item | `Count`, `Open`, `OnActiveChange` |
| NavigationMenu | Root, List, Item, Trigger, Content, Link, Popup, Viewport, … | `Value`, `Orientation`, `Delay` |
| Router | Router, Route, Layout, Link, Outlet | `InitialPath`, `Fallback`, `Href` |

See [routing](routing.md) and [overlays-and-dialogs](overlays-and-dialogs.md). SwiftUI controls are in [swift-ui](swift-ui.md) (macOS only).

## Go checkbox example

```go
func CheckboxExample() *ui.Element {
	checked, setChecked := ui.CreateSignal(false)
	checkbox := ui.NewCheckbox().Checked(checked()).OnCheckedChange(
		func(next bool, _ *native.Event) { setChecked(next) },
	)
	return checkbox.Root().FlexRow().Gap(8).Children(
		checkbox.Indicator().Child("✓"),
		"Remember me",
	)
}
```

Adding `OnClick` on a part keeps the default action. Call `PreventDefault()` on `OnClickEvent` to cancel it.

## Pitfalls

- Parts ship unstyled; you must set colors, padding, and layout.
- Disabled and read-only are separate.
- Select/Combobox lists use SystemPopover, not in-window Popover.
- Drawer is not in the Go SDK.
- VirtualList: pass `OverscanPixels` / `ItemHeights` (Go), `overscanPixels` / `itemHeights` (TS), `with_overscan_pixels` / `set_item_heights` (Rust) for known-height tables.
