# SecuredCalling – Responsive UI Implementation Guide

This document describes how to make the app responsive across **Mobile**, **Tablet**, and **Laptop** without changing functionality or user flow. Work through it feature-by-feature.

---

## 1. Foundation (Do First)

### 1.1 Breakpoints and Layout Types

Define a single source of truth for breakpoints and layout type. Add this **before** touching any feature UI.

| Layout Type | Min Width | Typical devices |
|-------------|-----------|------------------|
| **Mobile**  | 0 – 599 px   | Phones (portrait/landscape) |
| **Tablet**  | 600 – 1023 px | Tablets, small laptops |
| **Laptop**  | 1024+ px   | Desktops, large laptops |

**Recommended:** Add a responsive helper in `lib/core/` so all features use the same logic.

**New file: `lib/core/utils/responsive_utils.dart`** (create this first)

```dart
import 'package:flutter/material.dart';

class AppBreakpoints {
  static const double mobile = 0;
  static const double tablet = 600;
  static const double laptop = 1024;
}

enum AppLayoutType { mobile, tablet, laptop }

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  AppLayoutType get layoutType {
    final w = screenWidth;
    if (w >= AppBreakpoints.laptop) return AppLayoutType.laptop;
    if (w >= AppBreakpoints.tablet) return AppLayoutType.tablet;
    return AppLayoutType.mobile;
  }

  bool get isMobile => layoutType == AppLayoutType.mobile;
  bool get isTablet => layoutType == AppLayoutType.tablet;
  bool get isLaptop => layoutType == AppLayoutType.laptop;
}

/// Use for content that should not stretch too wide on large screens (forms, cards).
///
/// Laptop returns a narrower value (480) than tablet (560) on purpose: on wide screens,
/// forms and centered content read better when kept moderately narrow; tablet gets
/// slightly more width for mid-size screens. Use this for forms and card content, not
/// for full-bleed layouts.
double contentMaxWidth(BuildContext context) {
  switch (context.layoutType) {
    case AppLayoutType.mobile:
      return double.infinity;
    case AppLayoutType.tablet:
      return 560;
    case AppLayoutType.laptop:
      return 480;
  }
}

/// Standard horizontal/outer padding by layout. Use consistently so screens don't mix
/// hardcoded values. Required for the feature plan below.
double responsivePadding(BuildContext context) {
  if (context.isLaptop) return 32;
  if (context.isTablet) return 24;
  return 16;
}

/// Use for in-call control sizes (e.g. mic circle, speaker button) in the Agora meeting
/// room. Single source of truth so radii are consistent and maintainable.
///
/// Values scale *down* on larger screens on purpose: on mobile, touch targets need to
/// be large (60) for fingers; on laptop, pointer/mouse allows smaller controls (48);
/// tablet (56) is in between. If you preferred "scale up on bigger screens," invert
/// the values and add a comment here.
double controlRadius(BuildContext context) {
  if (context.isLaptop) return 48;
  if (context.isTablet) return 56;
  return 60; // mobile default
}
```

Use `context.layoutType`, `context.isMobile`, `context.isTablet`, `context.isLaptop`, `contentMaxWidth(context)`, and `responsivePadding(context)` everywhere you need to branch layout or spacing.

### 1.2 Responsive Spacing and Sizing

- Replace **fixed values** (e.g. `16`, `24`, `80`) with values that scale by layout where it improves UX (e.g. padding, icon sizes, card padding).
- Use **`responsivePadding(context)`** from `responsive_utils.dart` for screen and card padding so all features stay consistent; do not hardcode different padding values per screen.
- Keep using your existing **`.w` and `.h`** extensions from `app_int_extension.dart` for small inline spacing; for layout-dependent values, use the responsive helpers above.

### 1.3 LayoutBuilder vs MediaQuery

- **MediaQuery** (e.g. `MediaQuery.sizeOf(context)`, the extension above) is ideal for **screen-level** decisions: full-width layout, breakpoint-based columns, app bars. It reflects the full screen size.
- **LayoutBuilder** is better for **widgets deep in the tree** that are already inside a constrained parent (e.g. a card inside a `ConstrainedBox`, or `MeetingInfoCard` inside a scroll view with a max width). There, the widget’s **actual available width** can be less than the screen width; `LayoutBuilder` gives you that constraint, so you can avoid overflow or wrong layout when the card is narrow. Use `LayoutBuilder` when a widget’s layout should depend on the space it’s given, not the whole screen.

