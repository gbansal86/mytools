/*
 USB_Hub_Probe.cs
 ----------------
 Low-level, read-only helper used by USB_Port_Explorer.ps1.

 Why this file exists:
 Standard PowerShell Plug-and-Play properties can tell us what device is present,
 but they often cannot tell us the logical USB port protocols or the current
 driver-reported USB signaling mode. This helper calls documented Windows
 SetupAPI and USB hub IOCTL interfaces to obtain that extra information.

 It does NOT install a driver and does NOT write to the device. The hub handle is
 opened only so DeviceIoControl can ask the Windows USB stack for information.

 Layman note:
 - "Protocols" = what the logical hub port says it can expose.
 - "Link speed" = what the attached device/path is currently using.
 - Neither value, by itself, guarantees the advertised maximum of the visible
   physical connector on the PC case.
*/
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;

namespace UsbPortExplorerNative
{
    public sealed class HubPort
    {
        public string HubInstanceId { get; set; }
        public string HubPath { get; set; }
        public int Port { get; set; }
        public string Protocols { get; set; }
        public string LinkSpeed { get; set; }
        public string Connection { get; set; }
        public string Details { get; set; }
        public string Source { get; set; }
    }

    public sealed class ScanResult
    {
        public HubPort[] Ports { get; set; }
        public string[] Warnings { get; set; }
        public int HubsFound { get; set; }
        public int HubsOpened { get; set; }
    }

    public static class UsbHubProbe
    {
        // USB_GET_NODE_INFORMATION=258, USB_GET_NODE_CONNECTION_INFORMATION_EX=274,
        // USB_GET_NODE_CONNECTION_INFORMATION_EX_V2=279. FILE_DEVICE_USB=0x22.
        private const uint NODE_INFORMATION = 0x220408;
        private const uint CONNECTION_EX = 0x220448;
        private const uint CONNECTION_EX_V2 = 0x22045C;
        private const uint DIGCF_PRESENT = 0x2;
        private const uint DIGCF_DEVICEINTERFACE = 0x10;
        private const uint FILE_SHARE_READ = 1;
        private const uint FILE_SHARE_WRITE = 2;
        private const uint OPEN_EXISTING = 3;
        private const uint GENERIC_READ = 0x80000000;
        private const uint GENERIC_WRITE = 0x40000000;
        private static readonly Guid HubGuid = new Guid("F18A0E88-C30C-11D0-8815-00A0C906BED8");

        [StructLayout(LayoutKind.Sequential)]
        private struct SP_DEVICE_INTERFACE_DATA
        {
            public uint cbSize;
            public Guid InterfaceClassGuid;
            public uint Flags;
            public IntPtr Reserved;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct SP_DEVINFO_DATA
        {
            public uint cbSize;
            public Guid ClassGuid;
            public uint DevInst;
            public IntPtr Reserved;
        }

