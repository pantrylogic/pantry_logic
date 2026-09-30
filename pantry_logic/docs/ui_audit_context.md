# Pantry Logic — UI Audit Context

Read-only investigation done to support planning the UI polish pass. No source files were changed.
All paths are relative to the repo root. `L` = line number(s) at time of audit (commit `441344f`).

> **Schema caveat.** The repo has **no SQL migrations or DDL** (no `*.sql` files, no `supabase/` folder), and the Supabase MCP server failed to connect during this audit. Every schema statement below is **inferred from Dart queries and models** and marked as such. Verify against the live DB before writing migrations.

---

## 1. Architecture basics

### State management
- **Plain `StatefulWidget` + `setState` everywhere.** No Riverpod, Provider, Bloc, or InheritedWidget-based state. `pubspec.yaml` dependencies are only `supabase_flutter`, `google_fonts` (`pantry_logic/pubspec.yaml`).
- Data comes from Supabase via service classes that are instantiated per screen (`final _service = InventoryService();` etc.). Live lists use a `StreamController` + `RealtimeChannel` that refetches everything on any change:
  - `InventoryService.streamInventoryItems` — `pantry_logic/lib/services/inventory_service.dart` L93-132
  - `GroceryService.streamGroceryItems` — `pantry_logic/lib/services/grocery_service.dart` L138-177
  - `MealService.streamMeals` / `streamNeedList` — `pantry_logic/lib/services/meal_service.dart` L62-116 / L121-193
  - `CalendarService.streamWeek` — `pantry_logic/lib/services/calendar_service.dart` L34-98
- **One-shot (non-realtime) screens:** Home (`home_screen.dart` L41-64, loaded once in `initState`, pull-to-refresh only), Settings, Hungry screens, Restock.
- Each of the 6 services has its own copy of the `_householdId` JWT decoder (for example `inventory_service.dart` L13-29). `searchAutocomplete` and `getOrCreateItem` are copied three times (grocery, inventory, and meal services).

### Routing / navigation
- **No go_router and no named routes.** Everything uses imperative `Navigator.push(MaterialPageRoute(...))`. No `RouteSettings` is set anywhere (a grep for `RouteSettings|settings:|pushNamed|routes:` returns nothing).
- Root: `MaterialApp(home: _AuthGate())` — `pantry_logic/lib/main.dart` L27-41. `_AuthGate` (L51-139) picks between `SignUpScreen`, `CreateHouseholdScreen`, and `MainShell`.
- **Bottom nav:** `pantry_logic/lib/screens/shell/main_shell.dart`
  - `_currentIndex` is private state on `_MainShellState` (L17). **No controller or callback is exposed**, so child screens cannot switch tabs.
  - `IndexedStack` over `const [HomeScreen(), GroceryListScreen(), PantryScreen(), MealsScreen(), CalendarScreen()]` (L20-26, L36-39). All tabs stay alive, so `initState` runs once per app session.
  - A custom `_NavItem` row (L110-155) is used instead of `BottomNavigationBar`/`NavigationBar`. Labels: Home, Grocery, **Pantry** (L77), Meals, Calendar.
- Pushed (non-tab) screens: Settings (from the Home gear, `home_screen.dart` L119-123), MealDetail (`meals_screen.dart` L173-176), the Hungry flow (`home_screen.dart` L241-245), and RestockScreen from 4 places (see §5).

### Local persistence
- **None.** `shared_preferences`, Hive, and `localStorage` are all absent from `pubspec.yaml` and `lib/`. Persisting collapsed pantry sections will need a new dependency: `shared_preferences` works on web (it uses `localStorage`).

### Theme setup — `pantry_logic/lib/core/theme.dart`
- `nsSans({...})` helper (L12-36) wraps `GoogleFonts.nunitoSans` with fallback `['NotoColorEmoji','Roboto','Segoe UI','sans-serif']`. Most screens call `nsSans(...)` directly for every `Text`.
- `AppColors` (L40-72), all `static const`:

| Token | Light | Dark (`…Dm`) |
|---|---|---|
| primary | `#2D5A27` | `#7FB87A` |
| primaryDark | `#1E3D1A` | `#2D5A27` |
| secondary | `#7A9E77` | `#5A8A56` |
| accentLight | `#C5D8C2` | `#3A4D38` |
| accentSoft | `#D4E2A5` | `#A3C78F` |
| background | `#F7F7F4` | `#1A1C1A` |
| surface | `#FFFFFF` | `#252825` |
| textPrimary | `#2C2C2C` | `#E8E8E4` |
| textSecondary | `#6B6B6B` | `#9EAA9C` |
| textMuted | `#9E9E9E` | `#6B736B` |
| success | `#4CAF50` | `#66BB6A` |
| warning | `#E8A838` | `#FFAB40` |
| error | `#C75450` | `#EF5350` |
| border | `#E8E8E4` | `#3A3D3A` |

- **Measured contrast (WCAG):** textMuted on background **2.50:1**, on surface **2.68:1** (fails AA 4.5:1). textSecondary on background 4.97:1 (passes). warning `#E8A838` on white **2.08:1**, success on white **2.78:1**; both are used as small text colors (for example the "Missing" label). Dark textMutedDm on surfaceDm is 3.04:1.
- `ThemeData` light (L206-265) and dark (L269-328): `useMaterial3: true`, `ColorScheme.light/dark` with primary/secondary/surface/error/on* only.
- **Centralized:** `textTheme` (L77-124, defines only `displayLarge, headlineMedium, bodyLarge, bodyMedium, bodySmall, labelLarge`), `inputDecorationTheme` (L126-164: filled, `contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14)`, radius 12, 1.5px borders), `elevatedButtonTheme`, `outlinedButtonTheme`, `cardTheme`, `appBarTheme` (24px bold title), `dividerTheme`.
- **Not centralized / missing:** no `chipTheme`, `filledButtonTheme` (even though `FilledButton` is the most-used button), `textButtonTheme`, `snackBarTheme`, `bottomSheetTheme`, `dialogTheme`, `listTileTheme`, or `ThemeData.fontFamily`.
  - Because `fontFamily` isn't set and `titleMedium`, `labelMedium`, `labelSmall`, and `titleLarge` aren't defined, anything using them falls back to **Roboto**. That includes the Pantry section headers (`pantry_screen.dart` L496 `labelSmall`), the Pantry sheet title (L686 `titleMedium`), the "Location" label (L691 `labelMedium`), and the Pantry search field (L261).
