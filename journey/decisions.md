# Decision log

Calls made, what was ambiguous, what was chosen, and what was traded away.

This file is deliberately separate from the run log. The run log records *"agent hit an
error, agent fixed it"*, which is low signal. This records decisions, the actual content.

---

## D1: Review the spec before executing it
**2026-08-05**

**Ambiguity:** The plan read as authoritative and had an explicit "execute step by step"
instruction. Tempting to just start.

**Chose:** Verify every load-bearing claim against the real repos, packages, and machine first.

**Why:** A plan written without reading the target repo can be confidently wrong, and the
first destructive step (deleting `.cshtml` files) is unrecoverable without commits.

**Result:** Eight wrong claims found, including one impossible success criterion. See
`chapters/00-spec-review.md`.

**Traded:** ~20 minutes before any code was written.

---

## D2: Razor and JsxCore coexist; rewrite the impossible criterion
**2026-08-05**

**Ambiguity:** Spec required *"no `.cshtml` files remain"* AND *"do not modify the
infrastructure layer."* ASP.NET Identity ships 7 Razor Pages wired through
`Equinox.Infra.CrossCutting.Identity`. Both constraints cannot hold.

**Chose:** Keep Identity on Razor. Rewrite the criterion to **"no `.cshtml` under
`Views/`"**.

**Why:** Identity is not the thing being demonstrated. Rewriting it in TSX means
reimplementing authentication in an unproven view engine, which is high risk and zero relevance to
the point. Mixed view engines in one app is also a more realistic migration story than a
big-bang rewrite.

**Traded:** The clean "zero Razor" headline. Gained a criterion that can actually be
satisfied, so the loop can terminate.

---

## D3: The demo database is disposable
**2026-08-05**

**Ambiguity:** SQLite on any container platform is fragile, because ephemeral filesystems on
Azure F1/Container Apps, node-bound volumes on Bunny that can return empty.

**Chose:** Seed on startup, let data reset, and say so in the UI:
*"Demo resets periodically, running on free-tier infrastructure."*

**Why:** Equinox already ships `DbMigrationHelpers.EnsureSeedData()` wired into
`Program.cs`, so this is nearly free. It also removes an entire class of hosting
constraints from the decision. Naming a limitation in the UI turns a defect into evidence
the tier was understood.

**Traded:** Persistent user-created records. Public unauthenticated CRUD would have been
filled with garbage by visitor #50 regardless.

---

## D4: Host on Bunny.net Magic Containers
**2026-08-05**

**Ambiguity:** Original spec said Azure App Service F1. F1 turned out to have a 60
CPU-minute/day quota and no Always On, so a public demo link would eventually land on a
cold start or a 403.

**Options considered:**

| | Cost/mo | Warm? | SQLite |
|---|---|---|---|
| Azure F1 | $0 | ❌ quota cliff | ❌ |
| Azure Container Apps | ~$4-9 | ✅ idle rate | ⚠️ needs Azure Files |
| Azure B1 | $13.14 | ✅ | ✅ `/home` persists |
| Railway | $5 floor (free tier removed 2023) | ✅ | ✅ volumes |
| Fly.io | ~$3-6 | ✅ auto stop/start | ✅ volumes |
| Render | free | ❌ 60s cold start | ❌ paid only |
| **Bunny Magic Containers** | **~$7.60-13** | ✅ | ⚠️ volumes can return empty |

**Chose:** Bunny Magic Containers, region-pinned, 1 replica.

**Why:** Not the cheapest and not the safest. Chosen because it's off the beaten path,
and the thesis is problem-solving under low domain knowledge rather than optimal
infrastructure selection. A well-trodden Azure path has fewer problems in it, which makes
it worse material. Bunny's deploy API is also the right shape for the loop: build image →
push → roll app to a new SHA. Idempotent, retry-safe, rollback is the same call with the
previous tag.

**Known caveats, accepted:**
- Persistent volumes are public preview; no automatic backups or replication
- Volumes bind to nodes, so a reschedule may hand back an empty disk (mitigated by D3)
- $2/mo fixed Anycast IP makes small deployments proportionally expensive
- Region pinning disables the platform's main value prop (global edge distribution)

**Traded:** The Azure credential, which reads as the expected default to a .NET hiring
audience. Accepted deliberately.

---

## D5: Container first, deploy second
**2026-08-05**

**Ambiguity:** Whether to deploy early and iterate against the live host, or get it
working locally first.

**Chose:** Build and run the Node-free container locally before touching Bunny.

**Why:** Two immature dependencies are now in the stack: JsxCore v1.0.0 (281 downloads)
and Bunny's preview volumes. If both are introduced at once, every failure has multiple
plausible causes and there's no way to isolate. If the image works locally, any Bunny
failure is *by construction* a Bunny failure.

