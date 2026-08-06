"use server";

import { Layout } from "../Shared/Layout.tsx";
import {
    AntiforgeryField,
    CustomerFields,
    ValidationSummary,
    type Customer,
} from "../Shared/CustomerForm.tsx";

export const head = { title: "Edit Customer - Equinox Project" };

export default function Edit({ model }: { model: Customer }) {
    return (
        <Layout>
            <h2>Edit Customer</h2>

            <form method="post" action={`/customer-management/edit-customer/${model.id}`}>
                <div class="form-horizontal">
                    <hr />

                    <ValidationSummary />
                    <AntiforgeryField />

                    {/* The Edit POST binds CustomerViewModel.Id, which the route also carries.
                        Razor emitted this via asp-for="Id"; here it is explicit. */}
                    <input type="hidden" name="Id" value={model.id} />

                    <CustomerFields model={model} />

                    <div class="form-group">
                        <div class="col-md-offset-2 col-md-10">
                            <input type="submit" value="Save" class="btn btn-success" />{" "}
                            <a href="/customer-management/list-all" class="btn btn-info">Back to List</a>
                        </div>
                    </div>
                </div>
            </form>
        </Layout>
    );
}
