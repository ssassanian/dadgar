'use strict';
const fs = require('fs');
const path = require('path');
const { pageFor } = require('../lib/pages');

const TEMPLATE = path.join(__dirname, '..', 'dynamic', 'page.html');
module.exports = async (req, res) => {
  const pathname = new URL(req.url, 'http://localhost').pathname.replace(/\/$/, '') || '/';
  const page = pageFor(pathname);
  if (!page) { res.statusCode = 404; res.setHeader('Content-Type', 'text/html; charset=utf-8'); return res.end('<!doctype html><html lang="fa" dir="rtl"><meta charset="utf-8"><title>صفحه پیدا نشد</title><body style="font-family: sans-serif;padding:4rem"><h1>صفحه پیدا نشد</h1><a href="/">بازگشت به صفحه اصلی</a></body></html>'); }
  const [title, lead, ...sections] = page;
  const sectionCopy = ['تصمیم‌گیری را با اطلاعات روشن و قابل اتکا شروع کنید.', 'جزئیات این مسیر را متناسب با شرایط و هدف شما بررسی می‌کنیم.', 'در هر مرحله، پاسخ‌گویی شفاف و همراهی تخصصی کنار شماست.'];
  const html = fs.readFileSync(TEMPLATE, 'utf8')
    .replaceAll('%%TITLE%%', title)
    .replace('%%LEAD%%', lead)
    .replace('%%SECTIONS%%', sections.map((x, i) => `<article><span>۰${i + 1}</span><h2>${x}</h2><p>${sectionCopy[i % sectionCopy.length]}</p><a class="card-link" href="/contact">دریافت راهنمایی</a></article>`).join(''))
    .replace('%%CTA%%', '<a class="btn" href="/contact">ثبت درخواست مشاوره</a>')
    .replace('%%PATH%%', pathname);
  res.statusCode = 200; res.setHeader('Content-Type', 'text/html; charset=utf-8'); res.setHeader('Cache-Control', 'no-store'); res.end(html);
};
module.exports.config = { maxDuration: 10 };
