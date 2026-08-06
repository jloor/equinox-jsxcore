"use server";

import { Layout } from "./Layout.tsx";

export const head = { title: "Oops! An error has occurred! - Equinox Project" };

/**
 * Replaces Shared/Error.cshtml.
 *
 * ErrorViewModel is the one model JsxCore generated TypeScript for, since it lives in
 * Equinox.UI.Web.Models - the same assembly as the views. CustomerViewModel lives in
 * Equinox.Application.ViewModels and was not picked up, which is why the Customer views
 * declare their own shape.
 *
 * The generated declaration confirms the camelCase serialisation:
 *   interface ErrorViewModel { errorCode: number; title: string; message: string; }
 *
 * Razor used @Html.Raw here. JSX escapes by default, and these strings come from
 * HomeController's error handling rather than user input, so they are rendered as text.
 * Preserving the raw behaviour would need dangerouslySetInnerHTML, which is not worth
 * the XSS surface on an error page.
 */
export default function Error({ model }: { model?: { errorCode: number; title: string; message: string } }) {
    if (!model) {
        return (
            <Layout>
                <div>
                    <h2>
                        Oops! An error has occurred, but don't worry. Our time will be reviewed
                        and we will correct it soon!
                    </h2>
                </div>
            </Layout>
        );
    }

    return (
        <Layout>
            <h1>{model.title}</h1>
            <h2 class="text-danger">{model.message}</h2>
        </Layout>
    );
}
