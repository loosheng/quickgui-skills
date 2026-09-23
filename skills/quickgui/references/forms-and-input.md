# Forms and input

Native text editors, fields, selection controls, pickers, and pointer/keyboard/focus rules. Keep values in signals (Go/TS) or view fields (Rust) and write accepted changes back from callbacks. Parts are unstyled.

## Text

| | Go | TypeScript | Rust |
| --- | --- | --- | --- |
| Single line | `ui.Input()` | `<Input>` / `<TextInput>` | `text_input(...)` |
| Multiline | `ui.TextArea()` | `<TextArea>` | `text_area(...)` |

```go
ui.Input().
	Value(value()).
	Placeholder("Write here").
	OnInputEvent(func(event *native.Event) { setValue(event.Value) }).
	Width(320).Height(32)
```

```tsx
<Input value={value()} onInput={event => setValue(event.value ?? "")} placeholder="Name" />
<TextArea value={notes()} onInput={event => setNotes(event.value ?? "")} />
```

```rust
text_input(self.name.as_str()).placeholder("Name").on_input(edit)
text_area(self.notes.as_str()).on_input(edit_notes)
```

`OnSubmit` / `onSubmit` / `on_submit` handles Return in a single-line input. Return inserts a newline in a textarea.

`max_length` counts grapheme clusters. A rejected edit leaves value, selection, history, and `on_input` untouched. `invalid` plus `validation_message` are paint + accessibility; they suppress submit.

## Field and Fieldset

**Go** — `ui.NewField(FieldRootProps)` parts: `Root`, `Label`, `Control`, `Description`, `Error`, `Item`, `Validity`. `ValidationMode`: `"onSubmit"` | `"onBlur"` | `"onChange"`. Nested fields inherit fieldset `Disabled`. Label forwards clicks unless `Passive`.

```go
field := ui.NewField(ui.FieldRootProps{
	Required: true,
	Filled:   func() bool { return email() != "" },
})
return field.Root().FlexCol().Gap(6).Children(
	field.Label().Child("Email"),
	field.Control(ui.FieldControlProps{
		InputPartProps: ui.InputPartProps{
			Value:       email,
			Placeholder: "you@example.com",
			OnInput:     func(event *native.Event) { setEmail(event.Value) },
		},
	}),
	field.Description().Child("Used for receipts"),
	field.Error().Child("Enter a valid email address"),
)
```

**TypeScript**

```tsx
<Field.Root required invalid={name().length === 0} validationMessage="Enter a name">
  <Field.Label><Text>Name</Text></Field.Label>
  <Field.Control value={name()} onInput={event => setName(event.value ?? "")} />
  <Field.Description><Text>Shown on your profile.</Text></Field.Description>
  <Field.Error><Text>Enter a name.</Text></Field.Error>
</Field.Root>
```

**Rust** — `Fieldset::new`, `field(...)`, `root_with` / `label_with` / `control_with` / `description_with` / `error_with`. `form().on_form_submit` / `on_form_invalid`. `submit_button` submits the nearest form.

## Choices

Radio groups keep one value. Checkbox and toggle groups can keep several. Disabled ≠ read-only. Mixed checkbox state is `ToggleState::Mixed` / indeterminate.

```go
group := ui.NewCheckboxGroup(ui.CheckboxGroupProps{
	AllValues: []string{"email", "push"},
	Value:     values,
	OnValueChange: func(next []string, _ *native.Event) { setValues(next) },
})
email := ui.NewCheckbox(ui.CheckboxProps{Value: "email"})
return group.Root().FlexCol().Gap(8).Children(email.Root().Child("Email"))
```

```tsx
<Checkbox.Root checked={checked()} onCheckedChange={setChecked}>
  <Checkbox.Indicator><Text>✓</Text></Checkbox.Indicator>
  <Text>Remember this device</Text>
</Checkbox.Root>
```

```rust
let checkbox = Checkbox::new(self.checked);
checkbox.root().flex_row().gap(8.0).on_click(toggle)
    .child(checkbox.indicator_with(div().size(16.0, 16.0)))
    .child(text("Remember this device"))
```

Also: `Switch` (Root + Thumb), `Radio` / `RadioGroup`, `Toggle` / `ToggleGroup`.

## Select, Combobox, Autocomplete

| | Select | Combobox | Autocomplete |
| --- | --- | --- | --- |
| Model | choose from a list | typing + constrained pick | free-form + suggestions |
| Go | `ui.NewSelect(SelectRootProps)` | `ui.NewCombobox` | `ui.NewAutocomplete` |
| TS | `<Select.Root items value onValueChange>` | `Combobox` | `Autocomplete` |
| Rust | `SelectState<T>` | `ComboboxState<T>` | `AutocompleteState<T>` |

The option surface is a native popover (`SystemPopover`). Keep option IDs stable. Multiple select uses `Values` / `OnValuesChange` (Go) or `multiple` (TS/Rust).

```go
picker := ui.NewSelect(ui.SelectRootProps{
	PickerSourceProps: ui.PickerSourceProps{
		Items: func() []ui.OptionDeclaration {
			return []ui.OptionDeclaration{{Value: "go", Label: "Go"}}
		},
	},
	Value: value,
	OnValueChange: func(next *string, _ *native.Event) { setValue(next) },
})
return picker.Root().Children(picker.Value(), picker.Icon().Child("▾"))
```

```tsx
<Select.Root
  ariaLabel="Theme"
  items={[
    { value: "system", label: "System" },
    { value: "light", label: "Light" },
    { value: "dark", label: "Dark" },
  ]}
  value={theme()}
  onValueChange={setTheme}
/>
```

## NumberField, Slider, OTP

**NumberField** — increment, decrement, scrub. Typing does not clamp; clamp/format on commit (Return/blur). Invalid text reports `valid: false` and does not submit. Alt = small step, Shift = large step.

**Slider** — one or more thumbs (`Value []float64` in Go). `OnValueCommitted` fires at the commit boundary. Rust caps thumbs (`MAX_SLIDER_THUMBS` = 8).

**OtpField** — up to 12 one-character slots. Go: `NewOtpField` → `Root`, `Input(index)`, `Separator`; `OnComplete`. Rust: bind `otp_field_key_bindings()` before editing.

## Date, time, calendar

No locale database: the app supplies format, weekday, and separators.

| | Go | Notes |
| --- | --- | --- |
| DateField | `Root`, `Segment(name)`; `Format: "ymd"`; `Min`/`Max` ISO strings | partly filled = invalid; min/max do not rewrite typing |
| TimeField | `Root`, `Segment`; `Hour12`, `ShowSeconds` | Rust stores 24h |
| Calendar | `Root`, `Week(i)`, `Day(id)`; `FirstWeekday` Mon=0..Sun=6 | min/max refuse selection, not movement |

## Pointer, keyboard, focus

- Mouse: `on_mouse_down` / `capture_any_mouse_down` / `on_mouse_down_out` / `on_hover`. `stop_propagation` and `prevent_default` are independent.
- Keys: shortcut identity vs printable `key_char`. Only `TextInput` is committed text.
- Focus: dialogs trap Tab. A hosted AppKit view that takes focus blurs the framework’s focused element (macOS).
- Go: `.OnClick` vs `.OnClickEvent(*native.Event)`. Keep UI updates on the UI goroutine.

## Pitfalls

- Controlled values only; do not keep a second copy the core does not own.
- NumberField: type freely; commit clamps.
- OTP length ≤ 12.
- Select lists leave the window; size SystemPopover content.
