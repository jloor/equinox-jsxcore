"use server";

export default function Default({ model }: { model: { Count: number } }) {
    return <aside class="summary">Summary: {model.Count} customers</aside>;
}
