# SwiftUI

Embed real macOS SwiftUI controls in a QuickGUI tree, or reverse-host QuickGUI inside SwiftUI. **macOS only.** Ordinary QuickGUI components work without this. Appearance (including Liquid Glass) follows the OS version.

## Enable

| Language | How |
| --- | --- |
| Go | `ui.SwiftUI.*` (no extra feature) |
| TypeScript | `import { Host, Button, Toggle, … } from "@quickgui/solid/swift-ui"`; modifiers in `@quickgui/solid/swift-ui/modifiers` |
| Rust | `features = ["swift-ui"]` — `MacSwiftUiHost`, `SwiftUiButton`, … |

## Host

The host is the `NSHostingView` boundary. It can size itself from its content.

**Go**

```go
ui.SwiftUI.Host(
	ui.SwiftUIHostProps{MatchContents: true},
	func() *ui.Element {
		return ui.SwiftUI.Button(ui.SwiftUIButtonProps{Label: "Continue"})
	},
)
```

Per-axis intrinsic size:

```go
ui.SwiftUIHostProps{
	MatchContents: ui.SwiftUIMatchContents{Vertical: true},
	PartProps:     ui.PartProps{Style: ui.Style().Width(320)},
}
```

**TypeScript**

```tsx
import { Host, Button } from "@quickgui/solid/swift-ui";

<Host matchContents>
  <Button label="Continue" />
</Host>
```

**Rust** — `MacSwiftUiHost::new` / `new_with_control_events`, `sync`, then `native_view(host.view())`. `native_view_with_outset` / `MacNativeView::with_outset` grow the AppKit frame past the element’s layout box without moving siblings. Points in that ring that hit no hosted content fall through.

The host measures at native control size. Extra outset is a few points for ordinary controls (bezel and focus ring) and 24 points only when the content contains a glass control. Under a transparent titlebar, controls are not pushed below the window safe area.

A hosted AppKit view that takes keyboard focus blurs the framework’s focused element.

## Controls

Button, Slider, Toggle, ProgressView, Stepper, TextField, SecureField, Picker, SegmentedControl, DatePicker, ColorPicker, Gauge, plus labels and popovers.

Bind a signal (Go/TS) or view field (Rust) and store the value from the native callback. A SwiftUI control and a QuickGUI view can share the same signal.

```go
on, setOn := ui.CreateSignal(true)
ui.SwiftUI.Host(ui.SwiftUIHostProps{MatchContents: true}, func() *ui.Element {
	return ui.SwiftUI.Toggle(ui.SwiftUIToggleProps{
		IsOn:         on,
		Label:        "Notifications",
		OnIsOnChange: func(next bool, _ *native.Event) { setOn(next) },
	})
})
```

```tsx
<Host matchContents>
  <Toggle label="Notifications" isOn={enabled()} onIsOnChange={setEnabled} />
</Host>
```

DatePicker values are Unix timestamps in **milliseconds** (Go). ColorPicker returns CSS-style RGBA strings.

Key props (from the component catalog):

| Control | Notable props |
| --- | --- |
| Button | `Label`, `SystemImage`, `Role`, `OnPress`, `Modifiers` |
| Slider | `Value`, `Min`, `Max`, `Step`, `OnValueChange` |
| Toggle | `IsOn`, `Label`, `OnIsOnChange` |
| ProgressView | `Value`, `Total`, `Label` |
| Stepper | `Value`, `Min`, `Max`, `Step` |
| TextField / SecureField | `Value`, `Placeholder`, `OnValueChange`, `OnSubmit` |
| Picker | `Selection`, `Options`, `Style`, `OnSelectionChange` |
| SegmentedControl | `Selection`, `Options`, `Role` |
| DatePicker | `Value`, `Min`, `Max`, `DisplayedComponents` |
| ColorPicker | `Selection`, `SupportsOpacity` |
| Gauge | `Value`, `Min`, `Max`, `Style` |

## Modifiers

**Go** — pass factories through `Modifiers`: `ButtonStyle`, `ButtonBorderShape`, `ControlSize`, `LabelStyle`, `Tint`, `Disabled`.

```go
ui.SwiftUI.Button(ui.SwiftUIButtonProps{
	Label: "Create project",
	Modifiers: []ui.SwiftUIModifier{
		ui.SwiftUI.ButtonStyle("borderedProminent"),
		ui.SwiftUI.ControlSize("large"),
		ui.SwiftUI.Tint("#f97316"),
	},
})
```

`ui.SwiftUI.ButtonStyle("glass")` requests the system glass button when the OS supports it.

**TypeScript** — `buttonStyle("glass")`, `controlSize`, `tint`, and other factories from `@quickgui/solid/swift-ui/modifiers`.

**Rust** — `SwiftUiButtonStyle::Glass`, `SwiftUiControlSize::Large`, and related enums.

## Reverse hosting

`QuickGUIHostView` hosts a QuickGUI subtree inside SwiftUI.

```go
ui.SwiftUI.Host(ui.SwiftUIHostProps{MatchContents: true}, func() *ui.Element {
	return ui.SwiftUI.QuickGUIHostView(
		ui.SwiftUIQuickGUIHostViewProps{Width: 320, Height: 180},
		func() *ui.Element {
			return ui.View().Child("QuickGUI inside SwiftUI").
				Width("100%").Height("100%").Padding(16)
		},
	)
})
```

TypeScript: `QuickGUIHostView` with `width`, `height`, `matchContents`, `background`. Rust: `SwiftUiQuickGuiHost` + `set_embedded_view`.

## SwiftUI popover

Native trigger; content can host QuickGUI children. Go: `SwiftUI.Popover.Root` / `Trigger` / `Content`. TypeScript: `Popover.Trigger` / `Content`. Rust: `SwiftUiPopover`. Props include `IsPresented` / `OnIsPresentedChange`, `AttachmentAnchor`, `ArrowEdge`.

## Pitfalls

- macOS only; other platforms have no SwiftUI host.
- Always wrap controls in `Host` / `MacSwiftUiHost`.
- DatePicker is milliseconds, not seconds.
- Windowless visual tests cannot capture raw `NSView` pixels; assert the QuickGUI host element instead ([testing](testing.md)).
