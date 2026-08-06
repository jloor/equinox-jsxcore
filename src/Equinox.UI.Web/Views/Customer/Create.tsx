"use server";

import { Layout } from "../Shared/Layout.tsx";
import {
    AntiforgeryField,
    CustomerFields,
    ValidationSummary,
    type Customer,
} from "../Shared/CustomerForm.tsx";

export const head = { title: "Register new Customer - Equinox Project" };

export default function Create({ model }: { model: Partial<Customer> }) {
    return (
        <Layout>
            <h2>Register new Customer</h2>

            <form method="post" action="/customer-management/register-new">
                <div class="form-horizontal">
                    <hr />

                    <ValidationSummary />
                    <AntiforgeryField />

                    <CustomerFields model={model ?? {}} />

                    <div class="form-group">
                        <div class="col-md-offset-2 col-md-10">
                            <input type="submit" value="Create" class="btn btn-success" />{" "}
                            <a href="/customer-management/list-all" class="btn btn-info">Back to List</a>
                        </div>
                    </div>
                </div>
            </form>
        </Layout>
    );
}
