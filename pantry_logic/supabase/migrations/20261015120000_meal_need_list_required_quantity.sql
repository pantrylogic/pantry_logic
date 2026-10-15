alter table public.meal_need_list
  add column required_quantity integer;

alter table public.meal_need_list
  add constraint meal_need_list_required_quantity_positive
  check (required_quantity is null or required_quantity > 0);
