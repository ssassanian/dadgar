-- =====================================================================
-- دادگر — DDL جدول booking_requests (CMD-061 — درخواست نوبت از تقویم راهبران)
-- فرم عمومی «ثبت نوبت» در صفحات پروفایل /team/<slug> → POST /api/booking
-- تلفن با AES-256-GCM (sec.encText، aad=booking.phone) ذخیره می‌شود.
-- وضعیت: ✅ اعمال شد (2026-11-19) از طریق Supabase Management API /database/query —
-- نکته اجرا (الگوی CMD-054): نقش dadgar_app روی pooler مجوز CREATE در schema
-- public ندارد؛ DDL مستقیماً با Management API اعمال شد و ستون‌ها وارسی شد.
-- =====================================================================

CREATE TABLE IF NOT EXISTS booking_requests(
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  slug TEXT NOT NULL,                -- اسلاگ راهبر از لیست سفید dadgar-data.team
  name TEXT NOT NULL,                -- نام متقاضی
  phone_enc TEXT NOT NULL,           -- موبایل رمزنگاری‌شده
  phone_last4 TEXT,                  -- چهار رقم آخر برای نمایش/جستجو
  day_label TEXT NOT NULL,           -- برچسب روز انتخابی از تقویم (مثل «شنبه ۲۹ آبان»)
  note TEXT,                         -- توضیح اختیاری
  status TEXT NOT NULL DEFAULT 'new' CHECK(status IN('new','contacted','scheduled','done','canceled')),
  created_at BIGINT NOT NULL,
  ip TEXT);
CREATE INDEX IF NOT EXISTS ix_booking_created ON booking_requests(created_at DESC);
ALTER TABLE booking_requests DISABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON booking_requests TO dadgar_app;
