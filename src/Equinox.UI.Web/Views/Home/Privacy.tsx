"use server";

import { Layout } from "../Shared/Layout.tsx";

export const head = { title: "Privacy Policy - Equinox Project" };

export default function Privacy() {
    return (
        <Layout>
            <h1>Privacy Policy</h1>
            <p>Use this page to detail your site's privacy policy.</p>
        </Layout>
    );
}
