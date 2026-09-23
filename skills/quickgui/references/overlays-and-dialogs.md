# Overlays and dialogs

In-window popovers, menus, tooltips, dialogs, toasts, context menus, and native file/alert dialogs. In-window overlays cannot paint outside the window; `SystemPopover` opens a native child window that can.

## Popover (in-window)

Side is a preference; placement flips on overflow.

**Go**

```go
popover := ui.NewPopover().Side("bottom").SideOffset(8)
return popover.Root().Children(
	popover.Trigger().Child("Account"),
	popover.Positioner().Child(
		popover.Popup().Width(240).Padding(16).Children(
			popover.Title().Child("Account"),
			popover.Description().Child("Manage your account settings."),
			popover.Close().Child("Done"),
		),
	),
)
```

**TypeScript**

```tsx
<Popover.Root open={open()} onOpenChange={setOpen}>
  <Popover.Trigger><Text>Account</Text></Popover.Trigger>
  <Popover.Portal>
    <Popover.Positioner side="bottom" sideOffset={8}>
      <Popover.Popup style={{ width: 240, padding: 16 }}>
        <Popover.Title><Text>Account</Text></Popover.Title>
        <Popover.Close><Text>Done</Text></Popover.Close>
      </Popover.Popup>
    </Popover.Positioner>
  </Popover.Portal>
</Popover.Root>
```

**Rust** — store `open` on the view. Mount the positioner only while open.

```rust
let popover = Popover::new("help-trigger", "help-popup", open)
    .side(AnchorSide::Bottom)
    .side_offset(8.0);
let mut root = popover.root().child(
    popover.trigger().on_click(toggle).child("Account"),
);
if popover.is_open() {
    root = root.child(popover.positioner().child(
        popover.popup().w(240.0).p(16.0).on_dismiss(dismiss).children([
            popover.title().child("Account"),
            popover.close("Close").on_click(dismiss).child("Done"),
        ]),
    ));
}
root
```

Transparent Go compound roots such as `Popover.Root` and `Toast.Provider` do not insert a layout box around children.

## SystemPopover

```go
popover := ui.NewSystemPopover()
return popover.Root().Children(
	popover.Trigger().Child("Account"),
	popover.Content(ui.PopoverContentProps{
		Width: 240, Height: 120, Placement: "bottom-start",
	}).Child("Account settings"),
)
```

Give content a width and height. Select and some menus use this host on macOS.

## Dialog and AlertDialog

Build modal content under `Portal`. `Title` and `Description` name the dialog. `AlertDialog` is for confirmations: Escape is on, backdrop dismiss is off. Ordinary dialogs dismiss on escape and backdrop.

**Go**

```go
dialog := ui.NewDialog()
return dialog.Root().Children(
	dialog.Trigger().Child("Open dialog"),
	dialog.Portal().Children(
		dialog.Backdrop(),
		dialog.Popup().Padding(20).Width(360).Children(
			dialog.Title().Child("Confirm action"),
			dialog.Description().Child("Review the details before continuing."),
			dialog.Close().Child("Cancel"),
		),
	),
)
```

**TypeScript** — put `Dialog.Viewport` between Backdrop and Popup.

```tsx
<Dialog.Root open={open()} onOpenChange={setOpen}>
  <Dialog.Trigger><Text>Edit profile</Text></Dialog.Trigger>
  <Dialog.Portal>
    <Dialog.Backdrop />
    <Dialog.Viewport>
      <Dialog.Popup>
        <Dialog.Title><Text>Edit profile</Text></Dialog.Title>
        <Dialog.Description><Text>Changes are saved immediately.</Text></Dialog.Description>
        <Dialog.Close><Text>Done</Text></Dialog.Close>
      </Dialog.Popup>
    </Dialog.Viewport>
  </Dialog.Portal>
</Dialog.Root>
```

**Rust** — `Dialog::new` / `Dialog::alert`. Mount with `is_mounted()` during exit so the close animation can finish. `EnterDuration` / `ExitDuration` keep closing content mounted.

Go Dialog does not expose Rust’s explicit `initial_focus` / `restore_focus_to`.

