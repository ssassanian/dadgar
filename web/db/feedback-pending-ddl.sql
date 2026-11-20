-- =====================================================================
-- دادگر — DDL جدول feedback_messages (CMD-064 — انتقادات و پیشنهادات)
-- فرم عمومی /criticism-and-suggestions → POST /api/feedback
-- تلفن با AES-256-GCM (sec.encText، aad=feedback.phone) ذخیره می‌شود.
-- وضعیت: ✅ اعمال شد — 2026-11-20 با Supabase Management API (ACT-123 / رجیستر 2.71)
-- الگوی اجرا: cmd061-apply-ddl.py / apply-feedback-ddl.py با خواندن SUPABASE_TOKEN از .secrets
-- وارسی پس از اعمال: ۱۰ ستون، RLS خاموش، GRANT به dadgar_app، count=0،
-- چرخه‌ی کامل POST /api/feedback روی تولید → ردیف با phone_enc (AES-256-GCM) → پاکسازی تست
-- =====================================================================

CREATE TABLE IF NOT EXISTS feedback_messages(
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name TEXT NOT NULL,                -- نام (و نام خانوادگی در صورت پر شدن)
  family TEXT,                       -- نام خانوادگی (اختیاری)
  email TEXT,                        -- ایمیل (اختیاری)
  phone_enc TEXT NOT NULL,           -- موبایل رمزنگاری‌شده
  phone_last4 TEXT,                  -- چهار رقم آخر برای نمایش/جستجو
  message TEXT NOT NULL,             -- متن انتقاد یا پیشنهاد (۱۰ تا ۲۰۰۰ نویسه)
  status TEXT NOT NULL DEFAULT 'new' CHECK(status IN('new','read','archived')),
  created_at BIGINT NOT NULL,
  ip TEXT);
CREATE INDEX IF NOT EXISTS ix_feedback_created ON feedback_messages(created_at DESC);
ALTER TABLE feedback_messages DISABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON feedback_messages TO dadgar_app;
