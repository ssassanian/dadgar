-- =====================================================================
-- CMD-010 — DDL جدول settings (افزوده‌ی ثبت‌شده — نه پورت مرجع)
-- وضعیت: ✅ اعمال شد — 2026-10-29 با Supabase Management API (CMD-011 / REL-010)
-- نکته‌ی اعمال: Supabase روی جدول جدید RLS را پیش‌فرض روشن می‌کند؛ خط ALTER در
--         پایین همین فایل لازم است (بدون آن INSERT با 42501 شکست می‌خورد).
-- پس از اعمال: بدون هیچ تغییر کد یا دیپلوی، مسیرهای /api/settings و
--              /api/settings/public و UIهای aSet/aCms به‌صورت خودکار فعال می‌شوند
--              (کد از قبل با 42P01 degrade می‌شود). — تایید شد: ready:true بدون دیپلوی
-- =====================================================================

CREATE TABLE IF NOT EXISTS settings(
  key TEXT PRIMARY KEY,
  value TEXT,
  updated_at BIGINT NOT NULL,
  updated_by BIGINT REFERENCES users(id)
);

-- هم‌سویی با بقیه‌ی جداول اپ: RLS خاموش (مدل امنیتی در لایه‌ی API است — CSRF/نرخ/نقش).
-- (Supabase روی جدول جدید RLS را پیش‌فرض روشن می‌کند؛ بدون این خط، INSERT با 42501 شکست می‌خورد)
ALTER TABLE settings DISABLE ROW LEVEL SECURITY;

-- دسترسی کامل به نقش اپلیکیشن (هم‌سو با بقیه‌ی جداول):
GRANT SELECT, INSERT, UPDATE, DELETE ON settings TO dadgar_app;
