using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Web.Script.Serialization;

namespace MyPinball
{
    // One machine from the Virtual Pinball Spreadsheet database (virtualpinballspreadsheet.github.io),
    // reduced to what the launcher needs. Only machines with at least one VPX table are kept.
    public class VpsGame
    {
        public string Id;
        public string Name;
        public string Maker;
        public int Year;
        public string Type;         // SS = solid state, EM = electro-mechanical, PM = pure mechanical, ...
        public string Mpu;          // e.g. "Williams WPC-95"
        public string Designers;
        public string Themes;
        public string TableUrl;     // download page of the best VPX table
        public string TableBy;      // its authors and version
        public int TableCount;      // VPX tables listed for this machine
        public string[] Roms = new string[0];
        public Dictionary<string, string> RomUrls = new Dictionary<string, string>();
        public string B2sUrl;
        internal string Key;        // lower-case letters/digits of name + maker + year, for searching
    }

    public static class VpsDb
    {
        static List<VpsGame> games;
        static readonly Regex RomName = new Regex("^[A-Za-z0-9_]{3,}$");

        public static int Load(string path)
        {
            var json = new JavaScriptSerializer { MaxJsonLength = int.MaxValue, RecursionLimit = 200 };
            var all = (object[])json.DeserializeObject(File.ReadAllText(path, Encoding.UTF8));
            var list = new List<VpsGame>();
            foreach (Dictionary<string, object> g in all)
            {
                var table = BestTable(Items(g, "tableFiles"));
                if (table == null) continue;
                var game = new VpsGame
                {
                    Id = Str(g, "id"), Name = Str(g, "name").Trim(), Maker = Str(g, "manufacturer"),
                    Year = (int)Num(g, "year"), Type = Str(g, "type"), Mpu = Str(g, "MPU"),
                    Designers = string.Join(", ", Strings(g, "designers")), Themes = string.Join(", ", Strings(g, "theme")),
                    TableUrl = FirstUrl(table), TableCount = Items(g, "tableFiles").Count(t => Str(t, "tableFormat") == "VPX")
                };
                var by = string.Join(", ", Strings(table, "authors").Take(3));
                var version = Str(table, "version");
                game.TableBy = version.Length > 0 ? by + " v" + version.TrimStart('v', 'V') : by;
                var roms = new List<string>();
                foreach (var r in Items(g, "romFiles"))
                {
                    // "version" holds the ROM set name (afm_113b); skip free-text entries.
                    var name = Str(r, "version").Trim();
                    if (!RomName.IsMatch(name) || roms.Contains(name)) continue;
                    roms.Add(name);
                    var url = FirstUrl(r);
                    if (url != null) game.RomUrls[name] = url;
                }
                game.Roms = roms.ToArray();
                var b2s = Items(g, "b2sFiles").OrderByDescending(b => Num(b, "updatedAt")).FirstOrDefault();
                if (b2s != null) game.B2sUrl = FirstUrl(b2s);
                game.Key = Squash(game.Name + " " + game.Maker + " " + game.Year);
                list.Add(game);
            }
            games = list.OrderBy(x => x.Name, StringComparer.OrdinalIgnoreCase).ThenBy(x => x.Year).ToList();
            return games.Count;
        }

        // Every word of the query must appear; titles that start with it come first.
        public static VpsGame[] Search(string query, int max)
        {
            if (games == null) return new VpsGame[0];
            var words = (query ?? "").ToLowerInvariant().Split(new[] { ' ', ',', ':', '-', '\'' }, StringSplitOptions.RemoveEmptyEntries)
                .Select(Squash).Where(w => w.Length > 0).ToArray();
            if (words.Length == 0) return new VpsGame[0];
            var whole = Squash(query);
            return games.Where(g => words.All(w => g.Key.Contains(w)))
                .OrderBy(g => Squash(g.Name).StartsWith(whole) ? 0 : Squash(g.Name).Contains(whole) ? 1 : 2)
                .ThenByDescending(g => g.TableCount)
                .Take(max).ToArray();
        }

        // Prefer VPin Workshop builds, then originals over mods, then the most recently updated.
        static Dictionary<string, object> BestTable(IEnumerable<Dictionary<string, object>> tables)
        {
            return tables
                .Where(t => Str(t, "tableFormat") == "VPX" && FirstUrl(t) != null && !Strings(t, "features").Contains("VPU Patch"))
                .OrderByDescending(t => IsVpw(t) ? 1 : 0)
                .ThenBy(t => Strings(t, "features").Contains("MOD") ? 1 : 0)
                .ThenByDescending(t => Num(t, "updatedAt"))
                .FirstOrDefault();
        }

        static bool IsVpw(Dictionary<string, object> t)
        {
            return Strings(t, "authors").Any(a => a.IndexOf("VPW", StringComparison.OrdinalIgnoreCase) >= 0)
                || Str(t, "comment").IndexOf("VPW", StringComparison.OrdinalIgnoreCase) >= 0;
        }

        static string Squash(string s)
        {
            var sb = new StringBuilder();
            foreach (var c in (s ?? "").ToLowerInvariant()) if (char.IsLetterOrDigit(c) || c == ' ') sb.Append(c);
            return sb.ToString();
        }

        static string Str(Dictionary<string, object> d, string key)
        {
            object v;
            return d.TryGetValue(key, out v) && v != null ? v.ToString() : "";
        }

        static long Num(Dictionary<string, object> d, string key)
        {
            object v;
            if (!d.TryGetValue(key, out v) || v == null) return 0;
            try { return Convert.ToInt64(v); } catch { return 0; }
        }

        static IEnumerable<Dictionary<string, object>> Items(Dictionary<string, object> d, string key)
        {
            object v;
            if (!d.TryGetValue(key, out v) || !(v is IEnumerable) || v is string) return new Dictionary<string, object>[0];
            return ((IEnumerable)v).OfType<Dictionary<string, object>>();
        }

        static string[] Strings(Dictionary<string, object> d, string key)
        {
            object v;
            if (!d.TryGetValue(key, out v) || !(v is IEnumerable) || v is string) return new string[0];
            return ((IEnumerable)v).OfType<object>().Select(x => x.ToString()).ToArray();
        }

        static string FirstUrl(Dictionary<string, object> d)
        {
            var u = Items(d, "urls").Select(x => Str(x, "url")).FirstOrDefault(x => x.Length > 0);
            return u;
        }
    }
}
