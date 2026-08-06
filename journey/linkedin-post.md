# LinkedIn post

Draft C is the current preference - leads with intent rather than findings.
A and B are earlier, more technical framings. None are posted.

Links: demo https://equinox-jsxcore.jonathanloor.com ·
writeup https://equinox-jsxcore.jonathanloor.com/journey ·
repo https://github.com/jloor/equinox-jsxcore

---

## Draft C — leads with the why (current preference)

I wanted to find out what I could actually build in a stack I'm not an expert in.

So I set myself a deliberately awkward challenge: take a well-known .NET reference
application, swap out its entire view layer for a library released three weeks ago, and put
it in production. Not a tutorial project. Someone else's real codebase, and a dependency
with a few hundred downloads and no Stack Overflow answers to lean on.

I'm not a .NET expert. That was the point.

It's live: https://equinox-jsxcore.jonathanloor.com

What I learned is not really about .NET.

The single most valuable thing I did was refuse to start. I had a detailed plan, and before
running any of it, I checked every claim it made against the actual repository. Ten were
wrong. It named a folder that doesn't exist. It told me to do a database migration that had
already been done. It required two things that couldn't both be true at once.

Catching that needed no expertise at all. It needed reading the code before trusting a
description of the code. I think that's the skill that actually transfers between stacks.

The rest was ordinary difficulty, honestly reported. Some things got worse, not better. I
spent hours convinced the library was broken before discovering my own one-character
mistake. Several of my own tests passed when they should have failed — including one about
thirty seconds after I'd finished writing about that exact problem.

I wrote all of it down, corrections included, because the version where everything goes
smoothly isn't useful to anyone.

The part I didn't expect was how much I'd find worth giving back. Working carefully through
two open-source projects surfaced four real issues — including a dependency update that
doesn't fully patch what it claims to, and a bug that makes an app return errors on every
request under a common configuration. All four are now filed upstream with reproductions,
and I'd rather that be the outcome than a demo nobody looks at.

The full writeup: https://equinox-jsxcore.jonathanloor.com/journey

Sincere thanks to Eduardo Pires, whose Equinox Project is a genuinely excellent codebase to
learn architecture from, and David Whitney, whose JsxCore is an ambitious piece of work. Both
MIT. Neither of them asked for any of this.

If you're on the fence about building something in a stack you don't know: the gap is
smaller than it looks, and it's mostly filled by being willing to check things.

#dotnet #softwareengineering #learninginpublic

---

## Draft A — technical framing (earlier version)

I had a detailed plan to migrate a .NET reference app to a view engine released three weeks
ago. Before running a single step, I had it verified against the actual repository.

Ten of its claims about the codebase were wrong.

It said to convert Views/Customers. The folder is Views/Customer — singular. The plan itself
warned about Linux being case-sensitive.

It said to migrate SQL Server to SQLite. Already done. It said to update a connection string
in appsettings.json. There was no connection string in appsettings.json. It required that no
Razor views remain AND that the infrastructure layer not be modified — and ASP.NET Identity
ships seven Razor pages wired through the infrastructure layer, so both rules could not hold
at once.

None of that needed .NET expertise. It needed reading the repo before acting on claims about
it.

The result is live. Every view is now a TypeScript component, running in production:
https://equinox-jsxcore.jonathanloor.com

Three things I'd want to read in someone else's post about this:

1. Six things got WORSE.

No layout mechanism, so every view wraps itself. @inject became a registered service.
@Html.AntiForgeryToken() became a hand-written component. [DisplayName] has no equivalent at
all, so labels are now string literals that silently drift. A like-for-like port of a
server-rendered CRUD app is exactly the case Razor already handles well.

2. I declared the library broken. It was one character.

Models serialize to camelCase. I wrote model.Count against a payload containing count. In
JSX, undefined renders as nothing — no error, no warning, HTTP 200, a page that looks
structurally correct with a blank where the data should be.

A casing mistake and a broken framework produce byte-identical output. I picked the
explanation that blamed the dependency, and wrote a whole chapter on it before finding out.

3. Four of my own checks passed when they should have failed.

One used a curl flag that doesn't exist, so curl errored, grep got empty input, found no
problem, and reported success. One asserted a nav link was present after deploy — which the
OUTGOING container also served, so it proved a build was live, never which one.

One reported a page live with HTTP 200 while that page rendered "Chapter not found". That
happened about thirty seconds after I finished writing about this exact failure mode.

They all share a shape: the check couldn't distinguish "this is fine" from "I failed to
look." Knowing about it confers no immunity. What helps is comparing against something that
can actually differ — the deployed commit vs the expected commit, rendered markup vs a
status code.

Verifying my own work turned up four things worth sending upstream, including a dependency
update that's been open since April and still leaves five of eight high-severity advisories
in place, and an app that starts perfectly cleanly and then returns 500 on every request
when optional credentials aren't configured. All four are filed with reproductions.

The whole thing is written up, mistakes included, rendered from the repo's own markdown by
an npm package installed without npm — which is one of the claims being demonstrated:
https://equinox-jsxcore.jonathanloor.com/journey

Credit where it's due: the Equinox Project is Eduardo Pires' — Microsoft Regional Director
and MVP, founder of desenvolvedor.io. JsxCore is David Whitney's, an independent consultant
in London. Both MIT, both worth a look, and both codebases were a pleasure to work in.

#dotnet #softwareengineering #ai

---

## Draft B — shorter, if A feels long for the feed

