using System;
using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.Rendering;

// Automatically starts in a macOS player; no scene object is required.
internal sealed class WallwallDesktop : MonoBehaviour
{
    private static float realtimeFramesUntil;
    internal static void RequestRealtimeFrames()
    {
        realtimeFramesUntil = Time.unscaledTime + 1f;
    }
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
            if (hostReady)
            {
                if (cursorSampleFrame != Time.frameCount)
                {
                    cursorSampleFrame = Time.frameCount;
                    cursorSampleValid = WWDesktopCursor(out cursorX, out cursorY) == 1;
                }
                if (cursorSampleValid) return new Vector3(cursorX * Screen.width, cursorY * Screen.height, 0);
            }
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
            dragInput.Reset();
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
                dragInput.Reset();
                // Never fall back to focused-window buttons in wallpaper mode.
                return true;
            }

            dragInput.Sample(downRevision, upRevision, nativeHeld != 0,
                pressX * Screen.width, pressY * Screen.height,
                releaseX * Screen.width, releaseY * Screen.height);
            dragSamplePosition = dragInput.Down || dragInput.Up
                ? new Vector2(dragInput.X, dragInput.Y) : position;
        }
        position = dragSamplePosition;
        down = dragInput.Down;
        held = dragInput.Held;
        up = dragInput.Up;
        if (down || held || up) RequestRealtimeFrames();
        return true;
#else
        return false;
#endif
    }
#if UNITY_STANDALONE_OSX && !UNITY_EDITOR
    private static bool hostReady;
    private static int cursorSampleFrame = -1;
    private static bool cursorSampleValid;
    private static float cursorX, cursorY;
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
    private static readonly WallwallDragInput dragInput = new WallwallDragInput();
    private static Vector2 dragSamplePosition;

    private float nextAttempt;
    private bool pluginMissing;
    private bool originalRunInBackground;
    private int originalFrameRate, originalVSync, originalRenderInterval;
    private int frameBudget = 30;
    private int originalSleepTimeout;
    private int idleFrameRate = 24;
    private bool profile;
    private double profileStarted;
    private double profilePrevious;
    private int profileUpdates, profileRenders;
    private float profileMaxStep;

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
        originalSleepTimeout = Screen.sleepTimeout;
        Screen.sleepTimeout = SleepTimeout.SystemSetting;
        // Explicit diagnostic launch options; normal launches keep the policy.
        foreach (string argument in Environment.GetCommandLineArgs())
        {
            if (argument == "--wallwall-profile") profile = true;
            const string prefix = "--wallwall-idle-fps=";
            if (argument.StartsWith(prefix, StringComparison.Ordinal) &&
                int.TryParse(argument.Substring(prefix.Length), out int requested) &&
                (requested == 20 || requested == 24 || requested == 30)) idleFrameRate = requested;
        }
        profileStarted = Time.realtimeSinceStartupAsDouble;
        profilePrevious = profileStarted;
        originalFrameRate = Application.targetFrameRate;
        originalVSync = QualitySettings.vSyncCount;
        originalRenderInterval = OnDemandRendering.renderFrameInterval;
        Application.runInBackground = true;
    }

    private void Update()
    {
        if (hostReady && !pluginMissing)
        {
            int rate = WallwallFramePolicy.UpdateRate(frameBudget, IsWallpaperMode,
                Time.unscaledTime < realtimeFramesUntil, idleFrameRate);
            if (Application.targetFrameRate != rate) Application.targetFrameRate = rate;
            // Hidden: keep a slow lifecycle/input tick, submit only one frame
            // per second. Visible animated content must render every tick.
            int interval = WallwallFramePolicy.RenderInterval(frameBudget);
            if (OnDemandRendering.renderFrameInterval != interval) OnDemandRendering.renderFrameInterval = interval;
        }
        if (profile) RecordFrameBudget();
        if (pluginMissing || Time.unscaledTime < nextAttempt)
        {
            return;
        }

        nextAttempt = Time.unscaledTime + (hostReady ? 0.5f : 2f);
        try
        {
            int result = WWDesktopConfigure();
            hostReady = result == 1;
            if (hostReady)
            {
                if (QualitySettings.vSyncCount != 0) QualitySettings.vSyncCount = 0;
                int frameRate = WWDesktopFrameRate();
                if (frameBudget != frameRate) Debug.Log("[WALLWALL budget] update cap=" + frameRate);
                frameBudget = frameRate;
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

    private void RecordFrameBudget()
    {
        profileUpdates++;
        if (OnDemandRendering.willCurrentFrameRender) profileRenders++;
        double now = Time.realtimeSinceStartupAsDouble;
        profileMaxStep = Mathf.Max(profileMaxStep, (float)(now - profilePrevious));
        profilePrevious = now;
        double elapsed = now - profileStarted;
        if (elapsed < 5) return;
        // Counts scheduled render frames, not compositor presentations or GPU time.
        Debug.Log("[WALLWALL profile] updateHz=" + (profileUpdates / elapsed).ToString("F1") +
            " renderHz=" + (profileRenders / elapsed).ToString("F1") +
            " maxUpdateMs=" + (profileMaxStep * 1000f).ToString("F1") +
            " cap=" + Application.targetFrameRate + " interval=" + OnDemandRendering.renderFrameInterval +
            " pixels=" + Screen.width + "x" + Screen.height +
            " spineThreads=" + Spine.Unity.RuntimeSettings.UseThreadedAnimation + "/" +
            Spine.Unity.RuntimeSettings.UseThreadedMeshGeneration);
        profileStarted = now;
        profileUpdates = profileRenders = 0;
        profileMaxStep = 0;
    }

    private void OnApplicationQuit()
    {
        Application.runInBackground = originalRunInBackground;
        Screen.sleepTimeout = originalSleepTimeout;
        Application.targetFrameRate = originalFrameRate;
        QualitySettings.vSyncCount = originalVSync;
        OnDemandRendering.renderFrameInterval = originalRenderInterval;
        if (!pluginMissing)
        {
            WWDesktopRestore();
        }
    }
#endif
}
