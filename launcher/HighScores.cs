using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

namespace MyPinball
{
    public class ScoreEntry
    {
        public string Initials;
        public long Score;
    }

    public class ScoreBlock
    {
        public int Offset;
        public int EntrySize;    // 8 or 9 bytes: initials + 5 or 6 score bytes
        public List<ScoreEntry> Entries = new List<ScoreEntry>();
    }

    // Reads high scores out of a PinMAME .nv file for Williams/Bally WPC games.
    // WPC stores each table as N entries of [3 initials][5 or 6 BCD score bytes],
    // followed by a big-endian checksum equal to 0xFFFF minus the sum of the block's
    // bytes. The checksum lets us find the tables exactly without per-game maps.
    public static class HighScores
    {
        static bool IsInitial(byte b)
        {
            return (b >= 'A' && b <= 'Z') || (b >= '0' && b <= '9') || b == ' ' || b == '@' || b == '.' || b == '-' || b == '!' || b == '&' || b == '*' || b == '?';
        }

        static bool TryEntry(byte[] b, int at, int scoreBytes, out ScoreEntry entry)
        {
            entry = null;
            if (at + 3 + scoreBytes > b.Length) return false;
            if (!IsInitial(b[at]) || !IsInitial(b[at + 1]) || !IsInitial(b[at + 2])) return false;
            long score = 0;
            for (int k = 0; k < scoreBytes; k++)
            {
                byte v = b[at + 3 + k];
                if ((v >> 4) > 9 || (v & 15) > 9) return false;
                score = score * 100 + (v >> 4) * 10 + (v & 15);
            }
            entry = new ScoreEntry { Initials = Encoding.ASCII.GetString(b, at, 3).Trim(), Score = score };
            return true;
        }

        public static List<ScoreBlock> Read(string nvPath)
        {
            var blocks = new List<ScoreBlock>();
            if (!File.Exists(nvPath)) return blocks;
            byte[] b = File.ReadAllBytes(nvPath);

            for (int i = 0; i < b.Length; i++)
            {
                ScoreBlock found = null;
                foreach (int scoreBytes in new[] { 6, 5 })
                {
                    int size = 3 + scoreBytes, sum = 0;
                    var block = new ScoreBlock { Offset = i };
                    for (int n = 1; n <= 12; n++)
                    {
                        int at = i + (n - 1) * size;
                        ScoreEntry e;
                        if (!TryEntry(b, at, scoreBytes, out e)) break;
                        block.Entries.Add(e);
                        for (int k = 0; k < size; k++) sum += b[at + k];
                        int end = at + size;
                        if (end + 2 > b.Length) break;
                        int checksum = (b[end] << 8) | b[end + 1];
                        if (checksum == 0xFFFF - (sum & 0xFFFF) && HasLetter(block) && block.Entries.Exists(x => x.Score > 0))
                        {
                            found = new ScoreBlock { Offset = i, EntrySize = size, Entries = new List<ScoreEntry>(block.Entries) };
                        }
                    }
                    if (found != null) break;
                }
                if (found != null)
                {
                    blocks.Add(found);
                    i += found.Entries.Count * found.EntrySize + 1;
                }
            }
            return blocks;
        }

        // Player 1-4 scores of the last (or interrupted) game. In WPC RAM they follow a
        // system record that starts 00 03 11 xx xx 00 00 and is 13-16 bytes long. WPC
        // scores always end in 0, which pins down where the four score slots begin.
        // That record only looks like this once a game is over, and its length varies
        // (11-15 bytes seen), but the score slots never move. So the address is learned
        // once and the caller passes it back as knownOffset; a known address always wins.
        // Returns null unless the slots can be located.
        public static long[] ReadLastScores(string nvPath, int scoreBytes, int knownOffset, out int offset)
        {
            offset = knownOffset;
            if (!File.Exists(nvPath)) return null;
            byte[] b = File.ReadAllBytes(nvPath);
            if (offset < 0)
            {
                int hits = 0, found = -1;
                for (int i = 0; i + 16 + 4 * scoreBytes <= b.Length; i++)
                {
                    if (b[i] != 0 || b[i + 1] != 0x03 || b[i + 2] != 0x11 || b[i + 5] != 0 || b[i + 6] != 0) continue;
                    // Earliest start where player 1's score is real: BCD, ends in 0, and
                    // has a leading zero byte (no score fills every digit). A start that is
                    // a byte too late fails one of these, which is what fixes the alignment.
                    for (int start = i + 11; start <= i + 16; start++)
                    {
                        var scores = ReadSlots(b, start, scoreBytes);
                        if (scores == null || scores[0] == 0 || b[start] != 0) continue;
                        found = start; hits++;
                        break;
                    }
                }
                if (hits == 1) offset = found;
            }
            if (offset < 0 || offset + 4 * scoreBytes > b.Length) { offset = -1; return null; }
            return ReadSlots(b, offset, scoreBytes);
        }

        static long[] ReadSlots(byte[] b, int start, int scoreBytes)
        {
            var scores = new long[4];
            for (int p = 0; p < 4; p++)
            {
                long v = 0;
                for (int k = 0; k < scoreBytes; k++)
                {
                    byte x = b[start + p * scoreBytes + k];
                    if ((x >> 4) > 9 || (x & 15) > 9) return null;
                    v = v * 100 + (x >> 4) * 10 + (x & 15);
                }
                if (v % 10 != 0) return null;
                scores[p] = v;
            }
            return scores;
        }

        static bool HasLetter(ScoreBlock block)
        {
            foreach (var e in block.Entries)
                foreach (char c in e.Initials) if (Char.IsLetter(c)) return true;
            return false;
        }
    }

