"use server";

import { Layout } from "../Shared/Layout.tsx";

export const head = { title: "Equinox + JsxCore - Welcome" };

const REPO = "https://github.com/jloor/equinox-jsxcore";

export default function Index() {
    return (
        <Layout>
            <div class="alert alert-info" role="alert">
                <strong>This is a demo.</strong> The database resets periodically — it runs on
                free-tier infrastructure with a single instance and a small volume. Create,
                edit and delete customers freely; nothing here is permanent.
            </div>

            <div>
                <img src="/images/banner1.svg" alt="ASP.NET" class="img-responsive" />
                <br />
                <br />
            </div>

            <h2>The Equinox Project, with every view converted to JSX</h2>
            <p class="lead">
                This is <a href="https://github.com/EduardoPires/EquinoxProject" target="_blank">Eduardo Pires'
                Equinox Project</a> — a DDD/CQRS/Event Sourcing reference application — with its
                Razor views replaced by TypeScript components rendered by{" "}
                <a href="https://github.com/davidwhitney/JsxCore" target="_blank">JsxCore</a>.
                Everything you can click is server-rendered from a <code>.tsx</code> file.
            </p>
            <p>
                The interesting part was not the JSX. It was the ten things the migration plan got
                wrong about the codebase, a three-tier authorization model nobody had documented,
                and three deploy failures that each produced a completely clean startup log.{" "}
                <a href={`${REPO}/tree/master/journey`}>The whole thing is written up here</a>,
                including the mistakes.
            </p>

            <hr />

            <div class="row">
                <div class="col-md-4">
                    <h3>Architecture</h3>
                    <p class="text-muted">
                        <small>Unchanged from the original — this migration only touched the presentation layer.</small>
                    </p>
                    <ul>
                        <li>Full architecture with responsibility separation concerns, SOLID and Clean Code</li>
                        <li>DDD Concepts - Layers and Domain Model Pattern</li>
                        <li>CQRS - Command Query Responsibility Segregation</li>
                        <li>Event Sourcing</li>
                    </ul>
                </div>

                <div class="col-md-4">
                    <h3>Technologies</h3>
                    <ul>
                        <li>.NET 9.0</li>
                        <li>ASP.NET MVC 9.0</li>
                        <li>ASP.NET Identity 9.0</li>
                        <li>EF Core 9.0 — SQLite</li>
                        <li><strong>JsxCore</strong> — TSX views, Preact</li>
                        <li>AutoMapper</li>
                        <li>FluentValidator</li>
                        <li>MediatR</li>
                    </ul>
                </div>

                <div class="col-md-4">
                    <h3>What was verified</h3>
                    <ul>
                        <li>
                            Built with <strong>no Node.js and no npm</strong> — asserted in CI, in a
                            container where both are absent
                        </li>
                        <li>Every view is a <code>.tsx</code> file, server-rendered</li>
                        <li>Full customer CRUD, antiforgery enforced</li>
                        <li>
                            0 build warnings — 8 high-severity advisories patched along the way,
                            including CVE-2026-26171
                        </li>
                    </ul>
                </div>
            </div>

            <hr />

            <div class="row">
                <div class="col-md-8">
                    <h4>Where the Razor still is</h4>
                    <p>
                        The ASP.NET Identity pages are still Razor, deliberately. Logging in is
                        required to exercise Customer CRUD, and reimplementing authentication in a
                        1.0.0 view engine was not the point. Two view engines run side by side in
                        this app — that is the honest outcome of the migration, not a workaround.
                    </p>
                </div>
                <div class="col-md-4">
                    <h4>Links</h4>
                    <ul>
                        <li><a href={REPO}>Source and writeup</a></li>
                        <li><a href="https://github.com/EduardoPires/EquinoxProject" target="_blank">Equinox Project</a> (MIT)</li>
                        <li><a href="https://github.com/davidwhitney/JsxCore" target="_blank">JsxCore</a> (MIT)</li>
                    </ul>
                </div>
            </div>
        </Layout>
    );
}
