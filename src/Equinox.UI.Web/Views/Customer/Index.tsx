"use server";

import { Layout } from "../Shared/Layout.tsx";
import { CustomerTable } from "../Shared/CustomerTable.tsx";
import type Equinox from "@/generated/types.d.ts";

export const head = { title: "Customer Management - Equinox Project" };

type Customer = Equinox.Application.ViewModels.CustomerViewModel;

/**
 * Replaces Customer/Index.cshtml.
 *
 * The "use server" directive is the view's own preference, but JsxRenderModeFilter overrides
 * it to RenderMode.ServerAndClient for this action - the endpoint's choice wins over the
 * directive. So the table below is written into the response for first paint and for clients
 * with JavaScript disabled, and then the same components hydrate in the browser to make the
 * history modal work.
 *
 * The table, the buttons and the modal all live in Shared/CustomerTable.tsx. That file used to
 * be 25 lines of jQuery building HTML with string concatenation.
 */
export default function Index({ model }: { model: Customer[] }) {
    return (
        <Layout>
            <div>
                <h2>Customer Management</h2>
            </div>
            <hr />

            <div class="row">
                <div class="col-md-12">
                    <div>
                        <div class="pull-left">
                            <a href="/customer-management/register-new" class="btn btn-primary">
                                <span title="Register New" class="fas fa-plus"></span> Register New
                            </a>
                        </div>
                    </div>
                </div>
            </div>
            <br />

            <CustomerTable customers={model ?? []} />
        </Layout>
    );
}
