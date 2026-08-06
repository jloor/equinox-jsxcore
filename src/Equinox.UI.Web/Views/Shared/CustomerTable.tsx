import { useState } from "preact/hooks";
import type Equinox from "@/generated/types.d.ts";
import { formatDate } from "./CustomerForm.tsx";

type Customer = Equinox.Application.ViewModels.CustomerViewModel;
type HistoryEntry = Equinox.Application.EventSourcedNormalizers.CustomerHistoryData;

/**
 * The customer table and its history modal.
 *
 * This component runs TWICE under RenderMode.ServerAndClient: once on the server, where
 * its markup is written into the response for first paint and for clients without
 * JavaScript, and once in the browser, where the existing DOM is hydrated and the event
 * handlers come alive. One component, one file, both passes.
 *
 * The first render must be deterministic or hydration has to repair the DOM: no Date.now(),
 * no Math.random(), no reading window. useState returns its initial value on the server and
 * effects never run, so the modal renders closed in both passes and matches exactly.
 *
 * What this replaces, inherited verbatim from upstream Equinox:
 *
 *     $(".viewbutton").on("click", function () {
 *         $.ajax({ url: "/customer-management/customer-history/" + customerId })
 *             .done(function (data) {
 *                 var html = "<table class='table table-striped'>";
 *                 html += "<thead><th>Action</th>...</thead>";
 *                 for (var i = 0; i < data.length; i++) {
 *                     html += "<tr><td>" + c.action + "</td>...";
 *
 * String-concatenated HTML, untyped, and interpolating server data straight into markup.
 * HistoryEntry below is generated from the C# CustomerHistoryData, so the fields cannot
 * drift and JSX escapes the values.
 */
export function CustomerTable({ customers }: { customers: Customer[] }) {
    const [historyFor, setHistoryFor] = useState<Customer | null>(null);

    return (
        <>
            <div class="panel panel-default">
                <table class="table table-striped">
                    <thead>
                        <tr>
                            <th>Name</th>
                            <th>E-mail</th>
                            <th>Birth Date</th>
                            <th></th>
                        </tr>
                    </thead>
                    <tbody>
                        {customers.map((item) => (
                            <tr key={item.id}>
                                <td>{item.name}</td>
                                <td>{item.email}</td>
                                <td>{formatDate(item.birthDate)}</td>
                                <td>
                                    <a href={`/customer-management/edit-customer/${item.id}`} title="Edit" class="btn btn-warning">
                                        <span class="fas fa-edit"></span>
                                    </a>{" "}
                                    <a href={`/customer-management/customer-details/${item.id}`} title="Details" class="btn btn-primary">
                                        <span class="fas fa-search"></span>
                                    </a>{" "}
                                    <a href={`/customer-management/remove-customer/${item.id}`} title="Delete" class="btn btn-danger">
                                        <span class="fas fa-trash-alt"></span>
                                    </a>{" "}
                                    <button
                                        type="button"
                                        class="btn btn-info"
                                        title="History"
                                        onClick={() => setHistoryFor(item)}
                                    >
                                        <span class="fas fa-clock"></span>
                                    </button>
                                </td>
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>

            {historyFor && (
                <HistoryModal customer={historyFor} onClose={() => setHistoryFor(null)} />
            )}
        </>
    );
}

/**
 * Owned entirely by Preact rather than Bootstrap's jQuery modal plugin, so opening it is
 * component state rather than a `data-toggle` attribute reaching into global jQuery.
 */
function HistoryModal({ customer, onClose }: { customer: Customer; onClose: () => void }) {
    const [entries, setEntries] = useState<HistoryEntry[] | null>(null);
    const [failed, setFailed] = useState(false);

    // Only ever runs in the browser: the server pass renders with historyFor === null, so
    // this component is never reached during server rendering.
    if (entries === null && !failed) {
        fetch(`/customer-management/customer-history/${customer.id}`, { cache: "no-store" })
            .then((r) => (r.ok ? r.json() : Promise.reject(new Error(String(r.status)))))
            .then((data: HistoryEntry[]) => setEntries(data))
            .catch(() => setFailed(true));
    }

    return (
        <>
            <div class="modal-backdrop fade show" onClick={onClose}></div>
            <div class="modal fade show" style="display: block" role="dialog" aria-modal="true">
                <div class="modal-dialog modal-lg" role="document">
                    <div class="modal-content">
                        <div class="modal-header">
                            <h5 class="modal-title">Customer Data History — {customer.name}</h5>
                            <button type="button" class="close" aria-label="Close" onClick={onClose}>
                                <span aria-hidden="true">&times;</span>
                            </button>
                        </div>
                        <div class="modal-body">
                            {failed && <p class="text-danger">Could not load history.</p>}
                            {!failed && entries === null && <p>Loading…</p>}
                            {entries !== null && entries.length === 0 && <p>No history recorded.</p>}
                            {entries !== null && entries.length > 0 && <HistoryTable entries={entries} />}
                        </div>
                        <div class="modal-footer">
                            <button type="button" class="btn btn-secondary" onClick={onClose}>Close</button>
                        </div>
                    </div>
                </div>
            </div>
        </>
    );
}

/** Typed against the generated CustomerHistoryData. Renders identically server or client. */
export function HistoryTable({ entries }: { entries: HistoryEntry[] }) {
    return (
        <table class="table table-striped">
            <thead>
                <tr>
                    <th>Action</th>
                    <th>When</th>
                    <th>Name</th>
                    <th>E-mail</th>
                    <th>Birth Date</th>
                    <th>By User</th>
                </tr>
            </thead>
            <tbody>
                {entries.map((e, i) => (
                    <tr key={`${e.id}-${i}`}>
                        <td>{e.action}</td>
                        <td>{e.timestamp}</td>
                        <td>{e.name}</td>
                        <td>{e.email}</td>
                        <td>{e.birthDate}</td>
                        <td>{e.who}</td>
                    </tr>
                ))}
            </tbody>
        </table>
    );
}
