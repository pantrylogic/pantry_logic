# PANTRY LOGIC — Complete Project Brief

## What This Document Is
This is the single source of truth for building Pantry Logic. It contains every product decision, feature spec, data model, UX rule, branding guideline, and build instruction. Claude in Cursor should reference this document before making any architectural or design decisions.

---

## Product Overview

**Name:** Pantry Logic
**Tagline:** "Argue over dinner, not about what's for dinner."
**Platform:** Cross-platform mobile (Flutter/Dart)
**Backend:** Supabase (Postgres, Auth, Realtime)
**Version:** V1 / MVP

Pantry Logic is a shared household app that helps families manage groceries, track food inventory, and decide what to eat. All data is shared between household members in real time.

The app answers three daily questions:
1. What food do we already have?
2. What do we need to buy?
3. What should we eat?

**Value Proposition:** Know what you have, know what to buy, and decide what to eat in seconds.

---

## Design Principles

These govern every decision. If a feature conflicts with these, simplify.

1. **Design for the tired, distracted user** — not the ideal organized one
2. **Inventory updates as a side effect** — never as a separate chore
3. **One action per thought** — no multi-step forms
4. **Text-first input everywhere** — type, autocomplete, done
5. **Only required field for anything: name** — everything else is optional
6. **Roughly correct and easy to maintain beats perfectly accurate and annoying**
7. **The app serves three moments:** before shopping, dinner decision time, in the kitchen
8. **Speed determines adoption** — adding 10 items should take under 15 seconds
9. **Could someone use this while standing in a kitchen holding groceries?** If not, simplify.

---

## User Model

- Users belong to a Household
- All data is shared at the household level
- One household per user in V1
- Two roles: Owner (creator) and Member (everyone else) — no functional difference in V1

### Auth Flow

**Primary user (household creator):**
- Full account: display name + email + password
- Creates the household, names it
- Receives an invite code to share

**Secondary users (joining):**
- Enter invite code + pick a display name
- That's it — they're in immediately
- Supabase anonymous auth session keeps them logged in
- Gentle prompt later: "Save your access? Create an account."
- If they don't create an account: full functionality on that device, need code again if they switch devices
- If they create an account: permanent access across devices

**Onboarding goal:** Under 2 minutes from download to shared functionality.

---

## Screens (V1)

7 main screens + 2 flow screens + 1 settings screen:

1. **Home Dashboard**
2. **Grocery List**
3. **Pantry (Inventory)**
4. **Meals**
5. **Meal Detail** (sub-screen of Meals)
6. **Dinner Calendar**
7. **Hungry Button Flow** (category pick → suggestion → restock)
8. **Auth Screens** (sign up, join household)
9. **Settings**

### Navigation
Bottom tab bar with 5 tabs:
- Home
- Grocery
- Pantry
- Meals
- Calendar

Hungry Button lives on the Home screen, not in the tab bar.
Settings accessible from Home screen (gear icon or profile area).

---

## Feature Specifications

### 1. Home Dashboard

The kitchen status board. Users glance at it like a weather app.

**Displays:**
- Greeting with user's name
- Tonight's dinner (from calendar, or "Nothing planned")
- Hungry Button (large, prominent, center of attention)
- Grocery list item count
- Pantry item count
- This week's dinner preview (compact)

**UX Rules:**
- Answers "What do I need right now?" not "What features does this app have?"
- Should be useful in a 3-second glance
- No clutter

---

### 2. Grocery List

Shared list editable by all household members.

**Each grocery item has:**
- Name (required)
- Quantity (optional)
- Notes (optional) — for brand, size, etc.
- Added by (auto — shows username)
- Purchased status (checked/unchecked)

**Functions:**
- Add item via text-first input (type → autocomplete from starter dictionary + household items → enter to add)
- Check off item → auto-adds to inventory with category-based default location
- Edit item
- Delete item (any user)
- "Clear completed" button to remove checked-off items

**Autocomplete behavior:**
- Suggests from starter item dictionary AND household's custom items
- Typing "chi" shows: Chicken breast, Chili powder, Chips
- Tapping a suggestion adds it instantly
- Typing something new and hitting enter creates a new item

**Checkoff → Inventory flow:**
- Item auto-adds to inventory
- Location assigned by category default (from starter dictionary or household override)
- If item already exists in inventory: merge and add quantities together
- Notes carry over from grocery to inventory

**Display:**
- Checkbox on left, item name center, (username) on right in subtle format
- Checked items: strikethrough, dimmed, moved to bottom of list
- Text input always visible at top, ready for typing

---

### 3. Pantry (Inventory)

Everything in the house, grouped by storage location.

