"use server";

export default function Default({ model }: { model: { count: number } }) {
    return <aside class="summary">Summary: {model.count} customers</aside>;
}
