// SPDX-License-Identifier: GPL-3.0-only
using UnityEngine;

// Schedules scene reactions; the recovered controller owns their playback.
internal sealed class WallwallAmbientInteraction : MonoBehaviour
{
    private IWallwallAmbientPlayer player;
    private WallwallAmbientSettings settings;
    private float activeSeconds;
    private float nextDue;
    private float lastRealtime;
    private int plays;
    private bool initialized;

    private void Update()
    {
        float now = Time.realtimeSinceStartup;
        float step = initialized ? Mathf.Clamp(now - lastRealtime, 0f, WallwallConsts.MaxActiveTimeStepSeconds) : 0f;
        lastRealtime = now;
        WallwallAmbientSettings current = WallwallAmbientSettings.Current;
        if (!initialized || current.IntervalSeconds != settings.IntervalSeconds ||
            current.PlaysPerInterval != settings.PlaysPerInterval)
        {
            settings = current;
            BeginCycle();
            initialized = true;
        }

        if (!WallwallDesktop.IsWallpaperMode)
        {
            if (player != null) player.CancelAmbientInteraction();
            return;
        }
        if (settings.PlaysPerInterval == 0) return;

        activeSeconds += step;
        if (activeSeconds >= settings.IntervalSeconds)
        {
            Debug.Log("[WALLWALL ambient] cycle complete plays=" + plays + "/" + settings.PlaysPerInterval);
            BeginCycle();
            return;
        }
        if (plays >= settings.PlaysPerInterval || activeSeconds < nextDue) return;
        if (player == null) player = FindFirstObjectByType<SpineClickSequencePlayer>();
        if (player != null && player.TryPlayRandomAmbientInteraction())
        {
            plays++;
            ScheduleNext();
        }
        else nextDue = activeSeconds + WallwallConsts.AmbientRetrySeconds;
    }

    private void BeginCycle()
    {
        activeSeconds = 0f;
        plays = 0;
        ScheduleNext();
        Debug.Log("[WALLWALL ambient] cycle interval=" + settings.IntervalSeconds +
            "s target=" + settings.PlaysPerInterval);
    }

    private void ScheduleNext()
    {
        if (settings.PlaysPerInterval == 0 || plays >= settings.PlaysPerInterval)
        {
            nextDue = float.PositiveInfinity;
            return;
        }
        float slice = (float)settings.IntervalSeconds / settings.PlaysPerInterval;
        nextDue = (plays + Random.Range(0.2f, 0.8f)) * slice;
        if (nextDue < activeSeconds) nextDue = activeSeconds + WallwallConsts.AmbientRetrySeconds;
    }
}
