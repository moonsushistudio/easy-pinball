using System;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;

namespace MyPinball
{
    public class VpxInfo
    {
        public string GameName;     // cGameName from the script (a PinMAME ROM name for ROM based tables)
        public bool UsesPinMame;    // script loads VPinMAME, so the ROM zip is required
        public string DmdOption;    // table option that shows/hides the DMD drawn inside the table
        public string DmdOffValue;  // value of that option meaning "off"
    }

    public static class VpxScan
    {
        // At the start of a line, so commented-out choices are skipped: Funhouse has
        // 'Const cGameName="fh_L9" above the Const cGameName="fh_905h" it really uses.
        static readonly Regex GameName = new Regex(
            "^[ \\t]*(?:(?:Public|Private|Dim|Const)[ \\t]+)?cGameName[ \\t]*=[ \\t]*\"([A-Za-z0-9_]+)\"",
            RegexOptions.IgnoreCase | RegexOptions.Multiline);
        static readonly Regex PinMame = new Regex("LoadVPM|VPinMAME\\.Controller", RegexOptions.IgnoreCase);
        // e.g. Table1.Option("Table DMD ON/OFF", 0, 1, 1, 0, 0, Array("On", "Off"))
        static readonly Regex DmdOption = new Regex(
            "\\.Option\\(\\s*\"([^\"]*DMD[^\"]*)\"\\s*,\\s*([\\d.]+)\\s*,\\s*[\\d.]+\\s*,\\s*([\\d.]+)\\s*,[^,]*,[^,]*,\\s*Array\\(([^)]*)\\)",
            RegexOptions.IgnoreCase);
        static readonly Regex OffWord = new Regex("\\b(off|hidden|hide|none|disabled?)\\b", RegexOptions.IgnoreCase);

        static void FindDmdOption(string text, VpxInfo info)
        {
            foreach (Match m in DmdOption.Matches(text))
            {
                var choices = m.Groups[4].Value.Split(',');
                for (int i = 0; i < choices.Length; i++)
                {
                    if (!OffWord.IsMatch(choices[i]) || choices[i].IndexOf("on", StringComparison.OrdinalIgnoreCase) >= 0 && choices[i].Contains("/")) continue;
                    double min = double.Parse(m.Groups[2].Value, System.Globalization.CultureInfo.InvariantCulture);
                    double step = double.Parse(m.Groups[3].Value, System.Globalization.CultureInfo.InvariantCulture);
                    info.DmdOption = m.Groups[1].Value;
                    info.DmdOffValue = (min + i * step).ToString(System.Globalization.CultureInfo.InvariantCulture);
                    return;
                }
            }
        }

        // Reads the table script straight out of the .vpx container (it is stored as
        // plain text) so we know which ROM a table needs without launching VPX.
        public static VpxInfo Scan(string vpxPath)
        {
            const int chunk = 8 * 1024 * 1024, overlap = 256;
            var latin1 = Encoding.GetEncoding(28591);
            var buffer = new byte[chunk + overlap];
            var info = new VpxInfo();
            using (var fs = new FileStream(vpxPath, FileMode.Open, FileAccess.Read, FileShare.Read, 1 << 20))
            {
                int carried = 0, read;
                while ((read = fs.Read(buffer, carried, chunk)) > 0)
                {
                    int len = carried + read;
                    string text = latin1.GetString(buffer, 0, len);
                    if (info.GameName == null)
                    {
                        var m = GameName.Match(text);
                        if (m.Success) info.GameName = m.Groups[1].Value;
                    }
                    if (!info.UsesPinMame) info.UsesPinMame = PinMame.IsMatch(text);
                    if (info.DmdOption == null) FindDmdOption(text, info);
                    carried = Math.Min(overlap, len);
                    Buffer.BlockCopy(buffer, len - carried, buffer, 0, carried);
                }
            }
            return info;
        }
    }

    public static class Windows
    {
        delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
        [System.Runtime.InteropServices.DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr lParam);
        [System.Runtime.InteropServices.DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
        [System.Runtime.InteropServices.DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
        [System.Runtime.InteropServices.DllImport("user32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode)]
        static extern int GetWindowText(IntPtr h, StringBuilder s, int n);

        // True while the process shows a visible top-level window whose title starts with prefix.
        public static bool HasWindow(int processId, string titlePrefix)
        {
            bool found = false;
            EnumWindows((h, l) =>
            {
                uint pid; GetWindowThreadProcessId(h, out pid);
                if (pid != processId || !IsWindowVisible(h)) return true;
                var sb = new StringBuilder(256); GetWindowText(h, sb, 256);
                if (sb.ToString().StartsWith(titlePrefix)) { found = true; return false; }
                return true;
            }, IntPtr.Zero);
            return found;
        }
    }
}
