# Meal ingredient availability

`meal_need_list.required_quantity` is an optional positive integer. A null
value keeps the existing presence requirement; a number requires that many
numeric inventory units.

- Inventory quantities remain free text. Plain numbers and fractions can be
  compared; blank, unit-bearing, and descriptive values are unknown for a
  count requirement.
- A numeric zero is missing, including for presence requirements.
- Numeric shortfalls are shown as `Need N more` and are copied to a newly
  created grocery item. Existing active grocery entries are not overwritten.
- Unknown quantities are not considered ready and are not automatically added
  to groceries.
- `Eat This` remains intentionally unchanged and still deducts one numeric
  unit per listed ingredient.

The migration `20261015120000_meal_need_list_required_quantity.sql` is local
only and must be reviewed and explicitly applied before this feature can run
against Supabase.
