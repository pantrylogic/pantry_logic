-- The app now learns item names and locations from user input (public.items).
-- Empty the pre-seeded global dictionary. The table is kept for now and will
-- be dropped in a later cleanup.
--
-- Backup: backup.starter_dictionary (non-exposed schema, created before this
-- migration) and supabase/backups/starter_dictionary_2026-10-11.json.
-- No foreign keys reference starter_dictionary, so nothing cascades.
delete from public.starter_dictionary;
