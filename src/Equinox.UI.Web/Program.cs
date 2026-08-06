using Equinox.UI.Web.Configurations;
using Equinox.Infra.CrossCutting.Identity.Configuration;
using Equinox.UI.Web.ViewServices;
using JsxCore.Hosting;

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
builder.Services.AddScoped<CurrentUser>();
builder.Services.AddScoped<AntiforgeryTokens>();

builder.AddJsxCore(options =>
{
    // Razor used @inject and tag helpers; JsxCore views reach .NET only through
    // registered globals. These replace _LoginPartial's SignInManager and
    // @Html.AntiForgeryToken(), which JsxCore has no equivalent for.
    options.Globals.Register<CurrentUser>("User");
    options.Globals.Register<AntiforgeryTokens>("Antiforgery");

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

// Applying migrations and seeding some data
app.UseDbSeed();

app.Run();