**Each inventory item has:**
- Name (required)
- Location (required — assigned automatically or manually)
- Quantity (optional)
- Notes (optional — carried over from grocery list)
- Category (auto-assigned, invisible to user in V1)

**Default locations:** Fridge, Freezer, Pantry, Deep Freeze
**Custom locations:** Users can create, rename, delete their own from Settings

**Functions:**
- View items grouped by location
- Search/filter inventory (fast — for the "do we have this?" moment)
- Add item manually (same text-first input)
- Edit item (location, quantity, notes)
- Delete item (any user)

**UX Rules:**
- Most inventory items should arrive via grocery checkoff or "Eat This" flow, not manual entry
- Manual add exists but isn't the primary path
- Should answer "Do we have this?" in under 3 seconds

---

### 4. Meals

Household meals with optional need lists.

**Each meal has:**
- Name (required)
- Category (required — from user-customizable list)
- Need list (optional — list of items needed to make this meal)
- Notes/instructions (optional — e.g., "cook on medium 20 min")

**Default meal categories:** Snack, Light Meal, Meal
**Custom categories:** Users can create, rename, delete their own from Settings

**Need list behavior:**
- Built with same text-first input (autocomplete from existing items or type new)
- Each need list item is a universal item (same items used in grocery and inventory)
- Display shows inventory status per item: "In fridge" (green) or "Missing" (amber)

**Functions:**
- Add meal
- Edit meal
- Delete meal (any user)
- View meal detail (see Meal Detail screen)

