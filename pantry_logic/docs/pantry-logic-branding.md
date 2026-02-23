# Pantry Logic — Branding & Visual Guide

## Brand Identity

**Name:** Pantry Logic
**Tagline:** "Argue over dinner, not about what's for dinner."
**Value Proposition:** Know what you have, know what to buy, and decide what to eat in seconds.

**Personality:**
- Calm
- Practical
- Supportive
- No-nonsense
- Helpful, not clever

**The app should feel like:**
- A whiteboard on the fridge
- A shared kitchen dashboard
- A calm assistant that removes small daily annoyances

**The app should NOT feel like:**
- A recipe app
- A diet tracker
- A productivity system
- A trendy food app

---

## Color Palette

Based on the existing logo, built around greens that feel organic, grounded, and food-adjacent.

### Light Mode

| Role | Color | Hex | Usage |
|------|-------|-----|-------|
| Primary | Deep Forest Green | `#2D5A27` | Primary buttons, nav highlights, key actions |
| Primary Dark | Dark Green | `#1E3D1A` | Headers, emphasis, logo outline |
| Secondary | Sage Green | `#7A9E77` | Secondary buttons, tags, category chips |
| Accent Light | Pale Sage | `#C5D8C2` | Subtle backgrounds, card borders, dividers |
| Accent Soft | Soft Lime | `#D4E2A5` | Highlights, "you have this" indicators |
| Background | Off-White | `#F7F7F4` | Main background (not pure white — warmer) |
| Surface | Warm White | `#FFFFFF` | Cards, input fields, list items |
| Text Primary | Charcoal | `#2C2C2C` | Body text, item names |
| Text Secondary | Warm Grey | `#6B6B6B` | Subtitles, "added by" labels, timestamps |
| Text Muted | Light Grey | `#9E9E9E` | Placeholder text, hints |
| Success | Green Check | `#4CAF50` | "You have everything" indicators |
| Warning | Soft Amber | `#E8A838` | "Missing items" indicators |
| Error | Muted Red | `#C75450` | Delete actions, out of stock |

### Dark Mode

| Role | Color | Hex | Usage |
|------|-------|-----|-------|
| Primary | Bright Sage | `#7FB87A` | Primary buttons, nav highlights, key actions |
| Primary Dark | Deep Forest | `#2D5A27` | Accents, logo fill |
| Secondary | Muted Sage | `#5A8A56` | Secondary buttons, tags |
| Accent Light | Dark Olive | `#3A4D38` | Card backgrounds, elevated surfaces |
| Accent Soft | Soft Green Glow | `#A3C78F` | Highlights, indicators |
| Background | Near Black | `#1A1C1A` | Main background (slightly green-tinted, not pure black) |
| Surface | Dark Card | `#252825` | Cards, input fields, list items |
| Text Primary | Off-White | `#E8E8E4` | Body text, item names |
| Text Secondary | Grey-Green | `#9EAA9C` | Subtitles, "added by" labels |
| Text Muted | Dark Grey | `#6B736B` | Placeholder text, hints |
| Success | Green | `#66BB6A` | "You have everything" |
| Warning | Amber | `#FFAB40` | "Missing items" |
| Error | Soft Red | `#EF5350` | Delete, out of stock |

### Key Color Rules
- Background is never pure white or pure black — always slightly warm/tinted
- Green is the dominant brand color but used intentionally, not everywhere
- Most of the UI is neutral (whites, greys, charcoal) with green as accent
- Status colors (success/warning/error) are muted, not alarming — this is a calm app

---

## Typography

**Approach:** Clean, readable, practical. Not trendy, not generic.

**Recommended pairing:**

- **Headlines / App Name:** Nunito Sans (Bold/ExtraBold) — rounded, warm, approachable without being childish
- **Body / List Items:** Nunito Sans (Regular/Medium) — consistent family, excellent readability at small sizes
- **Numbers / Quantities:** Nunito Sans (SemiBold) — slightly heavier for scanability

**Alternative if you want more contrast between display and body:**
- **Headlines:** Quicksand (Bold) — soft, modern, slightly more personality
- **Body:** Source Sans 3 (Regular) — clean and highly readable

**Type Scale:**
- App title / screen headers: 24px Bold
- Section headers: 18px SemiBold
- List item names: 16px Medium
- Secondary text (added by, notes): 14px Regular
- Hint / placeholder text: 14px Regular (muted color)
- Small labels / tags: 12px Medium

**Key Rules:**
- No all-caps anywhere — the app should feel conversational, not loud
- Left-aligned always
- Generous line height (1.4–1.5x) for readability while standing in a kitchen

---

## Logo

**Current logo:** Jar shape with horizontal bars inside (representing inventory levels / list items) and a checkmark overlay.

**Requested change:** Reverse the bar order — darkest green on the bottom, lightest on top. This creates a "filled from the bottom" feel, more natural and grounded.

**Logo usage:**
- App icon: Full jar with checkmark, no text
- In-app header: Can use small icon + "Pantry Logic" text next to it
- Splash screen: Centered icon, "Pantry Logic" below

**Logo color variants:**
- Full color (greens) on light backgrounds
- Light version (pale greens / white) on dark backgrounds
- Single-color dark green on white for simplicity

---

## UI Component Style

