# Deploying to Bunny Magic Containers

The `deploy` job in `.github/workflows/ci.yml` is written and skipped. It starts running
by itself the moment `BUNNY_APP_ID` exists as a repository variable — no workflow edit
required. Until then the pipeline stays green rather than failing on a missing secret.

## What the pipeline already does

```
verify   →  Node-free image · no-node assertion · 7 architecture tests · 15 oracle checks
publish  →  build · 9 production smoke checks · push ghcr.io :sha and :latest
deploy   →  roll Bunny to :sha · poll the live URL until it serves seeded data   (skipped)
```

The image is already public and anonymously pullable, so Bunny needs no registry
credentials:

```
ghcr.io/jloor/equinox-jsxcore:latest
```

## Bunny app configuration

Create the app from the existing image. The settings that matter, and why:

| Setting | Value | Why |
|---|---|---|
| Image | `ghcr.io/jloor/equinox-jsxcore` | public; no registry auth needed |
| Container name | `app` | must match `BUNNY_CONTAINER_NAME` (defaults to `app`) |
| Port | `8080` | the image binds `http://*:8080` |
| Replicas | **1** | SQLite is single-writer; see below |
| Regions | **one** | same reason |
| Volume mount path | `/data` | the image writes `/data/equinox.db` |

### Replicas and regions must be 1 — and CI enforces it

This is the one setting that will silently corrupt the demo if it is wrong.

Bunny gives **each pod its own volume**. Their docs are explicit: for "databases and caches
that expect a single writable disk, run with 1 replica per volume, because running multiple
replicas of a stateful service could lead to state inconsistency."

With two replicas you get **two separate SQLite databases**. Nothing errors, nothing logs.
Users see different data depending on which pod answers, and it presents as "records
randomly disappearing."

Because these are dashboard settings — changeable by hand, at any time, by anyone with
access — they are checked in CI rather than trusted:

```
scripts/bunny-guard.sh <app-id>
```

```json
{"id":"replicas","status":"PASS","detail":"min=1 max=1 (single writer preserved)"}
{"id":"regions","status":"PASS","detail":"pinned to 1 region"}
{"id":"volume","status":"PASS","detail":"persistent volume mounted at /data"}
```

It runs **before** the rollout, so a misconfigured app is never deployed into. It reads:

| Endpoint | Asserts |
|---|---|
| `GET /apps/{id}/autoscaling` | min and max replicas are both `1` |
| `GET /apps/{id}/region-settings` | exactly one region enabled |
| `GET /apps/{id}/volumes` | a volume is mounted at `/data` |

Base URL `https://api.bunny.net/mc`, header `AccessKey: <api key>`.

It reports `UNKNOWN` and **exits non-zero** if it cannot read a value, rather than assuming
the default is fine. A check that passes because it could not read the setting is worse
than no check — that exact bug shipped in an earlier version of the smoke test.

Pinning to one region disables Bunny's main feature, global edge distribution. That was a
known and accepted trade (D4).

### Persistent storage: verified, and idempotent

The image writes `/data/equinox.db`, so a volume mounted at `/data` gives real persistence.
Tested by destroying the container and starting a new one against the same volume:

| | customers | users |
|---|---|---|
| Run 1, fresh volume | 1 | 1 |
| *container destroyed, volume kept* | | |
| Run 2, new container, same volume | **1** | **1** |

Data survived, and seeding did **not** duplicate — `DbMigrationHelpers` guards with
`if (context.Customers.Any()) return;`.

### The volume can still come back empty

Bunny volumes have no automatic backups or replication, bind to specific nodes, and may
return a **new empty volume** after a reschedule or hardware failure.

That is survivable by design (D3): an empty disk causes `EnsureSeedData()` to recreate and
reseed the schema on startup. The demo resets; it does not break. Combined with the
idempotence above, both states are handled — an existing database is left alone, an empty
one is rebuilt.

Say so in the UI rather than pretending otherwise.

## Repository variables and secrets

Settings → Secrets and variables → Actions.

**Variables** (not secret):

| Name | Example | Notes |
|---|---|---|
| `BUNNY_APP_ID` | `a1b2c3…` | **Setting this is what enables the deploy job** |
| `BUNNY_APP_URL` | `https://equinox-jsxcore.b-cdn.net` | no trailing slash; enables live verification |
| `BUNNY_CONTAINER_NAME` | `app` | only if the container is not named `app` |

**Secret:**

| Name | Where from |
|---|---|
| `BUNNY_API_KEY` | Bunny dashboard → Account Settings → API key. **Main account key only** — the action does not accept sub-user keys |

