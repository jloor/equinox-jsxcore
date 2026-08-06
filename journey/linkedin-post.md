# LinkedIn post

Primary draft below. A shorter variant follows. Neither is posted.

Links: demo https://equinox-jsxcore.jonathanloor.com ·
writeup https://equinox-jsxcore.jonathanloor.com/journey ·
repo https://github.com/jloor/equinox-jsxcore

---

## Draft A — the one I'd post

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
