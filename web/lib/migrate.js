'use strict';
/* CMD-057 — رندرکننده صفحات مهاجرت‌شده‌ی dadgar.legal
 * داده از lib/dadgar-data.js (تولید خودکار؛ فهرست سفید تگ‌ها در مولد اعمال شده)
 * مسیرها عین ساختار سایت مبدأ: /lawyers /services /departments /blog /portfolio /about-us ...
 * هر resolve شکل {t:عنوان, l:لید, body:HTML امن, crumbs:[[نام,مسیر]]} می‌دهد؛ اگر null باشد caller به pages.js برمی‌گردد. */

const D = require('./dadgar-data');

const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

function faNum(n) { return String(n).replace(/\d/g, (d) => '۰۱۲۳۴۵۶۷۸۹'[d]); }
function faDate(d) {
  if (!d) return '';
  return d.replace(/-/g, '/');
}

/* ---------- بلوک‌های ساختاری (سرویس/دپارتمان/راهبر/ظرف) ---------- */
function blocksHTML(bs, { skipH1 = true } = {}) {
  const out = [];
  for (const b of bs || []) {
    const t = b.t;
    if (t === 'h1') { if (!skipH1) out.push(`<h2>${esc(b.x)}</h2>`); continue; }
    if (t === 'h2') out.push(`<h2>${esc(b.x)}</h2>`);
    else if (t === 'h3') out.push(`<h3>${esc(b.x)}</h3>`);
    else if (t === 'h4') out.push(`<h4>${esc(b.x)}</h4>`);
    else if (t === 'p') out.push(`<p>${esc(b.x)}</p>`);
    else if (t === 'ul' || t === 'ol') {
      const items = b.x.filter((li) => li !== 'خانه');
      if (!items.length) continue;
      out.push(`<${t}>${items.map((li) => `<li>${esc(li)}</li>`).join('')}</${t}>`);
    }
    else if (t === 'blockquote') out.push(`<blockquote>${esc(b.x)}</blockquote>`);
  }
  return out.join('');
}

/* ---------- کارت‌ها ---------- */
function card(route, { title, excerpt, photo, badge }, i) {
  const pic = photo ? `<figure class="cimg"><img src="${esc(photo)}" alt="${esc(title)}" loading="lazy" width="360" height="240"></figure>` : '';
  const bd = badge ? `<em class="badge">${esc(badge)}</em>` : '';
  return `<article class="mcard">${pic}<div class="cbody">${bd}<h2>${esc(title)}</h2><p>${esc(excerpt || '')}</p><a class="card-link" href="${esc(route)}">مشاهده<span class="ar">←</span></a></div></article>`;
}
function cardGrid(cards) { return `<div class="cgrid">${cards.join('')}</div>`; }

function countBar(n, label) {
  return `<div class="facts" style="grid-template-columns:repeat(1,1fr)"><div class="fact"><b>${faNum(n)}</b><span>${esc(label)}</span></div></div>`;
}

/* ---------- سربرگ جزئیات ---------- */
function detailHead({ photo, badge, meta }) {
  const pic = photo ? `<figure class="dimg"><img src="${esc(photo)}" alt="" loading="lazy"></figure>` : '';
  const m = meta ? `<ul class="lfgrid">${meta.map(([k, v]) => v ? `<li><span>${esc(k)}</span><p>${esc(v)}</p></li>` : '').join('')}</ul>` : '';
  const b = badge ? `<em class="badge">${esc(badge)}</em>` : '';
  return `<div class="dhead">${pic}<div class="dbody">${b}${m}</div></div>`;
}

/* ---------- پرسش‌های متداول ---------- */
function faqHTML(items) { return `<section class="faq"><h2 class="faq-h">پرسش‌های متداول</h2>${items.map((x) => `<details class="qa"><summary>${esc(x.q)}</summary><p>${x.a}</p></details>`).join('')}</section>`; }

/* ---------- لینک‌های مرتبط ---------- */
function moreHTML(pairs) {
  return `<section class="more"><h2 class="faq-h">لینک‌های مرتبط</h2><div class="more-grid">${pairs.map(([t, h]) => `<a class="more-link" href="${esc(h)}">${esc(t)}<span class="ar">←</span></a>`).join('')}</div></section>`;
}

/* ---------- بدنه‌ی HTML ایستا (پاک‌سازی‌شده در مولد) ---------- */
function staticBody(slug) {
  const p = D.static_pages[slug];
  if (!p) return null;
  return `<div class="rich">${p.body}</div>`;
}

