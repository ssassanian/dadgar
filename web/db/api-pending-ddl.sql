-- =====================================================================
-- CMD-026 — DDL افزوده‌ی اول D-6 (توکن موبایل — DOC-04 §۵-۲)
-- وضعیت: ✅ اعمال شد — 2026-10-30 با Supabase Management API (CMD-026 / REL-011)
-- نکته: جدول sessions از قبل موجود است و RLS آن خاموش است (relrowsecurity=false)،
--       پس برخلاف جدول جدید CMD-010 نیازی به خط DISABLE ROW LEVEL SECURITY نیست.
-- تغییر: افزودن ستون kind به sessions — افزایشی و سازگار با عقب:
--       ردیف‌های موجود خودکار 'web' می‌شوند؛ کد قدیمی بدون kind هم کار می‌کند
--       (INSERT بدون ذکر ستون → DEFAULT). پس از اعمال، مسیرهای /api/auth/token،
--       /api/auth/token/refresh و /api/auth/token/revoke و پذیرش Bearer بدون
--       هیچ تغییر کد یا دیپلوی اضافی فعال می‌شوند (کد از 42703 degrade می‌شد).
-- برگشت (در صورت نیاز): ALTER TABLE sessions DROP COLUMN kind;
-- =====================================================================

ALTER TABLE public.sessions ADD COLUMN IF NOT EXISTS kind TEXT NOT NULL DEFAULT 'web';

-- =====================================================================
-- CMD-029 — DDL درگاه پرداخت آنلاین (زیبال — انتخاب مدیر)
-- وضعیت: ✅ اعمال شد — 2026-10-31 با Supabase Management API (REL-011)
-- نکته: جدول جدید است؛ مطابق پیش‌نمونه‌ی CMD-010 خط DISABLE ROW LEVEL
--       SECURITY لازم است (سرور با role سرویس و مستقیم وصل می‌شود).
-- تغییر: CREATE TABLE payment_requests — افزایشی و سازگار با عقب؛
--       جدول بسته‌ی CMD-028 را تغییر نمی‌دهد؛ بدون آن کد payments
--       در نقطه‌ی INSERT خطای 42P01 می‌دهد (جدول نبود) — پس DDL پیش از دیپلوی.
-- برگشت (در صورت نیاز): DROP TABLE IF EXISTS public.payment_requests;
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.payment_requests(
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  invoice_id BIGINT NOT NULL REFERENCES public.invoices(id) ON DELETE CASCADE,
  client_id BIGINT NOT NULL REFERENCES public.users(id),
  gateway TEXT NOT NULL,
  track_id BIGINT NOT NULL UNIQUE,
  amount_rial BIGINT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  ref_number TEXT, card_number TEXT,
  created_at BIGINT NOT NULL, paid_at BIGINT);
ALTER TABLE public.payment_requests DISABLE ROW LEVEL SECURITY;