The container is also required regardless: Node v24 and npm are installed on this machine,
so the "no npm required" claim cannot be honestly tested here. A Node-free image is the
only way to verify it.

**Traded:** Nothing. Same work, different order.

---

## D6: Spike JsxCore before migrating anything
**2026-08-05**

**Ambiguity:** The entire project assumes JsxCore can do things nobody has verified.
it's a v1.0.0 package with 281 total downloads.

**Chose:** Prove three things in a throwaway `net9.0` project first:
1. A shared layout works (layouts are a Razor concept; JsxCore registers as an `IViewEngine`)
2. A form POST with `[ValidateAntiForgeryToken]` works
3. A ViewComponent works (`Views/Shared/Components/Summary` exists in Equinox)

**Why:** All three are load-bearing and unverified. If layouts don't work, the migration
plan changes shape entirely, and it is better to learn that in a throwaway project than halfway
through converting a real app with the originals already deleted.

**Traded:** ~30 minutes before real work starts. The spike doubles as standalone content:
it's the cleanest possible demonstration that adding JsxCore needs almost no .NET knowledge.

**Outcome:** 3 of 4 verified: server rendering, layouts (as components, not `_Layout`),
and antiforgery (via globals, undocumented). The fourth, ViewComponents, I initially
reported as broken; that was my own casing bug and is corrected in D7 and
`chapters/02-spike-four-unknowns.md`.

D6 still paid for itself: it found that JsxCore has **no layout mechanism at all**, which
invalidated the spec's view-conversion ordering before a single file was deleted.

---

## D7: Re-express the ViewComponent as a .NET global
**2026-08-05** · *reasoning corrected 2026-08-06*

> **Correction.** This decision was originally justified by "JsxCore never passes the
> ViewComponent's model." That was wrong. Models are serialised to **camelCase**, and the
> spike read `model.Count` instead of `model.count`. ViewComponents work.
>
> The decision stands, for different reasons: `<vc:summary />` is a Razor tag helper with
> no TSX equivalent, and Equinox's `Summary` takes no model at all, since it reads
> `ViewData.ModelState` and `ViewBag.Sucesso`, which a TSX view cannot reach. The
> full-document wrapping also still makes it unusable *embedded* in a page, which is
> exactly how Equinox uses it.
>
> See the correction in `chapters/02-spike-four-unknowns.md`.

**Ambiguity:** Equinox has `Views/Shared/Components/Summary`, embedded as `<vc:summary />`
inside Create, Edit and Delete. TSX views cannot invoke ViewComponents, and this one needs
`ModelState` and `ViewBag` rather than a model.

**Options:**
1. Fold the summary data into the parent ViewModel, which **requires modifying `Controllers/`,
   which the constraints forbid**
2. Keep `Default.cshtml` as Razor and let JsxCore handle everything else
3. Register the data source as a .NET global and call it from the TSX view

**Chose:** Option 3.

**Why:** It's the only one that both respects the do-not-modify-controllers constraint
*and* removes the Razor dependency. It also reuses the exact mechanism that already
solved antiforgery, so the migration has one escape hatch instead of two special cases.

**Traded:** The view now reaches into a service directly rather than receiving everything
through its model, arguably worse separation than MVC intends. Accepted, because the
alternative is modifying a layer that's declared off-limits.

---

## D8: Every converted view gets `"use server"`
**2026-08-05**

**Ambiguity:** JsxCore's default render mode is `Client`, which ships an empty root div
and hydrates in the browser.

**Chose:** `"use server"` as the first statement of every converted Equinox view.

**Why:** Equinox is a server-rendered MVC app. Client mode means no first paint without
JS and nothing for crawlers. It's also mandatory for any view using a .NET global, which
after D7 includes both the forms and the summary.

**Why this needs to be a written rule:** forgetting the directive doesn't error. The page
looks correct in a browser and is blank to everything else. It's the highest-risk silent
failure found so far, so it belongs in the verify script, not in someone's memory.

---

## D9: Repo-local git identity, not global
**2026-08-05**

**Ambiguity:** This machine has four GitHub accounts authenticated in `gh` (`dealfone`,
`StrongStool0954`, `dealfone-jl`, `jloor`) and a global git config committing as
`StrongStool0954`. The project needs to publish as `jloor`.

**Chose:** Set `user.name`, `user.email`, `user.signingkey`, and `core.sshCommand`
**repo-local**. Global config untouched.

**Why:** The global identity is used by every other project on this machine. Repointing it
to publish one repo would silently re-attribute unrelated work.

**Email:** `30563101+jloor@users.noreply.github.com` rather than a real address. GitHub
attributes commits by email, so this gets correct attribution *and* keeps a personal
address off a repo that is public by design.