### 1.4 What Not to Change

- **Navigation flow:** Same routes, same back/forward behavior.
- **GetX usage:** Controllers, bindings, Obx/GetBuilder stay as-is.
- **Business logic:** Auth, meeting creation, recording, permissions—no change.
- **Feature set:** No new/removed features; only layout and sizing adapt.

---

## 2. Feature-by-Feature Plan

Implement in this order so shared pieces (theme, widgets) are ready before screens that use them.

---

### Feature 1: Core theme and app shell

**Scope:** `lib/core/theme/app_theme.dart`, `lib/app/app.dart`, `main.dart`.

**Tasks:**

1. **Theme:** Keep current theme. Optionally add responsive text scale or padding in theme if you want global scaling (e.g. `MediaQuery.textScalerOf(context)` or padding in `MaterialApp`). Not required for a first pass.
2. **App shell:** If `MaterialApp` has any fixed padding or width, remove or make it depend on `MediaQuery`/layout type.
3. **No flow change:** App entry, theme, and routing stay the same.

**Deliverable:** Theme and app shell work on all widths; no new breakpoint logic required here if you only use the responsive utils in features below.

---

### Feature 2: Welcome screen

**File:** `lib/features/welcome/views/welcome_screen.dart`

**Current:** Uses `MediaQuery.of(context).size` and fixed padding (e.g. 24, 32).

**Tasks:**

1. **Layout:**  
   - **Mobile:** Keep current single-column, full-width layout.  
   - **Tablet/Laptop:** Wrap main content in `Center` + `ConstrainedBox` with `maxWidth` (e.g. 500–560) so the card and text don’t span the whole width.
2. **Sizing:**  
   - Logo: keep or make slightly larger on tablet/laptop (e.g. 80 → 96 on tablet, 100 on laptop) using `context.layoutType`.  
   - Padding: replace `EdgeInsets.symmetric(horizontal: 24)` with `responsivePadding(context)` (or 16/24/32 by layout).
3. **Flow:** Same buttons (Login / Register), same navigation; only layout and spacing change.

**Deliverable:** Welcome looks good on narrow and wide screens; content doesn’t over-stretch on tablet/laptop.

---

### Feature 3: Auth (Login & Register)

**Files:**  
- `lib/features/auth/views/login_screen.dart`  
- `lib/features/auth/views/register_screen.dart`

**Tasks:**

1. **Form width:**  
   - **Mobile:** Full width with existing padding.  
   - **Tablet/Laptop:** Center the form and limit width (e.g. `contentMaxWidth(context)` or 400–480) so the form doesn’t stretch across the screen.
2. **Padding:** Use responsive horizontal padding (e.g. 24 on mobile, 32 on tablet/laptop) and consistent vertical spacing.
3. **Logo and titles:** Same as welcome: optional slightly larger logo on larger layouts; keep hierarchy.
4. **Flow:** Same validation, same submit → navigation; no change to `LoginRegisterController` or bindings.

**Deliverable:** Login and Register are readable and centered on all devices; no flow change.

---

### Feature 4: Home screen

**File:** `lib/features/home/views/home_screen.dart`

**Current:** Single column, full-width profile card, tab bar, then tab content.

**Tasks:**

1. **Structure:**  
   - **Mobile:** Keep current layout (profile card → tabs → content).  
   - **Tablet/Laptop:**  
     - Option A: Same single column but with `ConstrainedBox` (e.g. maxWidth 600–700) and `Center` so content is centered.  
     - Option B: On laptop only, consider a two-column layout (e.g. profile + tabs on left, content on right); only if you want a denser layout without changing flow.
2. **Profile card:** Keep gradient and info; use responsive padding and font size if desired (e.g. slightly larger text on tablet/laptop).
3. **Tab bar:** Same two tabs (Host Meeting / Join Meeting); ensure tab bar doesn’t stretch awkwardly on wide screens (constrain width or center).
4. **AppBar:** Same actions (logout, debug). On tablet/laptop, ensure overflow and spacing look good.
5. **Flow:** Tab switch, navigation to Admin/Users, sign out—unchanged.

