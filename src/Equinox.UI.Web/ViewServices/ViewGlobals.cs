using Microsoft.AspNetCore.Antiforgery;
using Microsoft.AspNetCore.Identity;

namespace Equinox.UI.Web.ViewServices;

/// <summary>
/// Services exposed to .tsx views as JsxCore globals (<c>import { ... } from "dotnet:globals"</c>).
///
/// Razor reached these through <c>@inject</c> and tag helpers. JsxCore has no equivalent, so
/// anything a view needs from the request has to be registered explicitly. Views importing
/// these must render with the "use server" directive - globals only exist during server
/// rendering.
/// </summary>
public sealed class CurrentUser(
    IHttpContextAccessor accessor,
    SignInManager<IdentityUser> signInManager)
{
    /// <summary>Replaces <c>SignInManager.IsSignedIn(User)</c> from _LoginPartial.cshtml.</summary>
    public bool IsSignedIn() =>
        accessor.HttpContext?.User is { } user && signInManager.IsSignedIn(user);

    /// <summary>Replaces <c>User.Identity.Name</c>.</summary>
    public string Name() =>
        accessor.HttpContext?.User?.Identity?.Name ?? string.Empty;

    /// <summary>
    /// Replaces <c>[CustomAuthorize("Customers", "...")]</c>-driven UI decisions, so views can
    /// hide actions the user cannot perform. Registration grants "Write" only; "Remove" belongs
    /// to the seeded admin.
    /// </summary>
    public bool HasClaim(string type, string value) =>
        accessor.HttpContext?.User?.Claims.Any(c =>
            c.Type == type && c.Value.Split(',').Contains(value)) ?? false;
}

/// <summary>
/// Replaces <c>@Html.AntiForgeryToken()</c>, which JsxCore has no equivalent for - the docs
/// never mention antiforgery at all. Every &lt;form method="post"&gt; in a .tsx view must render
/// this hidden input or the POST is rejected with 400.
/// </summary>
public sealed class AntiforgeryTokens(
    IAntiforgery antiforgery,
    IHttpContextAccessor accessor)
{
    public string FieldName() =>
        antiforgery.GetAndStoreTokens(accessor.HttpContext!).FormFieldName;

    public string Token() =>
        antiforgery.GetAndStoreTokens(accessor.HttpContext!).RequestToken ?? string.Empty;
}
