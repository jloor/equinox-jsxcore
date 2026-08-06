using Equinox.UI.Web.Configurations;
using Equinox.Infra.CrossCutting.Identity.Configuration;
using Equinox.UI.Web.ViewServices;
using Microsoft.AspNetCore.Mvc.Infrastructure;
using JsxCore.Hosting;
using JsxCore.TypeScript;

var builder = WebApplication.CreateBuilder(args);

// Adding Services
builder.AddMvcConfiguration()                   // Entire Equinox MVC Config
       .AddDatabaseConfiguration()              // Setting DBContexts
       .AddWebIdentityConfiguration()           // ASP.NET Identity Config
       .AddDependencyInjectionConfiguration();  // DotNet Native DI Abstraction

// JsxCore renders .tsx views. It registers as an IViewEngine alongside Razor,
// which still serves the ASP.NET Identity pages under Areas/Identity.
// JsxCore writes its own <html>/<head>/<body> shell, so the stylesheets that
// used to live in _Layout.cshtml are injected here instead.
builder.Services.AddHttpContextAccessor();
// ModelState lives on the ActionContext, not the HttpContext, so views need this
// to reach validation errors.
builder.Services.AddSingleton<IActionContextAccessor, ActionContextAccessor>();
builder.Services.AddScoped<CurrentUser>();
builder.Services.AddScoped<AntiforgeryTokens>();
builder.Services.AddScoped<ValidationState>();

builder.AddJsxCore(options =>
{
    // Razor used @inject and tag helpers; JsxCore views reach .NET only through
    // registered globals. These replace _LoginPartial's SignInManager and
    // @Html.AntiForgeryToken(), which JsxCore has no equivalent for.
    options.Globals.Register<CurrentUser>("User");
    options.Globals.Register<AntiforgeryTokens>("Antiforgery");
    options.Globals.Register<ValidationState>("Validation");

    // By default the convention scans only this assembly, so it generated
    // Equinox.UI.Web.Models.ErrorViewModel and nothing else - CustomerViewModel lives in
    // Equinox.Application. That is why the Customer views originally declared their own
    // hand-written TypeScript interface, which is exactly the drift this feature exists to
    // prevent: the C# could change and the .tsx would keep compiling against a stale shape.
    //
    // Narrower than TypesFrom.AllUserCode, which the docs note also picks up services and
    // controllers.
    options.TypeDefinitions.AutoExport =
          TypesFrom.NamespaceContaining<Equinox.Application.ViewModels.CustomerViewModel>()
        + TypesFrom.NamespaceContaining<Equinox.UI.Web.Models.ErrorViewModel>();

    // Written into the source tree and committed, deliberately.
    //
    // Type generation runs twice: at build, and at application startup. The build "cannot
    // see your configuration" - AutoExport is application code that has not run yet - so a
    // build-only answer is the DEFAULT convention, which scans this assembly alone and
    // therefore misses CustomerViewModel entirely. That produces types which are correct
    // on a machine that has run the app and wrong on a fresh clone or in CI.
    //
    // Committing the generated output is the documented way to skip that approximation.
    options.TypeDefinitions.OutputPath = "Views/generated";

    options.Document.DefaultTitle = "Equinox Project";
    options.Document.HeadContent = """
        <link rel="stylesheet" href="/lib/bootstrap/dist/css/bootstrap.min.css" />
        <link rel="stylesheet" href="/css/site.css" />
        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.9.0/css/all.css" />
        """;
    options.Document.BodyContent = """
        <script src="/lib/jquery/dist/jquery.min.js"></script>
        <script src="/lib/bootstrap/dist/js/bootstrap.bundle.min.js"></script>
        <script src="/js/site.js"></script>
        """;
});

var app = builder.Build();

// Configure Services
if (app.Environment.IsDevelopment())
{
    app.UseDeveloperExceptionPage()
       .UseMigrationsEndPoint();
}
else
{
    app.UseExceptionHandler("/error/500")
       .UseStatusCodePagesWithRedirects("/error/{0}")
       .UseHsts();
}

app.UseJsxCore();

app.UseHttpsRedirection()
   .UseStaticFiles()
   .UseRouting()
   .UseAuthentication()
   .UseAuthorization();

app.MapControllerRoute(name: "default",pattern: "{controller=Home}/{action=Index}/{id?}");
app.MapRazorPages();

// Reports the commit this image was built from, so a deploy can be verified as "the NEW
// build is serving" rather than "something is serving".
//
// This exists because the previous check asserted a nav link was present - which the
// OUTGOING container also served. CI reported a successful deploy while the site was
// still showing the platform's "We're deploying your app!" placeholder. Liveness is not
// the same as freshness, and only one of them is what a deploy step is claiming.
app.MapGet("/version", () => Results.Text(
    Environment.GetEnvironmentVariable("BUILD_SHA") ?? "unknown",
    "text/plain"));

// Applying migrations and seeding some data
app.UseDbSeed();

app.Run();
