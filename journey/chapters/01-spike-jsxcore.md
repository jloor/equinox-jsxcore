# Chapter 1 — Does JsxCore actually work with no Node?

*2026-08-05. Throwaway project, before touching Equinox.*

## The setup

`mcr.microsoft.com/dotnet/sdk:9.0`, verified empty of JS tooling first:

```
dotnet: 9.0.316
node: absent    npm: absent    npx: absent    yarn: absent    pnpm: absent
```

This mattered: the host machine has Node v24 and npm 11 installed, so a build there
would have succeeded whether or not JsxCore needed them. The claim was untestable
until it ran somewhere clean.

## Result: it works

Three commands — `dotnet new web`, `dotnet add package JsxCore`, `dotnet build`:

```
Spike -> /work/Spike/bin/Debug/net9.0/Spike.dll
JsxCore: restoring with native: typescript, esbuild
JsxCore: created /work/Spike/package.json.
JsxCore: fetching @esbuild/linux-x64@0.28.1
JsxCore: fetching @typescript/typescript-linux-x64@7.0.2
JsxCore: fetching esbuild@0.28.1
JsxCore: fetching typescript@7.0.2

Build succeeded.
    0 Warning(s)
    0 Error(s)

Time Elapsed 00:00:09.31
```

`Program.cs` was 8 lines. `Index.tsx` was 3. `GET /` returned `200 OK`.

**The claim holds** — no Node runtime, no npm binary, TypeScript 7.0.2 and esbuild 0.28.1
sourced by the .NET build itself.

**The honest nuance:** "no npm" means *no npm binary*. JsxCore still writes a
`package.json` and speaks the registry protocol directly. Practical consequence for CI:
**the build machine needs egress to `registry.npmjs.org`**. An air-gapped or
strictly-allowlisted runner will fail, and the error won't obviously point at JsxCore.

## The finding that changes the plan

The default render mode is **client-side, not server-side**:

```html
<div id="jsxcore-root"></div>
<script type="application/json" id="jsxcore-model">{"name":"World"}</script>
<script type="module">
import Component from "/_jsx/ve801387ae0/views/Home/Index.js";
import { mountView } from "@jsxcore/client";
```

Response header: `X-JsxCore-Framework: preact`.

The root div ships **empty**. The model is serialized into a JSON script tag and the
component mounts in the browser.

This cuts two ways:

- **Good:** the Jint CPU cost I'd been worried about for a free-tier host doesn't apply
  per-request in this mode. No JavaScript executes server-side. The hosting math gets easier.
- **Bad:** an empty root div is wrong for an MVC app. No first paint without JS, nothing
  for crawlers. Server rendering is opt-in per response and has to be verified separately.

Also notable: the generated import map aliases `react`, `react-dom`, and
`react/jsx-runtime` onto `preact/compat`. React-shaped code works, but Preact is what
actually runs. The spec's "convert to React components" framing was imprecise.

And: `JsxCore generated TypeScript declarations for 0 .NET type(s)` — expected here, since
the model was an anonymous type. Real ViewModels are what exercise the type generation.

## Still unverified

The three things the migration actually depends on:

1. **Shared layouts** — layouts are a Razor concept; JsxCore registers as an `IViewEngine`
2. **Form POST with `[ValidateAntiForgeryToken]`** — needed for all of Customer CRUD
3. **ViewComponents** — Equinox has `Views/Shared/Components/Summary`

Plus, now: **server-side render mode**, which the default output doesn't use.

## Time

Under 15 minutes from empty directory to rendered page, including pulling the image.
No .NET knowledge was required for any of it — the whole surface was three commands
and two files copied from the README.
