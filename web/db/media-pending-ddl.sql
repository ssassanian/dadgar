-- =====================================================================
-- CMD-054 — DDL جدول media (تصاویر سایت — افزوده‌ی ثبت‌شده، الگوی CMD-010)
-- وضعیت: ⏳ در انتظار اعمال (پس از اعمال زنده، این سرنویس به «✅ اعمال شد» به‌روز می‌شود)
-- روش اعمال: DATABASE_URL="postgresql://…" node scripts/apply-media-ddl.js
-- پس از اعمال: بدون هیچ تغییر کد یا دیپلوی، تب «تصاویر» در پنل مدیر (aCms) فعال
--              می‌شود — کد از قبل با 42P01 degrade می‌شود (فهرست ready:false، نوشتن 503 صادقانه).
-- جای تصاویر: ali/sara/mahdi (سه وکلای موسسه در صفحه‌ی اصلی) و office (محیط موسسه).
-- =====================================================================

CREATE TABLE IF NOT EXISTS media(
  name TEXT PRIMARY KEY,
  mime TEXT,
  size BIGINT,
  file TEXT,
  updated_at BIGINT NOT NULL,
  updated_by BIGINT REFERENCES users(id)
);

-- هم‌سویی با بقیه‌ی جداول اپ: RLS خاموش (مدل امنیتی در لایه‌ی API است — CSRF/نرخ/نقش).
-- (Supabase روی جدول جدید RLS را پیش‌فرض روشن می‌کند؛ بدون این خط، INSERT با 42501 شکست می‌خورد)
ALTER TABLE media DISABLE ROW LEVEL SECURITY;

-- دسترسی کامل به نقش اپلیکیشن (هم‌سو با بقیه‌ی جداول):
GRANT SELECT, INSERT, UPDATE, DELETE ON media TO dadgar_app;
