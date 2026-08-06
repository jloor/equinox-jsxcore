# Chapter 2 — Testing the four things the migration depends on

*2026-08-05. Still in a throwaway project. Equinox untouched.*

The plan assumed JsxCore could do four things nobody had verified. Three work.
One doesn't, and one of the three works in a way that changes the migration's shape.

| # | Assumption | Verdict |
|---|---|---|
| 1 | Server-side rendering | ✅ works (`"use server"`) |
| 2 | Shared layouts | ⚠️ works, but **not** the way Razor does |
| 3 | Form POST + antiforgery | ✅ works — **via an undocumented route** |
| 4 | ViewComponents | ❌ **broken** |

---

## 1. Server rendering — works

Default render mode is `Client`, which ships an empty `<div id="jsxcore-root">` and
mounts in the browser. Wrong for an MVC app. The fix is a directive as the first
statement in the file:

```tsx
"use server";
```

Output becomes real markup:

```html
<div id="jsxcore-root"><div class="page"><header><nav>…</nav><h1>Home</h1></header>
<main><p>Hello World — server rendered.</p></main><footer>…</footer></div></div>
```

Three modes exist: `Client` (default), `Server`, `ServerAndClient`. Set per-view by
directive, or per-response at the endpoint.

**Migration consequence:** every converted Equinox view needs `"use server"` at the top.
Forget it and the page silently renders blank to crawlers and no-JS clients, while
looking fine in a browser. That's a nasty failure mode — it doesn't error, it just
quietly stops being an MVC app.

---

## 2. Layouts — there is no `_Layout`

**JsxCore has no layout concept at all.** No `_Layout`, no `_ViewStart`, no implicit
wrapping. Searching the entire docs tree for "layout" turns up only a "project layout"
heading and a component named `Layout.tsx` in an example.

A layout is just a component you import:

```tsx
"use server";
import { Layout } from "../Shared/Layout.tsx";

export default function Index({ model }) {
    return <Layout title="Home"><p>Hello {model.name}</p></Layout>;
}
```

Verified working. But the model is fundamentally different from Razor:

| Razor | JsxCore |
|---|---|
| `_ViewStart.cshtml` applies a layout to every view implicitly | Every view must import and wrap itself explicitly |
| Forgetting it → still wrapped | Forgetting it → page renders with no chrome |

**Migration consequence:** the spec's "`_Layout.cshtml` → `_Layout.tsx`" implies a 1:1
conversion. It isn't one. The file converts easily; the *mechanism* doesn't exist, and
every single view has to be edited to opt in. This is more like a props-drilling refactor
than a file rename — and it's invisible until you look at a rendered page.

---

## 3. Antiforgery — works, but nothing documents it

Searching every file in JsxCore's docs for `antiforgery`, `anti-forgery`, `csrf`,
`RequestVerificationToken`, or `forgery` returns **zero hits**. The original spec said
"check JsxCore docs for the equivalent of `@Html.AntiForgeryToken()`" — there is no
equivalent documented.

The mechanism that works is **.NET globals**. Register an ordinary C# service:

```csharp
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<AntiforgeryHelper>();
builder.AddJsxCore(o => o.Globals.Register<AntiforgeryHelper>("Antiforgery"));

public sealed class AntiforgeryHelper(IAntiforgery antiforgery, IHttpContextAccessor accessor)
{
    public string FieldName() => antiforgery.GetAndStoreTokens(accessor.HttpContext!).FormFieldName;
    public string Token()     => antiforgery.GetAndStoreTokens(accessor.HttpContext!).RequestToken!;
}
```

Call it from the view — synchronously, no bridge, no fetch:

```tsx
import { Antiforgery } from "dotnet:globals";
<input type="hidden" name={Antiforgery.fieldName()} value={Antiforgery.token()} />
```

Full round trip, against a real MVC controller with `[ValidateAntiForgeryToken]`:

```
GET  /Customer/Create   → <input type="hidden" name="__RequestVerificationToken"
                             value="CfDJ8KFuGI6XjExEukRUUlFV…"/>   (155 chars)
POST with token         → HTTP 200   CREATED name=Ada email=ada@example.com total=1
POST without token      → HTTP 400
```

Enforcement is genuinely active — not bypassed, not disabled. Model binding into
`CustomerViewModel` worked. And `return View(model)` from an MVC controller resolved
`Create.tsx` with no extra wiring.

**Constraint discovered:** globals only exist during server rendering. Any view using
one *must* be `"use server"`. So every form in Equinox is locked to server rendering —
which is correct anyway, but it's a coupling nobody wrote down.

---

## 4. ViewComponents — broken

Equinox has `Views/Shared/Components/Summary/`, so this matters.

```csharp
public class SummaryViewComponent : ViewComponent
{
    public IViewComponentResult Invoke(int count) => View(new SummaryModel { Count = 42 });
}
```

```tsx
"use server";
export default function Default({ model }: { model: { Count: number } }) {
    return <aside class="summary">Summary: {model.Count} customers</aside>;
}
```

`GET /Customer/Summary` → `HTTP 200`, and the file *is* found. But:

```html
<aside class="summary">Summary:  customers</aside>
```

**The model is empty.** Hardcoding `Count = 42` changes nothing — it still renders blank,
so the value isn't falsy-rendering, it's `undefined`. The ViewComponent's model never
reaches the TSX view. Normal controller views bind fine in the same app, so this is
specific to the ViewComponent path.

Second problem: the response is a **full HTML document** — `<!DOCTYPE html>`, `<head>`,
the whole import map, 1,599 bytes of it. A ViewComponent is supposed to emit a *fragment*
for embedding in a page. Two ViewComponents on one page would mean two nested documents.

**Verdict: unusable in 1.0.0.** Not "awkward" — the model silently vanishes.

### The workaround, and why it's interesting

The same mechanism that solved antiforgery solves this. Register the data source as a
global and call it directly from the view:

```csharp
builder.AddJsxCore(o => o.Globals.Register<SummaryService>("Summary"));
```

```tsx
import { Summary } from "dotnet:globals";
<aside>Summary: {Summary.getCount()} customers</aside>
```

This matters for Equinox specifically because the constraints forbid modifying
`Controllers/`. The obvious fix — fold the summary data into the parent ViewModel —
would require a controller change. Globals route around it entirely: the data reaches
the view without the controller knowing.

---

## Where this leaves the migration

Nothing here is fatal, but two things in the plan were wrong:

- **"Convert `_Layout.cshtml` → `_Layout.tsx`"** describes a file rename. The real work
  is that no layout mechanism exists, so every view must explicitly wrap itself.
- **ViewComponents can't be converted at all** in 1.0.0. They have to be re-expressed as
  globals.

Both were cheap to find here and would have been expensive to find mid-conversion, with
the original `.cshtml` files already deleted.

Total spike time including the first chapter: well under an hour.
