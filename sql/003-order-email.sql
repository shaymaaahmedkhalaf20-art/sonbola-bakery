-- 003: إيميل للأدمن مع كل طلب جديد، عن طريق Resend. شغّله بعد 002، وآمن لو اتشغّل تاني.
--
-- عشان الإيميل يشتغل لازم الاتنين دول:
--   1) إيميل الإشعارات مكتوب في لوحة التحكم > الإعدادات.
--      من غير دومين خاص، Resend بيبعت بس لنفس الإيميل اللي اتعمل بيه حساب Resend.
--   2) مفتاح Resend محفوظ في Vault. شغّل السطر ده مرة واحدة بنفسك في SQL Editor (المفتاح مايتكتبش في أي ملف):
--        select vault.create_secret('re_...المفتاح...', 'resend_api_key');
-- لو واحد منهم ناقص، الطلب بيتحفظ عادي ومفيش إيميل.
--
-- الإرسال بيحصل بعد ما الطلب يتحفظ (pg_net)، فلو Resend وقع أو اتأخر الطلب مايتأثرش.

create extension if not exists pg_net;

create or replace function public._html(t text) returns text
language sql immutable as $$
  select replace(replace(replace(replace(coalesce(t, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;'), '"', '&quot;');
$$;
revoke all on function public._html(text) from public, anon, authenticated;

create or replace function public.notify_new_order(p_order_id bigint) returns void
language plpgsql volatile security definer set search_path = public as $$
declare
  o public.orders; v_to text; v_key text; v_lines text; v_body text;
  v_site constant text := 'https://sonbola-bakery-2hb.pages.dev';
begin
  select notification_email into v_to from public.settings;
  select decrypted_secret into v_key from vault.decrypted_secrets where name = 'resend_api_key' limit 1;
  if v_to is null or v_key is null then return; end if;

  select * into o from public.orders where id = p_order_id;
  select string_agg(format('<tr><td>%s</td><td>%s %s</td><td>%s ج</td></tr>',
           _html(product_name), trim_scale(quantity), _html(unit_label), trim_scale(line_total)), '' order by id)
    into v_lines from public.order_lines where order_id = o.id;

  v_body := format($html$
<div dir="rtl" style="font-family:Tahoma,Arial,sans-serif;font-size:16px;line-height:1.7;color:#3a2414">
  <h2 style="color:#6b3a1e;margin:0 0 8px">طلب جديد رقم #%s</h2>
  <p style="margin:0 0 12px"><b>%s</b> · <a href="tel:%s">%s</a><br>%s</p>
  <table cellpadding="6" style="border-collapse:collapse;width:100%%;max-width:520px">%s
    <tr><td colspan="2">التوصيل</td><td>%s ج</td></tr>
    <tr><td colspan="2"><b>الإجمالي (كاش)</b></td><td><b>%s ج</b></td></tr>
  </table>
  %s
  <p><a href="%s/admin/#orders" style="background:#e2661f;color:#fff;padding:10px 20px;border-radius:99px;text-decoration:none">افتح الطلب في لوحة التحكم</a></p>
</div>$html$,
    o.number, _html(o.customer_name), o.phone, o.phone,
    case when o.fulfillment = 'delivery' then 'توصيل إلى: ' || _html(o.address) else 'استلام من المحل' end,
    v_lines, trim_scale(o.delivery_fee), trim_scale(o.total),
    case when o.notes is not null then '<p>ملاحظات: ' || _html(o.notes) || '</p>' else '' end,
    v_site);

  perform net.http_post(
    url     := 'https://api.resend.com/emails',
    headers := jsonb_build_object('Authorization', 'Bearer ' || v_key, 'Content-Type', 'application/json'),
    body    := jsonb_build_object(
                 'from',    'مخبز السنبله <onboarding@resend.dev>',
                 'to',      jsonb_build_array(v_to),
                 'subject', format('طلب جديد #%s — %s ج', o.number, trim_scale(o.total)),
                 'html',    v_body));
end $$;
revoke all on function public.notify_new_order(bigint) from public, anon, authenticated;