**Deliverable:** Home works on all sizes; content optionally centered/constrained on large screens.

---

### Feature 5: Home – Member tab (Host Meeting)

**File:** `lib/features/home/views/membar_tab_view_widget.dart`

**Tasks:**

1. **Content width:** Apply same max-width/centering as Home (e.g. parent already constrained, or add `ConstrainedBox` here).
2. **Action card (“Create Meeting”):** Already a card; ensure padding uses responsive values so it doesn’t look tiny on laptop.
3. **Meetings list:** Use the same list/grid rule as Feature 7: single column on mobile, 2-column (or 2–3 on laptop) grid on tablet/laptop. Implement when you do Feature 7 and reuse here.
4. **Flow:** Create Meeting → permission → `MeetingUtil.createNewMeeting`; stream of meetings—unchanged.

**Deliverable:** Member tab layout and list scale; flow unchanged.

---

### Feature 6: Home – User tab (Join Meeting)

**File:** `lib/features/home/views/user_tab.dart`

**Tasks:**

1. **Content width:** Align with Home: constrain/center on tablet/laptop.
2. **Meeting list / join UI:** Same behavior; use responsive padding and spacing.
3. **Flow:** Join meeting, navigation to meeting room—unchanged.

**Deliverable:** Join Meeting tab responsive; flow unchanged.

---

### Feature 7: Meeting tiles and cards

**Files:**  
- `lib/features/home/views/meeting_tile_widget.dart`  
- `lib/features/home/views/meeting_action_card.dart`  
- `lib/widgets/meeting_info_card.dart`

**Tasks:**

1. **Meeting tile list layout (firm):**  
   - **Mobile:** Single-column list; each tile is full-width row/card.  
   - **Tablet:** Grid with **2 columns** (e.g. `GridView` or `SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2)`), same tap-to-join behavior and scrolling.  
   - **Laptop:** Grid with **2 columns** (or 3 if tile min width allows); same behavior.  
   Use `context.layoutType` (or `context.isTablet`/`context.isLaptop`) to choose list vs grid in the parent that builds the meetings list (Member tab, User tab, View-all). Do not leave this optional—inconsistent list vs grid across screens looks unpolished.
2. **Meeting tile widget:** Tile content (title, time, actions) stays the same; ensure it lays out correctly when used inside a grid cell (bounded width).
3. **Action card (Create Meeting, etc.):** Use `responsivePadding(context)`; same button and `onPressed`.
4. **MeetingInfoCard:** Used in meeting detail; if inside a constrained parent, consider `LayoutBuilder` for internal padding/margin so it respects available width; keep all rows and copy behavior.
5. **Flow:** No change to tap targets or navigation.

**Decision (apply consistently):** Use a **single-column list** on mobile; use a **grid** on tablet and laptop so the meeting list looks intentional and consistent everywhere.

**Deliverable:** Cards and tiles adapt to width; meeting lists use a single-column list on mobile and a 2 (or 2–3) column grid on tablet/laptop everywhere they appear.

---

### Feature 8: Agora meeting room (in-call UI)

**File:** `lib/features/meeting/views/agora_meeting_room.dart`

**Current:** AppBar, video area, bottom controls (mic, speaker, end call) with fixed sizes (e.g. `radius: 60`, `radius: 75`). This is the highest-risk screen (live video, PTT, permissions).

**Layout plan (maintainable):**

- **Single computed value for control size:** Do not scatter inline ternaries for radius/padding. Use **`controlRadius(context)`** from `responsive_utils.dart` everywhere the mic circle, speaker button, or other in-call controls need a radius or size. Define it once in the foundation (see §1.1); in the meeting room, use only this getter (e.g. `CircleAvatar(radius: controlRadius(context), …)`). That keeps host vs participant and mobile vs tablet/laptop consistent and easy to tweak later.
- **Padding:** Use `responsivePadding(context)` for bottom bar and control spacing.

**Tasks:**

