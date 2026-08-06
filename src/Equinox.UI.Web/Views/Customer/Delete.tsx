"use server";

import { Layout } from "../Shared/Layout.tsx";
import {
    AntiforgeryField,
    ValidationSummary,
    formatDate,
    type Customer,
} from "../Shared/CustomerForm.tsx";

export const head = { title: "Delete Customer - Equinox Project" };

export default function Delete({ model }: { model: Customer }) {
    return (
        <Layout>
            <h2>Delete Customer</h2>

            <form method="post" action={`/customer-management/remove-customer/${model.id}`}>
                <ValidationSummary />
                <AntiforgeryField />

                <h3>Are you sure you want to delete the {model.name}?</h3>
                <div>
                    <hr />
                    <dl class="dl-horizontal">
                        <dt>Name</dt>
                        <dd>{model.name}</dd>
                        <dt>E-mail</dt>
                        <dd>{model.email}</dd>
                        <dt>Birth Date</dt>
                        <dd>{formatDate(model.birthDate)}</dd>
                    </dl>

                    <div class="form-actions no-color">
                        <input type="submit" value="Delete" class="btn btn-danger" />{" "}
                        <a href="/customer-management/list-all" class="btn btn-info">Back to List</a>
                    </div>
                </div>
            </form>
        </Layout>
    );
}
