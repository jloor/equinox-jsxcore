# Chapter 7 — Proving the claims

*2026-08-06. The migration was finished, deployed, and green. It proved almost nothing.*

Every view was TSX. Full CRUD worked. CI was green and the site was live. And a visitor
comparing it to the original Razor app would have seen no difference whatsoever, because
there wasn't one.

Worse, the honest scorecard of the migration looked like this:

| Razor gave you | JsxCore needed |
|---|---|
| `_Layout` + `_ViewStart`, automatic | every view imports and wraps itself |
| `@inject SignInManager` | a registered .NET global |
| `@Html.AntiForgeryToken()` | a hand-written component |
| `asp-validation-for` | another global plus a component |
| `[DisplayName("E-mail")]` | a string literal that silently drifts |
| `<vc:summary />` | cannot invoke ViewComponents from TSX at all |

Six things that got *worse*. A fair reader concludes Razor won, and they would be right —
because a like-for-like port of a server-rendered CRUD app is precisely the case Razor
already handles well.

So: what does JsxCore actually claim, and which of those had this project demonstrated?

| Claim | Before this chapter |
|---|---|
| No Node/npm required | ✅ proven |
| Types generated from C# | ⚠️ only `ErrorViewModel`; the model the app actually uses was hand-written |
| Same component renders server **and** client | ❌ everything was `"use server"` |
| npm packages work without npm | ❌ unused |
| Vite-like HMR | ❌ not shown |

One of five. The least interesting one.

---

## The pattern, stated up front

Four claims got proven in this chapter. **Every one of them was true. Not one was true by
default.** Each needed between one and three non-obvious steps, and in every case the
default configuration silently delivered something weaker that looked like it was working.

That is the finding, and it repeated so precisely it stopped being a coincidence.

---

## 1. Deploys were verified by liveness, not freshness

Not a JsxCore claim — a defect in the thing that verifies all the others.

The post-deploy check asserted that a nav link was present on the live site. It passed. But
the outgoing container also serves that nav link, so the check proved "*a* build is
serving", never "*this* build is serving".

It got caught by accident: CI reported a green deploy while the site was still showing
Bunny's *"We're deploying your app!"* placeholder.

The fix was `/version`, reporting the commit the image was built from, and gating the
deploy on it. The very next rollout showed exactly how wide the window had been:

```
[1] not the new build yet (got: <no response>)
[2] not the new build yet (got: <!DOCTYPE html><html class="" lang="en"><head><t...)
[3] not the new build yet (got: <!DOCTYPE html><html class="" lang="en"><head><t...)
[4] not the new build yet (got: <!DOCTYPE html><html class="" lang="en"><head><t...)
[5] not the new build yet (got: <!DOCTYPE html><html class="" lang="en"><head><t...)
New build is serving (b709108752570f0a247a2c54e85fc22ecc6b0c47).
Customer list is serving seeded data.
```

Roughly seventy-five seconds in which the old check could have declared success.

This had to come first. Everything else in this chapter is a claim about the deployed app,
so the step that certifies deployment had to be trustworthy before any of it meant anything.

---

## 2. Types generated from C#

I described this as a one-line config change. It was three interacting things.

**The default convention scans only the web assembly.** `CustomerViewModel` lives in
`Equinox.Application`, so it was never generated — which is exactly why the migration had
hand-written a TypeScript interface for it. The feature that prevents drift was, by
default, not covering the one model the application actually uses.

**The build cannot see your configuration.** Straight from the docs:

> `AutoExport`, a naming policy on `JsonSerializerOptions`, `EnumsAsStrings` and the rest
> are set in application code that has not run, so the build generates with the defaults.

Generation runs twice — at build with defaults, at startup with your config. There is no
MSBuild property to widen the build-time pass, and `dotnet:types/...` resolves into `obj/`,
which the build regenerates with defaults and git ignores. The committed runtime output has
to be imported by path instead.

**Type checking was advisory.** The first attempt to prove drift produced:

```
TS2339: Property 'emailAddress' does not exist on type 'CustomerViewModel'
    0 Error(s)
```

A warning. The build succeeded. "The model and the view cannot drift" was not true until
`<JsxCoreTypeChecking>error</JsxCoreTypeChecking>`, after which:

```
TS2339: Property 'emailAddress' does not exist on type 'CustomerViewModel'
Build FAILED.
    1 Error(s)
```

That is the claim, made real. Rename a property in C# and the build breaks.

---

## 3. One component, server and client

The customer history modal shipped in upstream Equinox as this:

```js
var html = "<table class='table table-striped'>";
html += "<thead><th>Action</th><th>When</th>...</thead>";
for (var i = 0; i < data.length; i++) {
    html += "<tr><td>" + c.action + "</td><td>" + c.timestamp + "</td>";
```

String-concatenated HTML, untyped, server data interpolated straight into markup — inside a
project whose entire premise is typed views. It is now a Preact component typed against the
generated `CustomerHistoryData`, and the page proves the claim in a single response:

```
<td>Eduardo Pires</td>                        server-rendered markup
mountView(Component, {..., "hydrate":true})   the same component hydrates
```

Three things were not obvious:

