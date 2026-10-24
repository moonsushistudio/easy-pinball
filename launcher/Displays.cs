using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

namespace MyPinball
{
    public class Display
    {
        public int Number;          // the n in \\.\DISPLAYn, which is how B2S picks a screen
        public string DeviceName;
        public bool Primary;
        public int X, Y, Width, Height;
    }

    // Monitors in physical pixels. EnumDisplaySettings reports the real mode whatever the
    // DPI awareness, unlike Screen.AllScreens, which scales screens with a different DPI.
    public static class Displays
    {
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        struct DISPLAY_DEVICE
        {
            public int cb;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string DeviceName;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceString;
            public int StateFlags;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceID;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceKey;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        struct DEVMODE
        {
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmDeviceName;
            public short dmSpecVersion, dmDriverVersion, dmSize, dmDriverExtra;
            public int dmFields;
            public int dmPositionX, dmPositionY, dmDisplayOrientation, dmDisplayFixedOutput;
            public short dmColor, dmDuplex, dmYResolution, dmTTOption, dmCollate;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmFormName;
            public short dmLogPixels;
            public int dmBitsPerPel, dmPelsWidth, dmPelsHeight, dmDisplayFlags, dmDisplayFrequency;
            public int dmICMMethod, dmICMIntent, dmMediaType, dmDitherType, dmReserved1, dmReserved2, dmPanningWidth, dmPanningHeight;
        }

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        static extern bool EnumDisplayDevices(string device, int index, ref DISPLAY_DEVICE dd, int flags);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        static extern bool EnumDisplaySettings(string device, int mode, ref DEVMODE dm);

        const int AttachedToDesktop = 1, PrimaryDevice = 4, CurrentSettings = -1;

        public static Display[] All()
        {
            var list = new List<Display>();
            var dd = new DISPLAY_DEVICE();
            dd.cb = Marshal.SizeOf(dd);
            for (int i = 0; EnumDisplayDevices(null, i, ref dd, 0); i++, dd.cb = Marshal.SizeOf(dd))
            {
                if ((dd.StateFlags & AttachedToDesktop) == 0) continue;
                var dm = new DEVMODE();
                dm.dmSize = (short)Marshal.SizeOf(dm);
                if (!EnumDisplaySettings(dd.DeviceName, CurrentSettings, ref dm)) continue;
                int n = 0;
                var digits = dd.DeviceName.Substring(dd.DeviceName.TrimEnd("0123456789".ToCharArray()).Length);
                int.TryParse(digits, out n);
                list.Add(new Display
                {
                    Number = n, DeviceName = dd.DeviceName, Primary = (dd.StateFlags & PrimaryDevice) != 0,
                    X = dm.dmPositionX, Y = dm.dmPositionY, Width = dm.dmPelsWidth, Height = dm.dmPelsHeight
                });
            }
            return list.ToArray();
        }
    }
}
