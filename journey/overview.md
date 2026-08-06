I gave an AI agent a detailed plan to migrate a 2016-era ASP.NET MVC application to a
view engine released three weeks ago, and told it to check the plan before running it.

Ten of the plan's claims about the codebase turned out to be wrong.

## What this is

[The Equinox Project](https://github.com/EduardoPires/EquinoxProject) is a well-known .NET
reference application — DDD, CQRS, Event Sourcing, the full architecture. Its views are
Razor. [JsxCore](https://github.com/davidwhitney/JsxCore) is a view engine that lets you
write ASP.NET Core views as TypeScript components instead, with no Node.js and no npm
anywhere in the build.

It is version 1.0.0. When I started it had 281 total downloads.

This is the result: every view converted, deployed, and running. [The demo is
live](/), and everything you can click is server-rendered from a `.tsx` file.

I am not a .NET expert. That was the point.

## The thing I did right, before writing any code

The plan said to convert `Views/Customers/`.

There is no `Views/Customers/` directory. It is `Views/Customer/`, singular — and the plan
warned, in its own text, about Linux being case-sensitive.

It also said to swap SQL Server for SQLite. That was already done. It said to update a
connection string in `appsettings.json`; there was no connection string in
`appsettings.json`. It required that no `.cshtml` files remain *and* that the
infrastructure layer not be modified — and ASP.NET Identity ships seven Razor pages wired
through the infrastructure layer, so those two rules could not both hold.

None of this required knowing .NET. It required reading the repository before acting on
claims about it. That single decision — verify first, then execute — is the only reason
the first destructive step didn't land on a folder that doesn't exist.

## What the migration actually cost

Here is the honest scorecard, because a post that only lists wins is not worth reading:

| Razor gave me | JsxCore needed |
|---|---|
| A layout applied to every view automatically | Every view imports and wraps itself |
| `@inject SignInManager` | A registered .NET global |
| `@Html.AntiForgeryToken()` | A hand-written component |
| `asp-validation-for` | Another global, plus a component |
| `[DisplayName("E-mail")]` | A string literal that silently drifts |
| `<vc:summary />` | You cannot invoke ViewComponents from TSX at all |

Six things got worse. JsxCore has **no layout mechanism at all** — no `_Layout`, no
`_ViewStart`, no implicit wrapping. A layout is just a component you import, which means
every single view has to opt in, and forgetting renders a page with no chrome instead of
failing.

The plan listed "convert `Home/Index`" as step 4.1 and "convert `_Layout`" as step 4.2.
Converting `Home/Index` requires the layout, the login partial, two .NET globals, and
head-content configuration. You cannot do 4.1 before 4.2. That ordering was knowable from
thirty minutes of reading the documentation, and was not in the plan.

## The bug that cost me the most was one character

JsxCore serialises view models to camelCase. I wrote `model.Count` against a payload
containing `count`.

In JSX, `undefined` renders as nothing. No error. No warning. HTTP 200. A page that looks
structurally correct with a blank where the data should be.

I wrote an entire chapter declaring the library's ViewComponents broken. They work fine. I
had written PascalCase against a camelCase payload, and the "hardcode a value to rule out
falsy rendering" test that felt like careful debugging only confirmed my own mistake more
precisely.

A casing mistake and a broken framework produce byte-identical output. I picked the
explanation that blamed the dependency.

## Then I made it prove itself

Once it was deployed and green, I realised the demo proved almost nothing. It looked
exactly like the Razor version, because it was a like-for-like port of a server-rendered
CRUD app — precisely the case Razor already handles well.

So I went back and made it demonstrate the things JsxCore actually claims:

- **No Node or npm.** Verified in a container where `node`, `npm`, `npx`, `yarn` and `pnpm`
  are all absent, asserted in CI before every build. The GitHub runner ships Node 22, so
  building there would have "proved" it regardless.
- **Types generated from C#.** Rename a property in C# and the build now fails.
- **One component, server and client.** The customer history modal — 25 lines of jQuery
  building HTML with string concatenation in the original — is now a typed component that
  server-renders for first paint and hydrates for interactivity.
- **npm packages with no npm.** `marked` renders these pages server-side. `highlight.js`
  reaches the browser as ES modules with no bundler.

Every one of those claims was true. **Not one was true by default.** Types generated the
wrong scope. Type checking warned instead of failing. The both-modes render was off. The
packages were never installed. In every case the default produced something that looked
like it was working.

One claim I could not prove: the hot-reload developer experience. It is a development-time
thing and no deployed URL can demonstrate it. Saying so seemed better than quietly dropping
it from the list.

## The failure mode that kept recurring

Four separate checks in this project passed when they should have failed.

One used `curl --max-file-size`, which is not a real flag. curl errored, `grep` received
empty input, found no problem, and reported success. One asserted a nav link was present
after a deploy — which the *outgoing* container also served, so it proved a build was live,
never *which* build. One reported a page was live with HTTP 200 while that page rendered
"Chapter not found".

That last one happened about thirty seconds after I finished writing a chapter about this
exact failure mode.

They all had the same shape: **the check could not distinguish "the thing is fine" from "I
failed to look".** Knowing about it confers no immunity. The only thing that helps is
comparing against something that can actually differ — the deployed commit against the
expected commit, rendered markup against a status code. What a check can *distinguish*,
not what it can *observe*.

## What I found in other people's code

Verifying against upstream turned up two things worth sending back:

A dependency update sitting open since April bumps a cryptography package to a version that
still carries **five of its eight high-severity advisories**. And the application registers
Facebook and Google authentication unconditionally, reading credentials that only exist in
the development config — so any real deployment starts perfectly cleanly, logs
`Application started`, and then returns HTTP 500 on **every request**, including inside its
own error handler.

Both are reproduced against a clean clone, with fixes.

## Where it runs

Bunny.net Magic Containers, pinned to one region and one replica — because each pod gets
its own volume and SQLite is single-writer, so a second replica silently produces a second
database. That's a dashboard setting anyone could change, so CI asserts it before every
deploy.

The whole pipeline: verify in a Node-free container, run 23 checks plus the architecture
tests, build, smoke-test the production image, publish, guard the deployment config, roll
by immutable commit SHA, then poll the live site until it serves *that* commit.

## Read the actual work

The chapters below are the engineering log, in order, including the mistakes and the
corrections. They are rendered from the repository's own markdown by an npm package
installed without npm — which is itself one of the claims being demonstrated.