**Overall feel:** Simple but not sterile. Somewhere between clean/minimal and warm/cozy.

### Cards & Surfaces
- Rounded corners: 12px (enough to feel soft, not bubbly)
- Subtle shadow on light mode (very light, `0 1px 3px rgba(0,0,0,0.08)`)
- Slight border on dark mode (`1px solid` using surface+10% lighter)
- No heavy drop shadows anywhere

### Buttons
- Primary: Filled with Primary green, white text, 12px rounded corners
- Secondary: Outlined with Primary green border, green text
- Destructive: Muted red, used sparingly
- All buttons: medium height (48px touch target minimum), generous horizontal padding
- Hungry Button on home screen: larger (56-64px height), prominent, centered

### Input Fields
- Text-first input: clean single line, subtle bottom border or light rounded container
- Autocomplete dropdown: appears immediately on typing, matches surface card style
- Placeholder text in muted color: "Add an item..." 
- No labels above inputs where placeholder is sufficient — reduce visual clutter

### Lists
- Grocery list items: checkbox on left, item name, subtle (username) on right
- Inventory items: item name, location tag/chip, optional quantity
- Meal items: meal name, category chip
- Swipe to delete (or long-press → delete option)
- Checked-off items: strikethrough with reduced opacity, move to bottom of list

### Tags / Chips
- Used for: locations (Fridge, Pantry, etc.), meal categories (Snack, Meal, etc.)
- Style: small rounded pill, sage green background, darker text
- Tappable when used as filters

### Navigation
- Bottom tab bar: 5 tabs (Home, Grocery, Inventory, Meals, Calendar)
- Active tab: Primary green icon + label
- Inactive tabs: muted grey icon + label
- No top app bar clutter — screen titles are part of the content, not a toolbar

---

## Iconography

- Style: Outlined, rounded, simple — matching the logo style
- Weight: 2px stroke, consistent across all icons
- Source: Lucide, Phosphor, or similar rounded icon sets
- Key icons needed:
  - Home (house or dashboard)
  - Cart / basket (grocery)
  - Box or shelf (inventory)
  - Utensils or plate (meals)
  - Calendar (calendar)
  - Plus (add)
  - Check (complete)
  - Search (magnifying glass)
  - Hungry button (could be a fun custom icon — fork + question mark, or just use the jar logo)

---

## Tone of Voice (UI Copy)

The app speaks in plain, warm language. Not corporate, not cute.

| Instead of | Say |
|------------|-----|
| "Inventory Management" | "What's in the house" |
| "Add item to database" | "Add an item" |
| "Meal planning module" | "Plan dinner" |
| "No results found" | "Nothing here yet" |
| "Item successfully deleted" | "Removed" |
| "Confirm selection" | "Got it" |
| "Optimize meal selection" | "What should we eat?" |
| "Insufficient ingredients" | "Missing a few things" |
| "Execute meal" | "Eat this" |

**Empty states should be encouraging, not blank:**
- Empty grocery list: "Nothing to buy — nice!"
- Empty inventory: "Add your first items to get started"
- Empty meals: "Add meals your household likes"
- No Hungry suggestions: "Add some meals first so we can help you decide"

---

## Key Screen Visual Notes

### Home Dashboard
- Clean, uncluttered
- Tonight's meal is the most prominent element (top of screen)
- Hungry Button is large and obvious — the visual anchor
- Grocery count is informational, not alarming
- Feels like a glance, not a dashboard full of widgets

### Grocery List
- Feels like a simple checklist / notepad
- Text input at the top, always visible and ready
- List items are scannable — name stands out, username is subtle
- Checked items dim and move down

### Inventory
- Grouped by location with collapsible sections or tabs
- Each location feels like a shelf or section of the kitchen
- Search bar at top for quick "do we have this?"
- Clean, not overwhelming even with many items

### Meals
- Simple list, each meal shows name + category chip
- Tapping a meal opens detail with need list and inventory status
- Green checkmarks for "have it", amber for "missing"

### Calendar
- Compact week strip, not a full calendar
- Each day is a simple cell: day name + meal name or empty
- Today is visually highlighted (green accent)
- Feels light and quick

### Hungry Button Flow
- Category selection: large, tappable cards or buttons (not a dropdown)
- Suggestion screen: meal name large and centered, status below, two clear action buttons
- Restock prompt: clean list with simple tap actions
- The whole flow should feel fast and decisive, not browsy

---

## Dark Mode Specific Notes

- Dark mode is not just "invert everything" — it should feel intentional
- Background has a very slight green warmth (`#1A1C1A` not `#000000`)
- Cards/surfaces are slightly lighter than background for depth
- Green accents should be slightly brighter than light mode to maintain contrast
- Text should be off-white, not pure white (reduces eye strain)
- The Hungry Button should still pop visually in dark mode

---

## Summary

Pantry Logic looks and feels like:
- A calm, reliable household tool
- Something you'd see on a well-organized fridge
- Practical enough for adults, approachable enough for teenagers
- Green, grounded, clean, quiet

It does NOT look or feel like:
- A Silicon Valley startup app
- A recipe magazine
- A gamified experience
- Something that demands attention with bright colors and badges

The visual design supports the product philosophy:
**Reduce stress. Make decisions easy. Get out of the way.**
