'use strict';
/* CMD-032 — رندرکننده‌ی لایه‌ی عمومی با بلوک‌های غنی: بخش‌ها، جدول، نوار آمار،
 * پرسش‌های متداول و لینک‌های مرتبط؛ هم‌سبک طراحی SPA (آبی/فیروزه‌ای/نارنجی). */
const fs = require('fs');
const path = require('path');
const { pages, pageFor } = require('../lib/pages');

const TEMPLATE = path.join(__dirname, '..', 'dynamic', 'page.html');

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
  ).join('') + `</div>`;
}

module.exports = async (req, res) => {
  const pathname = new URL(req.url, 'http://localhost').pathname.replace(/\/$/, '') || '/';
  const page = pageFor(pathname);
  if (!page) { res.statusCode = 404; res.setHeader('Content-Type', 'text/html; charset=utf-8'); return res.end('<!doctype html><html lang="fa" dir="rtl"><meta charset="utf-8"><title>صفحه پیدا نشد</title><body style="font-family: sans-serif;padding:4rem"><h1>صفحه پیدا نشد</h1><a href="/">بازگشت به صفحه اصلی</a></body></html>'); }
  const body = (pathname === '/sitemap' ? sitemapGrid() : page.s.map(sectionHTML).join(''))
    + (page.tbl ? tableHTML(page.tbl) : '')
    + (page.f ? factsHTML(page.f) : '')
    + (page.q ? faqHTML(page.q) : '')
    + (page.more ? moreHTML(page.more) : '');
  const html = fs.readFileSync(TEMPLATE, 'utf8')
    .replaceAll('%%TITLE%%', page.t)
    .replace('%%LEAD%%', esc(page.l))
    .replace('%%SECTIONS%%', body)
    .replace('%%PATH%%', pathname);
  res.statusCode = 200; res.setHeader('Content-Type', 'text/html; charset=utf-8'); res.setHeader('Cache-Control', 'no-store'); res.end(html);
};
module.exports.config = { maxDuration: 10 };