**Verified end-to-end before doing any real work.** The first commit reported
`GitHub verified: True, reason: valid, attributed to: jloor`. Worth doing on commit #1
rather than discovering it at commit #40.

### Two traps hit on the way

**1. SSH failed despite the key being correct.** `git clone` returned
`Permission denied (publickey)` while `ssh -T git@github.com` returned
`Hi jloor! You've successfully authenticated`. Cause: the 1Password agent holds **19 keys**,
and SSH exhausts `MaxAuthTries` before reaching the right one. There was also a
`1Password agent refused operation` on an unrelated key mid-negotiation.

Fixed without touching the global SSH config:

```bash
git config core.sshCommand 'ssh -o IdentitiesOnly=yes -i ~/.ssh/jloor_github.pub'
```

**2. `.gitignore` silently swallowed the entire project writeup.** The documentation was
being written to `journey/artifacts/`. Equinox ships the standard .NET `.gitignore`, whose
line 45 is `artifacts/`, meant for build output. `git add` reported success and staged
nothing; only `git check-ignore -v` revealed it.

Renamed to `journey/chapters/`. Fighting the ignore file with a negation would have worked
but left a trap for anyone reading the repo later.

**Worth noting:** this would have destroyed the deliverable silently. The code would have
been fine and every word of the writeup would have been absent from the public repo. The
one part of this project that can't be reconstructed afterwards.

---

## D10: Signing verification is local too
**2026-08-05**

**Ambiguity:** After the first signed commit, `git log --format=%G?` reported `N` (no
signature) and errored with `gpg.ssh.allowedSignersFile needs to be configured`.

**Chose:** Configure `~/.ssh/allowed_signers` rather than assume signing was broken.

**Why:** The commit object *did* contain a `gpgsig` header, so the signature existed. `N`
meant "cannot verify locally," not "not signed." Two different failures that look identical
if you only read the status letter.

This matters for the loop: an automated check reading `%G?` would have reported unsigned
commits and "fixed" a problem that didn't exist. The oracle has to distinguish
*absent signature* from *unverifiable locally*.

---

## D11: Patch the vulnerable crypto chain, breaking a stated constraint
**2026-08-06**

**Ambiguity:** The baseline build emitted 16 `NU1903` warnings, **8 distinct
high-severity advisories** against `System.Security.Cryptography.Xml` 9.0.3, including
CVE-2026-26171 (.NET Denial of Service). It is a *direct* `PackageReference` in
`Equinox.Infra.Data`.

The constraints say *"Do NOT modify the domain layer, application layer, or infrastructure
layer."* `Equinox.Infra.Data` **is** the infrastructure layer. So the rules forbid patching
known high-severity vulnerabilities in an app being deployed to the public internet.

The spec also demanded *"0 errors and 0 warnings"*, unreachable without the fix. Two of
its own rules in direct conflict.

**Chose:** Bump the chain to 9.0.18. Explicit, documented deviation from the constraint.

**Why:** The constraint exists to stop the migration turning into a rewrite of layers that
aren't being demonstrated. A dependency version bump isn't that. No logic changed, no
types moved, no behaviour altered. Publishing a demo with 8 known high-severity advisories,
then linking it from a post about engineering practice, is a materially worse outcome than
a one-line deviation that gets written down.

**What it actually took**, not one bump but three, discovered by failing:

```
NU1605: Detected package downgrade: System.Security.Cryptography.Pkcs from 9.0.18 to 9.0.3
  Equinox.Infra.Data -> System.Security.Cryptography.Xml 9.0.18 -> Pkcs (>= 9.0.18)
  Equinox.Infra.Data -> System.Security.Cryptography.Pkcs (>= 9.0.3)
```

`Xml` 9.0.18 requires `Pkcs` >= 9.0.18, which requires `System.Formats.Asn1`. All three are
pinned directly in the csproj, so all three had to move together. The project treats
NU1605 as an error, so this failed the restore rather than warning.

**Result:** `0 Warning(s), 0 Error(s)`. The oracle's `BASELINE_WARNINGS` moved from 16 to 0,
so the spec's original criterion is now asserted as written instead of as a concession,
and any new warning fails the build rather than hiding in the noise.

**Traded:** Strict constraint compliance, deliberately and on the record.

---

## D12: Three Razor files stay, by name
**2026-08-06**

**Ambiguity:** D2 said "Identity Razor Pages stay." But those pages drag Razor
infrastructure out of `Views/Shared/` with them, and the oracle's
`no-cshtml-in-views` check had to decide what counts as unconverted work.

**Chose:** An exact allowlist rather than ignoring `Shared/`:

