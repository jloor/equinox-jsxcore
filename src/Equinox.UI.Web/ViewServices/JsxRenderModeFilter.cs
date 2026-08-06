using JsxCore;
using JsxCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Mvc.ViewFeatures;

namespace Equinox.UI.Web.ViewServices;

/// <summary>
/// Opts specific actions into <c>RenderMode.ServerAndClient</c>.
///
/// JsxCore's three render modes are Client (default), Server, and ServerAndClient. The first
/// two have file-level directives - <c>"use server"</c>, <c>"use client"</c> - but
/// ServerAndClient deliberately has none, because it is a per-response decision: the same view
/// is often server-rendered on a public page and client-only behind a login. It is normally set
/// at the endpoint:
///
///     ViewData[JsxViewEngine.RenderModeKey] = RenderMode.ServerAndClient;
///
/// This project's constraints forbid modifying <c>Controllers/</c>, so it is set here instead.
/// A result filter runs after the action and before the view executes, which is exactly the
/// window in which ViewData is still writable.
///
/// Only the customer list opts in. Everything else stays <c>"use server"</c>: hydrating a page
/// that has no interactive elements ships JavaScript for nothing.
/// </summary>
public sealed class JsxRenderModeFilter : IResultFilter
{
    private static readonly HashSet<(string Controller, string Action)> Hydrated =
    [
        ("Customer", "Index"),
    ];

    public void OnResultExecuting(ResultExecutingContext context)
    {
        var controller = context.RouteData.Values["controller"]?.ToString();
        var action = context.RouteData.Values["action"]?.ToString();

        if (controller is null || action is null) return;
        if (!Hydrated.Contains((controller, action))) return;

        if (context.Controller is Microsoft.AspNetCore.Mvc.Controller mvc)
        {
            mvc.ViewData[JsxViewEngine.RenderModeKey] = RenderMode.ServerAndClient;
        }
    }

    public void OnResultExecuted(ResultExecutedContext context) { }
}
