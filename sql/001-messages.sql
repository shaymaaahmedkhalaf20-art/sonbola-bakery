-- 001: جدول رسائل فورم التواصل. شغّل ملفات sql/ بالترتيب في Supabase > SQL Editor، وكلها آمنة لو اتشغّلت تاني.

create table if not exists public.messages (
  id         bigint generated always as identity primary key,
  name       text        not null check (char_length(name)    between 1 and 80),
  phone      text        not null check (phone ~ '^01[0-9]{9}$'),
  message    text        not null check (char_length(message) between 1 and 1000),
  contact_ok boolean     not null default false,
  created_at timestamptz not null default now()
);

-- لو الجدول كان معمول قبل كده: نضيف عمود الموافقة على التواصل
alter table public.messages add column if not exists contact_ok boolean not null default false;

alter table public.messages enable row level security;

-- إضافة فقط للزوار (anon): مفيش قراية ولا تعديل ولا مسح
drop policy if exists "anon can insert messages" on public.messages;
create policy "anon can insert messages"
  on public.messages
  for insert
  to anon
  with check (true);

-- نشيل أي صلاحيات زيادة، ونسيب الإضافة بس (صلاحيات الأدمن بتتدّي في 002، فلو شغّلت الملف ده تاني شغّل 002 بعده)
revoke all on public.messages from anon, authenticated;
grant insert on public.messages to anon;
