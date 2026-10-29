'use strict';
/* پیش‌نمایش اپ موبایل — مسیر /mobile-preview (CMD-020).
   محتوای ثابت از dynamic/mobile-preview.html خوانده می‌شود (includeFiles)؛
   صفر تغییر در منطق موجود — فقط یک مسیر افزوده‌ی نمایشی. */
const fs = require('fs');
const path = require('path');

const FILE = path.join(__dirname, '..', 'dynamic', 'mobile-preview.html');
let cached = null;

module.exports = async (req, res) => {
  if (!cached) cached = fs.readFileSync(FILE);
  res.statusCode = 200;
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.setHeader('Cache-Control', 'public, max-age=300');
  res.setHeader('X-Robots-Tag', 'noindex');
  res.end(cached);
};

module.exports.config = { maxDuration: 10 };
