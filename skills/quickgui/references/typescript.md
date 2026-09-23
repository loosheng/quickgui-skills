# TypeScript

TypeScript idioms: Bun + Solid 2 JSX, worker ownership, style-prop rules, and project checks. There is no DOM or WebView.

## Packages

Applications depend on `@quickgui/native`, `@quickgui/solid`, and `solid-js`. `@quickgui/cli` is a development dependency.

| Import | Role |
| --- | --- |
| `@quickgui/native` | `app`, `Window`, clipboard, dialogs, menus, tray, shell |
| `@quickgui/solid` | `View`, `Text`, `Button`, `createRenderer`, compound controls |
| `solid-js` | `createSignal`, `createMemo`, `createEffect`, `Show`, `For`, `onCleanup` |
| `@quickgui/solid/router` | `Router`, `Route`, `Link`, `Outlet`, navigation hooks |
| `@quickgui/solid/swift-ui` | macOS SwiftUI controls and `Host` |

Pin `solid-js`, `@solidjs/compiler`, and `@solidjs/universal` together (scaffold uses `2.0.0-rc.8`). In `tsconfig.json` set `jsx: "preserve"` and `jsxImportSource: "@quickgui/solid"`. The default entry is `app.tsx`.

## Startup

Await `app.whenReady()` before opening windows. Each window has its own Solid root, disposed when the window closes.

```tsx
import { createSignal } from "solid-js";
import { app, Window } from "@quickgui/native";
import { Button, Text, View, createRenderer } from "@quickgui/solid";

function Counter() {
  const [count, setCount] = createSignal(0);
  return (
    <View style={{ padding: 24, display: "flex", flexDirection: "column", gap: 12 }}>
      <Text>Count: {count()}</Text>
      <Button onClick={() => setCount(count() + 1)}>Increment</Button>
    </View>
  );
}

function openWindow() {
  new Window({ title: "Counter", width: 720, height: 480, renderer: createRenderer(Counter) });
}

app.on("reopen", ({ hasVisibleWindows }) => {
  if (!hasVisibleWindows) openWindow();
});
await app.whenReady();
openWindow();
```

`Window.whenReady()` resolves when Rust has mounted the window (including hidden windows). Observe close with `window.onClose()` or `window.on("closed", ...)`. `onCloseRequested` can hold a close.

## JSX and styles

Put every layout, typography, paint, and preset declaration in `style` with camelCase keys. Direct style attributes, `class`, and `className` are unsupported.

```tsx
<div style={{ flexCol: true, gap2: true }}>
  some text
  <span style={{ textLg: true, fontSemibold: true }}>Styled text</span>
</div>
```

`<div>` and `<span>` are aliases for `View` and `Text`. `<View>` accepts plain text. `JSX.Style` provides editor completion.

Presets are boolean entries in the same object (`flexCol`, `itemsCenter`, `p3`, `roundedLg`, `textLg`, `fontBold`, `positionSticky`). `roundedLg` is 8px; `p3` is 12px (4px spacing scale). Presets take `true`, `false`, `null`, or `undefined`. A falsey preset withdraws that preset. Custom values use `borderRadius`, `padding`, `gridTemplateColumns`, `width`.

Style arrays merge left to right. Falsy array entries are ignored. Removing a field from a reactive style object clears that native property.

```tsx
import type { JSX } from "@quickgui/solid";

const panel = { p3: true, roundedXl: true, bg: "#18181b" } satisfies JSX.Style;
<View style={[panel, { textColor: "#fafafa" }]}>
  <Text>Hello</Text>
</View>;
```

Colors accept CSS hex or an integer packed as `0xAABBGGRR`.

## Components

Components construct once. Solid tracks JSX expressions and updates affected native properties or child edges. Use Solid 2 `Show`, `For`, signals, effects, and cleanup.

Compound parts are nested under their root:

```tsx
<Checkbox.Root checked={checked()} onCheckedChange={setChecked}>
  <Checkbox.Indicator>
    <Text>✓</Text>
  </Checkbox.Indicator>
  <Text>Remember this device</Text>
</Checkbox.Root>
```

Controlled values use the current value plus a change callback, or `defaultValue` / `defaultChecked` / `defaultOpen` when the component owns state.

```tsx
<Input value={name()} onInput={(event) => setName(event.value ?? "")} />
```

`TextInput` is the same as `Input`. Text events put the string in `event.value`.

Hooks such as `useTabsState` and `useSelectState` expose core state for custom presentation.

## Worker model

AppKit/Winit stay on Bun’s main thread. Solid, handlers, promises, timers, and application I/O run in a worker. Both isolates load the same Rust library; UI commands enter the host queue through FFI.

The host waits for a worker startup handshake before entering the native loop. Native events are copied into a bounded queue (8,192 events, 32 MiB) before JavaScript sees them. Overflow fails the application. Shutdown disposes windows and pending requests before terminating the worker. Destroying the native application rejects pending app-service requests.

TypeScript applications that include the updater must become ready so the install helper can acknowledge startup; otherwise a Windows or Linux update is rolled back. See [updater](updater.md).

## Optional extensions

```sh
bun add @quickgui/extension-editor
bun add @quickgui/extension-markdown
bun add @quickgui/extension-terminal
bun add @quickgui/extension-updater
```

Declare native libraries that need bundling in config, for example `extensions: ["@quickgui/extension-terminal"]` or `["@quickgui/extension-updater"]`. Editor/CodeBlock/DiffView do not need a second native image. `ExtensionSession` and `invokeExtension` call other extension services.

## Window and app APIs

`Window.close()`, `Window.setTitle()`, `Window.getState()`, `app.quit()`, and `app.exit()` use the native host. Value-returning operations are promises. Snapshots use `bounds`, `viewportSize`, and `scaleFactor`. `app.command()` exposes native JSON commands for advanced use.

If you supply `macos.entitlements`, include Bun’s JIT and unsigned-executable-memory entitlements (the CLI adds them by default otherwise).

## Checks

```sh
quickgui check
quickgui test
quickgui fmt
```

`check` typechecks. `test` preloads the same Solid compiler and client runtime as builds. Production builds embed Bun and both host/worker entrypoints in one executable.

## Pitfalls

- Styles only through the `style` prop; never `class` / `className` / loose style attributes.
- A signal read during setup is a snapshot; call it in JSX to stay live.
- `useParams()`, `useLocation()`, and `useSearchParams()` return store-like objects (`params.id`, `location.pathname`) — do not call them as accessors.
- Capture `Window.getCurrentWindow()` during setup; do not look it up from an unrelated callback later.
- Keep one updater for the process; closing a window must not close it.

Upstream: [TypeScript guide](https://github.com/egoist/quickgui/blob/v0.1.6/docs/typescript.md), [TypeScript getting started](https://github.com/egoist/quickgui/blob/v0.1.6/website/src/content/docs/typescript/en/getting-started.mdx).
