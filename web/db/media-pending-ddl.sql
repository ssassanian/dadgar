-- =====================================================================
-- CMD-054 — DDL جدول media (تصاویر سایت — افزوده‌ی ثبت‌شده، الگوی CMD-010)
-- وضعیت: ✅ اعمال شد (2026-11-18 — از طریق Supabase Management API /database/query؛
--        نقش dadgar_app روی pooler سازگاری CREATE در schema public ندارد — همان الگوی CMD-029)
-- راستی‌آزمایی پس از اعمال: ستون‌ها name/mime/size/file/updated_at/updated_by + چرخه‌ی کامل test-media.sh سبز (PASS-degrade پیش از اعمال، PASS-full پس از اعمال)
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