**`ServerAndClient` has no file directive.** `"use server"` and `"use client"` exist; the
both-modes case is deliberately per-response, because the same view is often server-rendered
publicly and client-only behind a login. It is normally set in the controller — which this
project may not modify — so a result filter sets it instead, for one action only.

**The component runs twice, and .NET globals are a server-pass feature.** `Layout` reads
`User` and `Antiforgery`, so the client pass would throw. Worse than throwing would be
rendering *differently*: a signed-in user would watch the nav flip to "Register / Login"
after hydration. The server now writes its answers into `data-*` attributes and the client
reads them back, so both passes emit identical markup and hydration is a no-op rather than
a repair.

**`RenderMode` is in the root `JsxCore` namespace**, not `JsxCore.Mvc` or `JsxCore.Rendering`.
Found by trying each.

---

## 4. npm packages, with no npm

```bash
dotnet npm add marked dayjs highlight.js
```

on a machine where `node` and `npm` are both absent. JsxCore talks to the registry itself.

- **`marked`** runs *server-side*, inside the embedded JavaScript engine, and renders this
  writeup at `/journey` from committed markdown.
- **`dayjs`** is imported through the server pass and also served to the browser.
- **`highlight.js`** runs in the browser only.

That last one is not a preference:

```
Jint.ScriptPreparationException: Script nesting exceeds maximum depth of 256 levels
```

`options.ServerRendering.MaxRecursionDepth` does not raise it — setting it to 4096 produced
the identical error, because that guards *runtime recursion* and this is *script
preparation*. So highlight.js is dynamically imported behind an `isServerRender()` guard.

Which improved the demonstration rather than weakening it: `marked` proves npm packages run
on the server, `highlight.js` proves they reach the browser as ES modules with no bundler:

```
"marked":       "/_jsx/v.../npm/0/marked/lib/marked.esm.js"
"highlight.js": "/_jsx/v.../npm/0/highlight.js/es/index.js"
```

**And the first `dotnet publish` on a clean checkout omits `node_modules`.** The docs are
explicit that "everything in your `dependencies` is copied into the publish output
automatically", and on a second publish it is. But on a *clean* checkout — which is exactly
what CI and a Docker build are — the packages are restored during that publish and end up
absent from its output:

| | `node_modules` in publish output |
|---|---|
| First publish, clean checkout | absent |
| Second publish | present, `dependencies` only |

Every page importing a package then returns 500 in the container while working perfectly in
development. JsxCore's own startup warning is what found it, and it is a genuinely good
error message:

> JsxCore: package.json declares marked, dayjs, highlight.js, which are not installed in
> /app. A view importing one will fail to render.

---

## The claim that stayed unproven

**HMR.** It is a development-time experience; no deployed URL can demonstrate it. It needs a
screen recording, and saying so is better than quietly dropping it from the list.

Final scorecard:

| Claim | Status |
|---|---|
| No Node/npm required | ✅ asserted in CI before every build |
| Types generated from C# | ✅ drift fails the build |
| Same component, server and client | ✅ server-rendered markup + `hydrate:true` |
| npm packages without npm | ✅ server-side and browser-side |
| Vite-like HMR | ❌ not provable by a deployment |

---

## What kept happening

**Every claim was true. None was on by default.** Types generated the wrong scope. Type
checking warned instead of failing. The both-modes render was off. The packages were never
installed. In each case the default produced something that looked like it was working.

That is not a complaint about JsxCore — the defaults are reasonable for the common case, and
the docs are unusually candid about the seams, including the line that explains the whole
type-generation problem. It is an observation about verifying claims: **"it built and the
page loaded" is compatible with almost every feature being inactive.**

The other thing that kept happening is more uncomfortable. Three separate checks in this
project passed when they should have failed:

- a smoke test using `curl --max-file-size` — not a real flag — so curl errored, `grep`
  received empty input, found no problem, and reported PASS
- a deploy check asserting liveness while claiming freshness
- a throwaway shell check that printed "server-rendered" against an empty response

All three had the same shape: **the check could not distinguish "the thing is fine" from "I
failed to look".** That is the failure mode worth designing against, and it is why every
check added in this chapter fails loudly when it cannot evaluate its own subject — including
the Bunny guard, which reports `UNKNOWN` and exits non-zero rather than assuming a default
is fine.

23 checks now run against the application on every push, plus 10 against the production
image and 3 against the deployment's configuration. Every claim on the home page is
machine-verified rather than asserted.

### Postscript: it happened again, immediately

Minutes after writing the paragraph above, I checked whether this very chapter was live:

```
/journey/07-proving-the-claims -> HTTP 200
```

It was not live. The page returned `200` while rendering **"Chapter not found"**, because
the view answered a missing chapter with an apology and a success status. At the same moment
the deployed commit was `3616b70` while the chapter was in `71b6e61`, and the CI check that
said "completed success" had read the *previous* run, because polling immediately after a
push returns the run that finished before it.

Three false passes in one command, in the space of about thirty seconds, in a check
verifying a chapter about false passes.

The bug was real and is fixed — an unknown chapter now returns `404`, and there is a check
asserting it. But the more useful lesson is that knowing about this failure mode does not
confer immunity from it. The only thing that helps is the boring one: compare against
something that can actually differ. The deployed SHA versus the expected SHA. Rendered
markup versus a status code. What the check can *distinguish*, not what it can *observe*.

The migration was the easy part.
