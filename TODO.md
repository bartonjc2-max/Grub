# Grub iOS — TODO

## Sprint 1 (App Store Launch)
- [x] Fix stat bar icons to match theme
- [x] Wire trait bonuses into gameplay
- [x] Wire decoration bonuses into gameplay
- [x] Fix AudioEngine performance
- [x] Fix stat bar timer leak
- [x] Fix toast race condition
- [x] Remove duplicate stats views
- [x] Refactor top bar to text-only
- [x] Remove journal entries tab
- [x] Add trait progress UI
- [x] Speed up decay rates
- [x] Foraging/expeditions cost stats
- [x] Reduce expedition/forage timers
- [x] Expedition exclusive rewards (scrolls, guaranteed rares)
- [x] Real-time expedition find popups
- [x] Faster stat decay while on expedition
- [x] Fix event firing on first launch
- [x] Remove dead code (StatsMenuView, sortedJournalEntries)
- [x] Add GameState deinit
- [x] Full QA pass
- [x] UI polish (remove green separator lines, fix 13 UI issues)
- [ ] App Store assets (icon, screenshots, description)
- [x] Privacy policy
- [ ] Signing & provisioning

## Sprint 2
- [ ] **Combat system** — grub can fight enemies for XP
- [ ] **Burrow visual overhaul** — visual representation of burrow with placed decorations, not just a list. Add direct access button on main screen
- [ ] **Save data versioning** — migration path for future updates
- [ ] **GameState refactor** — break up God Object (1161 lines, 70+ @Published)
- [ ] **SpriteRenderer refactor** — split 1817-line file by category
