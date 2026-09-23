# Routing

In-window routing with nested layouts, links, and path parameters. History stays inside the app (bounded memory history). Core matching is shared; each language projects it differently.

## Go

`ui.Router`, `ui.Route`, `ui.Layout`, `ui.Outlet`, `ui.Link`. `ui.UseRouter()` exposes `Navigate`, `Replace`, `Back`, `Forward`. Read `ui.UseParams()`, `ui.UseSearchParams()`, and `ui.UseLocation()` while rendering so text stays live. A `:name` segment captures one path parameter.

```go
func NestedRouterExample() *ui.Element {
	return ui.Router(ui.RouterProps{
		InitialPath: "/",
		Routes: []*ui.RouteDeclaration{
			ui.Layout(
				func() *ui.Element {
					return ui.View().FlexCol().Gap(12).Children(
						ui.Link(ui.LinkProps{Href: "/"}, "Home"),
						ui.Link(ui.LinkProps{Href: "/settings"}, "Settings"),
						ui.Outlet(),
					)
				},
				ui.Route("/", func() *ui.Element { return ui.Text("Home") }),
				ui.Route("/settings", func() *ui.Element { return ui.Text("Settings") }),
				ui.Route("/projects/:name", func() *ui.Element {
					params := ui.UseParams()
					return ui.Text("Project: ", params()["name"])
				}),
			),
		},
		Fallback: func() *ui.Element { return ui.Text("Page not found") },
	})
}
```

```go
func BackButton() *ui.Element {
	router := ui.UseRouter()
	return ui.Button().Child("Back").OnClick(router.Back)
}
```

Navigation between sibling routes keeps the layout mounted, so layout-local state survives.

## TypeScript

Import from `@quickgui/solid/router`. Nested `<Route>` paths are relative to the parent. A pathless parent is shared chrome without a URL segment. Render `<Outlet />` where the child belongs.

```tsx
import { Router, Route, Link, Outlet, useNavigate, useParams } from "@quickgui/solid/router";

<Router initialPath="/">
  <Route path="/" component={Shell}>
    <Route path="/" component={Home} />
    <Route path="/settings" component={Settings} />
    <Route path="/projects/:id" component={Project} />
  </Route>
</Router>

function Shell() {
  return (
    <View style={{ flexCol: true, gap: 12 }}>
      <Link href="/">Home</Link>
      <Link href="/settings">Settings</Link>
      <Outlet />
    </View>
  );
}

function Project() {
  const params = useParams();
  return <Text>Project {params.id}</Text>;
}
```

```tsx
const navigate = useNavigate();
<Button onClick={() => navigate("/projects/42")}>Open project</Button>
```

`useLocation()` and `useSearchParams()` return reactive objects. Read `location.pathname` and `searchParams.tab` in JSX. Push, replace, back, and forward are supported.

## Rust

```rust
let router = Router::new(
    [
        RouteDefinition::new("home", "/"),
        RouteDefinition::new("project", "/projects/:id"),
    ],
    "/",
)?;
```

`RouteDefinition::layout(id).parent(...)` declares a pathless ancestor. Relative child paths join the parent; an absolute child path starts at the root.

```rust
self.router.push("/projects/42")?;
cx.invalidate();
```

`replace`, `back`, and `forward` are also available. After navigation, invalidate.

```rust
if let Some(matched) = self.router.matched() {
    let id = matched
        .params()
        .iter()
        .find(|param| param.name() == "id")
        .map(|param| param.value())
        .unwrap_or("");
    text(format!("Project {id}"))
} else {
    text("Page not found")
}
```

## Pitfalls

- Read params/search during render (Go/TS) so bindings stay live.
- Rust: `push`/`replace` without `cx.invalidate()` shows the old UI.
- Layouts stay mounted across sibling navigations on purpose.
- Navigation stays in-app; it does not load URLs in a webview.

Upstream: [Go routing](https://github.com/egoist/quickgui/blob/v0.1.6/website/src/content/docs/go/en/routing.mdx).