        [DllImport("setupapi.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern IntPtr SetupDiGetClassDevs(ref Guid classGuid,
            string enumerator, IntPtr parent, uint flags);

        [DllImport("setupapi.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool SetupDiEnumDeviceInterfaces(IntPtr deviceInfoSet,
            IntPtr deviceInfoData, ref Guid interfaceClassGuid, uint memberIndex,
            ref SP_DEVICE_INTERFACE_DATA deviceInterfaceData);

        [DllImport("setupapi.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool SetupDiGetDeviceInterfaceDetail(IntPtr deviceInfoSet,
            ref SP_DEVICE_INTERFACE_DATA deviceInterfaceData, IntPtr deviceInterfaceDetailData,
            uint deviceInterfaceDetailDataSize, out uint requiredSize,
            ref SP_DEVINFO_DATA deviceInfoData);

        [DllImport("setupapi.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool SetupDiGetDeviceInstanceId(IntPtr deviceInfoSet,
            ref SP_DEVINFO_DATA deviceInfoData, StringBuilder deviceInstanceId,
            uint deviceInstanceIdSize, out uint requiredSize);

        [DllImport("setupapi.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool SetupDiDestroyDeviceInfoList(IntPtr deviceInfoSet);

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern IntPtr CreateFile(string fileName, uint access,
            uint shareMode, IntPtr security, uint creation, uint flags, IntPtr templateFile);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool DeviceIoControl(IntPtr device, uint controlCode,
            byte[] input, uint inputLength, byte[] output, uint outputLength,
            out uint returnedBytes, IntPtr overlapped);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool CloseHandle(IntPtr handle);

        private static string ProtocolText(uint protocols)
        {
            if ((protocols & 4) != 0) return "USB 3.x (SuperSpeed) supported on logical port";
            if ((protocols & 2) != 0) return "USB 2.0 (High-Speed) logical port";
            if ((protocols & 1) != 0) return "USB 1.x (Low/Full-Speed) logical port";
            return "Not returned by hub driver";
        }

        private static string ExSpeed(byte value)
        {
            switch (value)
            {
                case 0: return "Low-Speed (1.5 Mb/s signaling)";
                case 1: return "Full-Speed (12 Mb/s signaling)";
                case 2: return "High-Speed (480 Mb/s signaling)";
                case 3: return "SuperSpeed (USB 3.x; 5 Gb/s class)";
                default: return "Not reported";
            }
        }

        private static string V2Speed(uint flags, byte exSpeed, bool hasEx)
        {
            if ((flags & 4) != 0) return "SuperSpeedPlus or higher (USB 3.x; exact rate unknown)";
            if ((flags & 1) != 0) return "SuperSpeed or higher (USB 3.x; exact rate unknown)";
            return hasEx ? ExSpeed(exSpeed) : "Unknown";
        }

        public static ScanResult Scan()
        {
            List<HubPort> ports = new List<HubPort>();
            List<string> warnings = new List<string>();
            int hubsFound = 0;
            int hubsOpened = 0;
            Guid guid = HubGuid;
            IntPtr set = SetupDiGetClassDevs(ref guid, null, IntPtr.Zero, DIGCF_PRESENT | DIGCF_DEVICEINTERFACE);
            if (set == new IntPtr(-1))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Cannot enumerate USB hub interfaces");
            try
            {
                for (uint i = 0; i < 256; i++)
                {
                    SP_DEVICE_INTERFACE_DATA iface = new SP_DEVICE_INTERFACE_DATA();
                    iface.cbSize = (uint)Marshal.SizeOf(typeof(SP_DEVICE_INTERFACE_DATA));
                    if (!SetupDiEnumDeviceInterfaces(set, IntPtr.Zero, ref guid, i, ref iface))
                    {
                        int error = Marshal.GetLastWin32Error();
                        if (error == 259) break; // ERROR_NO_MORE_ITEMS
                        warnings.Add("Hub interface enumeration: Win32 error " + error);
                        break;
                    }
                    hubsFound++;
                    SP_DEVINFO_DATA dev = new SP_DEVINFO_DATA();
                    dev.cbSize = (uint)Marshal.SizeOf(typeof(SP_DEVINFO_DATA));
                    IntPtr detail = Marshal.AllocHGlobal(8192);
                    string path = null;
                    string instanceId = null;
                    try
                    {
                        // cbSize is 8 on x64, 6 on x86; string begins at byte offset 4.
                        Marshal.WriteInt32(detail, IntPtr.Size == 8 ? 8 : 6);
                        uint required;
                        if (!SetupDiGetDeviceInterfaceDetail(set, ref iface, detail, 8192, out required, ref dev))
                        {
                            warnings.Add("Hub interface detail unavailable: Win32 error " + Marshal.GetLastWin32Error());
                            continue;
                        }
                        path = Marshal.PtrToStringUni(IntPtr.Add(detail, 4));
                        StringBuilder id = new StringBuilder(2048);
                        uint ignored;
                        if (SetupDiGetDeviceInstanceId(set, ref dev, id, (uint)id.Capacity, out ignored))
                            instanceId = id.ToString();
                        else
                            warnings.Add("Hub instance ID unavailable: Win32 error " + Marshal.GetLastWin32Error());
                    }
                    finally { Marshal.FreeHGlobal(detail); }
                    if (String.IsNullOrEmpty(path) || String.IsNullOrEmpty(instanceId)) continue;
                    IntPtr handle = CreateFile(path, GENERIC_READ | GENERIC_WRITE,
                        FILE_SHARE_READ | FILE_SHARE_WRITE, IntPtr.Zero, OPEN_EXISTING, 0, IntPtr.Zero);
                    if (handle == new IntPtr(-1))
                    {
                        warnings.Add("Cannot open hub " + instanceId + " (Win32 " + Marshal.GetLastWin32Error() + ")");
                        continue;
                    }
                    hubsOpened++;
                    try
                    {
                        byte[] hubInfo = new byte[256];
                        uint returned;
                        if (!DeviceIoControl(handle, NODE_INFORMATION, hubInfo, (uint)hubInfo.Length,
                            hubInfo, (uint)hubInfo.Length, out returned, IntPtr.Zero) || returned < 7)
                        {
                            warnings.Add("Cannot read hub port count: " + instanceId +
                                " (Win32 " + Marshal.GetLastWin32Error() + ")");
                            continue;
                        }
                        int count = Math.Min((int)hubInfo[6], 255); // USB_HUB_DESCRIPTOR.bNumberOfPorts
                        if (count == 0)
                        {
                            warnings.Add("Hub returned zero ports: " + instanceId);
                            continue;
                        }
                        for (int port = 1; port <= count; port++)
                        {
                            HubPort result = new HubPort();
                            result.HubInstanceId = instanceId;
                            result.HubPath = path;
                            result.Port = port;
                            result.Protocols = "Unknown";
                            result.LinkSpeed = "Unknown";
                            result.Connection = "Unknown";
                            result.Source = "Windows USB hub IOCTL";
                            List<string> observations = new List<string>();

                            byte[] ex = new byte[4096];
                            Array.Copy(BitConverter.GetBytes((uint)port), ex, 4);
                            bool hasEx = DeviceIoControl(handle, CONNECTION_EX, ex, (uint)ex.Length,
                                ex, (uint)ex.Length, out returned, IntPtr.Zero) && returned >= 36;
                            int exErr = hasEx ? 0 : Marshal.GetLastWin32Error();
                            byte speed = 0;
                            if (hasEx)
                            {
                                // USB_NODE_CONNECTION_INFORMATION_EX: Speed at 23, status at 32.
                                speed = ex[23];
                                uint status = BitConverter.ToUInt32(ex, 32);
                                result.Connection = status == 0 ? "Empty" :
                                    status == 1 ? "Connected" : "Driver-reported connection state " + status;
                                if (status == 1) result.LinkSpeed = ExSpeed(speed);
                            }
                            else observations.Add("EX query failed (Win32 " + exErr + ")");

                            byte[] v2 = new byte[16];
                            Array.Copy(BitConverter.GetBytes((uint)port), 0, v2, 0, 4);
                            Array.Copy(BitConverter.GetBytes((uint)16), 0, v2, 4, 4);
                            // Set requested protocol mask before the query, per USB IOCTL contract.
                            Array.Copy(BitConverter.GetBytes((uint)7), 0, v2, 8, 4);
                            bool hasV2 = DeviceIoControl(handle, CONNECTION_EX_V2, v2, 16,
                                v2, 16, out returned, IntPtr.Zero) && returned >= 16;
                            int v2Err = hasV2 ? 0 : Marshal.GetLastWin32Error();
                            if (hasV2)
                            {
                                uint protocols = BitConverter.ToUInt32(v2, 8);
                                uint flags = BitConverter.ToUInt32(v2, 12);
                                result.Protocols = ProtocolText(protocols);
                                if (result.Connection == "Connected") result.LinkSpeed = V2Speed(flags, speed, hasEx);
                                if (result.Connection == "Unknown" && (flags & 1) != 0)
                                    result.LinkSpeed = V2Speed(flags, speed, false) + " (connection state unavailable)";
                                observations.Add("USB protocol flags: 0x" + protocols.ToString("X") +
                                    "; device speed flags: 0x" + flags.ToString("X"));
                                if ((flags & 2) != 0 && (flags & 1) == 0 && result.Connection == "Connected")
                                    observations.Add("Attached device is SuperSpeed-capable but is not operating at SuperSpeed on this path.");
                            }
                            else observations.Add("EX_V2 query failed (Win32 " + v2Err + ")");
                            result.Details = String.Join("; ", observations.ToArray());
                            ports.Add(result);
                        }
                    }
                    finally { CloseHandle(handle); }
                }
            }
            finally { SetupDiDestroyDeviceInfoList(set); }
            return new ScanResult { Ports = ports.ToArray(), Warnings = warnings.ToArray(),
                HubsFound = hubsFound, HubsOpened = hubsOpened };
        }
    }
}
