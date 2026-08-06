# Runtime image for the Equinox -> JsxCore demo.
#
# Replaces src/Equinox.UI.Web/Dockerfile, which upstream still pins to .NET 6 for a
# project targeting net9.0 - it cannot build this codebase at all.
#
# Build context is the REPOSITORY ROOT, not src/:
#   podman build -t ghcr.io/jloor/equinox-jsxcore:latest .
#
# The build stage is the plain .NET SDK image with no Node and no npm. JsxCore sources
# its own TypeScript compiler and esbuild from the npm registry during `dotnet build`,
# so the build needs network egress to registry.npmjs.org but never a Node runtime.
# That is the whole "no Node required" claim, and keeping this image Node-free is what
# makes it true rather than merely untested.

FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Fail loudly rather than silently invalidating the no-Node result.
RUN if command -v node >/dev/null || command -v npm >/dev/null; then \
        echo "FATAL: node/npm present in build image" >&2; exit 1; \
    fi

# Restore against the solution so project references resolve.
COPY Equinox.sln ./
COPY src/ ./src/
COPY tests/ ./tests/
RUN dotnet restore src/Equinox.UI.Web/Equinox.UI.Web.csproj

# JsxCore compiles the .tsx views here and emits them into the publish output.
RUN dotnet publish src/Equinox.UI.Web/Equinox.UI.Web.csproj \
        -c Release -o /app/publish --no-restore

# ---------------------------------------------------------------------------------

FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS final
WORKDIR /app

COPY --from=build /app/publish .

# Served at /version so a deploy can be verified as "the new build is live", not merely
# "something responds". Defaults to "unknown" for local builds.
ARG GIT_SHA=unknown
ENV BUILD_SHA=$GIT_SHA

# SQLite lives on a mounted volume. On Bunny Magic Containers volumes bind to nodes and
# can come back empty after a reschedule, so the app must survive an empty disk -
# DbMigrationHelpers.EnsureSeedData() recreates and reseeds on startup, which is why the
# demo is designed to be resettable (D3).
RUN mkdir -p /data
ENV ConnectionStrings__DefaultConnection="Data Source=/data/equinox.db"

# Upstream branched SQLite/SqlServer on IsDevelopment(). The provider is now explicit,
# so the container runs SQLite without pretending to be a development environment.
ENV DatabaseProvider="Sqlite"

# "Docker" rather than "Production", and it is load-bearing. DbMigrationHelpers gates all
# migration and seeding behind:
#     if (env.IsDevelopment() || env.IsEnvironment("Docker"))
# Under Production nothing creates the schema, so the app boots happily, reports
# "Application started", and then returns HTTP 500 on every request against a database
# that was never created. Equinox anticipated containers with this environment name.
ENV ASPNETCORE_ENVIRONMENT="Docker"

# '*' binds IPv4 and IPv6. '0.0.0.0' is IPv4-only, which silently hangs any client that
# resolves localhost to ::1 - the connection is accepted by the port forwarder and then
# never answered, which looks like a hung app rather than a binding mismatch.
ENV ASPNETCORE_URLS="http://*:8080"
EXPOSE 8080

# The project writeup, served at /journey and rendered from markdown by the `marked` npm
# package at request time. Copied from the build context - the build stage only copies the
# solution, src/ and tests/, so it has no journey/ of its own.
# npm packages the views import at RUNTIME.
#
# The docs say publish copies these for you; it did not, and the failure is a 500 on any
# page importing one. JsxCore does warn clearly at startup:
#
#   JsxCore: package.json declares marked, dayjs, highlight.js, which are not installed
#   in /app. A view importing one will fail to render.
#
# Copied from the build stage, where `dotnet publish` restored them from the registry
# without npm ever being installed.
COPY --from=build /src/src/Equinox.UI.Web/node_modules ./node_modules

COPY journey/chapters ./journey/chapters

ENTRYPOINT ["dotnet", "Equinox.UI.Web.dll"]
