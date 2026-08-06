using System.Text.RegularExpressions;

namespace Equinox.UI.Web.ViewServices;

public sealed record JourneyChapter(string Slug, string Title);

/// <summary>
/// Serves the project's own writeup from <c>journey/chapters/*.md</c>.
///
/// Exposed to .tsx views as a JsxCore global so a view can read the markdown and render it
/// with the <c>marked</c> npm package - server-side, inside Jint, in an image with no Node
/// and no npm installed.
/// </summary>
public sealed class JourneyLibrary
{
    private readonly string _root;

    public JourneyLibrary(IWebHostEnvironment env)
    {
        // ContentRootPath is src/Equinox.UI.Web when running from source and /app in the
        // container, so both layouts are probed rather than assumed.
        var candidates = new[]
        {
            Path.Combine(env.ContentRootPath, "journey", "chapters"),
            Path.Combine(env.ContentRootPath, "..", "..", "journey", "chapters"),
        };

        _root = candidates.FirstOrDefault(Directory.Exists) ?? candidates[0];
    }

    /// <summary>Chapters in filename order, which is chronological.</summary>
    public JourneyChapter[] List()
    {
        if (!Directory.Exists(_root)) return [];

        return Directory.GetFiles(_root, "*.md")
            .OrderBy(f => f)
            .Select(f => new JourneyChapter(
                Path.GetFileNameWithoutExtension(f),
                TitleOf(f)))
            .ToArray();
    }

    /// <summary>The narrative front page, rendered above the chapter list.</summary>
    public string Overview()
    {
        var path = Path.Combine(_root, "..", "overview.md");
        return File.Exists(path) ? File.ReadAllText(path) : string.Empty;
    }

    /// <summary>Raw markdown for one chapter, or empty if the slug is unknown.</summary>
    public string Read(string slug)
    {
        // Slug comes from the URL. Anything but the expected shape is rejected outright
        // rather than sanitised, so no traversal sequence can reach the filesystem.
        if (string.IsNullOrWhiteSpace(slug) || !Regex.IsMatch(slug, @"^[a-z0-9][a-z0-9-]{0,63}$"))
            return string.Empty;

        var path = Path.Combine(_root, slug + ".md");
        return File.Exists(path) ? File.ReadAllText(path) : string.Empty;
    }

    private static string TitleOf(string path)
    {
        foreach (var line in File.ReadLines(path))
        {
            if (line.StartsWith("# "))
                return line[2..].Trim();
        }
        return Path.GetFileNameWithoutExtension(path);
    }
}
