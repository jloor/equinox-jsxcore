"use server";

import { Layout } from "../Shared/Layout.tsx";

export const head = { title: "The writeup - Equinox + JsxCore" };

export default function Index({ model }: { model: { slug: string; title: string }[] }) {
    const chapters = model ?? [];

    return (
        <Layout>
            <h2>How this was built</h2>
            <p class="lead">
                The migration, in order, including the mistakes. Rendered from this repository's
                own markdown by the <code>marked</code> npm package — server-side, in an image
                with no Node and no npm.
            </p>
            <hr />

            {chapters.length === 0 && (
                <p class="text-muted">No chapters found on disk.</p>
            )}

            <ol>
                {chapters.map((c) => (
                    <li key={c.slug} style="margin-bottom: .5rem">
                        <a href={`/journey/${c.slug}`}>{c.title}</a>
                    </li>
                ))}
            </ol>

            <p>
                <a href="https://github.com/jloor/equinox-jsxcore" target="_blank">
                    Source on GitHub
                </a>
            </p>
        </Layout>
    );
}
