"use server";

import { Layout } from "../Shared/Layout.tsx";

export default function Index({ model }: { model: { name: string } }) {
    return (
        <Layout title="Home">
            <p>Hello {model.name} — server rendered.</p>
        </Layout>
    );
}
