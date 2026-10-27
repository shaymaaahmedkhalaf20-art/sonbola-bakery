-- 002: المنيو والطلبات ولوحة التحكم. شغّله بعد 001 في Supabase > SQL Editor، وآمن لو اتشغّل تاني.
-- القاعدة (docs/adr/0001): المتصفح مش موثوق، فكل الأسعار والحسابات والقواعد هنا جوه قاعدة البيانات.

-- ============ الأدمن ============
-- الأدمن = إيميل في الجدول ده + حساب بنفس الإيميل في Authentication. التسجيل من الموقع مقفول.
create table if not exists public.admins (
  email      text primary key check (email = lower(email)),
  created_at timestamptz not null default now()
);
alter table public.admins enable row level security;
revoke all on public.admins from anon, authenticated;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where email = lower(coalesce(auth.jwt() ->> 'email', '')));
$$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to anon, authenticated;

-- ============ الإعدادات (صف واحد بس) ============
create table if not exists public.settings (
  id                 boolean primary key default true check (id),
  opens_at           time    not null default '07:00',
  closes_at          time    not null default '00:00',   -- لو أصغر من أو بيساوي opens_at يبقى بيقفل بعد نص الليل
  ordering_paused    boolean not null default false,
  delivery_fee       numeric(10,2) not null default 0 check (delivery_fee >= 0),
  notification_email text check (notification_email is null or notification_email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  updated_at         timestamptz not null default now()
);
insert into public.settings (id) values (true) on conflict do nothing;
alter table public.settings enable row level security;
revoke all on public.settings from anon, authenticated;
grant select, update on public.settings to authenticated;
drop policy if exists "admins manage settings" on public.settings;
create policy "admins manage settings" on public.settings
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- مفتوحين دلوقتي؟ (بتوقيت القاهرة)
create or replace function public.is_open_now() returns boolean
language sql stable security definer set search_path = public as $$
  select not s.ordering_paused and (
    case when s.opens_at < s.closes_at
         then t >= s.opens_at and t < s.closes_at
         else t >= s.opens_at or t < s.closes_at
    end)
  from public.settings s, (select (now() at time zone 'Africa/Cairo')::time as t) n;
$$;
revoke all on function public.is_open_now() from public;

-- اللي الموقع العام محتاج يعرفه من الإعدادات، من غير إيميل الإشعارات
create or replace function public.public_settings() returns json
language sql stable security definer set search_path = public as $$
  select json_build_object(
    'open_now',        public.is_open_now(),
    'ordering_paused', s.ordering_paused,
    'opens_at',        to_char(s.opens_at, 'HH24:MI'),
    'closes_at',       to_char(s.closes_at, 'HH24:MI'),
    'delivery_fee',    s.delivery_fee)
  from public.settings s;
$$;
revoke all on function public.public_settings() from public;
grant execute on function public.public_settings() to anon, authenticated;

-- ============ المنيو ============
create table if not exists public.categories (
  id         bigint generated always as identity primary key,
  name       text not null unique check (char_length(name) between 1 and 40),
  emoji      text not null default '' check (char_length(emoji) <= 8),
  sort_order int  not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.products (
  id          bigint generated always as identity primary key,
  category_id bigint not null references public.categories(id) on delete restrict,
  name        text not null check (char_length(name) between 1 and 60),
  unit_label  text not null default '' check (char_length(unit_label) <= 30),  -- وحدة البيع: الحبّة، الربطة، الكيلو…
  price       numeric(10,2) not null check (price > 0),                       -- سعر الوحدة الواحدة
  qty_step    numeric(6,3)  not null default 1 check (qty_step > 0),          -- أصغر كمية: 1 أو 0.25 كيلو
  photo_url   text check (photo_url is null or photo_url ~ '^https://'),
  available   boolean not null default true,                                  -- false = خلص النهارده
  sort_order  int not null default 0,
  created_at  timestamptz not null default now()
);

alter table public.categories enable row level security;
alter table public.products   enable row level security;
revoke all on public.categories, public.products from anon, authenticated;
grant select on public.categories, public.products to anon, authenticated;
grant insert, update, delete on public.categories, public.products to authenticated;

drop policy if exists "everyone reads categories" on public.categories;
create policy "everyone reads categories" on public.categories for select using (true);
drop policy if exists "admins write categories" on public.categories;
create policy "admins write categories" on public.categories
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "everyone reads products" on public.products;
create policy "everyone reads products" on public.products for select using (true);
drop policy if exists "admins write products" on public.products;
create policy "admins write products" on public.products
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- أصناف المنيو الحالية (مرة واحدة بس لو الجدول فاضي). الأصناف المزدوجة اتقسمت لصنفين بنفس السعر.
do $$
declare c_bread bigint; c_bake bigint; c_sweet bigint;
begin
  if exists (select 1 from public.categories) then return; end if;
  insert into public.categories (name, emoji, sort_order) values ('العيش', '🌾', 1) returning id into c_bread;
  insert into public.categories (name, emoji, sort_order) values ('المخبوزات', '🥐', 2) returning id into c_bake;
  insert into public.categories (name, emoji, sort_order) values ('الحلويات', '🍰', 3) returning id into c_sweet;
  insert into public.products (category_id, name, unit_label, price, qty_step, sort_order) values
    (c_bread, 'عيش فينو',          'الحبّة',        3,   1,    1),
    (c_bread, 'عيش شامي',          'الربطة',        15,  1,    2),
    (c_bread, 'عيش توست',          'الباكو',        40,  1,    3),
    (c_bread, 'عيش بلدي فلاحي',    'ربطة ٥ أرغفة',  10,  1,    4),
    (c_bake,  'كرواسون سادة',      '',              20,  1,    1),
    (c_bake,  'كرواسون بالجبنة',   '',              30,  1,    2),
    (c_bake,  'فطيرة مشلتتة',      'الحبّة',        60,  1,    3),
    (c_bake,  'بيتزا مخبوزة',      '',              45,  1,    4),
    (c_sweet, 'كيكة سادة',         '',              70,  1,    1),
    (c_sweet, 'كيكة بالشوكولاتة',  '',              70,  1,    2),
    (c_sweet, 'بقلاوة',            'الكيلو',        200, 0.25, 3),
    (c_sweet, 'بسبوسة',            'الكيلو',        200, 0.25, 4),
    (c_sweet, 'كحك',               'الكيلو',        220, 0.25, 5),
    (c_sweet, 'بيتي فور',          'الكيلو',        220, 0.25, 6),
    (c_sweet, 'بسكوت بالسمنة',     'الكيلو',        180, 0.25, 7);
end $$;

-- صور الأصناف: أي حد يشوفها، والأدمن بس يرفع ويمسح
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('product-photos', 'product-photos', true, 2097152, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;
drop policy if exists "admins upload product photos" on storage.objects;
create policy "admins upload product photos" on storage.objects
  for insert to authenticated with check (bucket_id = 'product-photos' and public.is_admin());
drop policy if exists "admins change product photos" on storage.objects;
create policy "admins change product photos" on storage.objects
  for update to authenticated using (bucket_id = 'product-photos' and public.is_admin());
drop policy if exists "admins delete product photos" on storage.objects;
create policy "admins delete product photos" on storage.objects
  for delete to authenticated using (bucket_id = 'product-photos' and public.is_admin());

-- ============ الطلبات ============
create sequence if not exists public.order_number_seq start 1001;

create table if not exists public.orders (
  id            bigint generated always as identity primary key,
  number        bigint not null unique default nextval('public.order_number_seq'),
  status        text not null default 'new'
                check (status in ('new','accepted','ready','out_for_delivery','completed','cancelled')),
  fulfillment   text not null check (fulfillment in ('pickup','delivery')),
  customer_name text not null check (char_length(customer_name) between 1 and 80),
  phone         text not null check (phone ~ '^01[0-9]{9}$'),
  address       text check (address is null or char_length(address) <= 300),
  notes         text check (notes is null or char_length(notes) <= 500),
  subtotal      numeric(10,2) not null check (subtotal > 0),
  delivery_fee  numeric(10,2) not null default 0,
  total         numeric(10,2) not null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint delivery_has_address check (fulfillment <> 'delivery' or char_length(trim(coalesce(address, ''))) >= 5),
  constraint ready_is_pickup      check (status <> 'ready' or fulfillment = 'pickup'),
  constraint out_is_delivery      check (status <> 'out_for_delivery' or fulfillment = 'delivery')
);
alter sequence public.order_number_seq owned by public.orders.number;
create index if not exists orders_created_at_idx on public.orders (created_at desc);
create index if not exists orders_open_phone_idx on public.orders (phone) where status not in ('completed','cancelled');

-- سطر الطلب بيحتفظ باسم الصنف وسعره وقت الطلب، فتغيير السعر بعدين مايغيّرش الطلبات القديمة
create table if not exists public.order_lines (
  id          bigint generated always as identity primary key,
  order_id    bigint not null references public.orders(id) on delete cascade,
  product_id  bigint not null references public.products(id) on delete restrict,
  product_name text not null,
  unit_label  text not null default '',
  unit_price  numeric(10,2) not null,
  quantity    numeric(8,3)  not null check (quantity > 0),
  line_total  numeric(10,2) not null,
  unique (order_id, product_id)
);
create index if not exists order_lines_order_idx on public.order_lines (order_id);

-- الزوار مالهمش أي صلاحية على الطلبات. الطلب بيتعمل بس من place_order، والأدمن بيغيّر من الدوال تحت.
alter table public.orders      enable row level security;
alter table public.order_lines enable row level security;
revoke all on public.orders, public.order_lines from anon, authenticated;
grant select on public.orders, public.order_lines to authenticated;
drop policy if exists "admins read orders" on public.orders;
create policy "admins read orders" on public.orders for select to authenticated using (public.is_admin());
drop policy if exists "admins read order lines" on public.order_lines;
create policy "admins read order lines" on public.order_lines for select to authenticated using (public.is_admin());

-- يحسب سطور الطلب من الأسعار الحالية ويتأكد من الكميات. p_keep_prices: أسعار سطور موجودة قبل كده (تعديل الأدمن)
create or replace function public._build_lines(p_lines jsonb, p_check_available boolean, p_keep_prices jsonb default '{}')
returns table (product_id bigint, product_name text, unit_label text, unit_price numeric, quantity numeric, line_total numeric)
language plpgsql stable security definer set search_path = public as $$
declare l jsonb; p public.products; q numeric; n int := 0; seen bigint[] := '{}';
begin
  if jsonb_typeof(p_lines) is distinct from 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception 'invalid' using detail = 'empty';
  end if;
  for l in select * from jsonb_array_elements(p_lines) loop
    n := n + 1;
    if n > 40 then raise exception 'invalid' using detail = 'too many lines'; end if;
    select * into p from public.products where id = (l ->> 'product_id')::bigint;
    q := (l ->> 'quantity')::numeric;
    if p.id is null then raise exception 'changed' using detail = 'missing product'; end if;
    if p.id = any(seen) then raise exception 'invalid' using detail = 'duplicate product'; end if;
    if p_check_available and not p.available then raise exception 'changed' using detail = 'unavailable'; end if;
    if q is null or q <= 0 or q > 100 or mod(q, p.qty_step) <> 0 then raise exception 'invalid' using detail = 'quantity'; end if;
    seen := seen || p.id;
    product_id   := p.id;
    product_name := p.name;
    unit_label   := p.unit_label;
    unit_price   := coalesce((p_keep_prices ->> p.id::text)::numeric, p.price);
    quantity     := q;
    line_total   := round(unit_price * q, 2);
    return next;
  end loop;
end $$;
revoke all on function public._build_lines(jsonb, boolean, jsonb) from public, anon, authenticated;

-- الطريقة الوحيدة لعمل طلب. الأخطاء: closed / changed / too_many_open / invalid
create or replace function public.place_order(p jsonb) returns json
language plpgsql volatile security definer set search_path = public as $$
declare
  s public.settings;
  v_name text := trim(coalesce(p ->> 'name', ''));
  v_phone text := trim(coalesce(p ->> 'phone', ''));
  v_fulfillment text := p ->> 'fulfillment';
  v_address text := nullif(trim(coalesce(p ->> 'address', '')), '');
  v_notes text := nullif(trim(coalesce(p ->> 'notes', '')), '');
  v_subtotal numeric; v_fee numeric; v_total numeric; v_order public.orders;
begin
  select * into s from public.settings;
  if not public.is_open_now() then raise exception 'closed'; end if;
  if char_length(v_name) not between 1 and 80 or v_phone !~ '^01[0-9]{9}$'
     or v_fulfillment not in ('pickup','delivery')
     or (v_fulfillment = 'delivery' and char_length(coalesce(v_address, '')) < 5) then
    raise exception 'invalid' using detail = 'customer';
  end if;
  if v_fulfillment = 'pickup' then v_address := null; end if;

  drop table if exists _lines;
  create temp table _lines on commit drop as select * from public._build_lines(p -> 'lines', true);
  select sum(line_total) into v_subtotal from _lines;
  v_fee := case when v_fulfillment = 'delivery' then s.delivery_fee else 0 end;
  v_total := v_subtotal + v_fee;
  -- الزبون مايدفعش سعر ماشافهوش
  if (p ->> 'expected_total')::numeric is distinct from v_total then raise exception 'changed' using detail = 'total'; end if;

  perform pg_advisory_xact_lock(hashtext('open-orders:' || v_phone));
  if (select count(*) from public.orders where phone = v_phone and status not in ('completed','cancelled')) >= 3 then
    raise exception 'too_many_open';
  end if;

  insert into public.orders (fulfillment, customer_name, phone, address, notes, subtotal, delivery_fee, total)
  values (v_fulfillment, v_name, v_phone, v_address, left(v_notes, 500), v_subtotal, v_fee, v_total)
  returning * into v_order;
  insert into public.order_lines (order_id, product_id, product_name, unit_label, unit_price, quantity, line_total)
  select v_order.id, product_id, product_name, unit_label, unit_price, quantity, line_total from _lines;

  -- إيميل الأدمن (sql/003). لو فشل لأي سبب، الطلب يفضل محفوظ.
  begin
    perform public.notify_new_order(v_order.id);
  exception when undefined_function then null;
           when others then raise warning 'order email failed: %', sqlerrm;
  end;

  return json_build_object('number', v_order.number, 'total', v_order.total);
end $$;
revoke all on function public.place_order(jsonb) from public;
grant execute on function public.place_order(jsonb) to anon, authenticated;

-- مراحل الطلب: جديد ← اتأكد ← جاهز (استلام) / خرج للتوصيل (توصيل) ← اتسلّم، ويتلغى قبل ما يتسلّم
create or replace function public.set_order_status(p_order_id bigint, p_status text) returns void
language plpgsql volatile security definer set search_path = public as $$
declare o public.orders;
begin
  if not public.is_admin() then raise exception 'not_admin'; end if;
  select * into o from public.orders where id = p_order_id for update;
  if o.id is null then raise exception 'invalid' using detail = 'no order'; end if;
  if not (
       (o.status = 'new'              and p_status in ('accepted','cancelled'))
    or (o.status = 'accepted'         and p_status = 'ready'            and o.fulfillment = 'pickup')
    or (o.status = 'accepted'         and p_status = 'out_for_delivery' and o.fulfillment = 'delivery')
    or (o.status = 'accepted'         and p_status = 'cancelled')
    or (o.status in ('ready','out_for_delivery') and p_status in ('completed','cancelled'))
  ) then
    raise exception 'invalid' using detail = o.status || ' -> ' || p_status;
  end if;
  update public.orders set status = p_status, updated_at = now() where id = p_order_id;
end $$;
revoke all on function public.set_order_status(bigint, text) from public, anon;
grant execute on function public.set_order_status(bigint, text) to authenticated;

-- الأدمن يعدّل أصناف طلب جديد أو متأكد. الأصناف اللي كانت فيه بتفضل بسعرها وقت الطلب، والجديدة بالسعر الحالي.
create or replace function public.update_order_lines(p_order_id bigint, p_lines jsonb) returns json
language plpgsql volatile security definer set search_path = public as $$
declare o public.orders; v_keep jsonb; v_subtotal numeric;
begin
  if not public.is_admin() then raise exception 'not_admin'; end if;
  select * into o from public.orders where id = p_order_id for update;
  if o.id is null or o.status not in ('new','accepted') then raise exception 'invalid' using detail = 'locked'; end if;
  select coalesce(jsonb_object_agg(product_id::text, unit_price), '{}') into v_keep
    from public.order_lines where order_id = o.id;

  drop table if exists _lines;
  create temp table _lines on commit drop as select * from public._build_lines(p_lines, false, v_keep);
  delete from public.order_lines where order_id = o.id;
  insert into public.order_lines (order_id, product_id, product_name, unit_label, unit_price, quantity, line_total)
  select o.id, product_id, product_name, unit_label, unit_price, quantity, line_total from _lines;
  select sum(line_total) into v_subtotal from _lines;
  update public.orders set subtotal = v_subtotal, total = v_subtotal + delivery_fee, updated_at = now()
   where id = o.id;
  return json_build_object('total', v_subtotal + o.delivery_fee);
end $$;
revoke all on function public.update_order_lines(bigint, jsonb) from public, anon;
grant execute on function public.update_order_lines(bigint, jsonb) to authenticated;

-- ============ الرسائل ============
alter table public.messages add column if not exists handled boolean not null default false;
grant select, update (handled) on public.messages to authenticated;
drop policy if exists "admins read messages" on public.messages;
create policy "admins read messages" on public.messages for select to authenticated using (public.is_admin());
drop policy if exists "admins mark messages handled" on public.messages;
create policy "admins mark messages handled" on public.messages
  for update to authenticated using (public.is_admin()) with check (public.is_admin());

-- ============ التحديث اللحظي في لوحة التحكم ============
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'orders') then
    alter publication supabase_realtime add table public.orders;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'messages') then
    alter publication supabase_realtime add table public.messages;
  end if;
end $$;