I had a detailed plan to migrate a .NET reference app to a view engine released three weeks
ago. Before running a single step, I had it verified against the actual repository.

Ten of its claims about the codebase were wrong. It named a folder that doesn't exist. It
told me to do a database migration that was already done. It required two things that
couldn't both be true.

None of that needed .NET expertise. It needed reading the repo before acting on claims about
it.

It's live now — every view a TypeScript component, in production:
https://equinox-jsxcore.jonathanloor.com

The part I'd want to read in someone else's version: four of my own checks passed when they
should have failed. One used a curl flag that doesn't exist, so curl errored, grep got empty
input, and the check reported success. One reported a page live with HTTP 200 while that
page rendered "Chapter not found" — thirty seconds after I'd finished writing about that
exact failure mode.

They share a shape: the check couldn't distinguish "this is fine" from "I failed to look."

Six things also got worse than Razor, and I declared the library broken over what turned out
to be a one-character casing mistake. All of it is written up, including the corrections:
https://equinox-jsxcore.jonathanloor.com/journey

The Equinox Project is Eduardo Pires' (Microsoft RD/MVP, desenvolvedor.io). JsxCore is
David Whitney's. Both MIT.

#dotnet #softwareengineering #ai

---

## Follow-up comment — all the links

Post this as the first comment. Links in the body reportedly get less reach than links in a
comment, so Draft C keeps one (the demo) and everything else lives here.

```
Links, for anyone who wants to dig in:

The running app — Equinox with every view converted to TypeScript
https://equinox-jsxcore.jonathanloor.com

The writeup — 8 chapters, in order, including the parts I got wrong
https://equinox-jsxcore.jonathanloor.com/journey

Source, including the verification scripts and the CI pipeline
https://github.com/jloor/equinox-jsxcore

What went back upstream, all with reproductions:

• Equinox — a dependency bump that leaves 5 of 8 high-severity advisories in place
  https://github.com/EduardoPires/EquinoxProject/pull/218

• Equinox — app returns 500 on every request when optional social-auth credentials
  aren't configured; startup logs look completely clean
  https://github.com/EduardoPires/EquinoxProject/issues/220

• JsxCore — first publish on a clean checkout omits node_modules, so CI and container
  builds always hit the broken case
  https://github.com/davidwhitney/JsxCore/issues/3

• JsxCore — two docs gaps that cost me the most time
  https://github.com/davidwhitney/JsxCore/issues/4

The two projects this is built on, both MIT and both worth your time:

Equinox Project by Eduardo Pires — one of the better DDD/CQRS reference codebases out there
https://github.com/EduardoPires/EquinoxProject

JsxCore by David Whitney — TSX views for ASP.NET Core with no Node and no npm
https://github.com/davidwhitney/JsxCore
```

Notes on this comment:
- Order is deliberate: what I made, then what I gave back, then whose work it stands on.
  Leading with the upstream issues would read as "look what I found in your code".
- Each upstream link says what it is in plain terms. A bare issue number under a post that
  tags both authors invites people to click expecting drama.
- Linking PR #218 rather than the comment permalink puts the reader on the PR itself,
  where Dependabot's change and the reasoning sit together.
- If you would rather not surface the upstream issues publicly at all, cut that whole block.
  The post still stands without it, and the authors have the reports either way.

---

## Who to tag

**Eduardo Pires** — Equinox Project
- Microsoft Regional Director and MVP; founder of desenvolvedor.io
- São Paulo, Brazil
- GitHub: https://github.com/EduardoPires (4,093 followers)
- Site: https://desenvolvedor.io — his LinkedIn is linked from there
- Search LinkedIn for "Eduardo Pires desenvolvedor.io" or "Eduardo Pires Microsoft MVP"

**David Whitney** — JsxCore
- Independent software consultant, London UK; Electric Head Software
- GitHub: https://github.com/davidwhitney (311 followers)
- Site: https://www.davidwhitney.co.uk
- X/Twitter: @david_whitney
- Search LinkedIn for "David Whitney Electric Head Software" or via his site

Tagging notes:
- Verify each profile before tagging. Both names are common, and tagging the wrong person
  is worse than not tagging.
- Eduardo has a large following in the Brazilian .NET community, so a tag there has real
  reach — which cuts both ways, since the post says his project has an open security PR
  that doesn't fully patch and a startup bug. Both are filed with reproductions and written
  neutrally, and I'd make sure he's seen the issues before he sees the post.
- David's project is v1.0.0 with a few hundred downloads. A post describing real friction
  is useful to him, but tag him only if you're comfortable that the two issues you filed
  read as contributions rather than criticism. I think they do.

## Notes

- LinkedIn truncates around 200 characters. Both drafts put the hook above that line.
- LinkedIn does not render markdown. No bold, no bullets — the numbered sections rely on
  line breaks, which is why the paragraphs are short.
- Links in the post body reportedly get less reach than links in the first comment. If you
  care about that, move the /journey link to a comment and leave the demo link in the body.
- Deliberately not claimed: that this was easy, that JsxCore beats Razor, or that the HMR
  claim was proven. It wasn't — it can't be demonstrated by a URL.
- The AI framing is upfront on purpose. Directing the work and catching the plan's errors
  is the skill being shown; hiding the tool would undercut it.
- Before posting: the demo resets periodically by design, and JsxCore is v1.0.0 with a few
  hundred downloads. Both are stated in the writeup, so the post doesn't need to hedge —
  but don't let a comment catch you out on either.