- **Colors are resolved per widget, not through the theme.** Almost every screen repeats `final x = isDark ? AppColors.xDm : AppColors.x;` blocks (for example `home_screen.dart` L68-79, `meal_detail_screen.dart` L301-314). The exception is `pantry_screen.dart`, which uses `Theme.of(context).colorScheme`/`textTheme` and Material defaults (`ListTile`, `ChoiceChip`, `FilledButton`). That makes Pantry look visually different from the other tabs.
- Text styles are **set per widget** via `nsSans(fontSize:…, color:…)` in most places, not via `textTheme`.

### Font
- **Nunito Sans**, loaded at runtime via `google_fonts` (not bundled as an asset).
- **NotoColorEmoji** is bundled: `pantry_logic/pubspec.yaml` `fonts:` → `fonts/NotoColorEmoji-Regular.ttf`, **25.1 MB**, shipped in `docs/assets/fonts/` too. It exists only to render emoji. It's injected globally via `DefaultTextStyle.merge(fontFamilyFallback: ['NotoColorEmoji'])` in `main.dart` L36-39 and in `nsSans` fallback `theme.dart` L30-35.

---

## 2. PWA / web shell

### `pantry_logic/web/index.html` (full)
```html
<!DOCTYPE html>
<html>
<head>
  <!--
    If you are serving your web app in a path other than the root, change the
    href value below to reflect the base path you are serving from.

    The path provided below has to start and end with a slash "/" in order for
    it to work correctly.

    For more details:
    * https://developer.mozilla.org/en-US/docs/Web/HTML/Element/base

    This is a placeholder for base href that will be replaced by the value of
    the `--base-href` argument provided to `flutter build`.
  -->
  <base href="$FLUTTER_BASE_HREF">

  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
  <meta content="IE=Edge" http-equiv="X-UA-Compatible">
  <meta name="description" content="A new Flutter project.">

  <!-- iOS meta tags & icons -->
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black">
  <meta name="apple-mobile-web-app-title" content="pantry_logic">
  <link rel="apple-touch-icon" href="icons/Icon-192.png">

  <!-- Favicon -->
  <link rel="icon" type="image/svg+xml" href="icons/favicon.svg"/>

  <title>pantry_logic</title>
  <link rel="manifest" href="manifest.json">
</head>
<body>
  <!--
    You can customize the "flutter_bootstrap.js" script.
    This is useful to provide a custom configuration to the Flutter loader
    or to give the user feedback during the initialization process.

    For more details:
    * https://docs.flutter.dev/platform-integration/web/initialization
  -->
  <script src="flutter_bootstrap.js" async></script>
</body>
</html>
```

### `pantry_logic/web/manifest.json` (full)
```json
{
    "name": "Pantry Logic",
    "short_name": "pantry_logic",
    "start_url": ".",
    "display": "standalone",
    "background_color": "#0175C2",
    "theme_color": "#0175C2",
    "description": "Pantry Logic is a shared household app that helps families manage groceries, track food inventory, and decide what to eat.",
    "orientation": "portrait-primary",
    "prefer_related_applications": false,
    "icons": [
        { "src": "icons/Icon-192.png", "sizes": "192x192", "type": "image/png" },
        { "src": "icons/Icon-512.png", "sizes": "512x512", "type": "image/png" },
        { "src": "icons/Icon-maskable-192.png", "sizes": "192x192", "type": "image/png", "purpose": "maskable" },
        { "src": "icons/Icon-maskable-512.png", "sizes": "512x512", "type": "image/png", "purpose": "maskable" }
    ]
}
```

### Meta tags: current state
| Concern | Current value | Notes |
|---|---|---|
| Status bar | `apple-mobile-web-app-status-bar-style="black"` | Black bar on iOS. Brand background is `#F7F7F4`. |
| `theme-color` meta | **absent** | Only the manifest `theme_color` is set, and it's `#0175C2` (Flutter default blue, not brand green). |
| `background_color` | `#0175C2` | Flutter default blue shows on the Android splash. |
| apple-touch-icon | `icons/Icon-192.png` | iOS prefers 180×180. No other sizes. |
| iOS splash | **none** | No `apple-touch-startup-image` links. |
| Favicon | `icons/favicon.svg` | **That file doesn't exist.** `web/icons/` has only 4 PNGs. Commit `441344f` ("fix favicon") switched from `favicon.png` (which exists, 16×16) to the missing SVG. |
| `<title>` | `pantry_logic` | |
| description meta | `A new Flutter project.` | |
| apple title | `pantry_logic` | Shown under the home-screen icon on iOS. |
| manifest `name` / `short_name` | `Pantry Logic` / `pantry_logic` | `short_name` is what Android shows under the icon. |

### `pantry_logic/web/icons/`
- `Icon-192.png` (192×192), `Icon-512.png` (512×512), `Icon-maskable-192.png`, `Icon-maskable-512.png`.
- **The maskable icons are byte-identical to the non-maskable ones** (same MD5). They have no safe-zone padding, so Android adaptive masks will crop them.
- `pantry_logic/web/favicon.png` exists (16×16) but isn't referenced by the source `index.html`.
- Native iOS (`ios/Runner/Assets.xcassets/AppIcon.appiconset`) has a full icon set. `LaunchImage.imageset` PNGs are 68-byte placeholders. Neither affects the PWA.

### The deployed copy is out of sync
The repo-root `docs/` folder is the deployed build, last updated in commit `96c44bf`. It differs from `pantry_logic/web/`:
- `docs/index.html` has `<base href="/pantry_logic/">`, **no viewport meta** (the viewport fix in `07fd781` only reached `pantry_logic/web` and `pantry_logic/build/web`), and favicon `favicon.png`.
- `docs/manifest.json` has `"name": "pantry_logic"` and description `"A new Flutter project."`.
- `pantry_logic/build/web/` is also committed and matches the source (including the broken favicon.svg).
- `_headers` and `_redirects` (Netlify/Cloudflare-style) exist in `pantry_logic/web/` and `docs/`.

