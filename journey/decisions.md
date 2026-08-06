# Decision log

Calls made, what was ambiguous, what was chosen, and what was traded away.

This file is deliberately separate from the run log. The run log records *"agent hit an
error, agent fixed it"* — low signal. This records decisions, which is the actual content.

---

## D1 — Review the spec before executing it
**2026-08-05**

**Ambiguity:** The plan read as authoritative and had an explicit "execute step by step"
instruction. Tempting to just start.

**Chose:** Verify every load-bearing claim against the real repos, packages, and machine first.

**Why:** A plan written without reading the target repo can be confidently wrong, and the
first destructive step (deleting `.cshtml` files) is unrecoverable without commits.

**Result:** Eight wrong claims found, including one impossible success criterion. See
`artifacts/00-spec-review.md`.

**Traded:** ~20 minutes before any code was written.

---

## D2 — Razor and JsxCore coexist; rewrite the impossible criterion
**2026-08-05**

**Ambiguity:** Spec required *"no `.cshtml` files remain"* AND *"do not modify the
infrastructure layer."* ASP.NET Identity ships 7 Razor Pages wired through
`Equinox.Infra.CrossCutting.Identity`. Both constraints cannot hold.

**Chose:** Keep Identity on Razor. Rewrite the criterion to **"no `.cshtml` under
`Views/`"**.

**Why:** Identity is not the thing being demonstrated. Rewriting it in TSX means
reimplementing authentication in an unproven view engine — high risk, zero relevance to
the point. Mixed view engines in one app is also a more realistic migration story than a
big-bang rewrite.

**Traded:** The clean "zero Razor" headline. Gained a criterion that can actually be
satisfied, so the loop can terminate.

---

## D3 — The demo database is disposable
**2026-08-05**

**Ambiguity:** SQLite on any container platform is fragile — ephemeral filesystems on
Azure F1/Container Apps, node-bound volumes on Bunny that can return empty.

**Chose:** Seed on startup, let data reset, and say so in the UI:
*"Demo resets periodically — running on free-tier infrastructure."*

**Why:** Equinox already ships `DbMigrationHelpers.EnsureSeedData()` wired into
`Program.cs`, so this is nearly free. It also removes an entire class of hosting
constraints from the decision. Naming a limitation in the UI turns a defect into evidence
the tier was understood.

**Traded:** Persistent user-created records. Public unauthenticated CRUD would have been
filled with garbage by visitor #50 regardless.

---

## D4 — Host on Bunny.net Magic Containers
**2026-08-05**

**Ambiguity:** Original spec said Azure App Service F1. F1 turned out to have a 60
CPU-minute/day quota and no Always On — a public demo link would eventually land on a
cold start or a 403.

**Options considered:**

| | Cost/mo | Warm? | SQLite |
|---|---|---|---|
| Azure F1 | $0 | ❌ quota cliff | ❌ |
| Azure Container Apps | ~$4–9 | ✅ idle rate | ⚠️ needs Azure Files |
| Azure B1 | $13.14 | ✅ | ✅ `/home` persists |
| Railway | $5 floor (free tier removed 2023) | ✅ | ✅ volumes |
| Fly.io | ~$3–6 | ✅ auto stop/start | ✅ volumes |
| Render | free | ❌ 60s cold start | ❌ paid only |
| **Bunny Magic Containers** | **~$7.60–13** | ✅ | ⚠️ volumes can return empty |

**Chose:** Bunny Magic Containers, region-pinned, 1 replica.

**Why:** Not the cheapest and not the safest — chosen because it's off the beaten path,
and the thesis is problem-solving under low domain knowledge rather than optimal
infrastructure selection. A well-trodden Azure path has fewer problems in it, which makes
it worse material. Bunny's deploy API is also the right shape for the loop: build image →
push → roll app to a new SHA. Idempotent, retry-safe, rollback is the same call with the
previous tag.

**Known caveats, accepted:**
- Persistent volumes are public preview; no automatic backups or replication
- Volumes bind to nodes — a reschedule may hand back an empty disk (mitigated by D3)
- $2/mo fixed Anycast IP makes small deployments proportionally expensive
- Region pinning disables the platform's main value prop (global edge distribution)

**Traded:** The Azure credential, which reads as the expected default to a .NET hiring
audience. Accepted deliberately.

---

## D5 — Container first, deploy second
**2026-08-05**

**Ambiguity:** Whether to deploy early and iterate against the live host, or get it
working locally first.

**Chose:** Build and run the Node-free container locally before touching Bunny.

**Why:** Two immature dependencies are now in the stack — JsxCore v1.0.0 (281 downloads)
and Bunny's preview volumes. If both are introduced at once, every failure has multiple
plausible causes and there's no way to isolate. If the image works locally, any Bunny
failure is *by construction* a Bunny failure.

The container is also required regardless: Node v24 and npm are installed on this machine,
so the "no npm required" claim cannot be honestly tested here. A Node-free image is the
only way to verify it.

**Traded:** Nothing. Same work, different order.

---

## D6 — Spike JsxCore before migrating anything
**2026-08-05**

**Ambiguity:** The entire project assumes JsxCore can do things nobody has verified —
it's a v1.0.0 package with 281 total downloads.

**Chose:** Prove three things in a throwaway `net9.0` project first:
1. A shared layout works (layouts are a Razor concept; JsxCore registers as an `IViewEngine`)
2. A form POST with `[ValidateAntiForgeryToken]` works
3. A ViewComponent works (`Views/Shared/Components/Summary` exists in Equinox)

**Why:** All three are load-bearing and unverified. If layouts don't work, the migration
plan changes shape entirely — better to learn that in a throwaway project than halfway
through converting a real app with the originals already deleted.

**Traded:** ~30 minutes before real work starts. The spike doubles as standalone content:
it's the cleanest possible demonstration that adding JsxCore needs almost no .NET knowledge.

**Outcome:** 3 of 4 verified. ViewComponents are broken in 1.0.0 — the model never
reaches the view. See `artifacts/02-spike-four-unknowns.md`. Decision D6 paid for itself.

---

## D7 — Re-express the ViewComponent as a .NET global
**2026-08-05**

**Ambiguity:** Equinox has `Views/Shared/Components/Summary`. JsxCore resolves
ViewComponent views to `.tsx` but never passes the model, and wraps output in a full
HTML document rather than a fragment. So it cannot be converted as-is.

**Options:**
1. Fold the summary data into the parent ViewModel — **requires modifying `Controllers/`,
   which the constraints forbid**
2. Keep `Default.cshtml` as Razor and let JsxCore handle everything else
3. Register the data source as a .NET global and call it from the TSX view

**Chose:** Option 3.

**Why:** It's the only one that both respects the do-not-modify-controllers constraint
*and* removes the Razor dependency. It also reuses the exact mechanism that already
solved antiforgery, so the migration has one escape hatch instead of two special cases.

**Traded:** The view now reaches into a service directly rather than receiving everything
through its model — arguably worse separation than MVC intends. Accepted, because the
alternative is modifying a layer that's declared off-limits.

---

## D8 — Every converted view gets `"use server"`
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
