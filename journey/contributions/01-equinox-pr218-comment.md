# Draft: comment on EduardoPires/EquinoxProject#218

**Target:** https://github.com/EduardoPires/EquinoxProject/pull/218
**Type:** comment on an existing (stalled) Dependabot PR — not a competing PR
**Status:** DRAFT — not posted

---

Heads up that this bump doesn't fully clear the advisories — `9.0.15` is the first patched
version for one of them, but five others apply to that release too.

Measured against `master` (`fde9a95`) by restoring `Equinox.Infra.Data` and collecting the
distinct `NU1903` advisory IDs:

| `System.Security.Cryptography.Xml` | Distinct high-severity advisories |
|---|---|
| `9.0.3` (current `master`) | **8** |
| `9.0.15` (this PR) | **5** |
| `9.0.18` | **0** |

Still present at `9.0.15`:

```
GHSA-23rf-6693-g89p
GHSA-8q5v-6pqq-x66h
GHSA-cvvh-rhrc-wg4q
GHSA-g8r8-53c2-pm3f
GHSA-mmjf-rqrv-855v
```

Bumping the same two packages to `9.0.18` restores cleanly and reports zero advisories.
`System.Formats.Asn1` does **not** need to change — I checked, since `Xml` and `Pkcs` have
a version constraint between them:

```diff
-<PackageReference Include="System.Security.Cryptography.Pkcs" Version="9.0.3" />
-<PackageReference Include="System.Security.Cryptography.Xml" Version="9.0.3" />
+<PackageReference Include="System.Security.Cryptography.Pkcs" Version="9.0.18" />
+<PackageReference Include="System.Security.Cryptography.Xml" Version="9.0.18" />
```

One caveat worth knowing: bumping `Xml` **alone** fails the restore rather than warning,
because the project treats `NU1605` as an error:

```
error NU1605: Detected package downgrade: System.Security.Cryptography.Pkcs from 9.0.18 to 9.0.3
  Equinox.Infra.Data -> System.Security.Cryptography.Xml 9.0.18 -> Pkcs (>= 9.0.18)
  Equinox.Infra.Data -> System.Security.Cryptography.Pkcs (>= 9.0.3)
```

Both have to move together, which this PR already does — it just needs the higher version.

To reproduce:

```bash
git clone --depth 1 https://github.com/EduardoPires/EquinoxProject.git
cd EquinoxProject
sed -i 's|Cryptography.Pkcs" Version="9.0.3"|Cryptography.Pkcs" Version="9.0.18"|; \
        s|Cryptography.Xml" Version="9.0.3"|Cryptography.Xml" Version="9.0.18"|' \
    src/Equinox.Infra.Data/Equinox.Infra.Data.csproj
dotnet restore src/Equinox.Infra.Data/Equinox.Infra.Data.csproj 2>&1 | grep -oP 'advisories/\K\S+' | sort -u
# no output at 9.0.18; five GHSA ids at 9.0.15
```

Separately — and probably why this went unnoticed — CI on `master` currently can't run:
`.github/workflows/dotnet-core.yml` uses `actions/checkout@v2` and `actions/setup-dotnet@v1`,
both of which now fail on GitHub-hosted runners. Happy to open a separate PR bumping those
to `@v4` if that's useful.

Thanks for the project — I've been using it as the base for a view-engine migration
experiment and it's been a genuinely good reference codebase to work in.

---

## Notes for me, not for the comment

- Tone: additive to Dependabot's PR, not a competing one. The maintainer's cheapest action
  is to retarget the existing PR, so make that the obvious next step.
- Do **not** open a rival PR first. If asked, offer one.
- The CI observation is offered, not demanded — it's a separate concern and shouldn't
  dilute the security point.
- Verified on `fde9a95`, .NET SDK 9.0.316, in `mcr.microsoft.com/dotnet/sdk:9.0`.
