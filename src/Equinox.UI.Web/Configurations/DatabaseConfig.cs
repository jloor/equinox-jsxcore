using Equinox.Infra.Data.Context;
using Microsoft.EntityFrameworkCore;

namespace Equinox.UI.Web.Configurations
{
    public static class DatabaseConfig
    {
        public static WebApplicationBuilder AddDatabaseConfiguration(this WebApplicationBuilder builder)
        {
            if (builder == null) throw new ArgumentNullException(nameof(builder));

            var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");

            // Upstream branched on IsDevelopment(): SQLite in Development, SQL Server
            // everywhere else. That made Production undeployable here - there is no SQL
            // Server on free-tier container hosting, and appsettings.json carries no
            // connection string at all, so a Production container had nothing to connect to.
            //
            // The provider is now explicit configuration rather than an inference from the
            // environment name. Set "DatabaseProvider": "SqlServer" to restore the old
            // behaviour; the container sets Sqlite.
            var provider = builder.Configuration["DatabaseProvider"] ?? "Sqlite";

            if (string.Equals(provider, "SqlServer", StringComparison.OrdinalIgnoreCase))
            {
                builder.Services.AddDbContext<EquinoxContext>(options =>
                    options.UseSqlServer(connectionString));

                builder.Services.AddDbContext<EventStoreSqlContext>(options =>
                    options.UseSqlServer(connectionString));

                return builder;
            }

            builder.Services.AddDbContext<EquinoxContext>(options =>
                options.UseSqlite(connectionString));

            builder.Services.AddDbContext<EventStoreSqlContext>(options =>
                options.UseSqlite(connectionString));

            return builder;
        }


        public static WebApplication UseDbSeed(this WebApplication app)
        {
            ArgumentNullException.ThrowIfNull(app);

            DbMigrationHelpers.EnsureSeedData(app).Wait();

            return app;
        }
    }
}