**Display:**
- List of meals, each showing: name + category chip
- If need list exists: summary status ("You have everything" or "Missing 2 items")
- Meals without need lists show no status (they're just names)

---

### 5. Meal Detail (sub-screen)

Full view of a single meal.

**Displays:**
- Meal name
- Category chip
- Notes/instructions (if any)
- Need list with inventory status per item
- "Add [N] missing items to grocery list" button (if any missing)
- "Eat This" button

**"Add missing to grocery list":**
- Adds all missing need-list items to the grocery list in one tap
- Or user can tap individual missing items to add selectively

---

### 6. Dinner Calendar

One meal per day. Dinner only. Current week only in V1.

**Displays:**
- Week strip (Mon–Sun) with today highlighted
- Each day shows: assigned meal name, or "Tap to plan dinner"
- Status indicator per day: green dot (have everything), amber dot (missing items)

**Functions:**
- Tap empty day → assign meal (same text-first input from meals list)
- Tap assigned day → view meal, "Eat This", change, remove
- "Eat This" triggers the same restock flow as everywhere else

**Today's meal also displays on the Home Dashboard.**

---

### 7. Hungry Button Flow

The core daily habit feature. Helps decide what to eat in under 10 seconds.

**Flow:**

**Step 1: Tap "I'm Hungry" on Home screen**

**Step 2: Pick a category**
- Shows user's meal categories (defaults: Snack, Light Meal, Meal)
- Large tappable buttons, not a dropdown

**Step 3: App suggests one meal at a time**

Suggestion priority:
- First ~5 suggestions: meals in that category where ALL need-list items are in inventory, OR meals with no need list. Randomized within this pool.
- After 5 (or if fewer than 5 exist with full inventory): show meals with missing items
- Every suggestion shows inventory context: "You have everything ✓" or "Missing: ground beef, salsa"

**Step 4: User chooses**
- "Eat This" → triggers restock flow
- "Suggest Another" → next suggestion (next best, with some randomization)
- "← Change category" → back to category picker

---

### 8. "Eat This" / Restock Flow

Triggered from: Hungry Button, Meal Detail, or Calendar. Same logic everywhere.

**For meals WITH a need list:**

Screen shows: "Enjoy! Need to restock anything?" with list of need-list items.

Per item, two behaviors:

**If item has quantity in inventory:**
- Quantity auto-reduces by 1
- If qty hits 0: item removed from inventory, prompt "Add to grocery list?"
- If qty still above 0: shows "Auto-reduced ✓" — no action needed
- These items may not appear in the restock prompt at all if qty > 0 after reduction

**If item has NO quantity in inventory:**
- Shows two options: "Add to list" or "Still have some"
- "Add to list" → adds to grocery list, removes from inventory
- "Still have some" → item stays in inventory, no action

**"Done" button** at the bottom dismisses the flow.

**For meals WITHOUT a need list:**
- "Eat This" just confirms. No inventory interaction. No restock prompt.

---

### 9. Settings Screen

**Contains:**
- Household name (editable by owner)
- Invite code (with copy/share action)
- Member list (display names)
- Custom storage locations (add, rename, delete)
- Custom meal categories (add, rename, delete)
- User display name (editable)
- Sign out

---

## Starter Item Dictionary

A preloaded table of ~200-300 common grocery items. Each entry has:
- Name (e.g., "Milk")
- Category (e.g., "Dairy") — invisible to user in V1
- Default location (e.g., "Fridge")

**Purpose:**
- Powers autocomplete across grocery list, inventory, and meal need lists
- Auto-assigns category and default location when items are added
- Makes the app feel smart on day one

**Household overrides:**
- If a user changes an item's location, the app remembers that preference for the household
- Custom items added by the household join the autocomplete pool permanently

**Category → Default Location mapping:**
- Dairy → Fridge
- Produce → Fridge
- Meat → Fridge
- Beverages → Fridge
- Frozen → Freezer
- Dry Goods → Pantry
- Canned Goods → Pantry
- Snacks → Pantry
- Condiments → Pantry (or Fridge depending on item)
- Baking → Pantry
- Bread/Bakery → Pantry

**If an item is not in the dictionary:**
- Defaults to Pantry
- User can change location
- App remembers for next time

---

## Universal Item System

Items are the universal building block of the app. A single item (e.g., "Milk") can appear in:
- Inventory (you have it)
- Grocery list (you need to buy it)
- A meal's need list (you need it to make this meal)

**Same item, three contexts. Not three separate concepts.**

This means:
- Autocomplete draws from one unified pool
- Inventory matching for meals is exact by item name
- No fuzzy matching or brand normalization needed — users define their own vocabulary

---

## Data Models (Conceptual)

### Household
- id
- name
- invite_code

### User
- id
- display_name
- email (optional for guest users)
- household_id
- role (owner / member)
- auth_type (full / anonymous)

### Item (the universal item)
- id
- household_id
- name
- category (from dictionary or null)
- default_location (from dictionary or user override)

### Inventory Entry
- id
- household_id
- item_id
- location
- quantity (optional)
- notes (optional)

### Grocery Entry
- id
- household_id
- item_id
- quantity (optional)
- notes (optional)
- added_by (user_id)
- purchased (boolean)

### Meal
- id
- household_id
- name
- category
- notes (optional — instructions, tips)

### Meal Need List Entry
- id
- meal_id
- item_id

### Calendar Entry
- id
- household_id
- date
- meal_id

### Storage Location
- id
- household_id
- name
- is_default (boolean)
- sort_order

### Meal Category
- id
- household_id
- name
- is_default (boolean)
- sort_order

### Starter Dictionary (seed data, not user-editable)
- id
- name
- category
- default_location

---

## Build Order

Build in this exact sequence. Each phase builds on the last.

### Phase 1: Auth & Household
- Supabase auth setup (email/password + anonymous)
- Sign up screen (name + email + password)
- Create household (name it, generate invite code)
- Join household (enter code + display name)
- Gentle "save your access" prompt for anonymous users
- Basic session management

### Phase 2: Grocery List + Starter Dictionary
- Seed starter dictionary into database
- Text-first input with autocomplete
- Add, edit, delete grocery items
- "Added by" display
- Check off → auto-add to inventory with default location
- Merge duplicates in inventory, add quantities
- Notes field
- Clear completed button
- Real-time sync across users

### Phase 3: Inventory
- View items grouped by location
- Default locations (Fridge, Freezer, Pantry, Deep Freeze)
- Custom locations
- Search/filter
- Manual add (text-first input)
- Edit item (location, quantity, notes)
- Delete item
- Items at qty 0 removed + prompt add to grocery list

### Phase 4: Meals
- Add meal (name + category)
- Default categories (Snack, Light Meal, Meal)
- Custom categories
- Optional need list (text-first input, universal items)
- Meal detail view with inventory status
- "Add missing to grocery list" button
- Optional notes/instructions field
- Edit, delete meals

### Phase 5: Hungry Button
- Category picker screen
- Suggestion logic (full inventory first ~5, then partial)
- Suggestion display with inventory context
- "Eat This" → restock flow
- "Suggest Another" → next suggestion
- Restock flow: qty items auto-reduce, no-qty items prompt add to list or still have some

### Phase 6: Home Dashboard + Calendar
- Home: greeting, tonight's meal, Hungry Button, grocery count, pantry count, week preview
- Calendar: week view (current week only), one meal per day, assign/change/remove meals
- "Eat This" from calendar triggers same restock flow
- Settings screen: household info, invite code, members, custom locations, custom categories, display name, sign out

---

## What Is NOT in V1

Do not build any of these:
- Voting / approval system for meals
- Barcode scanning
- Recipe import / preloaded meal database
- Expiration date tracking
- Notifications / push alerts
- Prep time on meals
- Voice input
- AI-powered suggestions
- Multiple households per user
- Offline mode
- Photos / media
- Role-based permissions beyond owner/member
- Month calendar view
- Multiple meals per day (breakfast/lunch/dinner)
- Social sign-in (Apple/Google) — email + password only for V1

---

## Branding & Visual Design

### Brand Personality
- Calm, practical, supportive, no-nonsense
- Feels like a whiteboard on the fridge
- NOT a trendy food app, recipe magazine, or productivity system

### Color Palette — Light Mode
| Role | Hex | Usage |
|------|-----|-------|
| Primary | `#2D5A27` | Primary buttons, nav highlights, key actions |
| Primary Dark | `#1E3D1A` | Headers, emphasis |
| Secondary | `#7A9E77` | Secondary buttons, tags, chips |
| Accent Light | `#C5D8C2` | Subtle backgrounds, card borders |
| Accent Soft | `#D4E2A5` | Highlights, "you have this" indicators |
| Background | `#F7F7F4` | Main background (not pure white) |
| Surface | `#FFFFFF` | Cards, input fields, list items |
| Text Primary | `#2C2C2C` | Body text, item names |
| Text Secondary | `#6B6B6B` | Subtitles, "added by" labels |
| Text Muted | `#9E9E9E` | Placeholder text, hints |
| Success | `#4CAF50` | "You have everything" |
| Warning | `#E8A838` | "Missing items" |
| Error | `#C75450` | Delete actions |

### Color Palette — Dark Mode
| Role | Hex | Usage |
|------|-----|-------|
| Primary | `#7FB87A` | Primary buttons, nav highlights |
| Primary Dark | `#2D5A27` | Accents |
| Secondary | `#5A8A56` | Secondary buttons, tags |
| Accent Light | `#3A4D38` | Card backgrounds |
| Accent Soft | `#A3C78F` | Highlights |
| Background | `#1A1C1A` | Main background (slightly green-tinted) |
| Surface | `#252825` | Cards, input fields |
| Text Primary | `#E8E8E4` | Body text |
| Text Secondary | `#9EAA9C` | Subtitles |
| Text Muted | `#6B736B` | Placeholder text |
| Success | `#66BB6A` | "You have everything" |
| Warning | `#FFAB40` | "Missing items" |
| Error | `#EF5350` | Delete actions |

### Color Rules
- Never use pure white (#FFFFFF for bg) or pure black (#000000 for bg)
- Green is the dominant brand color but used intentionally as accent, not everywhere
- Status colors are muted, not alarming — this is a calm app
- Dark mode background has slight green warmth

### Typography
- Font: Nunito Sans (Google Fonts, free, works in Flutter)
- Screen headers: 24px Bold
- Section headers: 18px SemiBold
- List item names: 16px Medium
- Secondary text: 14px Regular
- Small labels/tags: 12px Medium
- No all-caps — conversational tone
- Left-aligned always
- Generous line height (1.4–1.5x)

### UI Components
- Rounded corners: 12px on cards and buttons
- Subtle shadows on light mode, slight borders on dark mode
- Touch targets: 48px minimum height
- Hungry Button: 56-64px height, prominent
- Autocomplete dropdown appears immediately on typing
- Checked-off grocery items: strikethrough, dimmed, bottom of list
- Swipe to delete or long-press → delete

### Tone of Voice (UI Copy)
| Instead of | Say |
|------------|-----|
| "Inventory Management" | "What's in the house" |
| "Add item to database" | "Add an item" |
| "No results found" | "Nothing here yet" |
| "Item successfully deleted" | "Removed" |
| "Confirm selection" | "Got it" |
| "Insufficient ingredients" | "Missing a few things" |

**Empty states:**
- Empty grocery list: "Nothing to buy — nice!"
- Empty inventory: "Add your first items to get started"
- Empty meals: "Add meals your household likes"
- No Hungry suggestions: "Add some meals first so we can help you decide"

### Dark Mode
- Supported from V1, follows system setting
- Not just "invert" — intentionally designed
- Background: `#1A1C1A` (slight green warmth)
- Green accents slightly brighter than light mode for contrast
- Text: off-white, never pure white

---

## Architecture Guidelines

- Structure code by: screens, models, services, widgets
- Keep business logic separate from UI
- Build working features before optimization
- Generate code in small, testable parts
- Use Supabase Realtime for sync where possible
- Store secrets (Supabase URL, anon key) in environment config, never in code

---

## Definition of Done

V1 is complete when a household can:
1. Create a home and invite members
2. Add groceries together from any device
3. Check off groceries and have them appear in inventory automatically
4. See what food is in the house, grouped by location
5. Create meals with optional need lists
6. See what's missing for a meal and add it to the grocery list
7. Tap Hungry and get a useful suggestion in seconds
8. "Eat This" and have inventory update + restock prompt work correctly
9. Plan dinners on a weekly calendar
10. Glance at the home screen and know what's happening today
