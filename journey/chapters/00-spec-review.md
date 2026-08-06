# Chapter 0: Reviewing the plan before running it

*Captured 2026-08-05. Nothing had been built yet.*

The project started as a written spec: convert the Equinox Project (ASP.NET Core MVC)
from Razor views to JsxCore TSX views, then deploy it as a public demo.

Before executing any of it, I had the plan checked against the actual repos, packages,
and machine. Eight of its claims were wrong. Several would have surfaced only after
destructive changes.

## What the spec got wrong

| # | Spec said | Reality |
|---|---|---|
| 1 | Views live in `Views/Customers/` | It's `Views/Customer/`, **singular**. The spec warns about Linux case-sensitivity while getting the path wrong itself, 7 times. |
| 2 | Replace `UseSqlServer` in `Program.cs` | `Program.cs` never calls it. DB wiring is in `Configurations/DatabaseConfig.cs`. |
| 3 | Swap SQL Server → SQLite | **Already done** for Development. `DatabaseConfig.cs` branches by environment and `Microsoft.EntityFrameworkCore.Sqlite 9.0.3` is already referenced. |
| 4 | Update the connection string in `appsettings.json` | There is no connection string in `appsettings.json`, only a `Logging` block. It has to be added, not edited. |
| 5 | "No `.cshtml` files remain" | Impossible as scoped. See below. |
| 6 | ".NET 9 only, a JsxCore hard requirement" | False. JsxCore ships `net8.0`, `net9.0`, `net10.0`. The net9 requirement comes from *Equinox*. |
| 7 | "JsxCore manages TypeScript + esbuild internally" | Half right. It renders with **Preact** by default (React is opt-in), and it restores npm packages by talking to the registry directly, so CI needs egress to `registry.npmjs.org`. |
| 8 | Phase 4 lists 7 views to convert | Misses `Home/Privacy`, `Shared/Error`, three partials, and a ViewComponent. |

## The contradiction that would have blocked completion

The spec required *"no `.cshtml` files remain"* while also forbidding changes outside
the presentation layer. Those cannot both hold.

Actual inventory, 22 `.cshtml` files:

```
  7  Areas/Identity/Pages/**          ← ASP.NET Identity Razor Pages
  5  Views/Customer/
  5  Views/Shared/                    ← _Layout, _LoginPartial, _ValidationScripts,
                                         _CookieConsent, Error
  2  Views/Home/                      ← Index, Privacy
  2  Views/                           ← _ViewImports, _ViewStart
  1  Views/Shared/Components/Summary/ ← a ViewComponent
```

`Program.cs` calls `app.MapRazorPages()` and the project references
`Microsoft.AspNetCore.Identity.UI`. Deleting the Identity pages breaks login, and
Identity is wired through `Equinox.Infra.CrossCutting.Identity`, a layer the
constraints declare off-limits.

An automated loop chasing this criterion could never terminate green. It would spend
its entire budget proving an impossibility.

## Environment gaps found on the machine

| Blocker | Status |
|---|---|
| .NET 9 SDK | ❌ Only 8.0.129. Equinox targets `net9.0`, so step one fails immediately. |
| Azure CLI | ❌ Not installed (available for el10, see below) |
| `dotnet ef` | ❌ Not installed |
| Browser automation | ❌ None, so no way to verify "CRUD works in the browser" |
| `gh` auth | ✅ authed, `repo` + `workflow` scopes |
| nuget / github reachable | ✅ |

Also: **Node v24 and npm 11 are installed on this machine.** A build here would succeed
whether or not JsxCore secretly needed them, so the "no Node required" claim is
*unverifiable in this environment*. It needs a Node-free container to test honestly.

Host OS is Rocky Linux 10.2 (`platform:el10`). The commonly-cited Azure CLI install
path (`packages.microsoft.com/yumrepos/azure-cli-el{8,9,10}`) 404s for every version,
Microsoft consolidated into `rhel/N/prod`. `azure-cli-2.89.0-1.el10.x86_64` exists there.
.NET 9 is in Rocky's own appstream (`dotnet-sdk-9.0`, 9.0.119).

## Risks the spec didn't mention

- **JsxCore is v1.0.0 with 281 total downloads.** The project's single largest technical
  dependency, treated as settled.
- **Azure F1 has a 60 CPU-minute/day quota and no Always On.** JsxCore renders server-side
  via **Jint**, a JavaScript interpreter written in C#, which is CPU-expensive. Quota exhaustion
  puts the app in a 403 state until midnight UTC, i.e. exactly when a post is getting clicks.
- **SQLite on ephemeral container storage** resets on every restart and redeploy.
- **Phases 7.1 and 7.3 are GUI click-paths** (Azure Portal → Deployment Center, download
  publish profile). An autonomous loop cannot perform them.
- **`dotnet publish --no-build` after `dotnet build`**, a known breakage pattern, riskier
  with JsxCore's build-time TypeScript compilation.

## Why the plan wasn't a loop yet

It was a checklist. Four things were missing:

1. **An oracle.** Six of nine success criteria had no machine-checkable form. Without a
   script emitting pass/fail, an agent grades its own homework, and reliably reports success.
2. **A termination condition.** *"If a step fails, diagnose and fix, do not skip"* is
   unbounded. On this machine, step 1.3 fails forever until .NET 9 is installed.
3. **Persistent state.** Nothing carried across iterations, so iteration N repeats
   iteration N−1's failure.
4. **Rollback.** Phase 4 deletes each `.cshtml` immediately after writing its `.tsx`, but
   nothing commits until Phase 5. If JsxCore can't do layouts, the working baseline is gone.

## What this cost, and what it saved

About twenty minutes of checking. Without it, the first destructive change would have
landed on a folder that doesn't exist, after "fixing" a database that was already
converted, chasing a criterion that cannot be satisfied.

None of the eight errors required .NET knowledge to find. They required checking the
claims against the repo before acting on them.
