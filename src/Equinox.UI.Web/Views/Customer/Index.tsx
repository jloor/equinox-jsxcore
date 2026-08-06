"use server";

import { Layout } from "../Shared/Layout.tsx";
import { formatDate, type Customer } from "../Shared/CustomerForm.tsx";

export const head = { title: "Customer Management - Equinox Project" };

/**
 * Replaces Customer/Index.cshtml.
 *
 * The controller returns IEnumerable<CustomerViewModel>, which arrives as a JSON array.
 * Razor's @Html.DisplayNameFor(model => model.Name) read the [DisplayName] attributes;
 * JsxCore's generated types carry property names but not display metadata, so the column
 * headers are literals here.
 *
 * Routes are the controller's explicit attribute routes (/customer-management/*), not
 * the conventional {controller}/{action} pattern asp-action generated.
 */
export default function Index({ model }: { model: Customer[] }) {
    const customers = model ?? [];

    return (
        <Layout>
            <div>
                <h2>Customer Management</h2>
            </div>
            <hr />

            <div class="row">
                <div class="col-md-12">
                    <div>
                        <div class="pull-left">
                            <a href="/customer-management/register-new" class="btn btn-primary">
                                <span title="Register New" class="fas fa-plus"></span> Register New
                            </a>
                        </div>
                    </div>
                </div>
            </div>
            <br />

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
                                    <a
                                        href={`/customer-management/edit-customer/${item.id}`}
                                        title="Edit"
                                        class="btn btn-warning"
                                    >
                                        <span class="fas fa-edit"></span>
                                    </a>{" "}
                                    <a
                                        href={`/customer-management/customer-details/${item.id}`}
                                        title="Details"
                                        class="btn btn-primary"
                                    >
                                        <span class="fas fa-search"></span>
                                    </a>{" "}
                                    <a
                                        href={`/customer-management/remove-customer/${item.id}`}
                                        title="Delete"
                                        class="btn btn-danger"
                                    >
                                        <span class="fas fa-trash-alt"></span>
                                    </a>{" "}
                                    <button
                                        type="button"
                                        class="btn btn-info viewbutton"
                                        title="History"
                                        data-id={item.id}
                                        data-toggle="modal"
                                        data-target="#customerHistory"
                                    >
                                        <span class="fas fa-clock"></span>
                                    </button>
                                </td>
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>

            <HistoryModal />
        </Layout>
    );
}

/**
 * The history modal and its jQuery handler lived in @section scripts, which JsxCore has
 * no equivalent for - there are no Razor sections. The script is inlined at the point of
 * use instead, which keeps it next to the markup it drives.
 */
function HistoryModal() {
    const script = `
        $(".viewbutton").on("click", function () {
            var customerId = $(this).data('id');
            $.ajax({ url: "/customer-management/customer-history/" + customerId, cache: false })
                .done(function (data) {
                    var html = "<table class='table table-striped'>";
                    html += "<thead><th>Action</th><th>When</th><th>Id</th><th>Name</th>";
                    html += "<th>E-mail</th><th>Birth Date</th><th>By User</th></thead>";
                    for (var i = 0; i < data.length; i++) {
                        var c = data[i];
                        html += "<tr><td>" + c.action + "</td><td>" + c.timestamp + "</td>";
                        html += "<td>" + c.id + "</td><td>" + c.name + "</td>";
                        html += "<td>" + c.email + "</td><td>" + c.birthDate + "</td>";
                        html += "<td>" + c.who + "</td></tr>";
                    }
                    html += "</table>";
                    $("#customerHistoryData").html(html);
                });
        });
    `;

    return (
        <>
            <style>{".modal-lg { max-width: 80%; }"}</style>
            <div
                class="modal fade"
                id="customerHistory"
                tabindex={-1}
                role="dialog"
                aria-labelledby="historyModalLabel"
                aria-hidden="true"
            >
                <div class="modal-dialog modal-lg" role="document">
                    <div class="modal-content">
                        <div class="modal-header">
                            <h5 class="modal-title" id="historyModalLabel">Customer Data History</h5>
                            <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                                <span aria-hidden="true">&times;</span>
                            </button>
                        </div>
                        <div class="modal-body">
                            <p id="customerHistoryData"></p>
                        </div>
                        <div class="modal-footer">
                            <button type="button" class="btn btn-secondary" data-dismiss="modal">Close</button>
                        </div>
                    </div>
                </div>
            </div>
            <script dangerouslySetInnerHTML={{ __html: script }} />
        </>
    );
}