Set them from the CLI if you prefer:

```bash
gh variable set BUNNY_APP_ID   --repo jloor/equinox-jsxcore --body "<app id>"
gh variable set BUNNY_APP_URL  --repo jloor/equinox-jsxcore --body "https://<host>"
gh secret   set BUNNY_API_KEY  --repo jloor/equinox-jsxcore   # prompts, not echoed
```

## Two things to know before trusting a green deploy

**The Bunny API key is account-wide.** It is not scoped to one application, so this
repository's CI can reach every resource on the account. That is the action's constraint,
not a choice made here — worth knowing before putting it on a public repo's workflow.

**The action is pinned to `@main`.** That is what Bunny documents, and it is a mutable
reference: the code that runs in your pipeline can change without any commit in this repo.
Pin it to a commit SHA once a tagged release exists.

## Rollback

Deploys go out by immutable commit SHA, never `:latest`. Rolling back is the same
operation with an earlier SHA:

```bash
gh workflow run ci.yml --ref <previous-good-sha>
```

or set the image tag directly in the Bunny dashboard. Both are safe to repeat — the
rollout is idempotent.

## Custom domain: and why it was necessary, not cosmetic

Live at **https://equinox-jsxcore.jonathanloor.com**

The Bunny-assigned hostname `mc-5z62s7tghu.bunny.run` was **unreachable from the developer's
own network**:

```
$ curl https://mc-5z62s7tghu.bunny.run/
Connection refused

$ curl http://mc-5z62s7tghu.bunny.run/
HTTP 403   <title>Optimum Safe Browsing</title>

$ dig +short mc-5z62s7tghu.bunny.run
167.206.37.145      -> nomproxy-sia.vip.orbgny.alticeusa.net
```

The ISP (Optimum/Altice) intercepts the `.bunny.run` domain and answers with a
safe-browsing block page. Nothing was wrong with the deployment — CI reached it fine from
GitHub's runners — but it meant the person who built it could not open their own demo, and
any visitor on the same ISP would have seen a block page instead of the app.

**This is a good argument for verifying from more than one vantage point.** Local checks
said the site was dead; CI said it was live. CI was right.

Two hostnames were already available on the pull zone, and only one was blocked:

| Hostname | From this network |
|---|---|
| `mc-5z62s7tghu.bunny.run` | ❌ 403 safe-browsing block |
| `mc-5z62s7tghu.b-cdn.net` | ✅ 200 |
| `equinox-jsxcore.jonathanloor.com` | ✅ 200, valid TLS, ~72 ms |

### How it was set up

`jonathanloor.com` is on Bunny DNS, so everything went through the API.

```bash
# 1. attach the hostname to the app's pull zone (id from the app's endpoint)
curl -X POST -H "AccessKey: $BUNNY_API_KEY" -H "Content-Type: application/json" \
  -d '{"Hostname":"equinox-jsxcore.jonathanloor.com"}' \
  https://api.bunny.net/pullzone/6283227/addHostname          # -> 204

# 2. CNAME to the b-cdn.net hostname, NOT bunny.run
curl -X PUT -H "AccessKey: $BUNNY_API_KEY" -H "Content-Type: application/json" \
  -d '{"Type":2,"Name":"equinox-jsxcore","Value":"mc-5z62s7tghu.b-cdn.net","Ttl":300}' \
  https://api.bunny.net/dnszone/339995/records                # -> 201

# 3. free Let's Encrypt certificate
curl -H "AccessKey: $BUNNY_API_KEY" \
  "https://api.bunny.net/pullzone/loadFreeCertificate?hostname=equinox-jsxcore.jonathanloor.com"
```

`Type: 2` is CNAME in Bunny DNS (`0` = A, `3` = TXT, `4` = MX).

The CNAME points at **`b-cdn.net`**, not `bunny.run`, because that hostname is not on the
ISP's block list.

One practical note: querying the record *before* creating it poisoned the public resolvers
with a negative cache, so propagation appeared stuck for several minutes while the
authoritative servers (`kiki`/`coco.bunny.net`) already had it. Check
`dig @kiki.bunny.net <name>` before assuming something is wrong.

`BUNNY_APP_URL` points at the custom domain, so CI's post-deploy check verifies the URL
visitors actually use rather than one that happens to work only from a datacentre.

## Cold start

There is none to design around: the app runs continuously with 1 replica pinned to one
region. Bunny bills CPU and RAM by the hour rather than by request, so the demo is warm
whenever someone clicks the link — which was the whole reason for leaving Azure F1 and its
60 CPU-minute daily quota (D4).
