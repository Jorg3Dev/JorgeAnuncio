# Changelog - JorgeAnuncio (Business App)

## [Latest Version] - 2026-06-19

### ✨ Features & Improvements
- **Quick Business Management**: Added a new main "Open/Close Business" button directly on the Business Detail panel, removing the need to use external job menus or the admin panel for daily tasks.
- **Anti-Spam System (Cooldown)**: Implemented a 3-second visual cooldown system on the Open/Close button to prevent database overloads and avoid repetitive accidental clicks.
- **Instant Job Auto-refresh**: Upon receiving or changing a job (`/setjob`), the application interface now updates **instantly** via NUI, bypassing the 30-second background auto-save wait time. Added a 500ms safety margin to ensure proper data propagation from the server.
- **Clean Detail UI**: Removed the old redundant floating open/close button that overlapped with the reviews section on smaller mobile screens.

### 🐛 Bug Fixes
- **Critical SQL Error in Events**: Fixed a faulty SQL query in `server/main.lua` (`updateEvent`) that attempted to update a non-existent column (`time` instead of `eventTime`). This caused uploaded images, banners, and edited event descriptions to fail saving and disappear upon restarting the UI.
- **React Logic Flaw in Admin State**: Fixed a critical bug in `businessStore.tsx` that prevented the UI from applying the player's newly assigned job unless they also experienced a simultaneous change in administrative rank.
- **Admin Event Bypass**: Fixed a design flaw where administrators could create events on behalf of any business from the normal player interface. Administrators must now be assigned the business job (`job`) to manage events from the public view.
- **Admin Business Management Bypass**: Fixed a design flaw where administrators could Open/Close or customize any business from the normal player interface. The public view now strictly respects job ownership (`job`), delegating forced actions exclusively to the Admin Panel.
