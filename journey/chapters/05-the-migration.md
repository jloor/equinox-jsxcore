# Chapter 5: Converting the views

*2026-08-06. The part the original plan thought was the whole project.*

```json
{"id":"no-cshtml-in-views","status":"PASS","detail":"only Identity-required Razor files remain"}
{"id":"tsx-use-server","status":"PASS","detail":"all 8 .tsx views declare \"use server\""}
{"id":"build","status":"PASS","detail":"0 errors"}
{"id":"build-no-new-warnings","status":"PASS","detail":"0 warnings (baseline 0)"}
{"id":"no-node-toolchain","status":"PASS","detail":"built with no node/npm on PATH"}
{"id":"app-starts","status":"PASS"}
{"id":"route-home","status":"PASS"}
{"id":"route-list","status":"PASS"}
{"id":"auth-enforced","status":"PASS"}
{"id":"crud-auth","status":"PASS"}
{"id":"crud-create","status":"PASS"}
{"id":"crud-read","status":"PASS"}
{"id":"crud-update","status":"PASS"}
{"id":"crud-delete","status":"PASS"}
EXIT=0
```

Eight `.tsx` views. Full CRUD through antiforgery-protected forms. Zero warnings.

---

## The bug that took the longest was one character

JsxCore generates TypeScript declarations from .NET types. Opening them mid-migration:

```ts
declare namespace Equinox.UI.Web.Models {
    interface ErrorViewModel {
        errorCode: number;   // <- camelCase
        title: string;
        message: string;
    }
}
```

> *"These describe the model as it arrives in JavaScript, so they follow the application's
> `JsonSerializerOptions` rather than the .NET shape directly."*

`CustomerViewModel.Name` arrives as `model.name`. `BirthDate` as `model.birthDate`.

This is the same thing that made me declare ViewComponents broken back in chapter 2. I
had written `model.Count` against a payload containing `count`. That earlier verdict is
corrected there. ViewComponents work.

The failure mode is worth dwelling on: `undefined` renders as **nothing** in JSX. No error,
no warning, HTTP 200, a page that looks structurally correct with a blank where the data
should be. A casing mistake and a broken framework produce byte-identical output.

There is a second half to it, which is easy to miss:

```tsx
<input name="Name" value={model.name} />
```

The **attribute** stays PascalCase, because ASP.NET model binding reads it on POST. The
**model property** is camelCase, because that's JSON arriving from the server. Two different mechanisms,
two different conventions, in the same line.

---

## What each Razor feature became

| Razor | JsxCore |
|---|---|
| `_Layout.cshtml` + `_ViewStart` | `Layout.tsx` component every view imports explicitly |
| `<partial name="_LoginPartial" />` | component reading a `User` global |
| `@inject SignInManager` | `options.Globals.Register<CurrentUser>()` |
| `@Html.AntiForgeryToken()` | `<AntiforgeryField />` reading an `Antiforgery` global |
| `asp-validation-summary` | `<ValidationSummary />` reading a `Validation` global |
| `asp-validation-for="Name"` | `<FieldErrors field="Name" />` |
| `<vc:summary />` | a component, since TSX cannot invoke ViewComponents |
| `@Html.DisplayNameFor(m => m.Name)` | a string literal |
| `@Html.DisplayFor` + `[DisplayFormat]` | `formatDate()` helper |
| `@section scripts` | inline `<script>` at point of use |
| `asp-action="Edit" asp-route-id="@item.Id"` | `` href={`/customer-management/edit-customer/${item.id}`} `` |
| `@ViewData["Title"]` | `export const head = { title: ... }` |

Three of those needed .NET globals, which is request state Razor reached through `@inject`,
`ModelState`, and tag helpers, none of which JsxCore has. **`ModelState` doesn't live on
`HttpContext`**, so exposing validation errors meant registering `IActionContextAccessor`
as well.

The one with no equivalent at all is `[DisplayName("E-mail")]`. JsxCore's generated types
carry property *names* but not display *metadata*, so every label became a literal. Change
the attribute in C# now and the view silently keeps the old text. Razor would have
followed it automatically.

---

## The oracle earned its cost twice in one session

**It caught a warning I had dismissed.** After deleting the `.cshtml` files, a build showed
`1 Warning(s)`. I grepped for it, saw nothing, called it a stale incremental artifact, and
moved on. The oracle disagreed:

```json
{"id":"build-no-new-warnings","status":"FAIL","detail":"1 warnings > baseline 0: CS8632"}
```

Real, and mine: `ModelStateDictionary?` in a project with `<Nullable>disable</Nullable>`.
My grep had missed it; the check did not. Had the baseline still been 16 from before the
security patch, this would have hidden inside the noise. Patching the CVEs in D11 is what
made a single new warning visible at all.

**And it caught itself being wrong.** It flagged `Shared/Layout.tsx` for missing
`"use server"`. False positive: that is a *component*, not a view, and JsxCore consults
the directive only on the view an endpoint named. Fixed by testing for a `export default`,
which is the distinction the docs themselves draw.

---

## What the spec called simple

The original plan listed view conversion as seven steps, simplest first, starting with
`Home/Index.cshtml`.

Converting `Home/Index` actually required: the layout component, the login partial, two
.NET globals, head-content configuration, and body-script configuration. The spec had
`_Layout` as step **4.2**, *after* the view that cannot render without it.

The ordering only looks wrong once you know JsxCore has no layout mechanism. That was
knowable in about thirty minutes of reading the docs, and was not in the plan.

## Cost of coexistence

Two layouts now exist: `_Layout.cshtml` for Identity's Razor pages, `Layout.tsx` for
everything else. They render the same chrome today and will drift. That is the honest
price of keeping Identity on Razor, and it is a maintenance cost, not a one-time one.