/* ---------- صفحات فهرست ---------- */
function lawyersIndex() {
  const cards = D.lawyers.map((x) => card(`/lawyers/${x.slug}`, { title: x.name, excerpt: [x.rank, x.expertise].filter(Boolean).join(' · '), photo: x.photo }, 0));
  return {
    t: 'وکلا', l: 'وکلای متخصص موسسه حقوقی و داوری دادگر — با سابقه، تخصص و حوزه پروانه‌ی هر وکیل آشنا شوید.',
    body: countBar(D.lawyers.length, 'وکیل متخصص در دپارتمان‌های دادگر') + cardGrid(cards)
  };
}
function lawyerDetail(x) {
  const meta = [['عنوان پروانه', x.rank], ['دپارتمان', x.dept], ['تخصص', x.expertise], ['سوابق', x.exp], ['شماره پروانه', x.license], ['ایمیل', x.email], ['شماره تماس', x.phone]];
  const others = D.lawyers.filter((l) => l.slug !== x.slug && l.bio).slice(0, 6);
  return {
    t: x.name, l: x.rank || 'وکیل دادگستری',
    body: detailHead({ photo: x.photo, badge: x.rank, meta })
      + (x.bio ? `<div class="rich"><h2>بیوگرافی و معرفی کامل</h2>${x.bio}</div>` : '')
      + moreHTML([['فهرست همه وکلا', '/lawyers'], ['خدمات موسسه', '/services'], ['دپارتمان‌های تخصصی', '/departments']]
        .concat(others.length ? [['آشنایی با ' + others[0].name, `/lawyers/${others[0].slug}`]] : []))
  };
}
function servicesIndex() {
  const cards = D.services.map((x) => card(`/services/${x.slug}`, { title: x.title, excerpt: x.excerpt, photo: x.photo }, 0));
  return {
    t: 'خدمات ما', l: 'خدمات تخصصی حقوقی دادگر: از مشاوره و بیمه حقوقی تا وکالت تخصصی در دعاوی، داوری و تنظیم قرارداد.',
    body: countBar(D.services.length, 'خدمت تخصصی حقوقی') + cardGrid(cards)
  };
}
function blocksPage(x, back, extra) {
  return {
    t: x.title, l: x.excerpt || '',
    body: `<div class="rich">${blocksHTML(x.blocks)}</div>` + (extra || '') + moreHTML(back)
  };
}
function departmentsIndex() {
  const cards = D.departments.map((x) => card(`/departments/${x.slug}`, { title: x.title, excerpt: x.excerpt }, 0));
  return {
    t: 'دپارتمان‌ها', l: 'دپارتمان‌های تخصص‌محور دادگر: رسیدگی تخصصی به پرونده‌ها در حوزه‌های مختلف حقوقی.',
    body: countBar(D.departments.length, 'دپارتمان تخصصی') + cardGrid(cards)
  };
}
function postsIndex() {
  const cards = D.posts.map((x) => card(`/blog/${x.slug}`, { title: x.title, excerpt: x.excerpt, photo: x.photo, badge: faDate(x.date) }, 0));
  return {
    t: 'بلاگ و مقالات حقوقی', l: 'مقالات آموزشی و تحلیل‌های حقوقی کاربردی؛ از دعاوی ملکی تا قراردادها و خانواده.',
    body: countBar(D.posts.length, 'مقاله حقوقی منتشرشده') + cardGrid(cards)
  };
}
function postDetail(x) {
  return {
    t: x.title, l: x.excerpt,
    body: (x.photo ? `<figure class="dimg wide"><img src="${esc(x.photo)}" alt="${esc(x.title)}" loading="lazy"></figure>` : '')
      + `<div class="rich">${x.body}</div>`
      + moreHTML([['همه مقالات', '/blog'], ['خدمات موسسه', '/services'], ['دادنامه‌های موفق', '/portfolio']])
  };
}
function portfolioIndex() {
  const cards = D.portfolio.map((x) => card(`/portfolio/${x.slug}`, { title: x.title, excerpt: x.excerpt, photo: x.photo }, 0));
  return {
    t: 'دادنامه‌ها و پرونده‌های موفق', l: 'گزارش پرونده‌های واقعی دادگر: ماجراجویی حقوقی موکلان و مسیر رسیدن به نتیجه.',
    body: countBar(D.portfolio.length, 'پرونده گزارش‌شده') + cardGrid(cards)
  };
}
function faqPage() {
  return {
    t: 'سوالات متداول', l: 'پاسخ پرسش‌های پرتکرار شما درباره خدمات حقوقی دادگر، داوری و روند پرونده‌ها.',
    body: faqHTML(D.faqs) + moreHTML([['درخواست خدمات حقوقی', '/request'], ['تماس با ما', '/contact-us'], ['خدمات موسسه', '/services']])
  };
}
function testimonialsPage() {
  const cards = D.testimonials.map((x) => `<article class="mcard tstm"><div class="cbody"><h2>${esc(x.name)}</h2><div class="rich">${x.text}</div></div></article>`);
  return {
    t: 'نظرات موکلین', l: 'آنچه موکلان دادگر درباره تجربه همکاری با ما می‌گویند.',
    body: cardGrid(cards) + moreHTML([['دادنامه‌های موفق', '/portfolio'], ['وکلای موسسه', '/lawyers'], ['درخواست مشاوره', '/request']])
  };
}
function teamIndex() {
  const cards = D.team.map((x) => card(`/team/${x.slug}`, { title: x.name, excerpt: x.role, photo: x.photo }, 0));
  return {
    t: 'تیم دادگر', l: 'اعضای تیم اجرایی دادگر — چهره‌های کلیدی موسسه، پشت نامی قابل اتکا.',
    body: cardGrid(cards) + moreHTML([['وکلای موسسه', '/lawyers'], ['درباره ما', '/about-us'], ['فرصت‌های شغلی', '/careers']])
  };
}
/* ---------- CMD-061 — پروفایل کامل راهبران با تقویم حضور و درخواست نوبت ----------
 * ساختار صفحه عین سایت مبدأ: بیوگرافی و معرفی کامل + تحصیلات + مسیر حرفه‌ای + تخصص‌ها +
 * دوره‌ها/افتخارات + فرآیند همکاری + ماتریس ارزیابی مهارت‌ها + «تقویم حضور و زمان‌بندی»
 * (گرید شمسی با نشان تعطیل/تکمیل ظرفیت) + فرم و دکمه‌ی «ثبت نوبت» + سؤالات متداول + مقالات نویسنده.
 * داده‌ی تقویم از bio_blocks مهاجرت‌یافته می‌آید (حمیدی/تلخابی)؛ راهبرانی که در مبدأ تقویم ندارند
 * (لطفی/طاهری/سرلک — وفادار به مبدأ، ثبت 2.60) تقویم پیش‌فرض موسسه می‌گیرند تا فرم نوبت برای همه فعال باشد. */