---

## 3. Data model (Supabase) — inferred

| Table | Columns (as used by code) | Evidence |
|---|---|---|
| `households` | id, name, invite_code, created_by, created_at | `models/household.dart` |
| `profiles` | id, display_name, household_id, role (`owner`/`member`), auth_type (`full`/`anonymous`), created_at, updated_at | `models/profile.dart` L2-8, L24-32 |
| `items` | id, household_id, name, category (nullable), default_location (**text**) | `models/item.dart`. Unique on name per household (23505 handled in `inventory_service.dart` L165-173). |
| `inventory_items` | id, household_id, item_id, location (**text**), quantity (**text**), notes, updated_at | `models/inventory_item.dart` L2-9, L24-34. **UNIQUE(household_id, item_id)** (`grocery_service.dart` L241-249 upsert `onConflict`; `inventory_service.dart` L199-200). One row per item, so an item can't be in two locations at once. |
| `grocery_items` | id, household_id, item_id, quantity (text), notes, added_by (FK → profiles), purchased, purchased_at, created_at | `models/grocery_item.dart`. Join `profiles!added_by(display_name)` at `grocery_service.dart` L148. A 23505 is caught on insert at `hungry_service.dart` L188, which suggests a unique constraint exists; its exact definition is unknown. |
| `meals` | id, household_id, name, category_id (FK → meal_categories, nullable), notes (nullable text) | `models/meal.dart` L2-7, `meal_service.dart` L197-229 |
| `meal_need_list` | meal_id, item_id (+ possibly id per the brief) | `meal_service.dart` L128-131, L237-249. Unique(meal_id,item_id) inferred from the 23505 ignore at L247. **No per-ingredient quantity column.** |
| `calendar_entries` | id, household_id, meal_id (nullable), date (date), updated_at | `calendar_service.dart` L103-118. UNIQUE(household_id,date). |
| `storage_locations` | id, household_id, name, is_default, sort_order | `models/storage_location.dart` |
| `meal_categories` | id, household_id, name, sort_order (brief also lists is_default; the model doesn't read it) | `models/meal_category.dart` |
| `starter_dictionary` | name, category, default_location | `inventory_service.dart` L69-74 |

### Locations
- **A table (`storage_locations`) with a `sort_order` field, but links to it are by name.** `inventory_items.location` and `items.default_location` are free text, not FKs.
- Defaults (Fridge, Freezer, Pantry, Deep Freeze) are auto-seeded on household creation, per the brief and project memory. The seed `sort_order` values are **not visible in the repo**.
- **Display order in Pantry** is set in `pantry_screen.dart` L331-342: groups are sorted by the index in `_locations`. That list comes from `getStorageLocations()` ordered by `sort_order, name` (`inventory_service.dart` L33-40). Unknown location strings sort last (index 999), then alphabetically.
- Chip order in the add/edit sheet is the same `_locations` order (`pantry_screen.dart` L785).
- **No UI edits `sort_order`.** Settings has only add, rename, and delete (`settings_screen.dart` L295-355). Default locations can't be renamed or deleted (L522-523).
- `renameLocation`/`deleteLocation` (`settings_service.dart` L98-110) **don't cascade** to `inventory_items.location` or `items.default_location`. Renaming orphans the items.

### Quantity
- The column is **text**. The models cast `json['quantity'] as String?` (`inventory_item.dart` L30, `grocery_item.dart` L39), so a numeric column would throw.
- **".5" is stored verbatim as the string `".5"`** and **rendered raw**: Pantry subtitle `pantry_screen.dart` L521-524, Grocery trailing text `grocery_list_screen.dart` L597-612. There's no formatting on display.
- Numeric parsing only happens in:
  - `HungryService.executeRestock` (`hungry_service.dart` L132): `double.tryParse`, then `_formatQty` (L168-172) writes `"2"` for whole numbers and `double.toString()` otherwise (`"0.5"`, `"1.5"`). So `".5"` → 0.5 → minus 1 → ≤0 → **deleted**.
  - `GroceryService._mergeQuantities` (`grocery_service.dart` L275-291): sums two numeric strings on checkoff and writes whole numbers as ints, otherwise `toStringAsFixed(1)`. Non-numeric quantities keep the existing value.
- The quantity field is a free `TextField` with no `keyboardType` (`pantry_screen.dart` L702-710; hint `e.g. 2, 500 ml, half a bag`).

### `added_by` on inventory
- **Not present in the code.** There's no field in `InventoryItem`, nothing in the insert (`inventory_service.dart` L192-198), and nothing in the checkoff upsert (`grocery_service.dart` L241-249). Whether the DB column exists **can't be verified**, so assume it doesn't.
- If it's added, the display name is resolvable the same way grocery does it: `select('*, items(name), profiles!added_by(display_name)')` (pattern at `grocery_service.dart` L148, `grocery_item.dart` L32, L42). Profiles of household members are readable (Settings `getMembers`, `settings_service.dart` L54-63).
- On checkoff, the grocery row's `added_by` (or the current user) could be carried into inventory.

### Meal category and notes
- Category: `meals.category_id` → `meal_categories.name` via join (`meal_service.dart` L71). Notes: `meals.notes` text.
- **Where shown:**
  - Meal detail header strip, **only if either is non-null** (`meal_detail_screen.dart` L378-427). The category is a tappable pill that opens the category sheet; the notes are tappable text that opens the notes sheet.
  - Meals list: category is used only for **grouping** (section headers). Notes aren't shown.
  - Calendar meal picker: category as subtitle (`calendar_screen.dart` L537-542).
  - Hungry suggestion: neither is shown.
- A meal added from the Meals add bar gets **no category** (`meals_screen.dart` L55, `addMeal(name: name)`). It lands in "Uncategorized", and the Hungry flow **never suggests uncategorized meals** (`hungry_service.dart` L54 filters by `category_id`).

---

## 4. Screens and widgets

### Home — `pantry_logic/lib/screens/home/home_screen.dart`
- **Load:** a single `Future.wait` in `_load` (L41-64): profile, tonight entry, week entries, grocery count, pantry count. There's no realtime and no refresh on tab switch (IndexedStack), so data goes stale until pull-to-refresh (L85-86).
- **Greeting** (L100): `'Hey, ${displayName ?? 'there'} 👋'` plus the subtitle "Here's what's going on in the kitchen." (L109). There's a settings gear circle at L119-135 and an anonymous-user warning banner at L141-167.
- **Stat cards:** `_StatCard` (L325-380) is a plain `Container` and **isn't tappable**. The two cards are "N to buy" (cart icon) and "N in pantry" (inventory icon) (L172-203). Counts come from `SettingsService.getGroceryCount`/`getPantryCount` (`settings_service.dart` L150-161), which fetch full id lists and count them client-side.
- **Tonight card:** `_TonightCard` (L384-503). The card itself **isn't tappable**; only an inline "Eat This" pill (L474-492) is, and it pushes `RestockScreen` directly (L222-231). It shows the meal name and a status dot with "All ingredients in pantry" or "N ingredients missing" (L446-471). Empty state: "Nothing planned — tap Calendar to plan dinner." (L496). The status-dot row is hidden for meals with no need list.
- **I'm Hungry button** (L238-298): a `GestureDetector`+`Container` in primary color, with the emoji `🍽️` (L257), "I'm Hungry", "Find something to eat", and an arrow. It pushes `HungryCategoryScreen`.
- **This Week:** `_WeekPreview` (L507-657), a Mon–Sun card of 7 rows (day abbreviation, status dot, meal name or "–"). Rows **aren't tappable**. The week start is computed independently at L37 (`now.subtract(weekday-1)`, keeps the time of day).

### Pantry list — `pantry_logic/lib/screens/pantry/pantry_screen.dart`
- **Row widget:** `_InventoryTile` (L508-545), a Material `ListTile`. Title is the item name. Subtitle is `"quantity · notes"` joined (L521-524), so a row goes to 2 lines whenever it has a quantity or notes. Trailing is a chevron. It's wrapped in a `Dismissible` (end-to-start) that calls `_deleteItem` with **no confirm**. Tap opens the edit sheet.
- **Quantity rendering:** the raw string in the subtitle. It's shown even when it's `"1"`, with no pill and no fraction formatting.
- **Grouping/order:** groups by the `item.location` string (L326-329) and orders them by `_locations` index, then alphabetically (L331-342). Items within a group keep the stream order `updated_at desc` (`inventory_service.dart` L103-104), so they **aren't alphabetical**.
- **`_locations` is loaded once** in `initState` (L37, L44-49). Locations added or renamed in Settings don't show up until the app restarts.
- **Section header:** `_SectionHeader` (L485-504) uppercases the location name, styled `labelSmall` (Roboto, see §1) in primary color. It has **no count and can't collapse**. The header and its items are a `Column` inside `ListView.builder` (L344-363).
- **Search:** an AppBar toggle (L252-276). When active, the title becomes a borderless `TextField` (hint "Search pantry…"). The filter is client-side `contains` on the item name **or the location** (L293-303). Clearing happens on close (L233-240). "No items match" empty state at L305-322.
- **AppBar title:** `'Pantry'` (L263).

### Pantry add/edit bottom sheet — same file
- `_showEditSheet` (L164-198) → `_EditItemSheet` (L582-614) → the shared body `_ItemSheet` (L618-765). The add flow uses the same body via `_AddItemSheet` (L549-578, title `Add "$name"`, button "Add to Pantry").
- **Fields, in order:** drag handle; title = `item.itemName` as a plain `Text` (**name isn't editable**, L686); the label "Location" (L691) plus `_LocationChips` (L769-798, default M3 `ChoiceChip`s, order = `_locations`); a **Quantity** `TextField` (label "Quantity", free text, no numeric keyboard, L702-710); **Notes** (label "Notes (optional)", 2 lines, L714-722); a Save `FilledButton` (L726-747); a "Delete item" `TextButton` in error color (L748-760).
- Location is stored in a hidden `TextEditingController` (L652). If the dictionary default isn't one of the household's location names, no chip is selected but that value still saves.
- **Save:** `updateInventoryItem` sends location/quantity/notes (empty → null) (`inventory_service.dart` L205-219). There's a bug: `_saving` is set to true (L732) and **never reset on failure**, so after an error the button stays disabled with a spinner.
- **Delete:** **no confirm dialog.** It pops the sheet, then calls `_deleteItem` (L200-224), which deletes and shows a SnackBar "`X` removed from pantry." with a **`SnackBarAction` "Add to grocery list"** (L207-214). There's **no undo**.
- Field labels differ across the app: Pantry uses "Quantity" / "Notes (optional)"; the Grocery sheet uses "Quantity" / "Notes" with hints (`grocery_list_screen.dart` L177-194); the meal `_EditSheet` has a hint only and no label (`meal_detail_screen.dart` L790-809).

### Meal detail — `pantry_logic/lib/screens/meals/meal_detail_screen.dart`
- It receives a **snapshot** `Meal` (L11-12) and copies name/category/notes into local state (L24-27, L42-45).
- **Ingredient row:** built inline in `ListView.separated` (L473-549), with no named widget. A `Dismissible` (swipe removes it from the need list via `_removeNeedItem` L144-147, **no confirm, no undo**). The row has:
  - a status icon (`check_circle_rounded` in success, or `radio_button_unchecked_rounded` in warning) (L505-514)
  - the item name
  - a subtitle: **`'In pantry · ${location}'`** or **`'Missing'`** (L530-540)
- **Status computation:** `MealService.streamNeedList` (`meal_service.dart` L121-193) fetches `meal_need_list(item_id, items(name))`, then `inventory_items(item_id, location)` filtered by those `item_id`s. `inPantry = inventoryLocation != null` (`models/meal_need_item.dart` L9).
  - **Matching is by `item_id` (UUID FK), not by string.** The string matching happens earlier, when an ingredient is added: `getOrCreateItem` does `.ilike('name', trimmed)` (`meal_service.dart` L364-402). That's a case-insensitive exact match with no normalization, so "Tomato" and "Tomatoes" are different items. `%` and `_` in names act as wildcards because they aren't escaped.
  - Quantity is ignored: an inventory quantity of `"0"` still counts as "In pantry".
  - Sorted by item name (`meal_service.dart` L159).
- **Status circle:** a **display-only `Icon`**, not tappable.
- **Header:** a category pill and notes strip, shown only if either exists (L378-427). The section label is **`'NEED LIST'`** plus "N items" (L430-451).
- **Bottom controls:**
  - an action panel shown when `items.isNotEmpty && !_showSuggestions` (L553-606): an "Eat This" `FilledButton` (L564-583) and, if any are missing, a second full-width "Add N missing to grocery list" warning-tinted `FilledButton` (L584-603)
  - the autocomplete list (L609-656)
  - the add-ingredient bar (L659-712)
  - That's up to three stacked bottom regions plus the keyboard.
- **Overflow menu** (`PopupMenuButton`, L325-366): Rename meal → `_EditSheet`; Change category → `_CategorySheet`; Add/Edit notes → `_EditSheet` (4 lines); a divider; Delete meal (error color) → `_confirmDelete` `AlertDialog` (L256-295).
- Copy using "need list": L267 (delete dialog), L435 (header), L463 (empty state).

### Calendar — `pantry_logic/lib/screens/calendar/calendar_screen.dart`
- **Range:** exactly one Mon–Sun week. `_weekStart = now.subtract(Duration(days: now.weekday - 1))` (L24-26) keeps the time of day and isn't normalized to midnight.
- `_weekStart` and `_stream` are **`late final`** (L18-19) and set once in `initState`. The screen is kept alive by IndexedStack, so **the week never advances** until the app restarts.
- **No prev/next navigation.** The header is just the month/year label (L219-232, L256-267).
- **Past days:** **no special handling.** Same styling, tappable, can assign or Eat This. Only today gets a filled primary circle (L318-345).
- **Row** (L274-407): day abbreviation and number column, then a status dot and meal name, or muted "Tap to plan dinner" (L380-386), then an always-present chevron (L390-394), with dividers between.
- **Tap:** if a meal is planned → `_showDayActions` bottom sheet (L82-181) with **Eat This** (pushes `RestockScreen`), **Change meal** (opens the picker), and **Remove** (`clearDay`, deletes the row, **no confirm/undo**). If empty → `_MealPickerSheet` (L442-557), a `DraggableScrollableSheet` of all meals with a status dot, category subtitle, and add icon. Picking upserts the calendar entry (`calendar_service.dart` L103-118).
- The service already takes an arbitrary `weekStart` (`streamWeek(DateTime)`, `getWeek(DateTime)`), so week navigation is a UI-only change.

### Grocery list — `pantry_logic/lib/screens/grocery/grocery_list_screen.dart`
- **AppBar:** "Grocery List", plus a "Clear completed" `TextButton` when any are purchased (L249-268, **no confirm**). It uses a second `StreamBuilder` on the broadcast stream.
- **List:** unpurchased items sorted oldest→newest, then purchased items by `purchasedAt` (L294-306). Empty state: `✅` emoji and "Nothing to buy — nice!" (L308-328).
- **Row:** `_GroceryItemTile` (L502-646), a bordered rounded card (margin 12/3). It has:
  - a tappable circle checkbox (`GestureDetector`, L561-574) → `checkOffItem`/`uncheckItem`
  - the name, with the **quantity inline on the same line** in textSecondary (L581-613)
  - notes on a second line (L615-622)
  - **the `addedByName` on the right** (L628-638)
  - Purchased rows: 0.6 opacity plus strikethrough. Swipe end-to-start deletes (**no confirm, no undo**). Tapping the row opens the edit sheet.
- **Check-off:** `checkOffItem` (`grocery_service.dart` L211-251) marks the item purchased, then upserts it into inventory, keeping the existing location or using `items.default_location`, merging quantities, and carrying notes. Unchecking doesn't remove it from inventory.
- **Edit sheet:** built inline in `_showEditSheet` (L145-230). It has the name as a title (not editable), Quantity, Notes, a Save `ElevatedButton` (fire-and-forget update after pop), and "Delete item" (no confirm). The `TextEditingController`s are never disposed.
- **Add bar:** see the add-bars table below. Adding creates an item via autocomplete or `getOrCreateItem`, then inserts it with **no dedupe check** (L69-101).

### Meals list — `pantry_logic/lib/screens/meals/meals_screen.dart`
- **AppBar:** "Meals". The body is a realtime `StreamBuilder` of `streamMeals`.
- **Grouping:** by `categoryId`, sorted by category `sort_order`, with Uncategorized last (L88-111). Within a group, sorted by name (L116-118). Headers are uppercase muted 11px (L124-135).
- **Row** (inline, L158-218): a `Dismissible` swipe-delete → `_deleteMeal` (L64-71). **No confirm and no undo**, even though deleting from meal detail does confirm. The row shows the name and a status line: "No need list", "All in pantry" (success), or "N missing" (warning), each with a small icon (L140-156). Chevron. Tap pushes `MealDetailScreen`. Category isn't shown on the row (it's implied by the section), and neither are notes.
- **Empty state:** `🍽️` emoji plus copy mentioning "need lists" (L247-281).
- **Add bar:** "New meal…", with no autocomplete. Submitting creates an uncategorized meal (L45-62, L292-321).

### Hungry flow
1. **`HungryCategoryScreen`** — `screens/hungry/hungry_category_screen.dart`. Loads categories (L25-39) and shows "What are you feeling?" plus a list of `_CategoryCard`s (L137-207, all with the same `restaurant_rounded` icon). Empty state has the `🍽️` emoji (L76).
2. **`HungrySuggestionScreen`** — `screens/hungry/hungry_suggestion_screen.dart`.
   - **Logic:** `HungryService.getSuggestions` (`hungry_service.dart` L47-84) loads all meals in the category. **Pool A** is meals with `missingCount == 0`, which includes meals with no need list. **Pool B** is meals with any missing items. Each pool is shuffled, and the result is A then B. There's **no cap** (the brief says "~5").
   - **UI:** "i of N" counter (L162), a card with the name, a status row ("No need list" / "You have everything ✓" / "Missing N items" plus warning chips naming the missing items), and a "Ready to make" / "Missing a few things" pill (L169-290).
   - **Buttons:** "Eat This 🍽️" and "Suggest Another". The latter disables at the last suggestion with "No more suggestions"; there's no wrap-around (L295-339).
   - **Leading:** a custom "← Category" text button (L107-113).
   - **Eat This:**
     - For a meal with **no need list**: a SnackBar "Enjoy X! 🍽️", then it pops back to the category screen (L59-69).
     - Otherwise it pushes `RestockScreen`.
3. **`RestockScreen`** — `screens/hungry/restock_screen.dart` (see §5). Its "Done" button pops to the root (Home tab).

### Add bars (text-input "add" bars)
| Screen | Location | Widget | Hint | Styling | Autocomplete UI | Submit behavior |
|---|---|---|---|---|---|---|
| Grocery | `grocery_list_screen.dart` L384-422 | inline `TextField` | "Add an item…" | prefix `add_rounded` (primary), `OutlineInputBorder(r12)`, `contentPadding h12 v10`, `nsSans(15)`, caps: **words** | `_SuggestionTile` card list (L349-381, L429-498), history icon for household items | adds immediately |
| Pantry | `pantry_screen.dart` L405-440 (`_AddBar`, private) | `TextField` | "Add to pantry…" | prefix `Icons.add` (not rounded, default color), `OutlineInputBorder(r12)`, `contentPadding h12 v10`, **theme text style**, caps: sentences | `_SuggestionsDropdown` (L444-481), `ListTile`-based, shows category and default location | opens the add sheet |
| Meals | `meals_screen.dart` L292-321 | inline `TextField` | "New meal…" | same as Grocery but caps: sentences | none | creates the meal immediately |
| Meal detail | `meal_detail_screen.dart` L659-712 | inline `TextField` in a `Row` | "Add ingredient…" | **borderless**, `isDense`, `contentPadding: EdgeInsets.zero`, trailing `add_circle_rounded` 28px button and spinner | inline `Material` list (L609-656), add icon, category | adds to the need list |

- **They don't share a component.** The only shared input widget is `lib/widgets/auth_text_field.dart` (auth screens only). All four bars override the theme's `contentPadding` (h16 v14) differently, which is why their heights and alignment don't match.

---

## 5. "Eat This" behavior

### Entry points (all go to the same screen)
- Meal detail: `meal_detail_screen.dart` L564-572
- Home Tonight card: `home_screen.dart` L222-231
- Calendar day actions: `calendar_screen.dart` L133-143
- Hungry suggestion: `hungry_suggestion_screen.dart` L72-77. This is the only entry point that special-cases meals with no need list.

### Code path (from meal detail)
1. The "Eat This" `FilledButton` → `Navigator.push(RestockScreen(mealId, mealName))`. It's **only rendered when the need list is non-empty and the suggestions dropdown is closed** (L553). A meal with no ingredients has **no Eat This on its detail screen**.
2. `RestockScreen.initState` immediately calls `_executeRestock()` (`restock_screen.dart` L29-33, L35-49). **Inventory is mutated as soon as the screen opens**: there's no confirm step and no undo. Backing out after that doesn't revert anything.
3. `HungryService.executeRestock(mealId)` (`hungry_service.dart` L97-166):
   - Fetches the need list, then the inventory rows for those `item_id`s.
   - For each need-list item:
     - **Not in inventory → `continue`** (L130), skipped silently.
     - **Quantity parses as a number** (`double.tryParse`), then minus 1:
       - if ≤ 0, **deletes the inventory row** and returns `hitZero`
       - otherwise updates the quantity silently (`_formatQty`), and it doesn't appear on screen
     - **No quantity, or a non-numeric one** ("500 ml", "half a bag") → returns `noQuantity`, and the inventory is unchanged at that point.
4. The UI (`restock_screen.dart` L97-306): title "Enjoy!", no back button (`automaticallyImplyLeading: false`), the meal name, and "Need to restock anything?" or "You're all set — nothing to restock." It shows one card per decision:
   - `hitZero`: "Ran out — add to grocery list?" with **Add to list** / **Skip**. The item has already been removed from inventory either way.
   - `noQuantity`: "Still in the pantry?" with **Add to list** (adds to grocery **and deletes it from inventory**, L51-70, `removeFromInventoryByItemId` `hungry_service.dart` L195-198) / **Still have some** (no-op).
5. **Done** (L298-301): `popUntil((r) => r.isFirst || _shouldStop(r))`. `_shouldStop` (L328-333) checks route names `'/meal-detail'` and `'/hungry-category'`, but **no route in the app sets a name**, so it always pops to the root `MainShell`. From meal detail, Done drops the user on the Meals list rather than back on the meal.

### When ingredients are missing
- The button is **not disabled**, there's **no warning**, and it **silently proceeds**. Missing items are simply skipped (L130). This is the same from Home and Calendar. Only the Hungry card surfaces missing items beforehand.

### Logging
- **None.** Nothing is written to `calendar_entries` or any history table. The meal isn't marked as eaten anywhere.

---

## 6. Snackbars and dialogs

- **No shared helper.** There are about 36 direct `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(...)))` calls across 9 screen files, and no `SnackBarTheme`.
  - Many interpolate raw exceptions (`'Could not add meal: $e'`, `meals_screen.dart` L58; `meal_detail_screen.dart` L138, L166, L191, …).
  - The "capture the messenger before await" pattern is used inconsistently.
- **Only one `SnackBarAction` in the app:** Pantry delete → "Add to grocery list" (`pantry_screen.dart` L207-214). **There's no undo anywhere.**
- **Confirm dialogs (`AlertDialog`):** delete meal from detail (`meal_detail_screen.dart` L259-287) and sign out (`settings_screen.dart` L63-98). Settings also uses `AlertDialog`s with a `TextField` for name editing (L112, L182, L248, including the shared `_showNameDialog` L242-291).
- **Destructive actions with no confirm and no undo:**
  - Pantry swipe and sheet delete
  - Grocery swipe and sheet delete, and Clear completed
  - Meals-list swipe delete (removes the meal and its need list)
  - Need-list swipe remove
  - Calendar "Remove"
  - Settings location and category delete (`settings_screen.dart` L343-355, L406-419)
- Bottom sheets are also per-screen, each with its own handle, padding, and shape: `pantry_screen.dart` L675-684, `calendar_screen.dart` L103-111 and L480-488, `grocery_list_screen.dart` L150-156, and `meal_detail_screen.dart` `_EditSheet`/`_CategorySheet` (no handle).

---

## 7. Risks and complications

1. **"Pantry" means three things.**
   - (a) The tab label (`main_shell.dart` L77) and the Pantry screen AppBar (`pantry_screen.dart` L263).
   - (b) A default **location** name, seeded in the DB and used as the hardcoded fallback `'Pantry'` in 13 places: `models/inventory_item.dart` L29, `models/item.dart` L21, `models/grocery_item.dart` L38, `services/{grocery,inventory,meal}_service.dart` (autocomplete and `getOrCreateItem` defaults), `pantry_screen.dart` L115, L138.
   - (c) "Inventory" in copy: `home_screen.dart` L193 "in pantry", L462; `meals_screen.dart` L150; `restock_screen.dart` L191; `pantry_screen.dart` L147, L206, L310.
   - The worst case is `meal_detail_screen.dart` L532, which renders **"In pantry · Pantry"**.
   - Renaming the **location** needs a data migration: `storage_locations.name`, `inventory_items.location` (text), `items.default_location` (text), `starter_dictionary.default_location`, plus all the code fallbacks. That's because locations are joined by string, not FK.
   - Renaming the **tab** is UI-only (the 2 labels plus the copy strings). **The tab rename is much cheaper and safer.**
2. **Locations are free-text references.** Persisting collapsed state has to be keyed by location name, since there's no `location_id` on inventory. Settings rename/delete doesn't cascade (§3), so orphaned groups appear. Location ordering either needs a sort_order editing UI (none exists) or a hardcoded order, and the seeded `sort_order` values aren't known from the repo.
3. **Tabs are kept alive but never refresh their reference data.** Pantry `_locations` (L44-49), Meals `_categories` (L31-36), Home (all data), and Calendar (`_weekStart`) load once per session. Adding a "persist + auto-expand" feature on top of stale location lists will look buggy.
4. **Tappable stat cards need tab switching.** Home can't change `MainShell._currentIndex` today. That needs a callback passed down, an `InheritedNotifier`/`ValueNotifier`, or making `MainShell` expose a static accessor. `_screens` is `static const` (L20-26), so passing a callback also means making it non-const.
5. **Tappable Tonight card → meal detail needs a `Meal` object.** `CalendarEntry` only carries `mealId`/`mealName`/counts, while `MealDetailScreen` requires a full `Meal` (`meal_detail_screen.dart` L11-12). You'd need to fetch the meal first or change the constructor to take an id.
6. **Business logic in the UI and duplicated status logic.**
   - Meal status (`needCount`/`missingCount`) is computed in 4 places: `Meal.fromJson`, `CalendarEntry.fromJson`, `HungryService.getSuggestions`, and `meal_detail_screen.dart` L373.
   - The status→color/text/icon mapping is duplicated in `meals_screen.dart` L140-156, `calendar_screen.dart` L281-290 and L512-519, `home_screen.dart` L446-471 and L574-583, and `hungry_suggestion_screen.dart` L195-247.
   - The "Need List" → "Ingredients" rename and the clearer status treatment touch all of these. Extract a shared `MealStatus` helper first.
7. **No shared widget layer.** 4 add bars, 3 autocomplete dropdowns, 5+ bottom-sheet scaffolds, and 3 section-header styles are all independent. The only exception is `widgets/auth_text_field.dart`.
8. **Pantry screen styling is out of family.** It uses Material defaults and undefined text styles (Roboto). Restyling it to match the rest means rewriting it, not just tweaking it.
9. **Quantity is free text.** A stepper can only operate when `double.tryParse(q)` succeeds; you need a fallback for "500 ml" and similar.
   - "½" formatting should be **display-only** (keep storing `"0.5"`/`".5"`). Otherwise `double.tryParse` in restock and merge breaks.
   - There are 3 different number formatters today (restock `toString`, merge `toStringAsFixed(1)`, raw display). Consolidate into one `formatQuantity` utility.
   - "Hide pill when qty is 1": an item at `"1"` will be **deleted** on the next Eat This, so hiding the pill hides the fact that it's the last one.
10. **Editable item name renames globally.** The name lives on `items` and is shared by grocery, inventory, and the need list. `items` has a unique name constraint (23505 handling), so renaming to an existing name will fail and needs either merge logic or a clear error. `ilike` isn't escaped.
11. **Undo on Pantry delete vs the existing "Add to grocery list" action.** A SnackBar holds one action, so you'll need to choose, or put a second option elsewhere.
    - Undo can re-insert via `addInventoryItem`. It gets a new id, and realtime refetch handles the UI.
    - Delete-and-restore also resets `updated_at`, which changes the in-group order.
12. **Eat This is irreversible and runs on screen open.** Adding a "missing ingredients" warning has to happen **before** navigating to `RestockScreen`, at each of the 4 entry points, or `RestockScreen` has to gain a pre-confirm step. The `popUntil` route-name bug (§5) will matter if you change where Done lands.
13. **`_ItemSheet._saving` is never reset on error** (`pantry_screen.dart` L732). Fix it while reworking the sheet.
14. **Emoji → Material icons** covers 15 occurrences: `main.dart` L156; `auth/sign_up_screen.dart` L97; `auth/sign_in_screen.dart` L93; `auth/create_household_screen.dart` L105, L192; `auth/join_household_screen.dart` L119; `grocery_list_screen.dart` L315; `home_screen.dart` L100, L257; `hungry_category_screen.dart` L76; `hungry_suggestion_screen.dart` L64, L131, L205 (`✓`), L313; `meals_screen.dart` L255.
    - Removing them all would let you drop the **25 MB `NotoColorEmoji` asset** (`pubspec.yaml`, `theme.dart` L30-35, `main.dart` L36-39), which is a big web payload win.
    - Trade-off: emoji typed into user content (meal or item names) would then render with the platform font or as tofu.
15. **Web shell drift.**
    - The favicon points to a missing file.
    - The maskable icons are unpadded copies.
    - The manifest colors are Flutter blue.
    - The deployed `docs/` is stale: it lacks the viewport fix and has the old manifest name.
    - Any PWA fix needs `flutter build web --base-href /pantry_logic/` **and** a copy into `docs/`. Right now `pantry_logic/build/web` is also committed.
16. **Contrast change scope.** `textMuted` is used both for hints/placeholders and for real informational text (section headers, "to buy", "Tap to plan dinner", counts, category labels). Darkening the token changes hints too. Consider adding a separate `textTertiary`/`hint` token. warning and success are also below 3:1 as text colors.
17. **Meal category and uncategorized meals.** New meals have no category and are invisible to Hungry. If the polish shows category more prominently, consider prompting for one on create.
18. **Week computation is duplicated** in `home_screen.dart` L37 and `calendar_screen.dart` L26. Neither normalizes to midnight or updates after midnight. Week navigation needs `_weekStart`/`_stream` to become mutable state and the stream to be recreated (and the old one cancelled) on change.

---

## Suggested implementation order

Grouped so each step touches one cluster of files. Foundations come first so later steps can consume them.

**Step 1: Foundations** (`lib/core/theme.dart`, new `lib/widgets/`, new `lib/core/format.dart`, `pubspec.yaml`)
- Contrast: adjust `textMuted`/`textSecondary` (and maybe add a hint token) in `AppColors`.
- Text field `contentPadding` fix in `InputDecorationTheme`. Add the missing `titleMedium`/`labelMedium`/`labelSmall` text styles (or set `fontFamily`). Add `chipTheme`, `filledButtonTheme`, `snackBarTheme`, `bottomSheetTheme`.
- Shared widgets: `AddBar` (+ an optional suggestions dropdown), `SectionHeader` (collapsible, with count), `showAppSnackBar`/`showUndoSnackBar` helper, a sheet scaffold, and a `MealStatus` helper (color/icon/label).
- `formatQuantity()` (½ and friends, int trimming) and a numeric-quantity parser.
- Add the `shared_preferences` dependency.

**Step 2: Web shell** (`pantry_logic/web/index.html`, `manifest.json`, `web/icons/`, then rebuild into `docs/`) — independent of the Dart work and can ship any time.
- Status-bar style, `theme-color` meta, title/app names/short_name, a real favicon, padded maskable icons, a 180px apple-touch-icon, optional iOS splash.

**Step 3: Global copy and icon sweep** (light edits across many files — do it in one pass)
- Rename the Pantry tab/title (`main_shell.dart` L77, `pantry_screen.dart` L263) and the "in pantry" copy strings.
- "Need List" → "Ingredients" (`meal_detail_screen.dart` L267/L435/L463, `meals_screen.dart` L146/L270, `hungry_suggestion_screen.dart` L199, `hungry_service.dart` doc comments).
- Emoji → Material icons (the 15 sites in Risk 14). Optionally drop the NotoColorEmoji asset.

**Step 4: Pantry** (`pantry_screen.dart`, `inventory_service.dart`, `models/inventory_item.dart`, DB migration, possibly `settings_screen.dart` and `settings_service.dart`)
- DB: add `inventory_items.added_by` (FK → profiles) and populate it in `addInventoryItem` and `GroceryService.checkOffItem`. Join `profiles!added_by(display_name)`.
- Single-line rows with the quantity pill (hidden when 1), ½ formatting, alphabetical within group.
- Collapsible sections with counts, persisted state keyed by location name, auto-expand while searching.
- Location ordering. Decide between a hardcoded order and a sort_order reorder UI in Settings. Also refresh `_locations` when the tab regains focus.
- Edit sheet: editable name (handle unique-name collisions), quantity stepper (numeric only), chip styling and order, consistent field labels, added_by line, and the `_saving` bug fix.
- Undo snackbar on delete (resolve the conflict with "Add to grocery list").

**Step 5: Meals and meal detail** (`meal_detail_screen.dart`, `meals_screen.dart`, `meal_service.dart`, `restock_screen.dart`)
- Adopt the shared `AddBar` (meal detail, meals list).
- Ingredient rows: clearer status plus location (avoid "In pantry · Pantry"), shared `MealStatus`.
- Always show category and notes (with empty-state affordances). Show category/notes on list rows if desired.
- Reduce the bottom controls: move "Add missing" into the header or overflow, and keep a single primary Eat This.
- Eat This: pre-warn when ingredients are missing. Fix the `popUntil` route names (`RouteSettings(name: …)` on the pushes) so Done returns to the meal.
- Add a confirm or undo to the meals-list swipe delete.

**Step 6: Home and shell** (`home_screen.dart`, `main_shell.dart`)
- A tab-switching mechanism in `MainShell`, tappable stat cards, and a tappable Tonight card → meal detail (fetch the `Meal` by id).
- Replace "This Week". Refresh on tab focus or subscribe to streams.
- Grocery add bar adoption can ride along here or in Step 5 (`grocery_list_screen.dart`, which is otherwise untouched).

**Step 7: Calendar** (`calendar_screen.dart`; `calendar_service.dart` already supports arbitrary weeks)
- Mutable `_weekStart` normalized to midnight, prev/next/today navigation, stream re-subscription.
- Past-day dimming (decide whether past days stay tappable), quieter empty days (drop the chevron and the "Tap to plan dinner" repetition).
- Share week-start logic with Home.
