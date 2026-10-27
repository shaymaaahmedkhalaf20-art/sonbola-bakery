- مخبز السنبله. المعلومات في مخبز السنبله.docx، وما تخترعش غيرها.
- كل push على main بيتنشر على Cloudflare Pages لوحده. الموقع هو فولدر `site/` بس (الموقع العام `site/index.html`، ولوحة التحكم `site/admin/`)، واللينك https://sonbola-bakery-2hb.pages.dev
- مفيش سيرفر: الصفحات بتكلّم Supabase على طول، وكل القواعد والأسعار جوه قاعدة البيانات (`docs/adr/0001`). أي تعديل في قاعدة البيانات يبقى ملف جديد مترقّم في `sql/`، بيتشغّل بالإيد في SQL Editor.
- الفورم بيحفظ في جدول messages، والطلبات بتتعمل بس من دالة `place_order`.
- بعد أي تعديل: ابعت رسالة من الفورم على لينك pages.dev، واتأكد إنها وصلت الجدول.

## Agent skills

### Issue tracker

Issues live in GitHub Issues for `shaymaaahmedkhalaf20-art/sonbola-bakery` (via `gh`). See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `GLOSSARY.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.