1. **Video region:**  
   - Keep one main video area; ensure it scales with `Expanded` and doesn’t assume phone aspect ratio.  
   - **Tablet/Laptop:** Same layout; optionally show a larger video area or side panel for participants (only layout, same data).
2. **Bottom controls:**  
   - **Mobile:** Keep current layout (mic circle, speaker, end call).  
   - **Tablet/Laptop:** Same controls; use **`controlRadius(context)`** for the mic circle (and any other circular/control size). Use the same getter for host and participant views so host `radius: 60` and participant `radius: 75` are replaced by one source of truth. Scale any remaining button padding with `responsivePadding(context)` or a derivative so controls don't look too small or too large.
3. **AppBar:** Title and actions; ensure they don’t overflow on narrow mobile; on wide screens keep centered or aligned as now.
4. **JoinRequestWidget:** Same logic; ensure overlay/sheet is responsive (padding, max width).
5. **Flow:** PTT, speaker, end call, recording indicator, meeting info—all unchanged.

**Deliverable:** In-call UI scales; all control radii and key padding come from `controlRadius(context)` and `responsivePadding(context)` with no inline size logic.

---

### Feature 9: Meeting detail page

**File:** `lib/features/meeting/views/meeting_detail_page.dart`

**Current:** `CustomScrollView`, `SliverAppBar`, `MeetingInfoCard`, tabs (Participants / Recordings), lists.

**LayoutBuilder:** For widgets deep inside the constrained scroll view (e.g. `MeetingInfoCard`, participant list items), use **LayoutBuilder** (see §1.3) so they adapt to the *available* width, not just screen width—avoids overflow when content is constrained.

**Tasks:**

1. **Scroll view:** Keep; already flexible.
2. **Content width:** On tablet/laptop, consider constraining the scroll content (e.g. `SliverToBoxAdapter` with `ConstrainedBox` + `Center`) so text and cards don’t span full width.
3. **Tabs:** Same two tabs; responsive padding for tab bar and content.
4. **Participants list:** Same; optional: on laptop, table-like row layout for each participant (same data, different visual layout).
5. **Recordings:** Same mix/individual lists and actions (play, download); responsive padding and tile size.
6. **Flow:** Refresh, tab switch, copy meeting ID, download—unchanged.

**Deliverable:** Meeting detail readable and well-sized on all devices; flow unchanged.

---

### Feature 10: Dialogs and overlays

**Files:**  
- `lib/features/meeting/views/join_meeting_dialog.dart`  
- `lib/features/meeting/views/show_meeting_info.dart`  
- `lib/features/meeting/views/user_join_request_popup.dart`  
- `lib/features/meeting/widgets/extend_meeting_dialog.dart`  
- `lib/features/meeting/widgets/timer_warning_dialog.dart`  
- `lib/widgets/password_reset_dialog.dart`  
- `lib/widgets/user_credentials_dialog.dart`

**Tasks:**

1. **Dialog max width:** For all dialogs, set `maxWidth` (e.g. 400 on mobile, 500 on tablet/laptop) so they don’t stretch on large screens. Use `context.layoutType` when building the dialog.
2. **Padding and font size:** Responsive padding inside dialogs; keep text readable.
3. **Flow:** All buttons and callbacks (join, extend, accept request, copy credentials, etc.) unchanged.

**Deliverable:** Dialogs and popups look good on all screen sizes; behavior unchanged.

---

### Feature 11: Admin section

**Files:**  
- `lib/features/admin/admin_home.dart`  
- `lib/features/admin/member_form.dart`  
- `lib/features/admin/all_user_member_list.dart`  
- `lib/features/admin/member_reminder_page.dart`

**Decision (align with Feature 7):** Use the same list/grid pattern as meeting tiles for cohesion: **single column on mobile**, **2-column grid or table on tablet/laptop** for the member list and all-user/member lists. Do not leave this optional.

**LayoutBuilder:** For cards or form sections inside a constrained scroll view (e.g. member cards, reminder list), use **LayoutBuilder** (see §1.3) so layout respects available width.

**Tasks:**

1. **Admin home (member list):**  
   - **Mobile:** Single-column list/cards.  
   - **Tablet/Laptop:** Constrain content width and center; use a **2-column grid or table** for members (same data, same tap behavior). Search and filter chips—same behavior; responsive padding.
