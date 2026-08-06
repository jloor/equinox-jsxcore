"use server";

import { marked } from "marked";
import { isServerRender } from "dotnet:rendering";
import { Layout } from "../Shared/Layout.tsx";

/**
 * Renders one chapter of the project writeup, server-side.
 *
 * This page is the proof for "npm packages work, with no npm installed". `marked` and
 * `highlight.js` are real packages from the public registry, added with
 *
 *     dotnet npm add marked dayjs highlight.js
 *
 * on a machine with no Node and no npm - JsxCore talks to the registry itself. They are then
 * imported here and executed **on the server**, inside the embedded JavaScript engine, in a
 * container image that also has neither.
 *
 * Server-rendered on purpose: the writeup is the content, so it should be readable without
 * JavaScript and indexable.
 */
export const head = (model: { title: string }) => ({
    title: `${model.title} - Equinox + JsxCore`,
});

export default function Chapter({ model }: { model: { slug: string; title: string; markdown: string } }) {
    if (!model.markdown) {
        return (
            <Layout>
                <h2>Chapter not found</h2>
                <p><a href="/journey">Back to the writeup</a></p>
            </Layout>
        );
    }

    const html = marked.parse(model.markdown) as string;

    // highlight.js runs in the BROWSER only, and deliberately so: it cannot be
    // server-rendered here. Importing it during the server pass throws
    //   Jint.ScriptPreparationException: Script nesting exceeds maximum depth of 256 levels
    // because the embedded JavaScript engine's parser has a nesting limit that
    // options.ServerRendering.MaxRecursionDepth does not reach - that setting guards
    // runtime recursion, not script preparation.
    //
    // A dynamic import inside this guard is never evaluated on the server, so the page
    // still server-renders its markup and the highlighter is fetched only by browsers.
    // It arrives from the import map as ES modules, with no bundler involved.
    if (!isServerRender()) {
        void import("highlight.js").then((m) => m.default.highlightAll());
    }

    return (
        <Layout>
            <p>
                <a href="/journey">&larr; All chapters</a>
            </p>
            <article
                class="journey-chapter"
                // The source is this repository's own committed markdown, read from disk by
                // JourneyLibrary - not user input. The slug is validated against a strict
                // pattern before any file is opened.
                dangerouslySetInnerHTML={{ __html: html }}
            />
            <hr />
            <p class="text-muted">
                <small>
                    Rendered server-side by <code>marked</code>, highlighted by{" "}
                    <code>highlight.js</code> — both installed with <code>dotnet npm add</code>,
                    on a machine with no Node and no npm.
                </small>
            </p>
        </Layout>
    );
}
