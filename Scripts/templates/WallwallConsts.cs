// SPDX-License-Identifier: GPL-3.0-only

// Defaults and scheduler policy. The macOS menu stores the user's choices;
// these values are used before the desktop plug-in becomes ready.
internal static class WallwallConsts
{
    internal const int DefaultAmbientIntervalSeconds = 600;
    internal const int DefaultAmbientCount = 5;
    internal const float AmbientRetrySeconds = 2f;
    internal const float MaxActiveTimeStepSeconds = 1f;
}

internal interface IWallwallAmbientPlayer
{
    bool TryPlayRandomAmbientInteraction();
    void CancelAmbientInteraction();
}

internal readonly struct WallwallAmbientSettings
{
    internal readonly int IntervalSeconds;
    internal readonly int PlaysPerInterval;

    internal WallwallAmbientSettings(int intervalSeconds, int playsPerInterval)
    {
        IntervalSeconds = intervalSeconds > 0 ? intervalSeconds : WallwallConsts.DefaultAmbientIntervalSeconds;
        PlaysPerInterval = playsPerInterval >= 0 ? playsPerInterval : WallwallConsts.DefaultAmbientCount;
    }

    internal static WallwallAmbientSettings Current =>
        new WallwallAmbientSettings(WallwallDesktop.AmbientIntervalSeconds, WallwallDesktop.AmbientCount);
}
