import type { ComponentChildren } from "preact";

export function Layout({ title, children }: { title: string; children: ComponentChildren }) {
    return (
        <div class="page">
            <header>
                <nav>
                    <a href="/">Home</a> | <a href="/customers">Customers</a>
                </nav>
                <h1>{title}</h1>
            </header>
            <main>{children}</main>
            <footer>Equinox + JsxCore spike</footer>
        </div>
    );
}
