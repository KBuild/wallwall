# WALLWALL agent guide

## Project purpose

WALLWALL is a personal-use macOS port of the specific Windows Unity wallpaper app in `WallpaperEV/`. This is not an official Wallpaper Engine port or a general-purpose wallpaper player. The supplied folder is a Windows build, not a Unity source project.

## Working principles

- Preserve the behavior of `WallpaperEV/`, including animation, video, and pointer interactions. Record observed behavior separately from guesses based on binaries.
- Do not treat the Windows build as a Unity project that can simply be switched to a macOS build target. The original `Assets/`, `Packages/`, and `ProjectSettings/` directories are unavailable; document recovery limits before selecting the porting route.
- Prefer macOS-native behavior for desktop integration, lifecycle, permissions, display handling, and power use. Keep platform-specific code isolated from wallpaper parsing and rendering where practical.
- Work from user-provided or otherwise authorized files. The app is for personal use; do not assume third-party wallpaper service integration or redistribution rights.
- `WallpaperEV/` and generated `Port/` and `Builds/` are local artifacts excluded from Git. Keep redistributable porting scripts and documentation under `Scripts/` and the repository root. GPL applies to those new scripts, not to recovered game content or third-party runtimes.
- Preserve user files. Opening a wallpaper must not alter its source; put generated data in a separate cache that can be discarded.
- Treat wallpaper packages as untrusted input. Validate paths and sizes, avoid executing bundled scripts as native code, and document any permissions or network access a feature requires.
- Check behavior on multiple displays, different resolutions/scaling, sleep and wake, and app restart when the relevant feature is implemented. Pay attention to CPU/GPU load and battery impact.

## Planning and implementation workflow

- Use only Sol models for sub-agents. Explicitly select `gpt-6-sol` when spawning a sub-agent; do not inherit a non-Sol parent model. If Sol is unavailable, continue in the main agent rather than delegating to another model.

1. Inventory the supplied build in small steps. Inspect its Unity version, managed assemblies, native plug-ins, assets, and observable behavior without changing the original files.
2. Research existing macOS desktop wallpaper implementations on GitHub, prioritizing maintained and well-used projects, but verify their relevance to this Unity application wallpaper.
3. Port the C# behavior in small, reviewable increments. Keep Unity content, macOS desktop integration, and settings as distinct responsibilities where practical.
4. Record a milestone and acceptance criteria before each increment. Prefer short feedback loops and bounded memory use; avoid dumping or copying whole binary assets during investigation.
5. Do not add test code. Verify behavior manually or with end-to-end runs when useful, reporting the exact macOS version, build, device, interaction, and observed result.
6. Record unresolved behavior and porting gaps. Do not claim parity with the Windows app without checking it.
- Keep only the latest generated artifacts at canonical paths. Do not create or retain `old`, `previous`, `backup`, `fixed`, or similar duplicate outputs. Temporary staging may exist only while an operation runs and must be cleaned up afterward.

7. Keep `WORKLOG.md` current with tools used, failed attempts, corrections, and verified results as each step finishes.

## Documentation and third-party code

- Do not create new documentation files unless the user explicitly requests a new document. A code change, investigation, verification, or commit preparation is not permission to add a report, checklist, summary, or other document to the repository.
- Update the relevant existing document only when behavior or durable project guidance changes. Put transient plans, observations, verification results, and handoff notes in the existing Git-ignored `PLAN.md` or `WORKLOG.md`; prefer those files over creating more files. Keep commit-message drafts in a temporary directory outside the repository.
- Before creating any other internal note, verify that its path is ignored with `git check-ignore`. Do not force-add ignored notes, broadly ignore all Markdown, or hide existing project documentation merely to satisfy this rule. If no suitable ignored path exists, use the existing ignored notes or report in chat.
- Documentation requirements below govern necessary updates to existing documents; they do not require new files or README edits for every task. Write technical content in English first, then synchronize README.md (Korean) and README.en.md when their user-facing content is affected. Keep historical work-log entries intact.
- Before copying third-party code, inspect its license and record source, version, required notices, and integration conditions. Public source availability is not proof of an unrestricted license. Keep third-party terms separate from WALLWALL GPL code.
- Native replacement work must pass the feasibility and benefit gates in NATIVE_PLAN.md. Stop and report if it cannot materially improve the existing workflow.
