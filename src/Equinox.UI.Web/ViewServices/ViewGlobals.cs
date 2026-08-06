using Microsoft.AspNetCore.Antiforgery;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc.Infrastructure;

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

/// <summary>
/// Exposes ModelState to .tsx views, replacing <c>asp-validation-summary</c>,
/// <c>asp-validation-for</c> and the &lt;vc:summary /&gt; ViewComponent.
///
/// ViewComponents themselves work fine in JsxCore, but a .tsx view cannot invoke one -
/// &lt;vc:summary /&gt; is a Razor tag helper with no TSX equivalent - and Equinox's Summary
/// takes no model, reading ModelState directly. So the state comes through here instead.
///
/// BaseController.ResponseHasErrors adds domain/FluentValidation failures with an empty
/// key, which is what asp-validation-summary="ModelOnly" rendered.
/// </summary>
public sealed class ValidationState(IActionContextAccessor accessor)
{
    // No '?' annotation: Equinox.UI.Web sets <Nullable>disable</Nullable>, so reference
    // types are already implicitly nullable and the annotation raises CS8632.
    private Microsoft.AspNetCore.Mvc.ModelBinding.ModelStateDictionary State =>
        accessor.ActionContext?.ModelState;

    /// <summary>Model-level errors (empty key) - the "Oops! Something went wrong" list.</summary>
    public string[] Errors() =>
        State?.TryGetValue(string.Empty, out var entry) == true
            ? entry.Errors.Select(e => e.ErrorMessage).ToArray()
            : [];

    public bool HasErrors() => Errors().Length > 0;

    /// <summary>Field-level errors, replacing asp-validation-for="Name".</summary>
    public string[] For(string field) =>
        State?.TryGetValue(field, out var entry) == true
            ? entry.Errors.Select(e => e.ErrorMessage).ToArray()
            : [];
}
