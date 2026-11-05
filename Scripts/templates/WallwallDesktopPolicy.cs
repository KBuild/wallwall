// SPDX-License-Identifier: GPL-3.0-only
internal static class WallwallFramePolicy
{
    internal static int UpdateRate(int budget, bool wallpaper, bool reacting, int idle)
    {
        return budget == 30 && wallpaper && !reacting ? idle : budget;
    }
    internal static int RenderInterval(int budget) { return budget <= 2 ? 2 : 1; }
}

internal sealed class WallwallDragInput
{
    private bool needsBaseline = true, pendingDown, pendingUp;
    private uint seenDown, seenUp;
    private float pressX, pressY, releaseX, releaseY;
    internal bool Down { get; private set; }
    internal bool Held { get; private set; }
    internal bool Up { get; private set; }
    internal float X { get; private set; }
    internal float Y { get; private set; }

    internal void Reset()
    {
        needsBaseline = true;
        pendingDown = pendingUp = false;
        Down = Held = Up = false;
    }

    internal void Sample(uint down, uint up, bool held, float px, float py, float rx, float ry)
    {
        Down = Held = Up = false;
        if (needsBaseline)
        {
            seenDown = down;
            seenUp = up;
            needsBaseline = false;
        }
        else
        {
            if (down != seenDown)
            {
                seenDown = down;
                pendingDown = true;
                pressX = px; pressY = py;
            }
            if (up != seenUp)
            {
                seenUp = up;
                pendingUp = true;
                releaseX = rx; releaseY = ry;
            }
        }
        if (pendingDown)
        {
            pendingDown = false;
            X = pressX; Y = pressY;
            Down = Held = true;
        }
        else if (pendingUp)
        {
            pendingUp = false;
            X = releaseX; Y = releaseY;
            Up = true;
        }
        else Held = held;
    }
}
