'use strict';
/* CMD-032 — رندرکننده‌ی لایه‌ی عمومی با بلوک‌های غنی: بخش‌ها، جدول، نوار آمار،
 * پرسش‌های متداول و لینک‌های مرتبط؛ هم‌سبک طراحی SPA (آبی/فیروزه‌ای/نارنجی).
 * CMD-057 — حل‌گر مهاجرت dadgar.legal (lib/migrate.js) اولویت دارد؛ در نبودِ
 * مسیر مهاجرت، صفحات ساختاری خودمان (pages.js) رندر می‌شوند — صفر لینک شکسته. */
const fs = require('fs');
const path = require('path');
const { pages, pageFor } = require('../lib/pages');
const mig = require('../lib/migrate');

const TEMPLATE = path.join(__dirname, '..', 'dynamic', 'page.html');
const IMG_PUB = path.join(__dirname, '..', 'dynamic');
const IMG_MIME = { '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png', '.webp': 'image/webp', '.svg': 'image/svg+xml' };

/* CMD-057 — سرو عکس‌های واقعی مهاجرت از dynamic/img (همان الگوی امن serveStatic:
 * بدون تراورسال، فقط پسوند مجاز، کش یک‌ساعته) — در production همه‌ی مسیرهای
 * غیر API به همین تابع ریرایت می‌شوند، پس /img/* اینجا سرو می‌شود. */
function serveImg(req, res, pathname) {
  let rel; try { rel = decodeURIComponent(pathname); } catch { res.writeHead(400); return res.end(); }
  if (rel.includes('\0') || rel.includes('\\') || rel.split('/').some((s) => s === '..' || (s.startsWith('.') && s.length > 0))) { res.writeHead(404); return res.end('Not found'); }
  const file = path.join(IMG_PUB, rel);
  const ext = path.extname(file).toLowerCase();
  if (!IMG_MIME[ext] || !file.startsWith(IMG_PUB + path.sep)) { res.writeHead(404); return res.end('Not found'); }
  let st; try { st = fs.statSync(file); } catch { res.writeHead(404); return res.end('Not found'); }
  if (!st.isFile()) { res.writeHead(404); return res.end('Not found'); }
  res.writeHead(200, { 'Content-Type': IMG_MIME[ext], 'Content-Length': st.size, 'Cache-Control': 'public, max-age=3600', 'X-Content-Type-Options': 'nosniff' });
  if (req.method === 'HEAD') return res.end();
  fs.createReadStream(file).pipe(res);
}

const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

const sectionHTML = (s, i) => `<article><span>${faNum(i + 1)}</span><h2>${esc(s[0])}</h2><p>${esc(s[1])}</p></article>`;

const tableHTML = t => `<div class="tblwrap"><table><thead><tr>${t.head.map(h => `<th>${esc(h)}</th>`).join('')}</tr></thead><tbody>${t.rows.map(r => `<tr>${r.map(c => `<td>${esc(c)}</td>`).join('')}</tr>`).join('')}</tbody></table></div>`;

const factsHTML = f => `<div class="facts">${f.map(x => `<div class="fact"><b>${esc(x[0])}</b><span>${esc(x[1])}</span></div>`).join('')}</div>`;

const faqHTML = q => `<section class="faq"><h2 class="faq-h">پرسش‌های متداول</h2>${q.map(x => `<details class="qa"><summary>${esc(x[0])}</summary><p>${esc(x[1])}</p></details>`).join('')}</section>`;

const moreHTML = m => `<section class="more"><h2 class="faq-h">لینک‌های مرتبط</h2><div class="more-grid">${m.map(x => `<a class="more-link" href="${esc(x[1])}">${esc(x[0])}<span class="ar">←</span></a>`).join('')}</div></section>`;

function faNum(n) { return String(n).replace(/\d/g, d => '۰۱۲۳۴۵۶۷۸۹'[d]); }

function sitemapGrid() {
  const skip = new Set(['/sitemap']);
  const entries = Object.entries(pages).filter(([r]) => !skip.has(r));
  return `<div class="grid">` + entries.map(([route, p], i) =>
    `<article><span>${faNum(i + 1)}</span><h2>${esc(p.t)}</h2><p>${esc(p.l)}</p><a class="card-link" href="${esc(route)}">نمایش صفحه<span class="ar">←</span></a></article>`
  ).join('') + `</div>` + migSitemap();
}