2. **Member form:** Constrain form width on tablet/laptop; center; responsive padding. Same fields and submit flow.
3. **All user/member list and reminder page:** Same pattern—single column on mobile, 2-column grid or table on tablet/laptop; responsive padding. No flow change.
4. **Flow:** Create member, edit, reminders, navigation—unchanged.

**Deliverable:** Admin screens usable on all devices; list layout consistent with Feature 7; flow unchanged.

---

### Feature 12: Users screen and user creation

**Files:**  
- `lib/features/home/views/users_screen.dart`  
- `lib/features/home/views/user_creation_form.dart`

**Decision (align with Feature 7 and 11):** Same list/grid pattern: **single column on mobile**, **2-column grid or table on tablet/laptop** for the users list. Keeps all list screens (meetings, members, users) cohesive.

**Tasks:**

1. **Users list:**  
   - **Mobile:** Single-column list.  
   - **Tablet/Laptop:** 2-column grid or table for user rows; same actions (edit, delete, etc.). Responsive padding.
2. **User creation form:** Constrain width and center on large screens; responsive padding; same validation and submit.
3. **Flow:** List users, create user, navigate back—unchanged.

**Deliverable:** Users and user creation responsive; list layout consistent with Features 7 and 11; flow unchanged.

---

### Feature 13: Remaining shared widgets and utils

**Files:**  
- `lib/widgets/app_text_form_widget.dart`  
- `lib/widgets/app_dropdown_field.dart`  
- `lib/widgets/participant_list_item.dart`  
- `lib/widgets/no_data_found_widget.dart`  
- `lib/features/meeting/widgets/recorder_audio_tile.dart`  
- `lib/features/meeting/widgets/clip_audio_downloader.dart` (if it has UI)  
- Other small widgets used across features

**Tasks:**

1. Replace fixed padding/margins with responsive values where the widget is used (or add an optional `padding` parameter and pass responsive padding from parent).
2. Ensure no fixed `width`/`height` that would break layout on small or large screens (use `Expanded`, `Flexible`, or layout-based values).
3. **Flow:** No behavioral change; only layout and spacing.

**Deliverable:** Shared widgets work well in all layouts.

---

### Feature 14: View-all meeting list and other secondary screens

**Files:**  
- `lib/features/home/views/view_all_meeting_list.dart`  
- `lib/features/home/network_log_screen.dart`  
- `lib/features/home/views/delete_confirmation_dialog.dart`

**Tasks:**

1. **View-all list:** Same as meeting tiles—responsive list/grid; constrain width on large screens if needed.
2. **Network log:** Responsive padding and font size; consider horizontal scroll for wide tables on mobile.
3. **Delete confirmation:** Same as other dialogs—max width and responsive padding.
4. **Flow:** Unchanged.

**Deliverable:** All secondary screens and dialogs responsive.

---

## 3. Implementation Checklist (Summary)

| Order | Feature | Main files | Key change |
|-------|--------|------------|------------|
| 0 | Foundation | New `core/utils/responsive_utils.dart` | Breakpoints, `layoutType`, `contentMaxWidth`, `responsivePadding`, `controlRadius` |
| 1 | Theme / app | `app_theme.dart`, `app.dart` | Optional global scaling; no flow change |
| 2 | Welcome | `welcome_screen.dart` | Center + maxWidth; responsive padding/logo |
| 3 | Auth | `login_screen.dart`, `register_screen.dart` | Center form; maxWidth; responsive padding |
| 4 | Home | `home_screen.dart` | Constrain/center body; responsive profile card and tabs |
| 5 | Member tab | `membar_tab_view_widget.dart` | Same constraint; list/grid per Feature 7 |
| 6 | User tab | `user_tab.dart` | Same constraint; responsive spacing |
| 7 | Tiles & cards | `meeting_tile_widget.dart`, `meeting_action_card.dart`, `meeting_info_card.dart` | Responsive padding; list on mobile, 2(-3) column grid on tablet/laptop (firm) |
| 8 | Meeting room | `agora_meeting_room.dart` | `controlRadius(context)` + `responsivePadding(context)`; no inline size logic |
| 9 | Meeting detail | `meeting_detail_page.dart` | Constrain content; responsive tabs and lists |
| 10 | Dialogs | All dialog/popup files listed in 2.10 | Max width; responsive padding |
| 11 | Admin | `admin_home.dart`, `member_form.dart`, etc. | Constrain/center; list on mobile, 2-col grid/table on tablet/laptop (firm); LayoutBuilder for deep widgets |
| 12 | Users | `users_screen.dart`, `user_creation_form.dart` | Constrain form and list; list on mobile, 2-col grid/table on tablet/laptop (firm) |
| 13 | Shared widgets | Form fields, list items, tiles | Responsive padding/sizing at usage site |
| 14 | Other screens | View-all, network log, delete dialog | Same patterns as above |

