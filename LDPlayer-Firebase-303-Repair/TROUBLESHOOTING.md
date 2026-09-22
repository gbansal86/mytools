# Troubleshooting

Use this guide when the main repair script finishes but the problem remains.

## 1. `adb devices` shows nothing

In LDPlayer:

**Settings → Others → ADB debugging → Enable local connection**

Then save/restart LDPlayer and run:

```cmd
"C:\LDPlayer\LDPlayer9\adb.exe" kill-server
"C:\LDPlayer\LDPlayer9\adb.exe" start-server
"C:\LDPlayer\LDPlayer9\adb.exe" devices
```

Expected shape:

```text
List of devices attached
emulator-5554    device
```

The emulator number may differ.

If it is still empty, try:

```cmd
"C:\LDPlayer\LDPlayer9\adb.exe" connect 127.0.0.1:5555
"C:\LDPlayer\LDPlayer9\adb.exe" connect 127.0.0.1:5557
"C:\LDPlayer\LDPlayer9\adb.exe" connect 127.0.0.1:5559
"C:\LDPlayer\LDPlayer9\adb.exe" devices
```

## 2. ADB shows `offline`

Run:

```cmd
"C:\LDPlayer\LDPlayer9\adb.exe" kill-server
"C:\LDPlayer\LDPlayer9\adb.exe" start-server
```

Restart LDPlayer and check again.

## 3. Chrome inside LDPlayer has no Internet

First determine whether Windows itself has Internet. If Windows works but LDPlayer does not:

1. run the repair script;
2. restart Windows if you previously ran `netsh winsock reset`;
3. restart LDPlayer;
4. test Chrome again;
5. only then consider LDPlayer **Network Bridge** mode.

Do not install/remove bridge drivers as a first step. Driver changes can affect the host PC's networking.

## 4. Chrome works, Play Store works, but one app shows #303

That is a different situation from “LDPlayer has no Internet.”

Run the main repair and allow the Google-service cleanup. If necessary, rerun it and provide that one app's package name so its local Firebase installation state can be recreated.

If the app still fails in a fresh LDPlayer instance while Chrome and Play Store work, the remaining cause may be outside the PC, such as the app's Firebase configuration, server availability, credentials, or emulator policy.

## 5. Google Play asks me to sign in again

This is expected after clearing:

- `com.android.vending`
- `com.google.android.gms`
- `com.google.android.gsf`

Sign in normally.

## 6. I do not know the app package name

Search installed packages:

```cmd
"C:\LDPlayer\LDPlayer9\adb.exe" shell pm list packages
```

Filter by a keyword:

```cmd
"C:\LDPlayer\LDPlayer9\adb.exe" shell pm list packages | findstr /i keyword
```

You can also leave the package blank; the script will not clear the app.

## 7. Android DNS test fails but Chrome works

Android's `ping` command is only a diagnostic hint. Some environments block ICMP/ping even when HTTPS works. A successful Chrome/Play Store test is more meaningful.

## 8. Restore Android Private DNS

The repair sets Private DNS to `off` temporarily.

Restore Android's normal opportunistic mode:

```cmd
"C:\LDPlayer\LDPlayer9\adb.exe" shell settings put global private_dns_mode opportunistic
```

## 9. Deeper Windows reset

Only use this when LDPlayer has a general networking problem, not when one app alone fails.

Open Command Prompt or PowerShell as Administrator:

```cmd
netsh winsock reset
ipconfig /flushdns
```

Then restart Windows.

## 10. What to share when asking for help

Share the generated file named similar to:

```text
LDPlayer_Repair_YYYYMMDD_HHMMSS.log
```

Before sharing publicly, review the log for machine/user names or local network addresses you do not want to publish.
