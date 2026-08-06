## Title

First `dotnet publish` on a clean checkout omits `node_modules` from the output

## Body

On a clean checkout the packages are restored *during* the publish and end up absent from
its output, so the published application cannot resolve them at runtime. A second publish
includes them.

[docs/build-and-deploy.md](https://github.com/davidwhitney/JsxCore/blob/main/docs/build-and-deploy.md)
says:

> Everything in your `dependencies` is copied into the publish output automatically

which is what happens on the second publish. The first is the one CI and container builds
always do.

### Reproduction

`.NET SDK 9.0.316`, `JsxCore 1.0.0`, in `mcr.microsoft.com/dotnet/sdk:9.0` with no Node and
no npm installed. Three packages in `dependencies`:

```json
"dependencies": {
  "marked": "^18.0.9",
  "dayjs": "^1.11.21",
  "highlight.js": "^11.11.1"
}
```

```bash
# clean checkout - no node_modules yet
rm -rf src/MyApp/node_modules

dotnet publish src/MyApp/MyApp.csproj -c Release -o /tmp/pub1
#   JsxCore: restoring with native: typescript, esbuild, marked, dayjs, highlight.js
#   JsxCore: fetching ...

ls /tmp/pub1/node_modules        # -> does not exist
ls src/MyApp/node_modules        # -> restored here: dayjs, highlight.js, marked, ...

# second publish, nothing to restore
dotnet publish src/MyApp/MyApp.csproj -c Release -o /tmp/pub2
ls /tmp/pub2/node_modules        # -> dayjs  highlight.js  marked   (dependencies only)
```

Same result with and without `--no-restore`. The deciding factor is whether `node_modules`
already existed when publish started.

### Why it bites

A Dockerfile or CI job is a clean checkout by definition, so it always hits the first case.
The build succeeds, the image builds, the app starts, and every view importing a package
returns 500:

```
JsxCore.JsxRenderException: JsxCore failed to server-render 'Journey/Chapter'.
 ---> JsxCore.JsxCoreException: JsxCore could not resolve the module 'marked' during
      server rendering. It was not found in node_modules. Searched:
```

The startup warning is genuinely helpful and is how I found it. Thank you for writing it:

> JsxCore: package.json declares marked, dayjs, highlight.js, which are not installed in
> /app. A view importing one will fail to render. Build again to restore them.

"Build again to restore them" is exactly right and exactly what a container image cannot do.

### Workaround

Copying them explicitly in the final stage:

```dockerfile
COPY --from=build /src/src/MyApp/node_modules ./node_modules
```

### Guess at the cause

It looks like the item group that carries `node_modules` into the publish output is
evaluated before the restore target populates the directory, so on the run that performs
the restore the glob matches nothing. I have not read the targets closely enough to be
confident, so treat that as a hint rather than a diagnosis.

Happy to open a PR if you can point me at the right target.

---

## Notes for me, not for the issue

- Verified on `main` docs and JsxCore 1.0.0 from NuGet.
- I originally wrote this up as "publish does not copy node_modules", which was wrong -
  it does, on the second run. Isolating clean-vs-warm was what made it a real report.
  Chapter 7 was corrected to match.
- Lead with the repro, not the theory. The cause guess is at the bottom and hedged
  because I did not verify it.
