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
    : pathname === '/services'
      ? [
          'از مشاوره اولیه تا پیگیری پرونده، مسیر خدمت را بر اساس مسئله واقعی شما تنظیم می‌کنیم.',
          'در هر حوزه، ابتدا شرایط و اسناد را بررسی می‌کنیم و سپس گزینه‌های عملی و هزینه‌های احتمالی را شفاف توضیح می‌دهیم.',
          'هدف ما فقط ارائه پاسخ نیست؛ همراهی منظم تا رسیدن به تصمیمی مطمئن و قابل اجراست.'
        ]
      : pathname === '/lawyers'
        ? [
            'با وکلایی آشنا شوید که تجربه تخصصی خود را با توضیح روشن و نگاه مسئله‌محور در اختیار شما می‌گذارند.',
            'حوزه فعالیت، سابقه و رویکرد هر عضو را بررسی کنید تا انتخاب شما بر اساس نیاز واقعی پرونده انجام شود.',
            'پس از انتخاب، تیم دادگر هماهنگی جلسه و ادامه مسیر ارتباطی را برای شما ساده و منظم می‌کند.'
          ]
          : pathname === '/lawyers/profile'
          ? [
              'پروفایل اختصاصی وکیل، مسیر ارتباط و اطلاعات لازم برای شروع همکاری را شفاف می‌کند.',
              'سوابق و حوزه تخصصی وکیل را در یک صفحه منظم بررسی کنید و با شناخت بهتری تصمیم بگیرید.',
              'پس از بررسی اطلاعات، درخواست مشاوره خود را ثبت کنید تا هماهنگی جلسه انجام شود.'
            ]
          : pathname === '/articles'
            ? [
                'مقالات دادگر، مفاهیم حقوقی پیچیده را به زبان روشن و کاربردی توضیح می‌دهند.',
                'مطالب را بر اساس موضوع، نیاز روزمره و پرسش‌های پرتکرار خود دنبال کنید.',
                'این محتوا برای آگاهی اولیه است و جایگزین بررسی اختصاصی پرونده توسط وکیل نیست.'
              ]
            : pathname === '/pricing'
              ? [
                  'تعرفه‌ها را بر اساس نوع خدمت، پیچیدگی موضوع و سطح پیگیری موردنیاز شفاف بررسی کنید.',
                  'پیش از شروع همکاری، دامنه خدمت، هزینه‌های قابل پیش‌بینی و مراحل پرداخت به‌صورت روشن توضیح داده می‌شود.',
                  'اگر درباره انتخاب مسیر مناسب مطمئن نیستید، از مشاوره اولیه برای برآورد دقیق‌تر استفاده کنید.'
                ]
            : pathname === '/faq'
              ? [
                  'پاسخ‌های روشن به پرسش‌های پرتکرار درباره خدمات، نوبت‌دهی و روند پیگیری پرونده.',
                  'راهنمای کوتاه برای آماده‌سازی مدارک و انتخاب مسیر مناسب پیش از دریافت مشاوره.',
                  'اگر پاسخ خود را پیدا نکردید، سؤال خود را مستقیم برای تیم دادگر ارسال کنید.'
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
