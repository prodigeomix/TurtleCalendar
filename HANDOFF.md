# TurtleCalendar — Project Status & Handoff Document

> **Last Updated:** 2026-09-06 09:05 (Antigravity Assistant)  
> **Status:** Production Ready (v1.4.3)  
> **Target Engine:** Turtle WoW 1.18.1 / Vanilla 1.12.1 Client (Turtle WoW & Capybara Paradise realms)  
> **Active Verification:** Pure Lua 5.0 compatible, FrameXML clean

---

## 1. Current Architecture
* **Purpose**: In-game calendar showing raid & instance reset timers, world buffs, and server events for Turtle WoW.
* **Core Components**:
  - `TurtleCalendar.lua`: Calendar grid rendering, reset calculations, character lockout synchronization.
  - `WorldBuffs.lua`: Tracking timers and countdowns for Onyxia / Nefarian head drops, Rend buff, and Hakkar heart.
  - `MinimapIcon.lua`: Minimap button integration with tooltip preview of upcoming resets.
  - `translations/`: Localization tables for English, Russian, Chinese.
* **Slash Command**: `/turtlecalendar` or `/tc` toggles the calendar interface.

---

## 2. Invariant Rules (DO NOT TOUCH)
1. **Timezone & Reset Calculations**:
   - Turtle WoW resets occur on server time (CET/CEST). Do not hardcode local client timezone offsets; use `GetServerTime()` or delta comparisons.
2. **Non-Blocking Calendar Math**:
   - Day and lockout matrix generation must execute lazily when the calendar window is opened, never inside the background `OnUpdate` loop.
3. **SavedVariables Integrity**:
   - Multicharacter lockout data (`TurtleCalendarDB`) must be defensively read; if corrupt or empty, reset gracefully to empty table `{}` without throwing errors on load.

---

## 3. Active Backlog & Next Steps
- [x] Tested and verified on Turtle WoW 1.18.1.
- [x] Git working tree is clean on branch `main`.
- [ ] No changes needed; keep stable.
