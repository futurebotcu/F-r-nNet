-- Yayımlı (status='published') Akademi tarifleri TÜM giriş yapmış
-- kullanıcılara görünür — uygulamadaki tarif listesi bunu okur. Taslak/
-- onay-bekleyen tarifler yalnız sahibine (ar_select_own) görünmeye devam
-- eder; yazma kuralları DEĞİŞMEZ.
drop policy if exists ar_select_published on public.academy_recipes;
create policy ar_select_published on public.academy_recipes
  for select to authenticated using (status = 'published');
