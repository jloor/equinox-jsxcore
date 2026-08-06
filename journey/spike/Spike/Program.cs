using JsxCore.Hosting;
using Microsoft.AspNetCore.Antiforgery;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllersWithViews();
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<AntiforgeryHelper>();

builder.AddJsxCore(options =>
{
    options.Globals.Register<AntiforgeryHelper>("Antiforgery");
});

var app = builder.Build();

app.UseJsxCore();
app.UseRouting();
app.MapControllerRoute(name: "default", pattern: "{controller=Home}/{action=Index}/{id?}");

app.Run();

public sealed class AntiforgeryHelper(IAntiforgery antiforgery, IHttpContextAccessor accessor)
{
    public string FieldName() =>
        antiforgery.GetAndStoreTokens(accessor.HttpContext!).FormFieldName;

    public string Token() =>
        antiforgery.GetAndStoreTokens(accessor.HttpContext!).RequestToken!;
}
