"use server";

import { Antiforgery } from "dotnet:globals";
import { Layout } from "../Shared/Layout.tsx";

export default function Create({ model }: { model: { Name: string; Email: string } }) {
    return (
        <Layout title="New customer">
            <form method="post" action="/Customer/Create">
                <input type="hidden" name={Antiforgery.fieldName()} value={Antiforgery.token()} />
                <label>
                    Name <input name="Name" defaultValue={model.Name} />
                </label>
                <label>
                    Email <input name="Email" defaultValue={model.Email} />
                </label>
                <button type="submit">Save</button>
            </form>
        </Layout>
    );
}
