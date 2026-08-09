-- SATTYYVVAA store schema — run this once in Supabase SQL Editor (Database → SQL Editor → New query)

-- Admins allow-list (same pattern used on FabQuote — only UIDs listed here count as admin)
create table public.sattyyvvaa_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz default now()
);
alter table public.sattyyvvaa_admins enable row level security;
create policy "Authenticated can read admins"
  on public.sattyyvvaa_admins for select to authenticated using (true);

-- Products
create table public.sattyyvvaa_products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null check (category in ('dresses','tops','bottoms','twopieces')),
  price numeric,               -- null/0 = "Enquire for price"
  description text,
  image_url text,
  stock int default 0,
  active boolean default true, -- inactive = hidden from storefront, still visible in admin
  sort_order int default 0,
  created_at timestamptz default now()
);
alter table public.sattyyvvaa_products enable row level security;

-- Storefront (anon) can only see active products — this is what index.html will read
create policy "Public can view active products"
  on public.sattyyvvaa_products for select to anon, authenticated
  using (active = true);

-- Only admins can create/edit/delete products
create policy "Admins can insert products"
  on public.sattyyvvaa_products for insert to authenticated
  with check (exists (select 1 from public.sattyyvvaa_admins where user_id = auth.uid()));
create policy "Admins can update products"
  on public.sattyyvvaa_products for update to authenticated
  using (exists (select 1 from public.sattyyvvaa_admins where user_id = auth.uid()));
create policy "Admins can delete products"
  on public.sattyyvvaa_products for delete to authenticated
  using (exists (select 1 from public.sattyyvvaa_admins where user_id = auth.uid()));
-- Admins also need to see inactive/draft products in the console, which the anon-only
-- select policy above doesn't cover for them, so add a second read policy scoped to admins:
create policy "Admins can view all products"
  on public.sattyyvvaa_products for select to authenticated
  using (exists (select 1 from public.sattyyvvaa_admins where user_id = auth.uid()));

-- Storage bucket for product photos, uploaded from the admin console
insert into storage.buckets (id, name, public) values ('product-images', 'product-images', true);
create policy "Public can view product images"
  on storage.objects for select to anon, authenticated
  using (bucket_id = 'product-images');
create policy "Admins can upload product images"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'product-images' and exists (select 1 from public.sattyyvvaa_admins where user_id = auth.uid()));
create policy "Admins can delete product images"
  on storage.objects for delete to authenticated
  using (bucket_id = 'product-images' and exists (select 1 from public.sattyyvvaa_admins where user_id = auth.uid()));
