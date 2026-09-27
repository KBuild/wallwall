// SPDX-License-Identifier: GPL-3.0-only
// New WALLWALL behavior attached to the recovered controller as a partial class.
using System;
using System.Collections.Generic;
using Spine;
using UnityEngine;

public partial class SpineClickSequencePlayer : IWallwallAmbientPlayer
{
    private Slot wallwallForegroundLeaf;
    private Slot wallwallFrontTail;
    private AreaBinding ambientOverlayArea;
    private float ambientOverlayEndsAt;
    private bool ambientPlayingSet;
    private int lastAmbientChoice = -1;
    private AreaBinding wallwallHoverArea;
    private float wallwallNextVisibilityCheck;
    private bool wallwallPointerVisible;
    private AreaBinding wallwallVisibilityArea;
    private float wallwallHoverStartedAt;
    private float wallwallHoverOverlayEndsAt;
    private bool wallwallHoverActive;
    private bool wallwallHoverTriggered;
    private bool wallwallDwellPlayingSet;
    private bool wallwallWasHoverMode;

    private void InitializeWallwallExtras()
    {
        wallwallForegroundLeaf = skeleton.FindSlot("BG_leaf");
        wallwallFrontTail = skeleton.FindSlot("YN_tale_2");
    }

    // The source atlas cuts BG_leaf off vertically at its right edge. Keep the
    // leaf behind YN's front tail piece so it hides the straight edge while
    // the main leaf cluster remains in front of the back tail.
    private void KeepLeafBehindWhiteTail()
    {
        if (wallwallForegroundLeaf == null || wallwallFrontTail == null) return;
        var drawOrder = skeleton.DrawOrder.AppliedPose;
        Slot[] slots = drawOrder.Items;
        int leafIndex = -1;
        int tailIndex = -1;
        for (int i = 0; i < drawOrder.Count; i++)
        {
            if (slots[i] == wallwallForegroundLeaf) leafIndex = i;
            if (slots[i] == wallwallFrontTail) tailIndex = i;
        }
        if (leafIndex < 0 || tailIndex < 0 || leafIndex < tailIndex) return;
        Slot leaf = slots[leafIndex];
        for (int i = leafIndex; i > tailIndex; i--) slots[i] = slots[i - 1];
        slots[tailIndex] = leaf;
    }

    public bool TryPlayRandomAmbientInteraction()
    {
        if (state == null || skeleton == null || isPlayingSet || pointerActive ||
            wallwallHoverArea != null || Input.GetMouseButton(0)) return false;

        List<AreaBinding> headAreas = new List<AreaBinding>();
        foreach (AreaBinding area in areas)
        {
            if (area != null && area.boneName != null &&
                area.boneName.EndsWith("_head_control", StringComparison.Ordinal) &&
                area.useOverlay && !string.IsNullOrEmpty(area.overlayAnimation) &&
                skeleton.Data.FindAnimation(area.overlayAnimation) != null)
                headAreas.Add(area);
        }

        List<AnimationSet> sequences = new List<AnimationSet>();
        HashSet<string> seen = new HashSet<string>();
        foreach (AnimationSet set in clickSets)
        {
            if (HasAvailableAmbientAnimations(set) && seen.Add(string.Join("|", set.animations)))
                sequences.Add(set);
        }
        foreach (AreaBinding area in areas)
        {
            if (area == null || area.clickSets == null) continue;
            foreach (AnimationSet set in area.clickSets)
            {
                if (HasAvailableAmbientAnimations(set) && seen.Add(string.Join("|", set.animations)))
                    sequences.Add(set);
            }
        }

        int count = headAreas.Count + sequences.Count;
        if (count == 0) return false;
        int choice = UnityEngine.Random.Range(0, count);
        if (count > 1 && choice == lastAmbientChoice)
            choice = (choice + UnityEngine.Random.Range(1, count)) % count;
        lastAmbientChoice = choice;

        if (choice < headAreas.Count)
        {
            ambientOverlayArea = headAreas[choice];
            ambientOverlayEndsAt = Time.realtimeSinceStartup + UnityEngine.Random.Range(2f, 4f);
            Debug.Log("[WALLWALL ambient] head=" + ambientOverlayArea.overlayAnimation);
        }
        else
        {
            AnimationSet set = sequences[choice - headAreas.Count];
            ambientPlayingSet = true;
            PlayAnimationSet(set);
            Debug.Log("[WALLWALL ambient] sequence=" + string.Join("|", set.animations));
        }
        return true;
    }

    public void CancelAmbientInteraction()
    {
        ambientOverlayArea = null;
        ambientOverlayEndsAt = 0f;
        if (ambientPlayingSet)
        {
            ambientPlayingSet = false;
            PlayIdle();
        }
    }

    private void AmbientSequenceCompleted()
    {
        if (!ambientPlayingSet && !wallwallDwellPlayingSet) return;
        ambientPlayingSet = false;
        wallwallDwellPlayingSet = false;
        PlayIdle();
    }

