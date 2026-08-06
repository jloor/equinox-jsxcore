using Equinox.Infra.CrossCutting.Identity.API;
using Equinox.Infra.CrossCutting.Identity.Data;
using Equinox.Infra.CrossCutting.Identity.User;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.IdentityModel.Tokens;
using System;
using System.Text;

namespace Equinox.Infra.CrossCutting.Identity.Configuration
{
    public static class AspNetIdentityConfig
    {
        public static WebApplicationBuilder AddApiIdentityConfiguration(this WebApplicationBuilder builder)
        {
            builder.AddIdentityDbContext()
                   .AddIdentityApiSupport()
                   .AddJwtSupport()
                   .AddAspNetUserSupport();

            return builder;
        }

        public static WebApplicationBuilder AddWebIdentityConfiguration(this WebApplicationBuilder builder)
        {
            builder.AddIdentityDbContext()
                   .AddIdentityWebUISupport()
                   .AddAspNetUserSupport()
                   .AddSocialAuthenticationSupport();

            return builder;
        }

        private static WebApplicationBuilder AddIdentityDbContext(this WebApplicationBuilder builder)
        {
            var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");

            // Mirrors Equinox.UI.Web/Configurations/DatabaseConfig.cs. Upstream inferred the
            // provider from the environment name, which left the Identity context on SQL
            // Server while the other two contexts ran SQLite. The mismatch surfaced as
            // "PendingModelChangesWarning: The model for context 'EquinoxIdentityContext'
            // has pending changes" and crashed the container on startup - a message that
            // points at migrations rather than at the provider that actually caused it.
            //
            // Set "DatabaseProvider": "SqlServer" to restore the previous behaviour.
            var provider = builder.Configuration["DatabaseProvider"] ?? "Sqlite";

            if (string.Equals(provider, "SqlServer", StringComparison.OrdinalIgnoreCase))
            {
                builder.Services.AddDbContext<EquinoxIdentityContext>(options =>
                        options.UseSqlServer(connectionString));

                return builder;
            }

            builder.Services.AddDbContext<EquinoxIdentityContext>(options =>
                    options.UseSqlite(connectionString));

            return builder;
        }

        private static WebApplicationBuilder AddIdentityApiSupport(this WebApplicationBuilder builder)
        {
            builder.Services.AddIdentityApiEndpoints<IdentityUser>()
                            .AddRoles<IdentityRole>()
                            .AddEntityFrameworkStores<EquinoxIdentityContext>()
                            .AddSignInManager()
                            .AddRoleManager<RoleManager<IdentityRole>>()
                            .AddDefaultTokenProviders();

            return builder;
        }

        private static WebApplicationBuilder AddIdentityWebUISupport(this WebApplicationBuilder builder)
        {
            builder.Services.AddIdentity<IdentityUser, IdentityRole>()
                    .AddEntityFrameworkStores<EquinoxIdentityContext>()
                    .AddDefaultTokenProviders()
                    .AddDefaultUI();

            return builder;
        }

        private static WebApplicationBuilder AddJwtSupport(this WebApplicationBuilder builder)
        {
            var appSettingsSection = builder.Configuration.GetSection("AppSettings");
            builder.Services.Configure<AppJwtSettings>(appSettingsSection);

            var appSettings = appSettingsSection.Get<AppJwtSettings>();
            var key = Encoding.ASCII.GetBytes(appSettings.SecretKey);

            builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
                .AddJwtBearer(options =>
                {
                    options.RequireHttpsMetadata = true;
                    options.SaveToken = true;
                    options.TokenValidationParameters = new TokenValidationParameters
                    {
                        ValidateIssuerSigningKey = true,
                        IssuerSigningKey = new SymmetricSecurityKey(key),
                        ValidateIssuer = true,
                        ValidateAudience = true,
                        ValidAudience = appSettings.Audience,
                        ValidIssuer = appSettings.Issuer
                    };
                });

            return builder;
        }

        public static WebApplicationBuilder AddAspNetUserSupport(this WebApplicationBuilder builder)
        {
            builder.Services.AddSingleton<IHttpContextAccessor, HttpContextAccessor>();
            builder.Services.AddScoped<IAspNetUser, AspNetUser>();

            return builder;
        }

        public static WebApplicationBuilder AddSocialAuthenticationSupport(this WebApplicationBuilder builder)
        {
            if (builder == null) throw new ArgumentNullException(nameof(builder));

            // Registered only when credentials are actually configured.
            //
            // Upstream registered both providers unconditionally. Their options are validated
            // lazily, on the first request rather than at startup, so a deployment without
            // credentials starts cleanly, logs nothing, and then throws
            // "ArgumentNullException: Value cannot be null. (Parameter 'AppId')" on EVERY
            // request - including inside the error handler, which then fails too.
            //
            // The credentials only ever existed in appsettings.Development.json (as
            // "SetYourDataHere" placeholders), so any real deployment hit this.
            var facebookAppId = builder.Configuration["Authentication:Facebook:AppId"];
            var facebookSecret = builder.Configuration["Authentication:Facebook:AppSecret"];
            var googleClientId = builder.Configuration["Authentication:Google:ClientId"];
            var googleSecret = builder.Configuration["Authentication:Google:ClientSecret"];

            var authentication = builder.Services.AddAuthentication();

            if (!string.IsNullOrWhiteSpace(facebookAppId) && !string.IsNullOrWhiteSpace(facebookSecret))
            {
                authentication.AddFacebook(o =>
                {
                    o.AppId = facebookAppId;
                    o.AppSecret = facebookSecret;
                });
            }

            if (!string.IsNullOrWhiteSpace(googleClientId) && !string.IsNullOrWhiteSpace(googleSecret))
            {
                authentication.AddGoogle(googleOptions =>
                {
                    googleOptions.ClientId = googleClientId;
                    googleOptions.ClientSecret = googleSecret;
                });
            }

            return builder;
        }
    }
}