| File | Required by |
|---|---|
| `_Layout.cshtml` | `Areas/Identity/Pages/_ViewStart.cshtml` names it by path: `Layout = "/Views/Shared/_Layout.cshtml"` |
| `_LoginPartial.cshtml` | `<partial name="_LoginPartial" />` inside `_Layout.cshtml` |
| `_ValidationScriptsPartial.cshtml` | `<partial ... />` in Login.cshtml and Register.cshtml |
| `_ViewImports` / `_ViewStart` | Razor infrastructure |

**Why exact:** ignoring `Shared/` wholesale would have let genuinely unconverted views
hide there. The allowlist is five names; anything else under `Views/` fails the build.

**Consequence:** the site now has **two parallel layouts**: `Shared/_Layout.cshtml` for
Identity's Razor pages, `Shared/Layout.tsx` for everything else. They render the same
chrome, and they will drift. That is the real cost of coexistence and it should be stated
plainly rather than discovered later.

### Deleted as genuinely dead

- `Shared/Components/Summary/Default.cshtml`, whose only callers were the Customer views,
  now TSX. Orphaned by the migration.
- `Shared/_CookieConsentPartial.cshtml`, referenced by nothing. Already dead before this
  project started.

### Converted but unreachable

`Home/Privacy.cshtml` → `Privacy.tsx`. **`HomeController` has no `Privacy` action**, so the
view was dead code in upstream Equinox and no route reaches it. Converted for parity and
kept rather than silently deleting shipped content, but it renders nowhere.

Worth noting because a checklist that says "convert every view" will happily spend time on
views the application cannot reach. Nothing in the original spec distinguished live views
from dead ones.

---

## D13: Provider is configuration, in both places
**2026-08-06**

**Ambiguity:** Upstream inferred the database provider from the environment name,
SQLite under `IsDevelopment()` and SQL Server otherwise, in **two** files:

- `Equinox.UI.Web/Configurations/DatabaseConfig.cs` (presentation layer)
- `Equinox.Infra.CrossCutting.Identity/Configuration/AspNetIdentityConfig.cs` (**infrastructure**)

`appsettings.json` carries no connection string at all, so any non-Development deployment
had nothing to connect to. Free-tier container hosting has no SQL Server.

**Chose:** An explicit `"DatabaseProvider"` setting, defaulting to `Sqlite`, in both files.
`"SqlServer"` restores the old behaviour.

**Why this is a second constraint break:** `AspNetIdentityConfig.cs` is the infrastructure
layer, which the constraints protect. Same reasoning as D11, since no logic changed and
only how a provider is selected, but unlike D11 this one was **not optional**. Without it there is no
deploy at all.

**How it failed, which is the interesting part:** fixing only `DatabaseConfig` left the
Identity context on SQL Server while the other two ran SQLite. The crash message was:

```
PendingModelChangesWarning: The model for context 'EquinoxIdentityContext'
has pending changes. Add a new migration before updating the database.
```

That points squarely at migrations. The actual cause was a provider mismatch two layers
away. A loop told to "diagnose and fix before moving on" would very plausibly have spent
its budget generating EF migrations that were never needed.

---

## D14: Register external auth only when configured
**2026-08-06**

**Ambiguity:** With the database finally working, every request returned HTTP 500:

```
System.ArgumentNullException: Value cannot be null. (Parameter 'AppId')
   at Microsoft.AspNetCore.Authentication.Facebook.FacebookOptions.Validate()
```

`AddSocialAuthenticationSupport` registered Facebook and Google unconditionally, reading
credentials that exist only in `appsettings.Development.json`, as the literal placeholders
`"SetYourDataHere"`.

**Chose:** Register each provider only when its credentials are non-empty.

**Why not just set dummy env vars:** that would put non-functional "Log in with Facebook"
buttons on a public demo. Conditional registration is also just correct, because an app should not
hard-fail because an optional feature is unconfigured.

**The failure mode is worth recording.** External auth options are validated **lazily, on
first use**, not at startup. So the app:

1. started cleanly
2. logged `Application started` and `Now listening on: http://*:8080`
3. reported healthy
4. threw on every single request, including inside the error handler, which then also
   threw

Startup logs were completely clean. Any health check based on "did the process start" or
"is the port open" would have reported success. Only an actual HTTP request revealed it,
which is precisely why the oracle fetches real pages instead of checking liveness.

### Two smaller container traps, same session

**A stale `HTTP 200` from someone else's service.** The first container run bound `-p 8080`,
which was already taken on this host. The container never started, and `curl localhost:8080`
cheerfully returned `200` and a page titled *"ReadMe Theme Forge"*, an unrelated app.
A verification script checking only the status code would have passed against the wrong
service entirely.

**IPv4-only bind.** `ASPNETCORE_URLS=http://0.0.0.0:8080` binds IPv4 only. `curl localhost`
resolves to `::1` first, the port forwarder accepts the connection, and nothing ever answers
`HTTP 000`, indistinguishable from a hung application. `http://*:8080` binds both.
