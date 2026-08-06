# Chapter 3 — The baseline nobody had verified

*2026-08-05. Unmodified Equinox, .NET 9 container, before any migration work.*

The spec's Phase 1.3 and 1.4 say "verify `dotnet build` passes" and "verify `dotnet run`
serves the app." Those were the only two steps in the entire plan that were supposed to
be free. Running them turned up four things.

---

## 1. It builds — but not to the spec's standard

```
Build succeeded.
    16 Warning(s)
    0 Error(s)
Time Elapsed 00:00:33.62
```

All 16 are the same warning:

```
warning NU1903: Package 'System.Security.Cryptography.Xml' 9.0.3 has a known
high severity vulnerability
https://github.com/advisories/GHSA-w3x6-4m5h-cxqf
```

The spec's success criterion is *"`dotnet build` passes with 0 errors and 0 warnings."*
**Unmodified, untouched Equinox does not meet it** — and the only way to reach zero is to
upgrade a transitive dependency or suppress the warning, neither of which is view-engine work.

More importantly: this is a **high-severity vulnerability in something about to be deployed
publicly**. The spec never mentions it. Nine spec errors were about being wrong; this is
about not looking.

## 2. The database swap was already done

`appsettings.Development.json`:

```json
"ConnectionStrings": { "DefaultConnection": "Data Source=EquinoxProject.db" }
```

The app boots, `DbMigrationHelpers.EnsureSeedData()` runs, and `EquinoxProject.db` appears.
Phase 2 of the spec — four steps of SQL Server → SQLite migration — is **already complete
for Development**.

`appsettings.json` still has no connection string at all, so Production has nothing to
connect to. That's the real work Phase 2 should have described, and it's the one that
matters for deployment.

## 3. The routes are nothing like the spec assumes

`GET /Customer` → **404**.

`CustomerController` uses explicit attribute routes, not the conventional
`{controller}/{action}` pattern the default route registers:

| Action | Actual route |
|---|---|
| Index | `/customer-management/list-all` |
| Details | `/customer-management/customer-details/{id:guid}` |
| Create | `/customer-management/register-new` |
| Edit | `/customer-management/edit-customer/{id:guid}` |
| Delete | `/customer-management/remove-customer/{id:guid}` |
| History | `/customer-management/customer-history/{id:guid}` |

Any verification script written from the spec would have tested `/Customer/Index` and
`/Customer/Create`, gotten 404s, and reported the migration broken when nothing was wrong.

## 4. Half of CRUD requires authentication

`CustomerController` is `[Authorize]` at the class level, with `[AllowAnonymous]` on
three actions:

| Operation | Anonymous? |
|---|---|
| Index / list | ✅ yes |
| Details | ✅ yes |
| History | ✅ yes |
| **Create** | ❌ 302 → `/Identity/Account/Login` |
| **Edit** | ❌ requires login |
| **Delete** | ❌ requires login |

Verified live:

```
/customer-management/list-all       HTTP 200
/customer-management/register-new   HTTP 302 -> /Identity/Account/Login?ReturnUrl=...
/Identity/Account/Login             HTTP 200
/Identity/Account/Register          HTTP 200
```

The spec's criterion — *"Customer CRUD works end-to-end in the browser"* — silently
requires a registered, logged-in user. Nothing in the plan mentions authentication.

### Two knock-on effects

**The CRUD oracle just got harder.** It can't simply POST a form. It has to register a
user, log in, carry the auth cookie *and* the antiforgery token through create → edit →
delete. That's the single most complex piece of the verification script, and the spec
treats it as a checkbox.

**The Identity Razor Pages are on the critical path.** Decision D2 kept them on Razor
because rewriting authentication in an unproven view engine was too risky. That now looks
less like a concession and more like the only workable choice: those pages are required to
exercise the feature being demonstrated. Deleting them, as the original criterion demanded,
would have made the success criterion untestable.

**And it fixes a problem I'd expected to have.** Earlier the plan assumed public
unauthenticated CRUD, with the risk that a demo link would get filled with junk by visitor
#50. It turns out anonymous users can read but not write. The abuse surface is much smaller
than assumed — writes need an account.

---

## One self-inflicted wound, for honesty

The first build attempt failed with 10 × `NETSDK1064: Package Microsoft.CodeAnalysis.Analyzers,
version 3.3.4 was not found`. Nothing to do with Equinox: `restore` and `build` ran in two
separate `podman run --rm` invocations, so the second container started with an empty NuGet
cache.

Fixed with a persistent volume, which also makes every subsequent build faster:

```bash
podman volume create nuget-cache
podman run -v nuget-cache:/root/.nuget/packages ...
```

Worth recording because the error message points confidently at a missing package and says
nothing about containers. An automated loop would very plausibly have "fixed" this by
pinning package versions or editing csproj files — chasing a phantom.

---

## Score so far

Ten claims in the original spec have now been falsified, and the two steps meant to be
free produced four findings. The migration hasn't started.