const WD_FA = ['شنبه', 'یکشنبه', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه'];
const MONTHS_FA = ['فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور', 'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'];

function jalToday() {
  try {
    const p = {};
    new Intl.DateTimeFormat('en-US-u-ca-persian-nu-latn', { year: 'numeric', month: 'numeric', day: 'numeric', timeZone: 'Asia/Tehran' }).formatToParts(new Date()).forEach((x) => { p[x.type] = x.value; });
    const y = parseInt(p.year, 10), m = parseInt(p.month, 10), d = parseInt(p.day, 10);
    if (y > 1300 && y < 1500 && m >= 1 && m <= 12 && d >= 1 && d <= 31) return { y, m, d };
  } catch { }
  return { y: 1405, m: 8, d: 28 };
}
function jalLeap(y) { return [1, 5, 9, 13, 17, 22, 26, 30].indexOf(((y % 33) + 33) % 33) >= 0; }
function jalMonthLen(y, m) { return m <= 6 ? 31 : m <= 11 ? 30 : (jalLeap(y) ? 30 : 29); }
function wdIdxFa(gMs) {
  const s = new Intl.DateTimeFormat('en-US', { weekday: 'short', timeZone: 'Asia/Tehran' }).format(new Date(gMs));
  return ['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'].indexOf(s);
}

/* تقویم راهبر: از بلوک‌های مهاجرت‌یافته؛ در نبودش تقویم ماه جاری شمسی با جمعه‌های تعطیل */
function leaderCal(blocks) {
  const t = jalToday();
  let title = MONTHS_FA[t.m - 1] + ' ' + t.y, working = 'شنبه تا چهارشنبه', hours = 'از ساعت ۱۰ صبح الی ۱۸ عصر', raw = null;
  for (let i = 0; i < (blocks || []).length; i++) {
    const b = blocks[i];
    if (b.t !== 'h2' || !/تقویم حضور/.test(b.x)) continue;
    for (let j = i + 1; j < blocks.length && blocks[j].t !== 'h2'; j++) {
      const c = blocks[j];
      if (c.t === 'p' && /روزهای کاری/.test(c.x)) working = c.x.split(':').slice(1).join(':').trim() || working;
      else if (c.t === 'p' && /زمان/.test(c.x)) hours = c.x.split(':').slice(1).join(':').trim() || hours;
      else if (c.t === 'h3' && /\d{4}/.test(c.x.replace(/[۰-۹]/g, '0'))) title = c.x;
      else if (c.t === 'ul' && Array.isArray(c.x) && c.x.some((s) => /^\s*\d+\s*(تعطیل|تکمیل)?\s*$/.test(String(s).trim()) || /^\s*$/.test(String(s)))) raw = c.x;
    }
    break;
  }
  let cells;
  if (raw) {
    cells = raw.map((s) => {
      const m2 = String(s).trim().match(/^(\d+)\s*(.*)$/);
      if (!m2) return { empty: true };
      return { d: parseInt(m2[1], 10), mark: /تعطیل/.test(m2[2]) ? 'hol' : (/تکمیل/.test(m2[2]) ? 'full' : '') };
    });
  } else {
    const len = jalMonthLen(t.y, t.m), off = wdIdxFa(Date.now() - (t.d - 1) * 86400000);
    cells = [];
    for (let i2 = 0; i2 < off; i2++) cells.push({ empty: true });
    for (let n = 1; n <= len; n++) cells.push({ d: n, mark: cells.length % 7 === 6 ? 'hol' : '' });
  }
  return { title, working, hours, cells };
}

/* گزینه‌های روز نوبت: فقط روزهای آزاد (نه تعطیل، نه تکمیل ظرفیت، نه گذشته) */
function bkOptions(cal, t) {
  const mm = cal.title.trim().match(/^(\S+)\s+(\d{4})$/);
  const mi = mm ? MONTHS_FA.indexOf(mm[1]) : -1, yy = mm ? parseInt(mm[2], 10) : 0;
  const cur = mi >= 0 && yy === t.y && (mi + 1) === t.m;
  const mn = mi >= 0 ? mi : t.m - 1;
  const out = [];
  cal.cells.forEach((c, idx) => {
    if (c.empty || !c.d || c.mark) return;
    if (cur && c.d < t.d) return;
    out.push({ d: c.d, label: WD_FA[idx % 7] + ' ' + faNum(c.d) + ' ' + MONTHS_FA[mn] });
  });
  return out;
}

function bookingBox(slug, opts) {
  const optsHTML = opts.length ? opts.map((o) => '<option value="' + esc(o.label) + '">' + o.label + '</option>').join('') : '<option value="">—</option>';
  return '<div class="bkbox"><div class="bk-i"><h3>درخواست نوبت مشاوره</h3><p>از تقویم بالا یک روزِ آزاد انتخاب کنید و درخواست خود را ثبت کنید؛ دفتر موسسه برای هماهنگی ساعت، با شما تماس می‌گیرد.</p></div>'
    + '<button class="btn bk-open" type="button">ثبت نوبت<span class="ar">←</span></button>'
    + '<form class="bk-form" hidden data-slug="' + esc(slug) + '"><div class="bk-g">'
    + '<label>نام و نام‌خانوادگی<input name="bname" required maxlength="80" placeholder="مثلاً زهرا محمدی"></label>'
    + '<label>شماره‌ی موبایل<input name="bphone" inputmode="tel" required maxlength="14" dir="ltr" placeholder="0912…"></label>'
    + '<label>روز نوبت<select name="bday">' + optsHTML + '</select></label>'
    + '<label class="bk-w">توضیح کوتاه (اختیاری)<textarea name="bnote" rows="3" maxlength="500" placeholder="موضوع مشاوره"></textarea></label>'
    + '</div><div class="bk-a"><button class="btn" type="submit">ارسال درخواست نوبت</button><span class="bk-msg" hidden></span></div></form>'
    + '<p class="bk-alt">یا با تلفن موسسه تماس بگیرید: <a href="tel:+982191002026" dir="ltr">۰۲۱-۹۱۰۰۲۰۲۶</a></p></div>';
}

function calSection(cal, opts, slug, t) {
  const mm = cal.title.trim().match(/^(\S+)\s+(\d{4})$/);
  const mi = mm ? MONTHS_FA.indexOf(mm[1]) : -1, yy = mm ? parseInt(mm[2], 10) : 0;
  const cur = mi >= 0 && yy === t.y && (mi + 1) === t.m;
  const cells = cal.cells.map((c) => {
    if (c.empty) return '<i class="ce"></i>';
    const cls = ['cd2']; let tag = '';
    if (c.mark === 'hol') { cls.push('hol'); tag = '<small>تعطیل</small>'; }
    else if (c.mark === 'full') { cls.push('full'); tag = '<small>تکمیل ظرفیت</small>'; }
    else if (cur && c.d < t.d) cls.push('past');
    else if (cur && c.d === t.d) cls.push('tdy');
    return '<span class="' + cls.join(' ') + '"><b>' + faNum(c.d) + '</b>' + tag + '</span>';
  }).join('');
  return '<section class="calbk" id="calbk"><h2>تقویم حضور و زمان‌بندی</h2>'
    + '<div class="calmeta"><span><b>روزهای کاری</b>' + esc(faNum(cal.working)) + '</span><span><b>زمان‌بندی پاسخگویی</b>' + esc(faNum(cal.hours)) + '</span></div>'
    + '<div class="calgrid"><div class="cal-t"><b>' + esc(faNum(cal.title)) + '</b></div><div class="cal-wd">' + WD_FA.map((w) => '<span>' + w + '</span>').join('') + '</div><div class="cal-ds">' + cells + '</div></div>'
    + bookingBox(slug, opts) + '</section>';
}

function splitTitle(text, cands) {
  let best = -1;
  for (const c of cands) { const i = text.indexOf(c); if (i > 8 && (best < 0 || i < best)) best = i; }
  return best < 0 ? null : [text.slice(0, best).trim(), text.slice(best).trim()];
}
const SPEC_CANDS = [' انواع', ' ارائه ', ' رسیدگی ', ' تنظیم، بازنگری', ' مشاوره ', ' پیگیری '];
const PROC_CANDS = [' در نخستین مرحله', ' اطلاعات و مستندات', ' براساس نتایج', ' پس از تعیین', ' روند انجام', ' در پایان هر'];
const ulFlat = (bs) => bs.filter((b) => b.t === 'ul' || b.t === 'ol').flatMap((b) => b.x);

/* رندر هر سکشن h2 صفحه‌ی راهبر (تقویم جدا رندر می‌شود) */
function teamSection(key, blob, postsByTitle) {
  const h2 = '<h2>' + esc(key) + '</h2>';
  if (/تحصیلات/.test(key)) return '<section class="rich">' + h2 + '<ul class="edug">' + ulFlat(blob).map((i) => '<li>' + esc(i) + '</li>').join('') + '</ul></section>';
  if (/مسیر حرفه|سوابق شغلی/.test(key)) {
    let html = '', open = false;
    for (const it of ulFlat(blob)) {
      if (/^\s*(13|14)\d\d\s*-/.test(it)) { if (open) html += '</ul></div>'; html += '<div class="job"><h4>' + esc(it) + '</h4><ul>'; open = true; }
      else if (open) html += '<li>' + esc(it) + '</li>';
      else html += '<p>' + esc(it) + '</p>';
    }
    if (open) html += '</ul></div>';
    return '<section class="rich">' + h2 + html + '</section>';
  }
  if (/تخصص/.test(key)) {
    const cards = ulFlat(blob).map((it) => {
      const sp = splitTitle(it, SPEC_CANDS);
      return sp ? '<div class="spcard"><b>' + esc(sp[0]) + '</b><p>' + esc(sp[1]) + '</p></div>' : '<div class="spcard"><p>' + esc(it) + '</p></div>';
    }).join('');
    return '<section class="rich">' + h2 + '<div class="spgrid">' + cards + '</div></section>';
  }
  if (/دوره|گواهینامه|افتخارات|عضویت/.test(key)) return '<section class="rich">' + h2 + '<ul class="cseg">' + ulFlat(blob).map((i) => '<li>' + esc(i) + '</li>').join('') + '</ul></section>';
  if (/فرآیند همکاری/.test(key)) {
    const steps = ulFlat(blob).map((it, n) => {
      const txt = String(it).replace(/^\s*\d+\s+/, '');
      const sp = splitTitle(txt, PROC_CANDS);
      return '<div class="pstep"><i>' + faNum(n + 1) + '</i><div>' + (sp ? '<b>' + esc(sp[0]) + '</b><p>' + esc(sp[1]) + '</p>' : '<p>' + esc(txt) + '</p>') + '</div></div>';
    }).join('');
    return '<section class="rich">' + h2 + steps + '</section>';
  }
  if (/ماتریس/.test(key)) {
    const uls = blob.filter((b) => b.t === 'ul').map((b) => b.x);
    const chips = (uls[0] || []).map((c) => '<em>' + esc(c) + '</em>').join('');
    const bars = (uls[1] || []).map((b2) => {
      const m2 = String(b2).match(/^\s*(\d+)\s*%\s*(.+)$/);
      if (!m2) return '';
      const p = Math.min(100, parseInt(m2[1], 10));
      return '<div class="skrow"><span class="sr1"><span>' + esc(m2[2]) + '</span><em>' + faNum(m2[1]) + '٪</em></span><span class="trk"><i style="width:' + p + '%"></i></span></div>';
    }).join('');
    return '<section class="rich">' + h2 + (chips ? '<div class="skchips">' + chips + '</div>' : '') + (bars ? '<div class="skbars">' + bars + '</div>' : '') + '</section>';
  }
  if (/سؤالات متداول|سوالات متداول/.test(key)) {
    const qa = ulFlat(blob).map((i) => { const j = String(i).indexOf('؟'); if (j < 0) return null; const q = String(i).slice(0, j + 1); const a = String(i).slice(j + 1).trim(); return a ? { q, a } : null; }).filter(Boolean);
    return '<section class="faq"><h2 class="faq-h">' + esc(key) + '</h2>' + qa.map((v) => '<details class="qa"><summary>' + esc(v.q) + '</summary><p>' + esc(v.a) + '</p></details>').join('') + '</section>';
  }
  if (/مقالات/.test(key)) {
    const cards = [];
    for (const b of blob) {
      if (b.t === 'h3') cards.push({ title: b.x });
      else if (b.t === 'p' && cards.length && !cards[cards.length - 1].ex) cards[cards.length - 1].ex = b.x;
    }
    const html = cards.map((c) => {
      const p = postsByTitle[c.title];
      return '<div class="artcard"><b>' + esc(c.title) + '</b>' + (c.ex ? '<p>' + esc(c.ex) + '</p>' : '') + (p ? '<a class="card-link" href="/blog/' + esc(p.slug) + '">مطالعه مقاله<span class="ar">←</span></a>' : '') + '</div>';
    }).join('');
    return '<section class="rich">' + h2 + '<div class="artgrid">' + html + '</div></section>';
  }
  return '<section class="rich">' + h2 + blocksHTML(blob) + '</section>';
}

function teamDetail(x) {
  const meta = [['نقش', x.role], ['سوابق', x.exp], ['ایمیل', x.email], ['شماره تماس', x.phone]];
  const bs = x.bio_blocks || [];
  const postsByTitle = {};
  D.posts.forEach((p) => { postsByTitle[p.title] = p; });
  const intro = []; const order = []; const secs = {}; let cur = null;
  for (const b of bs) {
    if (b.t === 'h2') { cur = b.x; if (!secs[cur]) { secs[cur] = []; order.push(cur); } continue; }
    if (cur === null) intro.push(b); else secs[cur].push(b);
  }
  let body = detailHead({ photo: x.photo, badge: x.role, meta });
  if (intro.length) {
    const quote = intro.length >= 2 && intro[0].t === 'p' ? '<div class="tbq">' + esc(intro[0].x) + '</div>' : '';
    const ps = intro.slice(quote ? 1 : 0).filter((b) => b.t === 'p').map((b) => '<p>' + esc(b.x) + '</p>').join('');
    body += '<section class="rich"><h2>بیوگرافی و معرفی کامل</h2>' + quote + ps + '</section>';
  } else if (x.desc) {
    body += '<section class="rich"><h2>بیوگرافی و معرفی کامل</h2><p>' + esc(x.desc) + '</p></section>';
  }
  for (const key of order) {
    if (/تقویم حضور/.test(key)) continue;
    body += teamSection(key, secs[key], postsByTitle);
  }
  const t = jalToday();
  const cal = leaderCal(bs);
  body += calSection(cal, bkOptions(cal, t), x.slug, t);
  body += moreHTML([['تیم دادگر', '/team'], ['وکلای موسسه', '/lawyers'], ['تماس با ما', '/contact-us']]);
  return { t: x.name, l: x.role || 'عضو تیم دادگر', body };
}
function officesPage() {
  const cards = D.offices.map((o) => `<article class="mcard"><div class="cbody"><h2>${esc(o)}</h2><p>ارائه خدمات حقوقی دادگر در ${esc(o.replace(/^نمایندگی /, ''))} — هماهنگی جلسات و پیگیری پرونده‌ها از طریق دفتر مرکزی.</p></div></article>`);
  return {
    t: 'نمایندگان استانی دادگر', l: 'شبکه نمایندگان استانی دادگر — دسترسی به خدمات حقوقی در سراسر کشور.',
    body: countBar(D.offices.length, 'نمایندگی استانی فعال') + cardGrid(cards)
  };
}

/* ---------- درباره ما و صفحات ظرف ---------- */
function aboutPage() {
  const subs = [
    ['داستان دادگر؛ آغاز با یک هدف، ادامه با یک تعهد', '/about-us/history'],
    ['دلایل اعتماد به دادگر، فراتر از یک انتخاب حقوقی', '/about-us/why-dadgar'],
    ['خط مشی دادگر؛ چارچوبی روشن برای ارائه خدمات حقوقی مسئولانه', '/about-us/core-values'],
    ['منشور اخلاقی دادگر؛ اصولی که رفتار حرفه‌ای ما را تعریف می‌کنند', '/about-us/code-of-ethics'],
    ['اصول اساسی وکالت؛ نگاهی به مبانی فکری و حرفه‌ای وکلای دادگر', '/about-us/basic-principles'],
    ['تیم دادگر؛ چهره‌های کلیدی موسسه، پشت نامی قابل اتکا', '/about-us/team'],
  ];
  const cards = subs.map(([t2, h2]) => card(h2, { title: t2.split('؛')[0], excerpt: t2.includes('؛') ? t2.split('؛').slice(1).join('؛').trim() : '' }, 0));
  return {
    t: 'درباره ما', l: 'در مسیر عدالت، با تعهد و تخصص — موسسه حقوقی دادگر با تکیه بر سال‌ها تجربه، دانش تخصصی و اصول اخلاقی در کنار شماست.',
    body: `<div class="rich">${blocksHTML(D.containers['about-us'])}</div>` + cardGrid(cards)
  };
}
function careersPage() {
  return {
    t: 'فرصت‌های شغلی', l: 'فرصتی برای همکاری با تیمی متعهد، متخصص و پیشرو در عرصه حقوق.',
    body: `<div class="rich">${blocksHTML(D.containers['careers'])}</div>` + moreHTML([['درباره ما', '/about-us'], ['تیم دادگر', '/team'], ['تماس با ما', '/contact-us']])
  };
}
function councilPage() {
  return {
    t: 'شورای عالی دادگر', l: 'پرونده‌های پیچیده، به تصمیم‌های دقیق‌تری نیاز دارند — رکن تخصصی رسیدگی به پرونده‌های چندبعدی.',
    body: `<div class="rich">${blocksHTML(D.containers['supreme-council'])}</div>` + moreHTML([['درباره ما', '/about-us'], ['وکلای موسسه', '/lawyers'], ['درخواست بررسی پرونده', '/request']])
  };
}
function requestPage() {
  return {
    t: 'درخواست خدمات حقوقی تخصصی', l: 'با تکمیل فرم درخواست، تیم دادگر پس از بررسی اطلاعات در اسرع وقت با شما تماس می‌گیرد.',
    body: `<div class="rich">${blocksHTML(D.containers['request'])}</div>`
      + `<section class="more"><h2 class="faq-h">ثبت درخواست</h2><div class="more-grid"><a class="more-link" href="/contact-us">فرم تماس با دادگر<span class="ar">←</span></a><a class="more-link" href="tel:+982191002026">تماس تلفنی ۰۲۱-۹۱۰۰۲۰۲۶<span class="ar">←</span></a><a class="more-link" href="/services">مشاهده خدمات<span class="ar">←</span></a></div></section>`
  };
}
function contactUsPage() {
  return {
    t: 'تماس با ما', l: 'آدرس و اطلاعات تماس شعبات دادگر — تهران زعفرانیه و بلوار کشاورز.',
    body: staticBody('contact-us')
      + `<div class="facts"><div class="fact"><b>۰۲۱-۹۱۰۰۲۰۲۶</b><span>شعبه یک — زعفرانیه، مقدس اردبیلی، مجتمع اکسیژن، طبقه ۳، واحد ۱</span></div><div class="fact"><b>۰۲۱-۸۸۹۸۵۴۵۸</b><span>شعبه دو — بلوار کشاورز، خیابان وصال شیرازی</span></div><div class="fact"><b>۰۹۹۴۱۴۶۷۷۰۳</b><span>واتس‌اپ دادگر</span></div><div class="fact"><b>۱۰–۱۸</b><span>شنبه تا چهارشنبه · پنجشنبه ۱۰–۱۴</span></div></div>`
      + moreHTML([['درخواست خدمات حقوقی', '/request'], ['سوالات متداول', '/faq'], ['فرصت‌های شغلی', '/careers']])
  };
}
function aboutSub(slug, back) {
  const p = D.static_pages[slug];
  return {
    t: p.title, l: '',
    body: `<div class="rich">${p.body}</div>` + moreHTML(back)
  };
}

/* ---------- حل‌گر مسیر ---------- */
function resolve(pathname) {
  const p = String(pathname || '').replace(/\/+$/, '') || '/';
  const parts = p.split('/').filter(Boolean);
  const L = D.lawyers, bySlug = (arr, s) => arr.find((x) => x.slug === s);

  if (p === '/') return null;
  if (p === '/lawyers') return lawyersIndex();
  if (parts[0] === 'lawyers' && parts.length === 2) {
    const x = bySlug(L, decodeURIComponent(parts[1]));
    if (x) return lawyerDetail(x);
    return null; // مسیرهای صفحات قدیمی مثل /lawyers/profile به pages.js می‌روند
  }
  if (p === '/services') return servicesIndex();
  if (parts[0] === 'services' && parts.length === 2) {
    const x = bySlug(D.services, decodeURIComponent(parts[1]));
    if (x) return blocksPage(x, [['همه خدمات', '/services'], ['دپارتمان‌های تخصصی', '/departments'], ['درخواست خدمت', '/request']]);
    return null;
  }
  if (p === '/departments') return departmentsIndex();
  if (parts[0] === 'departments' && parts.length === 2) {
    const x = bySlug(D.departments, decodeURIComponent(parts[1]));
    if (x) return blocksPage(x, [['همه دپارتمان‌ها', '/departments'], ['خدمات موسسه', '/services'], ['وکلای موسسه', '/lawyers']]);
    return null;
  }
  if (p === '/blog') return postsIndex();
  if (parts[0] === 'blog' && parts.length === 2) {
    const x = bySlug(D.posts, decodeURIComponent(parts[1]));
    if (x) return postDetail(x);
    return null;
  }
  if (p === '/portfolio') return portfolioIndex();
  if (parts[0] === 'portfolio' && parts.length === 2) {
    const x = bySlug(D.portfolio, decodeURIComponent(parts[1]));
    if (x) return postDetail(x);
    return null;
  }
  if (p === '/faq') return faqPage();
  if (p === '/testimonials') return testimonialsPage();
  if (p === '/team' || p === '/about-us/team') return teamIndex();
  if (parts[0] === 'team' && parts.length === 2) {
    const x = bySlug(D.team, decodeURIComponent(parts[1]));
    if (x) return teamDetail(x);
    return null;
  }
  if (p === '/offices') return officesPage();
  if (p === '/about-us') return aboutPage();
  if (p === '/about-us/history') return aboutSub('history', [['درباره ما', '/about-us'], ['چرا دادگر؟', '/about-us/why-dadgar'], ['تیم دادگر', '/about-us/team']]);
  if (p === '/about-us/why-dadgar') return aboutSub('why-dadgar', [['درباره ما', '/about-us'], ['داستان دادگر', '/about-us/history'], ['خدمات موسسه', '/services']]);
  if (p === '/about-us/core-values') return aboutSub('core-values', [['درباره ما', '/about-us'], ['منشور اخلاقی', '/about-us/code-of-ethics'], ['اصول اساسی وکالت', '/about-us/basic-principles']]);
  if (p === '/about-us/code-of-ethics') return aboutSub('code-of-ethics', [['درباره ما', '/about-us'], ['خط مشی دادگر', '/about-us/core-values'], ['تیم دادگر', '/about-us/team']]);
  if (p === '/about-us/basic-principles') return aboutSub('basic-principles', [['درباره ما', '/about-us'], ['وکلای موسسه', '/lawyers'], ['منشور اخلاقی', '/about-us/code-of-ethics']]);
  if (p === '/careers') return careersPage();
  if (p === '/supreme-council') return councilPage();
  if (p === '/request') return requestPage();
  if (p === '/contact-us') return contactUsPage();
  if (p === '/privacy-policy') { const b = staticBody('privacy-policy'); return b ? { t: 'سیاست‌های حفظ حریم خصوصی دادگر', l: 'حفاظت از اطلاعات موکلان و کاربران دادگر', body: b } : null; }
  if (p === '/terms-of-use') { const b = staticBody('terms-of-use'); return b ? { t: 'قوانین و مقررات استفاده از وب‌سایت دادگر', l: 'چارچوب استفاده از وب‌سایت موسسه حقوقی دادگر', body: b } : null; }
  if (p === '/criticism-and-suggestions') { const b = staticBody('criticism-and-suggestions'); return b ? { t: 'انتقادات و پیشنهادات', l: 'صدای شما مسیر بهبود ماست — انتقادات و پیشنهادات خود را با ما در میان بگذارید', body: b } : null; }
  if (p === '/authors') { const b = staticBody('authors'); return b ? { t: 'نویسندگان متخصص دادگر', l: 'نویسندگان متخصص برای ارتقای آگاهی حقوقی شما', body: b } : null; }
  return null;
}

module.exports = { resolve, blocksHTML };
