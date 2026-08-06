import type { ComponentChildren } from "preact";
import { isServerRender } from "dotnet:rendering";
import { User, Antiforgery } from "dotnet:globals";

/**
 * Resolves the values that only exist on the server, with a DOM fallback for the client pass.
 *
 * Under RenderMode.ServerAndClient a view renders twice, and .NET globals are a server-pass
 * feature - reaching for one in the browser throws. But rendering something *different* on
 * the client is worse than throwing: Preact would patch the nav, and a signed-in user would
 * watch it flip to "Register / Login" after hydration.
 *
 * So the server writes its answers into data attributes, and the client reads them back out
 * of the DOM it is about to hydrate. Both passes then produce byte-identical markup, which
 * is what makes hydration a no-op rather than a repair.
 */
function serverState() {
    if (isServerRender()) {
        return {
            signedIn: User.isSignedIn(),
            name: User.name(),
            tokenField: Antiforgery.fieldName(),
            token: Antiforgery.token(),
        };
    }

    const nav = document.querySelector<HTMLElement>("[data-jsx-nav]");
    return {
        signedIn: nav?.dataset.signedIn === "true",
        name: nav?.dataset.userName ?? "",
        tokenField: nav?.dataset.tokenField ?? "__RequestVerificationToken",
        token: nav?.dataset.token ?? "",
    };
}

/**
 * Replaces _Layout.cshtml.
 *
 * This is NOT a like-for-like port. JsxCore has no layout mechanism at all - no _Layout,
 * no _ViewStart, no implicit wrapping. A layout is just a component, so every view has to
 * import this and wrap itself explicitly. Forgetting to do so renders the page with no
 * chrome rather than failing.
 *
 * JsxCore also writes its own <html>/<head>/<body> shell, so this component must NOT emit
 * a document. Stylesheets and scripts that lived in _Layout.cshtml are set via
 * options.Document.HeadContent / BodyContent in Program.cs instead.
 *
 * Any view using this must declare "use server" - it reads .NET globals, which only exist
 * during server rendering.
 */
export function Layout({ children }: { children: ComponentChildren }) {
    return (
        <>
            <header>
                <nav class="navbar navbar-expand-sm navbar-toggleable-sm navbar-dark bg-dark border-bottom box-shadow mb-3">
                    <div class="container">
                        <a href="/" class="navbar-brand">
                            <img src="/images/logo.png" style="width: 170px; height: 37px" alt="Equinox Project" />
                        </a>
                        <button
                            class="navbar-toggler"
                            type="button"
                            data-toggle="collapse"
                            data-target=".navbar-collapse"
                            aria-controls="navbarSupportedContent"
                            aria-expanded="false"
                            aria-label="Toggle navigation"
                        >
                            <span class="navbar-toggler-icon"></span>
                        </button>
                        <div class="navbar-collapse collapse d-sm-inline-flex flex-sm-row-reverse">
                            <LoginPartial />
                            <ul class="navbar-nav flex-grow-1">
                                <li>
                                    <a class="nav-link text-light" href="/customer-management/list-all">
                                        Customers
                                    </a>
                                </li>
                            </ul>
                        </div>
                    </div>
                </nav>
            </header>

            <div class="container">
                <main role="main" class="pb-3">
                    {children}
                </main>
            </div>

            <footer class="border-top footer text-muted">
                <div class="container">
                    Equinox Project - Version 1.10 - Developed by -{" "}
                    <a href="http://eduardopires.net.br" target="_blank">
                        Eduardo Pires
                    </a>{" "}
                    - This is an open-source project{" "}
                    <a href="https://github.com/EduardoPires/EquinoxProject" target="_blank">
                        Equinox GitHub
                    </a>
                </div>
            </footer>
        </>
    );
}

/**
 * Replaces _LoginPartial.cshtml, which used @inject SignInManager / UserManager.
 * JsxCore has no @inject, so the state arrives through the "User" global.
 */
function LoginPartial() {
    const { signedIn, name, tokenField, token } = serverState();

    // The data-* attributes are what the client pass reads back during hydration, so they
    // are load-bearing rather than decorative.
    const navAttrs = {
        "data-jsx-nav": "",
        "data-signed-in": String(signedIn),
        "data-user-name": name,
        "data-token-field": tokenField,
        "data-token": token,
    };

    if (!signedIn) {
        return (
            <ul class="navbar-nav" {...navAttrs}>
                <li class="nav-item">
                    <a class="nav-link text-light" href="/Identity/Account/Register">Register</a>
                </li>
                <li class="nav-item">
                    <a class="nav-link text-light" href="/Identity/Account/Login">Login</a>
                </li>
            </ul>
        );
    }

    return (
        <ul class="navbar-nav" {...navAttrs}>
            <li class="nav-item">
                <a class="nav-link text-light" href="/Identity/Account/Manage" title="Manage">
                    Hello {name}!
                </a>
            </li>
            <li class="nav-item">
                {/* Razor's form tag helper injected the antiforgery token automatically.
                    In TSX it has to be written by hand or the POST is rejected with 400. */}
                <form class="form-inline" method="post" action="/Identity/Account/Logout?returnUrl=%2F">
                    <input type="hidden" name={tokenField} value={token} />
                    <button type="submit" class="nav-link btn btn-link text-light">Logout</button>
                </form>
            </li>
        </ul>
    );
}