## Tooltip and PreviewCard

**Go:** `ui.NewTooltipProvider` + `ui.NewTooltip` → Provider, Root, Trigger, Portal, Positioner, Popup, Arrow. `Delay`, `CloseDelay`, `Side`, `Hoverable`.

**TypeScript:** `Tooltip.Provider` + `Tooltip.Root` …

**Rust:** short form `.tooltip("...")`, or `TooltipProvider` + `TooltipState`. Default delay is about 500 ms.

PreviewCard is a richer hover/focus preview over in-window Popover (600 ms open, 300 ms leave).

## Toast

**Go:** `ui.NewToast(ToastProviderProps{Timeout, Limit})` plus `ui.UseToastManager().Add(ToastRequest{...})`.

**TypeScript:** `useToastManager()` with `Toast.Provider` / Viewport / Root / Title / Description / Action / Close.

**Rust:** `ToastManager` / `ToastViewport`; the app drives `next_deadline()` and `expire`. Cap `MAX_TOASTS` = 8.

Hovering a toast pauses its countdown.

## Menu, ContextMenu, Menubar

Menu anatomy: Root, Trigger, Portal, Backdrop, Positioner, Popup, Arrow, Item, LinkItem, SubmenuRoot, SubmenuTrigger, Group, GroupLabel, RadioGroup, RadioItem, CheckboxItem, Separator.

**Go ContextMenu**

```go
menu := ui.NewContextMenu(ui.ContextMenuRootProps{Items: items, OnSelect: onSelect})
return menu.Root().Child(menu.Trigger().Child(content))
```

**Rust:** `ContextMenuState.element(...)` plus `PopoverMenu` rows; opens at secondary-click.

`PopoverMenu` is a compact model-driven menu in a native popover (`Items`, `OnSelect`). `Menubar` is a horizontal in-window bar.

## Drawer (TypeScript and Rust only)

Not in the Go SDK.

```tsx
<Drawer.Root open={open()} snapPoints={[0.4, 0.9]} onOpenChange={setOpen}>
  <Drawer.Trigger><Text>Open drawer</Text></Drawer.Trigger>
  <Drawer.Portal>
    <Drawer.Backdrop />
    <Drawer.Viewport>
      <Drawer.Popup>
        <Drawer.SwipeArea />
        <Drawer.Content><Settings /></Drawer.Content>
      </Drawer.Popup>
    </Drawer.Viewport>
  </Drawer.Portal>
</Drawer.Root>
```

Rust: `DrawerState` / `Drawer::from_state`; `DrawerModality::{Modal, TrapFocus, NonModal}`; max 8 snap points and 8 nested drawers.

## Native dialogs

Capture the parent window while rendering (Go) or use promises (TS) / `cx` (Rust).

```go
window := native.CurrentWindow()
native.ShowOpenDialog(native.OpenDialogOptions{
	Window: window, Title: "Open folder", Properties: []string{"openDirectory"},
}, func(result native.OpenDialogResult, err error) {
	if err == nil && !result.Canceled {
		fmt.Println(result.FilePaths)
	}
})
```

Also `ShowSaveDialog`, `ShowAlertDialog`.

```tsx
import { Dialog } from "@quickgui/native";
const choice = await Dialog.showAlertDialog({
  message: "Save changes?",
  buttons: [{ label: "Save" }, { label: "Cancel", role: "cancel" }],
});
const result = await Dialog.showOpenDialog({ properties: ["openFile", "multiSelections"] });
```

```rust
cx.prompt("Save changes?", ["Save", "Cancel"]);
cx.prompt_for_paths(PathPromptOptions::new().files(true).multiple(true));
cx.message_box(MessageBoxOptions::new("Replace this file?"));
```

## Pitfalls

- In-window Popover vs SystemPopover: no silent fallback; overflow needs SystemPopover.
- Rust: do not leave closed overlay content in the tree.
- Exit animations: keep mounted until `ExitDuration` / `is_mounted`, not by setting `open=false` and unmounting immediately.
- `Show` / omitting a branch removes children immediately (no fade).