    private bool HasAvailableAmbientAnimations(AnimationSet set)
    {
        if (!HasPlayableAnimations(set)) return false;
        foreach (string animation in set.animations)
        {
            if (!string.IsNullOrEmpty(animation) && skeleton.Data.FindAnimation(animation) == null)
                return false;
        }
        return true;
    }

    // Hover mode uses the existing cursor source and never takes Finder's
    // mouse event. Drag mode is handled by the recovered pointer controller.
    private void UpdateWallwallHover()
    {
        bool wallpaperMode = WallwallDesktop.IsWallpaperMode;
        bool hoverMode = wallpaperMode && WallwallDesktop.PointerMode == 0;
        if (hoverMode != wallwallWasHoverMode)
        {
            StopWallwallHover();
            pointerActive = pointerDragging = false;
            hasDraggedThisPress = false;
            activeArea = null;
            activeBone = null;
            wallwallNextVisibilityCheck = 0f;
        }
        wallwallWasHoverMode = hoverMode;
        if (!hoverMode ||
            !enableCursorBoneDrive || state == null)
        {
            StopWallwallHover();
            return;
        }

        Vector2 position = WallwallDesktop.PointerPosition;
        AreaBinding area = FindAreaUnder(position);
        if (!HasDwellReaction(area) || (pointerActive && !wallwallHoverActive))
        {
            StopWallwallHover();
            return;
        }

        float now = Time.realtimeSinceStartup;
        if (area != wallwallVisibilityArea || now >= wallwallNextVisibilityCheck)
        {
            wallwallVisibilityArea = area;
            wallwallPointerVisible = WallwallDesktop.PointerUnobscured;
            wallwallNextVisibilityCheck = now + 0.1f;
        }
        if (!wallwallPointerVisible)
        {
            StopWallwallHover();
            return;
        }

        if (area != wallwallHoverArea)
        {
            StopWallwallHover();
            wallwallHoverArea = area;
            wallwallHoverStartedAt = Time.realtimeSinceStartup;
            return;
        }

        if (wallwallHoverActive)
        {
            if (now >= wallwallHoverOverlayEndsAt) ReleaseWallwallHoverOverlay();
            else pointerCurrScreen = position;
            return;
        }
        if (wallwallHoverTriggered) return;
        if (now - wallwallHoverStartedAt < WallwallDesktop.HoverDwellSeconds ||
            (isPlayingSet && !ambientPlayingSet)) return;

        CancelAmbientInteraction();
        wallwallHoverTriggered = true;
        if (area.useOverlay && !string.IsNullOrEmpty(area.overlayAnimation) &&
            areaBones.TryGetValue(area, out Bone bone) && bone != null)
        {
            activeArea = area;
            activeBone = bone;
            pointerActive = pointerDragging = true;
            pointerPrevScreen = pointerCurrScreen = position;
            wallwallHoverActive = true;
            wallwallHoverOverlayEndsAt = now + 2f;
            Debug.Log("[WALLWALL dwell] overlay=" + area.overlayAnimation + " area=" + area.boneName);
        }
        else if (FindDwellSequence(area) is AnimationSet set)
        {
            wallwallDwellPlayingSet = true;
            PlayAnimationSet(set);
            Debug.Log("[WALLWALL dwell] sequence=" + string.Join("|", set.animations));
        }
    }

    private bool HasDwellReaction(AreaBinding area)
    {
        if (area == null) return false;
        if (area.useOverlay && !string.IsNullOrEmpty(area.overlayAnimation) &&
            skeleton.Data.FindAnimation(area.overlayAnimation) != null &&
            areaBones.TryGetValue(area, out Bone bone) && bone != null) return true;
        return FindDwellSequence(area) != null;
    }

    private AnimationSet FindDwellSequence(AreaBinding area)
    {
        if (area == null || !area.useClickSequence || area.clickSets == null) return null;
        foreach (AnimationSet set in area.clickSets)
            if (HasAvailableAmbientAnimations(set)) return set;
        return null;
    }

    // The recovered click sequence is normally suppressed once the pointer
    // crosses the drag threshold. In wallpaper drag mode, play a touch-area
    // sequence once at that threshold so stroking HY's tail is responsive.
    private void TryPlayWallwallDragSequence(AreaBinding area)
    {
        if (!WallwallDesktop.IsWallpaperMode || WallwallDesktop.PointerMode != 1) return;
        AnimationSet set = FindDwellSequence(area);
        if (set == null) return;
        wallwallDwellPlayingSet = true;
        PlayAnimationSet(set);
        Debug.Log("[WALLWALL drag] sequence=" + string.Join("|", set.animations));
    }

    private void ReleaseWallwallHoverOverlay()
    {
        if (!wallwallHoverActive) return;
        if (logInteractions) Debug.Log("[WALLWALL dwell] end area=" + wallwallHoverArea.boneName);
        pointerActive = pointerDragging = false;
        activeArea = null;
        activeBone = null;
        wallwallHoverActive = false;
    }

    private void StopWallwallHover()
    {
        ReleaseWallwallHoverOverlay();
        wallwallHoverArea = null;
        wallwallHoverTriggered = false;
    }
}
