# Chapter 6 — The part that actually resisted

*2026-08-06. Everything up to here was view conversion. This is where it fought back.*

The migration was green in development. Containerising it took three separate failures,
none mentioned anywhere in the original plan, and each one looked like something other
than what it was.

## The Dockerfile that shipped was three majors stale

`src/Equinox.UI.Web/Dockerfile`, from upstream:

```dockerfile
FROM mcr.microsoft.com/dotnet/aspnet:6.0 AS base
FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build
```

For a project targeting `net9.0`. It cannot build this codebase. The plan's deployment
phase never mentioned a Dockerfile at all — it assumed `dotnet publish` to Azure App
Service, so the one file that would have been the starting point was invisible to it.

---

## Failure 1: a provider inferred from an environment name, in two places

Upstream picked the database provider by asking what environment it was in — SQLite under
`IsDevelopment()`, SQL Server otherwise. `appsettings.json` has no connection string at
all, so any non-Development deployment had nothing to connect to.

I fixed `DatabaseConfig.cs`, rebuilt, and got:

```
PendingModelChangesWarning: The model for context 'EquinoxIdentityContext'
has pending changes. Add a new migration before updating the database.
```

That message is about migrations. The cause was not migrations. The **same
environment-name branch existed a second time**, in
`Equinox.Infra.CrossCutting.Identity/Configuration/AspNetIdentityConfig.cs`, so the
Identity context was still on SQL Server while the other two ran SQLite.

An agent instructed to "diagnose and fix before moving on" would have read that error and
started generating EF migrations. They would not have helped, and each one would have
looked like progress.

## Failure 2: seeding gated on the environment name too

`DbMigrationHelpers`:

```csharp
if (env.IsDevelopment() || env.IsEnvironment("Docker"))
{
    await context.Database.MigrateAsync();
    ...
}
```

Under `Production`, nothing creates the schema. Equinox anticipated containers with a
`Docker` environment name, so the fix was to use the codebase's own convention rather than
patch the helper — `ASPNETCORE_ENVIRONMENT=Docker` in the image.

## Failure 3: a clean startup that 500s on every request

Database working, container up, logs perfect:

```
Now listening on: http://*:8080
Application started. Press Ctrl+C to shut down.
Hosting environment: Docker
```

Every request returned 500:

```
System.ArgumentNullException: Value cannot be null. (Parameter 'AppId')
   at Microsoft.AspNetCore.Authentication.Facebook.FacebookOptions.Validate()
```

`AddSocialAuthenticationSupport` registered Facebook and Google unconditionally, reading
credentials that only ever existed in `appsettings.Development.json` — as the literal
placeholder string `"SetYourDataHere"`. Their options validate **lazily, on first use**,
so nothing failed at startup. It failed inside the error handler too, so even the error
page 500'd.

**A health check based on "process started" or "port open" reports success here.** That is
the entire argument for an oracle that fetches real pages.

---

## Two traps that had nothing to do with .NET

**A `200` from a completely different application.** The first container run bound
`-p 8080`, already taken on this host. The container never started. `curl localhost:8080`
returned `200` and a page titled *"ReadMe Theme Forge"*. A check asserting only on status
code would have passed against someone else's service.

The smoke test now binds `18080` and asserts on page *content*, not just the code.

**An IPv4-only bind that looks like a hang.** `ASPNETCORE_URLS=http://0.0.0.0:8080` binds
IPv4 only. `curl localhost` resolves `::1` first, the port forwarder accepts the
connection, and nothing ever answers — `HTTP 000`, indistinguishable from a deadlocked app.
`http://*:8080` binds both.

---

## What CI had to be shaped around

The GitHub `ubuntu-latest` runner ships **Node 22.23.1 and npm 10.9.8** preinstalled.

Running `dotnet build` directly on it would succeed whether or not JsxCore needed Node —
exactly the problem that made the claim untestable on my own machine. So every .NET step
in CI runs inside `scripts/Dockerfile.verify`, which hard-fails if `node` or `npm` are
present, and the workflow asserts it explicitly before doing anything else.

The upstream workflow also had to go: `actions/checkout@v2` and `setup-dotnet@v1` are both
deprecated and now fail, which would have put a permanent red X on a repo people reach from
a blog post. Its `dotnet test` step is folded into the new one — worth keeping, because
Equinox ships 7 architecture tests enforcing layer boundaries and this project deliberately
edited the infrastructure layer twice. They still pass.

## And the oracle had a false pass in it

The first version of the smoke test checked server rendering like this:

```bash
curl -s --max-file-size 2000000 "$BASE/" | grep -q '<div id="jsxcore-root"></div>'
```

`--max-file-size` is not a curl flag; it is `--max-filesize`. curl exited with an error,
grep received empty input, found no empty root div, and the check reported **PASS**.

A check that passes when its own fetch fails is worse than no check, because it is
counted. It now captures the body first and fails if it is empty.

---

## Result

```json
{"id":"container-responds","status":"PASS"}
{"id":"environment","status":"PASS","detail":"Docker (migrations + seeding enabled)"}
{"id":"home","status":"PASS"}
{"id":"customer-list","status":"PASS"}
{"id":"identity-login","status":"PASS"}
{"id":"identity-reg","status":"PASS"}
{"id":"server-rendered","status":"PASS","detail":"markup present in root div"}
{"id":"sqlite-on-volume","status":"PASS"}
{"id":"no-unhandled-exceptions","status":"PASS"}
```

CI green end to end: Node-free verification, 7 architecture tests, 15 development checks,
9 production smoke checks, image published to `ghcr.io` tagged with both the commit SHA and
`latest`.

Deploying by immutable SHA is deliberate — it makes the rollout idempotent and makes
rollback the same call with the previous tag, rather than hoping `:latest` points somewhere
sane.