---

## 4. Testing Strategy

- **Mobile:** Portrait and landscape (e.g. 360×800, 800×360).  
- **Tablet:** 600×960, 768×1024, 1024×768.  
- **Laptop:** 1280×720, 1920×1080.

**Orientation change:** Test **dynamic orientation change** (e.g. rotate a tablet or phone mid-session). Layout is driven by `MediaQuery.sizeOf`, so constraints update when the size changes, but orientation change is a common source of layout bugs in Flutter (overflow, wrong constraints, or stale layout). Explicitly run through key screens in both orientations and after rotating during a flow (e.g. welcome → rotate → login → home → rotate → open meeting list) to catch issues.

For each feature after changes:

1. **Flow:** Run through the same user journey (e.g. login → home → create/join meeting → in-call → meeting detail).  
2. **Layout:** Resize window (Flutter desktop) or use different device sizes; ensure no overflow, no clipped content, and readable text.  
3. **Touch/targets:** On mobile, keep tap targets ≥ 48 pt where possible.

---

## 5. Quick Reference: Do’s and Don’ts

**Do:**

- Use `context.layoutType` (or `isMobile` / `isTablet` / `isLaptop`) for layout branches.
- Use `contentMaxWidth(context)` (or similar) for forms and centered content.
- Use `responsivePadding(context)` for consistency (do not hardcode 16/24/32 per screen).
- Keep all navigation, controllers, and business logic unchanged.
- Test at 360px, 600px, and 1024px width; test orientation change on tablet/phone.

**Don’t:**

- Change route names, arguments, or navigation flow.
- Remove or add features for “desktop only” or “mobile only” in this pass.
- Use hard-coded widths for full-screen content (prefer `double.infinity` or `Expanded` and constraints from parent).
- Introduce different UX flows per device (e.g. different steps to join a meeting); only layout and density should differ.

Following this guide feature-by-feature will give you a responsive Mobile/Tablet/Laptop UI while preserving the existing functionality flow.

---

## 6. Cross-check: Implementation safeguards (no functionality break)

Use this section to verify that responsive changes do **not** change behavior or break the app.

### 6.1 Routes and navigation — do not change

| Route / target | How it's used today | Safeguard |
|----------------|---------------------|------------|
| `AppRouter.welcomeRoute` | Welcome → Login | Keep `Navigator.pushNamed(context, AppRouter.loginRoute)`. |
| `AppRouter.loginRoute` | Login → Home | Keep `Navigator.pushReplacementNamed(context, AppRouter.homeRoute)`. |
| `AppRouter.homeRoute` | Home; Admin/Users from app bar | Keep `Navigator.push(..., AdminScreen())` / `UsersScreen()`. |
| `AppRouter.meetingDetailRoute` | Tile tap → detail | Keep `arguments: {'meetingId': widget.model.meetId}`. |
| `AppRouter.meetingRoomRoute` | Join/start meeting | Keep `arguments: {'channelName': ..., 'isHost': ..., 'meetingId': ...}`. |
| `AppRouter.meetingViewAllRoute` | User tab "View All" | Keep `arguments: meetings` (full `List<MeetingModel>`). |

Do not replace `Navigator.pushNamed` / `Navigator.push` with different APIs or change argument keys/values. Do not add or remove routes.

### 6.2 Controllers and bindings — do not change

