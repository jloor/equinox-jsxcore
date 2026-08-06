"use server";

import { marked } from "marked";
import { Layout } from "../Shared/Layout.tsx";

export const head = {
    title: "Migrating a .NET reference app to a three-week-old view engine",
};

interface JourneyIndexModel {
    overview: string;
    chapters: { slug: string; title: string }[];
}

/**
 * The writeup's front page: a narrative overview, then the chapters.
 *
 * Both the overview and every chapter are rendered from this repository's own markdown by
 * `marked` - an npm package installed with `dotnet npm add` on a machine with no npm, and
 * executed here on the server inside the embedded JavaScript engine. The page is therefore
 * both the article and one of the things the article is claiming.
 */
export default function Index({ model }: { model: JourneyIndexModel }) {
    const chapters = model?.chapters ?? [];
    const overviewHtml = model?.overview ? (marked.parse(model.overview) as string) : "";

    return (
        <Layout>
            <article class="journey-chapter">
                <h1>Migrating a .NET reference app to a three-week-old view engine</h1>
                <p class="journey-standfirst">
                    Equinox Project → JsxCore → production, with limited expert knowledge of
                    .NET, the view engine, or the hosting.
                </p>

                {/* Source is this repository's committed markdown, read from disk - not user input. */}
                <div dangerouslySetInnerHTML={{ __html: overviewHtml }} />
            </article>

            <hr />

            <h2>The chapters</h2>
            <ol class="journey-toc">
                {chapters.map((c) => (
                    <li key={c.slug}>
                        <a href={`/journey/${c.slug}`}>{c.title}</a>
                    </li>
                ))}
            </ol>

            {chapters.length === 0 && <p class="text-muted">No chapters found on disk.</p>}

            <hr />
            <p>
                <a href="/">See the running application</a> ·{" "}
                <a href="https://github.com/jloor/equinox-jsxcore" target="_blank">
                    Source on GitHub
                </a>
            </p>
        </Layout>
    );
}
