-- =====================================================================
-- CMD-010 — DDL جدول settings (افزوده‌ی ثبت‌شده — نه پورت مرجع)
-- وضعیت: در انتظار اعمال توسط مدیر (دسترسی CREATE اسکیمای public فقط نزد مدیر است؛
--         role کم‌دسترسی dadgar_app عمداً مجوز DDL ندارد — طبق CMD-002/ACT-006)
-- نحوه‌ی اعمال: اجرای همین فایل در Supabase SQL Editor (پروژه dadgar)
-- پس از اعمال: بدون هیچ تغییر کد یا دیپلوی، مسیرهای /api/settings و
--              /api/settings/public و UIهای aSet/aCms به‌صورت خودکار فعال می‌شوند
--              (کد از قبل با 42P01 degrade می‌شود).
-- =====================================================================

CREATE TABLE IF NOT EXISTS settings(
  key TEXT PRIMARY KEY,
  value TEXT,
  updated_at BIGINT NOT NULL,
  updated_by BIGINT REFERENCES users(id)
);

-- دسترسی کامل به نقش اپلیکیشن (هم‌سو با بقیه‌ی جداول):
GRANT SELECT, INSERT, UPDATE, DELETE ON settings TO dadgar_app;
