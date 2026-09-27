using System;
using System.Runtime.InteropServices;
using UnityEngine;

// Automatically starts in a macOS player; no scene object is required.
internal sealed class WallwallDesktop : MonoBehaviour
{
    internal static bool IsWallpaperMode
    {
        get
        {
#if UNITY_STANDALONE_OSX && !UNITY_EDITOR
            return hostReady && WWDesktopIsInteractive() == 0;
#else
            return false;
#endif
        }
    }

    internal static Vector3 PointerPosition
    {
        get
        {
#if UNITY_STANDALONE_OSX && !UNITY_EDITOR
            if (hostReady && WWDesktopCursor(out float x, out float y) == 1)
                return new Vector3(x * Screen.width, y * Screen.height, 0);
#endif
            return Input.mousePosition;
        }
    }

    internal static int PointerMode
    {
        get
        {
#if UNITY_STANDALONE_OSX && !UNITY_EDITOR
            if (hostReady) return WWDesktopPointerMode();
#endif
            return 0;
        }
    }

    internal static float HoverDwellSeconds
    {
        get
        {
#if UNITY_STANDALONE_OSX && !UNITY_EDITOR
            if (hostReady) return WWDesktopDwellMilliseconds() * 0.001f;
#endif
            return 3f;
        }
    }

    internal static int AmbientIntervalSeconds
    {
        get
        {
#if UNITY_STANDALONE_OSX && !UNITY_EDITOR
            if (hostReady) return WWDesktopAmbientIntervalSeconds();
#endif
            return WallwallConsts.DefaultAmbientIntervalSeconds;
        }
    }

    internal static int AmbientCount
    {
        get
        {
#if UNITY_STANDALONE_OSX && !UNITY_EDITOR
            if (hostReady) return WWDesktopAmbientCount();
#endif
            return WallwallConsts.DefaultAmbientCount;
        }
    }

    internal static bool PointerUnobscured
    {
        get
        {
#if UNITY_STANDALONE_OSX && !UNITY_EDITOR
            return hostReady && WWDesktopPointerUnobscured() == 1;
#else
            return true;
#endif
        }
    }

    internal static bool TryGetWallpaperDragInput(out Vector2 position, out bool down, out bool held, out bool up)
    {
        position = PointerPosition;
        down = held = up = false;
#if UNITY_STANDALONE_OSX && !UNITY_EDITOR
        if (!IsWallpaperMode || PointerMode != 1)
        {
            dragNeedsBaseline = true;
            dragPendingDown = dragPendingUp = false;
            dragSampleFrame = -1;
            // Wallpaper Hover owns input independently of Unity mouse buttons.
            return IsWallpaperMode;
        }
        if (dragSampleFrame != Time.frameCount)
        {
            dragSampleFrame = Time.frameCount;
            if (WWDesktopDragState(out int nativeHeld, out uint downRevision, out uint upRevision,
                out float pressX, out float pressY, out float releaseX, out float releaseY) != 1)
            {
                dragSampleFrame = -1;
                dragNeedsBaseline = true;
                // Never fall back to focused-window buttons in wallpaper mode.
                return true;
            }

            dragSamplePosition = position;
            dragSampleDown = dragSampleHeld = dragSampleUp = false;
            if (dragNeedsBaseline)
            {
                dragSeenDown = downRevision;
                dragSeenUp = upRevision;
                dragNeedsBaseline = false;
            }
            else
            {
                if (downRevision != dragSeenDown)
                {
                    dragSeenDown = downRevision;
                    dragPendingDown = true;
                    dragPressPosition = new Vector2(pressX * Screen.width, pressY * Screen.height);
                }
                if (upRevision != dragSeenUp)
                {
                    dragSeenUp = upRevision;
                    dragPendingUp = true;
                    dragReleasePosition = new Vector2(releaseX * Screen.width, releaseY * Screen.height);
                }
            }
            if (dragPendingDown)
            {
                dragPendingDown = false;
                dragSamplePosition = dragPressPosition;
                dragSampleDown = true;
                dragSampleHeld = true;
            }
            else if (dragPendingUp)
            {
                dragPendingUp = false;
                dragSamplePosition = dragReleasePosition;
                dragSampleUp = true;
            }
            else dragSampleHeld = nativeHeld != 0;
        }
        position = dragSamplePosition;
        down = dragSampleDown;
        held = dragSampleHeld;
        up = dragSampleUp;
        return true;
#else
        return false;
#endif
    }
#if UNITY_STANDALONE_OSX && !UNITY_EDITOR
    private static bool hostReady;
    [DllImport("WallwallDesktop")]
    private static extern int WWDesktopCursor(out float x, out float y);
    [DllImport("WallwallDesktop")]
    private static extern int WWDesktopPointerUnobscured();
    [DllImport("WallwallDesktop")]
    private static extern int WWDesktopFrameRate();
    [DllImport("WallwallDesktop")]
    private static extern int WWDesktopConfigure();

