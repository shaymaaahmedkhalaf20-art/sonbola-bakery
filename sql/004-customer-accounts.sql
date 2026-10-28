-- 004: دخول الزبون بالإيميل (اختياري). شغّله بعد 003، وآمن لو اتشغّل تاني.
-- الزبون اللي داخل: الطلب بيتربط بحسابه، يشوف طلباته وحالتها، وبياناته بتتحفظ للمرة الجاية.
-- الطلب من غير دخول شغال زي ما هو. والأدمن لسه متحدد بجدول admins بس، فالتسجيل لازم يفضل مفتوح للزباين.

-- ============ بيانات الزبون المحفوظة ============
create table if not exists public.customers (
  id         uuid primary key references auth.users(id) on delete cascade,
  name       text check (name is null or char_length(name) <= 80),
  phone      text check (phone is null or phone ~ '^01[0-9]{9}$'),
  address    text check (address is null or char_length(address) <= 300),
  updated_at timestamptz not null default now()
);
alter table public.customers enable row level security;
revoke all on public.customers from anon, authenticated;
grant select on public.customers to authenticated;
drop policy if exists "customers read own profile" on public.customers;
create policy "customers read own profile" on public.customers
  for select to authenticated using (id = auth.uid());

-- ============ ربط الطلب بالزبون ============
alter table public.orders add column if not exists customer_id uuid references auth.users(id) on delete set null;
create index if not exists orders_customer_idx on public.orders (customer_id, created_at desc);

-- الزبون يشوف طلباته هو بس (الأدمن ليه سياسة لوحده في 002)
drop policy if exists "customers read own orders" on public.orders;
create policy "customers read own orders" on public.orders
  for select to authenticated using (customer_id = auth.uid());
drop policy if exists "customers read own order lines" on public.order_lines;
create policy "customers read own order lines" on public.order_lines
  for select to authenticated using (exists (
    select 1 from public.orders o where o.id = order_id and o.customer_id = auth.uid()));

-- نفس place_order من 002، وزيادة: لو الزبون داخل، الطلب بيتربط بيه وبياناته بتتحفظ
create or replace function public.place_order(p jsonb) returns json
language plpgsql volatile security definer set search_path = public as $$
declare
  s public.settings;
  v_name text := trim(coalesce(p ->> 'name', ''));
  v_phone text := trim(coalesce(p ->> 'phone', ''));
  v_fulfillment text := p ->> 'fulfillment';
  v_address text := nullif(trim(coalesce(p ->> 'address', '')), '');
  v_notes text := nullif(trim(coalesce(p ->> 'notes', '')), '');
  v_customer uuid := auth.uid();
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

  insert into public.orders (fulfillment, customer_name, phone, address, notes, subtotal, delivery_fee, total, customer_id)
  values (v_fulfillment, v_name, v_phone, v_address, left(v_notes, 500), v_subtotal, v_fee, v_total, v_customer)
  returning * into v_order;
  insert into public.order_lines (order_id, product_id, product_name, unit_label, unit_price, quantity, line_total)
  select v_order.id, product_id, product_name, unit_label, unit_price, quantity, line_total from _lines;

  if v_customer is not null then
    insert into public.customers (id, name, phone, address)
    values (v_customer, v_name, v_phone, coalesce(v_address, (select address from public.customers where id = v_customer)))
    on conflict (id) do update set name = excluded.name, phone = excluded.phone,
      address = coalesce(v_address, public.customers.address), updated_at = now();
  end if;

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
