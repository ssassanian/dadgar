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
function teamDetail(x) {
  const meta = [['نقش', x.role], ['سوابق', x.exp], ['ایمیل', x.email], ['شماره تماس', x.phone]];
  const bio = x.bio_blocks && x.bio_blocks.length ? `<div class="rich"><h2>بیوگرافی و معرفی کامل</h2>${blocksHTML(x.bio_blocks)}</div>` : '';
  return {
    t: x.name, l: x.role || 'عضو تیم دادگر',
    body: detailHead({ photo: x.photo, badge: x.role, meta })
      + (x.desc ? `<div class="rich"><p>${esc(x.desc)}</p></div>` : '') + bio
      + moreHTML([['تیم دادگر', '/team'], ['درباره ما', '/about-us'], ['تماس با ما', '/contact-us']])
  };
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
