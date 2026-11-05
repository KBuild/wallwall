// SPDX-License-Identifier: GPL-3.0-only
using System;
class DesktopPolicyTests
{
    static void Check(bool condition) { if (!condition) throw new Exception("Desktop policy regression"); }
    static void Main()
    {
        Check(WallwallFramePolicy.UpdateRate(30, true, false, 24) == 24);
        Check(WallwallFramePolicy.UpdateRate(30, true, true, 24) == 30);
        Check(WallwallFramePolicy.UpdateRate(30, false, false, 24) == 30);
        Check(WallwallFramePolicy.UpdateRate(15, true, true, 24) == 15);
        Check(WallwallFramePolicy.UpdateRate(2, true, true, 24) == 2);
        Check(WallwallFramePolicy.RenderInterval(2) == 2);
        Check(WallwallFramePolicy.RenderInterval(15) == 1);
        Check(WallwallFramePolicy.RenderInterval(30) == 1);
        var drag = new WallwallDragInput();
        drag.Sample(0, 0, false, 0, 0, 0, 0);
        drag.Sample(1, 1, false, 10, 20, 30, 40);
        Check(drag.Down && drag.Held && !drag.Up && drag.X == 10 && drag.Y == 20);
        drag.Sample(1, 1, false, 10, 20, 30, 40);
        Check(!drag.Down && !drag.Held && drag.Up && drag.X == 30 && drag.Y == 40);
        drag.Sample(1, 1, false, 0, 0, 0, 0);
        Check(!drag.Down && !drag.Up && !drag.Held);
        drag.Sample(2, 2, false, 10, 20, 30, 40);
        drag.Reset();
        drag.Sample(2, 2, false, 10, 20, 30, 40);
        Check(!drag.Down && !drag.Up && !drag.Held);
        drag.Sample(3, 2, true, 10, 20, 30, 40);
        Check(drag.Down && drag.Held);
        drag.Sample(3, 2, true, 0, 0, 0, 0);
        Check(!drag.Down && drag.Held && !drag.Up);
        drag.Reset();
        drag.Sample(uint.MaxValue, uint.MaxValue, false, 0, 0, 0, 0);
        drag.Sample(0, 0, false, 1, 2, 3, 4);
        Check(drag.Down && drag.Held);
        drag.Sample(0, 0, false, 1, 2, 3, 4);
        Check(drag.Up && !drag.Held);
        Console.WriteLine("Frame policy and sampled drag checks passed");
    }
}
