## Title

Docs: two things that cost me hours — model casing, and antiforgery in MVC forms

## Body

I migrated a real ASP.NET MVC app ([Equinox
Project](https://github.com/EduardoPires/EquinoxProject)) from Razor to JsxCore — every
view, deployed and running. The docs are genuinely good; these are the two places I lost
the most time, offered in case they are worth a paragraph each.

Happy to send a PR for either or both — `CONTRIBUTING.md` says to ask first, so I'm asking.

---

### 1. Model casing, and the way it fails

[`model-types.md`](https://github.com/davidwhitney/JsxCore/blob/main/docs/model-types.md)
does say the declarations "follow the application's `JsonSerializerOptions` rather than the
.NET shape directly", and the generated file repeats it. I read both and still wrote:

```tsx
export default function Default({ model }: { model: { Count: number } }) {
    return <aside>Summary: {model.Count} customers</aside>;
}
```

against a payload containing `count`.

The failure mode is what makes this expensive. `undefined` renders as **nothing** in JSX:
no error, no warning, HTTP 200, and a page that is structurally correct with a blank where
the value should be. A casing mistake and a broken feature produce byte-identical output.

I concluded ViewComponents were broken, hardcoded a value to "rule out falsy rendering",
saw the same blank, and wrote it up as a library bug. It was one character.

A troubleshooting entry along the lines of *"a value renders as nothing → check the casing;
models are camelCase"* would have saved me a couple of hours and one incorrect bug report.

The second half is easy to miss too, because both conventions appear in one line:

```tsx
<input name="Name" value={model.name} />
```

The **attribute** stays PascalCase — ASP.NET model binding reads it on POST. The **model
property** is camelCase — that is JSON arriving from the server. Two mechanisms, two
conventions, adjacent.

---

### 2. Antiforgery for MVC forms

Searching the docs tree for `antiforgery`, `anti-forgery`, `csrf` and
`RequestVerificationToken` returns nothing. For anyone porting Razor forms this is the first
wall they hit: `@Html.AntiForgeryToken()` has no equivalent, and every `<form method="post">`
against a `[ValidateAntiForgeryToken]` action returns 400 until you work out that globals
are the answer.

What worked, verified end to end against a real MVC controller:

```csharp
public sealed class AntiforgeryTokens(IAntiforgery antiforgery, IHttpContextAccessor accessor)
{
    public string FieldName() => antiforgery.GetAndStoreTokens(accessor.HttpContext!).FormFieldName;
    public string Token()     => antiforgery.GetAndStoreTokens(accessor.HttpContext!).RequestToken!;
}

builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<AntiforgeryTokens>();
builder.AddJsxCore(o => o.Globals.Register<AntiforgeryTokens>("Antiforgery"));
```

```tsx
import { Antiforgery } from "dotnet:globals";

export function AntiforgeryField() {
    return <input type="hidden" name={Antiforgery.fieldName()} value={Antiforgery.token()} />;
}
```

```
GET  /customer-management/register-new  ->  <input type="hidden"
                                              name="__RequestVerificationToken" value="CfDJ8..."/>
POST with token                        ->  200
POST without token                     ->  400
```

Worth stating explicitly that a view using this **must** be server-rendered, since globals
are a server-pass feature. That coupling is obvious once you know it and invisible before.

The same pattern covers the other Razor request-state helpers — `asp-validation-for` and
`asp-validation-summary` need `ModelState`, which lives on the `ActionContext` rather than
the `HttpContext`, so it needs `IActionContextAccessor` registered as well. A short
"porting Razor helpers" table would cover all of it in one place.

---

Thanks for the project. The no-Node claim held up completely — I verified it in a container
with `node`, `npm`, `npx`, `yarn` and `pnpm` all absent, asserted in CI on every build,
because the GitHub runner ships Node 22 and building there would have "proved" it either
way.

---

## Notes for me, not for the issue

- Ask first, as CONTRIBUTING requests. Do not send an unsolicited docs PR.
- Lead with "the docs already say this and I still got it wrong" - it is true, and it
  makes the point about the failure mode rather than about a missing sentence.
- Own the incorrect bug report explicitly. It is the strongest evidence that the
  troubleshooting entry is worth having.
- Do NOT bundle the publish/node_modules bug in here; that is a separate issue with a
  separate repro.
