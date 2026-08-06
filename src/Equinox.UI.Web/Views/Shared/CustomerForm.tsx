import { Antiforgery, Validation } from "dotnet:globals";

/**
 * Models arrive serialised to camelCase, following the app's JsonSerializerOptions
 * rather than the .NET property names. CustomerViewModel's Name/Email/BirthDate become
 * name/email/birthDate here. Getting this wrong renders nothing and errors nothing.
 *
 * Form field NAMES stay PascalCase - those are bound by ASP.NET model binding on POST,
 * which is a different mechanism than the JSON the view receives.
 */
export interface Customer {
    id: string;
    name: string;
    email: string;
    birthDate: string;
}

/** Replaces <vc:summary /> - the Summary ViewComponent Equinox embeds in Create/Edit/Delete. */
export function ValidationSummary() {
    if (!Validation.hasErrors()) return null;

    return (
        <div class="alert alert-danger">
            <button type="button" class="close" data-dismiss="alert">×</button>
            <h3 id="msgRetorno">Oops! Something went wrong:</h3>
            <div class="text-danger">
                <ul>
                    {Validation.errors().map((e: string) => <li>{e}</li>)}
                </ul>
            </div>
        </div>
    );
}

/** Replaces @Html.AntiForgeryToken(), which Razor's form tag helper added automatically. */
export function AntiforgeryField() {
    return <input type="hidden" name={Antiforgery.fieldName()} value={Antiforgery.token()} />;
}

/** Replaces <span asp-validation-for="Field" class="text-danger"></span>. */
function FieldErrors({ field }: { field: string }) {
    const errors = Validation.for(field);
    if (errors.length === 0) return null;
    return <span class="text-danger">{errors.join(" ")}</span>;
}

/**
 * Replaces the asp-for label/input/validation triplet. The [DisplayName] attributes on
 * CustomerViewModel ("Name", "E-mail", "Birth Date") drove Razor's labels; JsxCore's
 * generated types carry property names but not display metadata, so the labels are
 * passed in explicitly.
 */
function Field({
    name,
    label,
    value,
    type = "text",
}: {
    name: string;
    label: string;
    value?: string;
    type?: string;
}) {
    return (
        <div class="form-group">
            <label for={name} class="col-md-2 control-label">{label}</label>
            <div class="col-md-10">
                <input id={name} name={name} type={type} value={value} class="form-control" />
                <FieldErrors field={name} />
            </div>
        </div>
    );
}

/** The Name/Email/BirthDate block shared by Create.tsx and Edit.tsx. */
export function CustomerFields({ model }: { model: Partial<Customer> }) {
    return (
        <>
            <Field name="Name" label="Name" value={model.name} />
            <Field name="Email" label="E-mail" value={model.email} />
            <Field name="BirthDate" label="Birth Date" type="date" value={formatDate(model.birthDate)} />
        </>
    );
}

/** Replaces [DisplayFormat(DataFormatString = "{0:yyyy-MM-dd}")]. */
export function formatDate(value?: string): string {
    if (!value) return "";
    return value.split("T")[0];
}
