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
  const customCopy = pathname === '/about'
    ? [
        'دادگر با هدف ساده‌کردن مسیر دریافت خدمات حقوقی و نزدیک‌کردن تخصص به زندگی روزمره شکل گرفته است.',
        'شفافیت، محرمانگی و مسئولیت‌پذیری، پایه تصمیم‌ها و تجربه‌ای است که برای هر موکل طراحی می‌کنیم.',
        'تیم ما از وکلا و مشاورانی تشکیل شده که تجربه عملی را با ارتباط روشن و پیگیری منظم همراه می‌کنند.'
      ]
    : null;
  const sectionCopy = sections.map((section, index) => {
    const endings = ['را با اطلاعات روشن و قابل اتکا شروع کنید.', 'را متناسب با شرایط و هدف خود بررسی می‌کنیم.', 'را با پاسخ‌گویی شفاف و همراهی تخصصی پیش می‌بریم.'];
    return customCopy?.[index] || `${section} ${endings[index % endings.length]}`;
  });
  const html = fs.readFileSync(TEMPLATE, 'utf8')
    .replaceAll('%%TITLE%%', title)
    .replace('%%LEAD%%', lead)
    .replace('%%SECTIONS%%', sections.map((x, i) => `<article><span>۰${i + 1}</span><h2>${x}</h2><p>${sectionCopy[i]}</p><a class="card-link" href="/contact">دریافت راهنمایی</a></article>`).join('') + (pathname === '/sitemap' ? Object.entries(require('../lib/pages').pages).filter(([route]) => route !== '/sitemap').map(([route, data], i) => `<article><span>${String(i + 1).padStart(2, '۰')}</span><h2>${data[0]}</h2><p>${data[1]}</p><a class="card-link" href="${route}">نمایش صفحه</a></article>`).join('') : ''))
    .replace('%%CTA%%', '<a class="btn" href="/contact">ثبت درخواست مشاوره</a>')
    .replace('%%PATH%%', pathname);
  res.statusCode = 200; res.setHeader('Content-Type', 'text/html; charset=utf-8'); res.setHeader('Cache-Control', 'no-store'); res.end(html);
};
module.exports.config = { maxDuration: 10 };
