# Draft: issue for EduardoPires/EquinoxProject

**Type:** bug report, with a PR to follow
**Status:** DRAFT, not posted
**Verified on:** `master` @ `fde9a95`, .NET SDK 9.0.316, unmodified clone

---

## Title

Every request returns HTTP 500 when Facebook/Google credentials aren't configured

## Body

`AddSocialAuthenticationSupport` registers the Facebook and Google handlers
unconditionally, so their options are always validated. Because remote authentication
options are validated **lazily, on first use rather than at startup**, so an app with no
social credentials starts perfectly cleanly and then fails every single request.

`src/Equinox.Infra.CrossCutting.Identity/Configuration/AspNetIdentityConfig.cs`:

```csharp
builder.Services.AddAuthentication()
    .AddFacebook(o =>
    {
        o.AppId = builder.Configuration["Authentication:Facebook:AppId"];
        o.AppSecret = builder.Configuration["Authentication:Facebook:AppSecret"];
    })
    .AddGoogle(googleOptions =>
    {
        googleOptions.ClientId = builder.Configuration["Authentication:Google:ClientId"];
        googleOptions.ClientSecret = builder.Configuration["Authentication:Google:ClientSecret"];
    });
```

### Why this affects real deployments

`appsettings.json`, the base file used by **Production** and any environment without its
own overrides, has no `Authentication` section at all:

| File | `Authentication` section |
|---|---|
| `appsettings.json` | **absent** |
| `appsettings.Development.json` | present (`"SetYourDataHere"` placeholders) |
| `appsettings.Staging.json` | present |
| `appsettings.Testing.json` | present |

So the configuration only exists in environments a developer runs locally. Deploy to
Production and every request 500s.

### What makes it hard to spot

The startup log is completely clean:

```
info: Microsoft.Hosting.Lifetime[14]
      Now listening on: http://0.0.0.0:5000
info: Microsoft.Hosting.Lifetime[0]
      Application started. Press Ctrl+C to shut down.
```

Any health check based on "did the process start" or "is the port open" reports success.
The failure only appears on an actual request:

```
fail: Microsoft.AspNetCore.Diagnostics.ExceptionHandlerMiddleware[1]
      An unhandled exception has occurred while executing the request.
      System.ArgumentNullException: Value cannot be null. (Parameter 'AppId')
         at Microsoft.AspNetCore.Authentication.Facebook.FacebookOptions.Validate()
         at Microsoft.AspNetCore.Authentication.RemoteAuthenticationOptions.Validate(String scheme)
```

It also throws **inside the error handler**, so `UseExceptionHandler("/error/500")` cannot
render either:

```
fail: Microsoft.AspNetCore.Diagnostics.ExceptionHandlerMiddleware[3]
      An exception was thrown attempting to execute the error handler.
      System.ArgumentNullException: Value cannot be null. (Parameter 'AppId')
```

### Reproduction

Isolated from the database configuration by running in Development (so SQLite is used) and
removing only the `Authentication` section, which is exactly the state of `appsettings.json`:

```bash
git clone --depth 1 https://github.com/EduardoPires/EquinoxProject.git
cd EquinoxProject
dotnet build Equinox.sln

python3 - <<'PY'
import json, io
p = 'src/Equinox.UI.Web/appsettings.Development.json'
d = json.load(io.open(p, encoding='utf-8-sig'))
d.pop('Authentication', None)
json.dump(d, open(p, 'w'), indent=2)
PY

cd src/Equinox.UI.Web
dotnet run --no-build --urls http://0.0.0.0:5000
```

```
Application started.          <- healthy
curl -o /dev/null -w '%{http_code}' http://localhost:5000/
500
```

### Suggested fix

Register each provider only when its credentials are present. Nothing else changes:
configured deployments behave exactly as before, and the placeholder values in
`appsettings.Development.json` keep working.

```csharp
var facebookAppId  = builder.Configuration["Authentication:Facebook:AppId"];
var facebookSecret = builder.Configuration["Authentication:Facebook:AppSecret"];
var googleClientId = builder.Configuration["Authentication:Google:ClientId"];
var googleSecret   = builder.Configuration["Authentication:Google:ClientSecret"];

var authentication = builder.Services.AddAuthentication();

if (!string.IsNullOrWhiteSpace(facebookAppId) && !string.IsNullOrWhiteSpace(facebookSecret))
{
    authentication.AddFacebook(o =>
    {
        o.AppId = facebookAppId;
        o.AppSecret = facebookSecret;
    });
}

if (!string.IsNullOrWhiteSpace(googleClientId) && !string.IsNullOrWhiteSpace(googleSecret))
{
    authentication.AddGoogle(googleOptions =>
    {
        googleOptions.ClientId = googleClientId;
        googleOptions.ClientSecret = googleSecret;
    });
}
```

An app shouldn't hard-fail because an optional feature is unconfigured, and the current
behaviour is especially awkward because the login page still advertises the providers.

Happy to open a PR with this if you'd like it. I have it running against a deployed
instance.

---

## Notes for me, not for the issue

- **File the issue first, offer the PR.** Sending an unsolicited PR to a maintained project
  reads worse than asking.
- Deliberately **not** mentioned: the SQL Server/SQLite provider split
  (`DatabaseConfig.cs` and `AspNetIdentityConfig.cs` both branching on `IsDevelopment()`).
  That is arguably intentional, since they expect SQL Server in production, and mixing it in
  would muddy a clear, unambiguous bug. Separate issue if it's worth raising at all.
- The repro isolates social auth from the database on purpose. Running `master` directly in
  a non-Development environment crashes *earlier*, on
  `PendingModelChangesWarning: The model for context 'EquinoxContext' has pending changes`,
  which is the provider mismatch and would obscure this bug entirely.
- Do not claim "affects everyone". SQL Server deployments get past the database and then
  hit this; SQLite-in-production deployments never get that far.
