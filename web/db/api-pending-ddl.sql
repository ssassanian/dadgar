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