/* CMD-057 — بخش نقشه‌ی صفحات مهاجرت‌شده */
function migSitemap() {
  const D = require('../lib/dadgar-data');
  const groups = [
    ['وکلا (' + D.lawyers.length + ' پروفایل)', D.lawyers.slice(0, 8).map(x => [`/lawyers/${x.slug}`, x.name])],
    ['خدمات (' + D.services.length + ' خدمت)', D.services.map(x => [`/services/${x.slug}`, x.title])],
    ['دپارتمان‌ها (' + D.departments.length + ' دپارتمان)', D.departments.map(x => [`/departments/${x.slug}`, x.title])],
    ['دادنامه‌ها (' + D.portfolio.length + ' پرونده)', D.portfolio.slice(0, 8).map(x => [`/portfolio/${x.slug}`, x.title])],
    ['مقالات (' + D.posts.length + ' مقاله)', D.posts.slice(0, 8).map(x => [`/blog/${x.slug}`, x.title])],
  ];
  const staticLinks = [['/lawyers', 'وکلا'], ['/services', 'خدمات ما'], ['/departments', 'دپارتمان‌ها'], ['/blog', 'بلاگ و مقالات'],
    ['/portfolio', 'دادنامه‌ها و پرونده‌های موفق'], ['/faq', 'سوالات متداول'], ['/testimonials', 'نظرات موکلین'],
    ['/team', 'تیم دادگر'], ['/offices', 'نمایندگان استانی'], ['/about-us', 'درباره ما'], ['/about-us/history', 'داستان دادگر'],
    ['/about-us/why-dadgar', 'چرا دادگر؟'], ['/about-us/core-values', 'خط مشی دادگر'], ['/about-us/code-of-ethics', 'منشور اخلاقی دادگر'],
    ['/about-us/basic-principles', 'اصول اساسی وکالت'], ['/about-us/team', 'تیم دادگر — اعضای اجرایی'],
    ['/supreme-council', 'شورای عالی دادگر'], ['/careers', 'فرصت‌های شغلی'], ['/request', 'درخواست خدمات حقوقی'],
    ['/contact-us', 'تماس با ما'], ['/privacy-policy', 'حریم خصوصی'], ['/terms-of-use', 'قوانین و مقررات'],
    ['/criticism-and-suggestions', 'انتقادات و پیشنهادات'], ['/authors', 'نویسندگان دادگر']];
  return `<section class="more"><h2 class="faq-h">صفحات مهاجرت‌شده از dadgar.legal</h2>`
    + `<div class="tblwrap"><table><thead><tr><th>بخش</th><th>دسترسی سریع</th></tr></thead><tbody>`
    + groups.map(([g, rows]) => `<tr><td>${esc(g)}</td><td>${rows.map(([h, t]) => `<a class="card-link" href="${esc(h)}">${esc(t)}</a>`).join(' · ')} …</td></tr>`).join('')
    + `<tr><td>صفحات ایستا</td><td>${staticLinks.map(([h, t]) => `<a class="card-link" href="${esc(h)}">${esc(t)}</a>`).join(' · ')}</td></tr>`
    + `</tbody></table></div></section>`;
}

module.exports = async (req, res) => {
  const pathname = new URL(req.url, 'http://localhost').pathname.replace(/\/$/, '') || '/';
  if (/^\/img\//.test(pathname) || /^\/img$/.test(pathname)) return serveImg(req, res, pathname);
  const m = mig.resolve(pathname);          /* اولویت: داده‌ی واقعی مهاجرت‌شده */
  const page = m || pageFor(pathname);
  if (!page) { res.statusCode = 404; res.setHeader('Content-Type', 'text/html; charset=utf-8'); return res.end('<!doctype html><html lang="fa" dir="rtl"><meta charset="utf-8"><title>صفحه پیدا نشد</title><body style="font-family: sans-serif;padding:4rem"><h1>صفحه پیدا نشد</h1><a href="/">بازگشت به صفحه اصلی</a></body></html>'); }
  const body = m ? m.body
    : (pathname === '/sitemap' ? sitemapGrid() : page.s.map(sectionHTML).join(''))
      + (page.tbl ? tableHTML(page.tbl) : '')
      + (page.f ? factsHTML(page.f) : '')
      + (page.q ? faqHTML(page.q) : '')
      + (page.more ? moreHTML(page.more) : '');
  const html = fs.readFileSync(TEMPLATE, 'utf8')
    .replaceAll('%%TITLE%%', page.t)
    .replace('%%LEAD%%', esc(page.l || ''))
    .replace('%%SECTIONS%%', body)
    .replace('%%PATH%%', pathname);
  res.statusCode = 200; res.setHeader('Content-Type', 'text/html; charset=utf-8'); res.setHeader('Cache-Control', 'no-store'); res.end(html);
};
module.exports.config = { maxDuration: 10 };