    [DllImport("WallwallDesktop")]
    private static extern int WWDesktopIsInteractive();
    [DllImport("WallwallDesktop")]
    private static extern int WWDesktopPointerMode();
    [DllImport("WallwallDesktop")]
    private static extern int WWDesktopDwellMilliseconds();
    [DllImport("WallwallDesktop")]
    private static extern int WWDesktopAmbientIntervalSeconds();
    [DllImport("WallwallDesktop")]
    private static extern int WWDesktopAmbientCount();
    [DllImport("WallwallDesktop")]
    private static extern int WWDesktopDragState(out int held, out uint downRevision, out uint upRevision,
        out float pressX, out float pressY, out float releaseX, out float releaseY);

    [DllImport("WallwallDesktop")]
    private static extern void WWDesktopRestore();

    private static int dragSampleFrame = -1;
    private static bool dragNeedsBaseline = true;
    private static uint dragSeenDown, dragSeenUp;
    private static bool dragPendingDown, dragPendingUp;
    private static Vector2 dragPressPosition, dragReleasePosition, dragSamplePosition;
    private static bool dragSampleDown, dragSampleHeld, dragSampleUp;

    private float nextAttempt;
    private bool pluginMissing;
    private bool originalRunInBackground;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    private static void StartDesktopHost()
    {
        var args = Environment.GetCommandLineArgs();
        if (Array.IndexOf(args, "--wallwall-export-video") >= 0 ||
            Array.IndexOf(args, "--wallwall-windowed") >= 0) return;
        var host = new GameObject("WallwallDesktopHost");
        DontDestroyOnLoad(host);
        host.AddComponent<WallwallDesktop>();
        host.AddComponent<WallwallAmbientInteraction>();
    }

    private void Awake()
    {
        originalRunInBackground = Application.runInBackground;
        Application.runInBackground = true;
    }

    private void Update()
    {
        if (pluginMissing || Time.unscaledTime < nextAttempt)
        {
            return;
        }

        nextAttempt = Time.unscaledTime + 2f;
        try
        {
            int result = WWDesktopConfigure();
            hostReady = result == 1;
            if (hostReady)
            {
                if (QualitySettings.vSyncCount != 0) QualitySettings.vSyncCount = 0;
                int frameRate = WWDesktopFrameRate();
                if (Application.targetFrameRate != frameRate) Application.targetFrameRate = frameRate;
            }
            if (result < 0)
            {
                Debug.LogError("WALLWALL desktop plug-in must run on the macOS main thread.");
                pluginMissing = true;
            }
        }
        catch (DllNotFoundException exception)
        {
            Debug.LogError("WALLWALL desktop plug-in is missing: " + exception.Message);
            pluginMissing = true;
        }
        catch (EntryPointNotFoundException exception)
        {
            Debug.LogError("WALLWALL desktop plug-in has an incompatible entry point: " + exception.Message);
            pluginMissing = true;
        }
    }

    private void OnApplicationQuit()
    {
        Application.runInBackground = originalRunInBackground;
        if (!pluginMissing)
        {
            WWDesktopRestore();
        }
    }
#endif
}