    // VPX's SaveValue store (User\VPReg.stg), where original tables keep their scores.
    // It is an OLE compound file: one storage per table name, one stream per key, and
    // each value a UTF-16 string. Returns table name -> key -> value.
    public static class SavedValues
    {
        public static Dictionary<string, Dictionary<string, string>> Read(string path)
        {
            var result = new Dictionary<string, Dictionary<string, string>>(StringComparer.OrdinalIgnoreCase);
            if (!File.Exists(path)) return result;
            byte[] b;
            using (var fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
            {
                b = new byte[fs.Length];
                int n = 0, r;
                while (n < b.Length && (r = fs.Read(b, n, b.Length - n)) > 0) n += r;
            }
            if (b.Length < 512 || BitConverter.ToUInt32(b, 0) != 0xE011CFD0) return result;

            int ss = 1 << BitConverter.ToUInt16(b, 0x1E), mss = 1 << BitConverter.ToUInt16(b, 0x20);
            int fatCount = BitConverter.ToInt32(b, 0x2C), dirStart = BitConverter.ToInt32(b, 0x30);
            long cutoff = BitConverter.ToUInt32(b, 0x38);
            int miniFatStart = BitConverter.ToInt32(b, 0x3C), difat = BitConverter.ToInt32(b, 0x44);

            // The FAT's own sectors: 109 listed in the header, any more in DIFAT sectors.
            var fatSectors = new List<int>();
            for (int i = 0; i < 109 && fatSectors.Count < fatCount; i++) fatSectors.Add(BitConverter.ToInt32(b, 0x4C + 4 * i));
            for (int guard = 0; fatSectors.Count < fatCount && difat >= 0 && (difat + 2L) * ss <= b.Length && guard < 1000; guard++)
            {
                int at = (difat + 1) * ss;
                for (int i = 0; i < ss / 4 - 1 && fatSectors.Count < fatCount; i++) fatSectors.Add(BitConverter.ToInt32(b, at + 4 * i));
                difat = BitConverter.ToInt32(b, at + ss - 4);
            }
            var fat = new List<int>();
            foreach (int s in fatSectors)
            {
                if (s < 0 || (s + 2L) * ss > b.Length) continue;
                for (int i = 0; i < ss / 4; i++) fat.Add(BitConverter.ToInt32(b, (s + 1) * ss + 4 * i));
            }

            byte[] dir = Chain(b, fat, dirStart, ss, ss, -1);
            if (dir.Length < 128) return result;
            var miniFatBytes = miniFatStart >= 0 ? Chain(b, fat, miniFatStart, ss, ss, -1) : new byte[0];
            var miniFat = new List<int>();
            for (int i = 0; i + 4 <= miniFatBytes.Length; i += 4) miniFat.Add(BitConverter.ToInt32(miniFatBytes, i));
            byte[] ministream = Chain(b, fat, BitConverter.ToInt32(dir, 116), ss, ss, BitConverter.ToUInt32(dir, 120));

            foreach (int table in Children(dir, BitConverter.ToInt32(dir, 76)))
            {
                if (dir[table * 128 + 66] != 1) continue;   // storages only
                var values = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
                foreach (int key in Children(dir, BitConverter.ToInt32(dir, table * 128 + 76)))
                {
                    int e = key * 128;
                    if (dir[e + 66] != 2) continue;           // streams only
                    int start = BitConverter.ToInt32(dir, e + 116);
                    long size = BitConverter.ToUInt32(dir, e + 120);
                    byte[] data = size < cutoff ? Chain(ministream, miniFat, start, mss, 0, size) : Chain(b, fat, start, ss, ss, size);
                    values[Name(dir, key)] = Encoding.Unicode.GetString(data).TrimEnd('\0');
                }
                result[Name(dir, table)] = values;
            }
            return result;
        }

        static string Name(byte[] dir, int entry)
        {
            int len = Math.Max(0, Math.Min(64, (int)BitConverter.ToUInt16(dir, entry * 128 + 64)) - 2);
            return Encoding.Unicode.GetString(dir, entry * 128, len);
        }

        // Siblings are kept in a binary tree (left/right links); walk all of it.
        static List<int> Children(byte[] dir, int root)
        {
            var found = new List<int>();
            var todo = new Stack<int>();
            int count = dir.Length / 128;
            if (root >= 0 && root < count) todo.Push(root);
            while (todo.Count > 0 && found.Count < count)
            {
                int n = todo.Pop();
                found.Add(n);
                foreach (int link in new[] { BitConverter.ToInt32(dir, n * 128 + 68), BitConverter.ToInt32(dir, n * 128 + 72) })
                    if (link >= 0 && link < count && !found.Contains(link)) todo.Push(link);
            }
            return found;
        }

        // Follows a sector chain. Regular sectors start one header (base = sector size)
        // into the file; mini sectors start at 0 of the mini stream.
        static byte[] Chain(byte[] src, List<int> table, int sector, int size, int baseOffset, long length)
        {
            var ms = new MemoryStream();
            for (int guard = 0; sector >= 0 && sector < table.Count && guard <= table.Count; guard++)
            {
                long at = baseOffset + (long)sector * size;
                if (at + size > src.Length) break;
                ms.Write(src, (int)at, size);
                if (length >= 0 && ms.Length >= length) break;
                sector = table[sector];
            }
            byte[] all = ms.ToArray();
            if (length < 0 || all.Length <= length) return all;
            var cut = new byte[length];
            Array.Copy(all, cut, length);
            return cut;
        }
    }
}