- **GetX:** Keep all `Get.find`, `Get.put`, `Obx`, `GetBuilder`, and bindings (e.g. `MeetingBinding`, `MeetingDetailBinding`, `AuthBinding`) exactly as today. Only the **widget tree and layout** (padding, constraints, list vs grid) change; controller logic and lifecycle stay the same.
- **MeetingDetailPage:** Takes `meetingId` (String); route passes `args['meetingId']`. Do not change the constructor or the way the binding/controller receives `meetingId`.
- **MeetingUtil.createNewMeeting(context: context):** Keep the same call from the Member tab; only the surrounding layout (e.g. padding, max width) may change.

### 6.3 List → grid: preserve behavior and scroll

- **Same widget in grid:** Use the existing **`MeetingTileWidget(model: meeting)`** (and same for Admin/Users list items) as the grid/list child. Do not change the widget’s `onTap`, `onPressed`, or navigation; only the **parent** changes from list to grid (or vice versa by breakpoint).
- **Scroll behavior:** Today, Member tab and User tab use a **Column** of tiles inside the screen’s **SingleChildScrollView**, so the whole screen scrolls. When switching to a grid on tablet/laptop, either: (a) use **GridView** with `shrinkWrap: true` and `physics: const NeverScrollableScrollPhysics()` so the parent scroll view still drives scrolling, or (b) give the grid its own scroll (e.g. make it the scrollable body) and keep the rest of the screen structure. Avoid two competing scrollables (e.g. scrollable grid inside scrollable column without shrinkWrap) to prevent broken or janky scrolling.
- **ViewAllMeetingList:** Currently uses `ListView.builder` with `MeetingTileWidget`. Applying the same list/grid rule here is safe as long as the route still receives `List<MeetingModel>` and each tile still uses the same navigation (detail or meeting room with same arguments).

### 6.4 Agora meeting room — control size only

- **Host** today: `CircleAvatar(radius: 60, ...)`; **participant:** `radius: 75`. The guide replaces both with **`controlRadius(context)`** for one consistent size. That is an intentional **visual** change (unified size); **logic** (PTT, speaker, end call, recording) must not change.
- Do not change: `meetingController.startPtt()`, `meetingController.stopPtt()`, `meetingController.toggleSpeaker`, `meetingController.endMeeting`, recording toggles, or `JoinRequestWidget` / `showMeetingInfo`. Only replace hard-coded radii and padding with `controlRadius(context)` and `responsivePadding(context)`.

### 6.5 Dialogs and overlays

- **Max width** is applied by constraining the **content** of the dialog (e.g. `ConstrainedBox(maxWidth: ...)` around the child). Do not change how dialogs are shown (`showDialog`, `showModalBottomSheet`, `Get.toNamed` for join meeting, etc.) or the **callbacks** passed to buttons (e.g. join, extend, accept request, copy credentials). Same for **JoinRequestWidget** and **showMeetingInfo**: same logic and callbacks; only layout/padding responsive.

### 6.6 New file and imports

- **New file:** `lib/core/utils/responsive_utils.dart`. The project does not have `core/utils/` yet; create the **utils** folder under **core** and add this file. All other code stays in existing files; only **add** imports for `responsive_utils.dart` where layout or padding is made responsive.
- **MeetingDetail** model lives in `lib/models/meeting_detail.dart`; **MeetingInfoCard** in `lib/widgets/meeting_info_card.dart`. LayoutBuilder or responsive padding around them must not change their required parameters (e.g. `MeetingInfoCard(meeting: meetingDetail)`).

### 6.7 Quick verification after implementation

1. **Auth:** Login → Home (same route); register flow unchanged.
2. **Home:** Tab switch (Host Meeting / Join Meeting); open Admin or Users (same screens).
3. **Meetings:** Create meeting (permission → MeetingUtil → same flow); tap tile → Meeting Detail (same route + meetingId); from detail or tile, join → Meeting room (same arguments).
4. **In-call:** PTT, speaker, end call, recording, meeting info, join requests — same behavior; only control and padding sizes responsive.
5. **Admin / Users:** List → tap → same actions (edit, delete, create); only list is single column or grid by breakpoint.

If any of the above changes (e.g. different route, missing argument, or broken scroll), treat it as a regression and fix before shipping.
