"use server";

import { Layout } from "../Shared/Layout.tsx";
import { formatDate, type Customer } from "../Shared/CustomerForm.tsx";

export const head = { title: "Customer Details - Equinox Project" };

export default function Details({ model }: { model: Customer }) {
    return (
        <Layout>
            <h2>Customer Details</h2>

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
            </div>
            <div>
                <a href={`/customer-management/edit-customer/${model.id}`} class="btn btn-warning">Edit</a>{" "}
                <a href="/customer-management/list-all" class="btn btn-info">Back to List</a>
            </div>
        </Layout>
    );
}
