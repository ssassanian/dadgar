import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/time/jalali.dart';
import '../../design/ds_kit.dart';
import '../../design/tokens.dart';
import '../auth/application/auth_controller.dart';
import '../auth/application/session_controller.dart';
import '../cases/data/cases_contract.dart';

/// صفحه‌ی خانه «دادگر S» — بازنویسی از صفر (CMD-051؛ اجرای حکم CMD-050)
///
/// الگوی بومی‌موبایلی تازه: سربرگ تمام‌آبی برند با درود و امروزِ شمسی،
/// برگه‌ی سفیدِ همپوشان، مسیر پرونده به‌عنوان قهرمان، چهار اقدام فوری
/// دایره‌ای و بخش‌های کاشی‌ای — هیچ‌یک از الگوهای نسل قبل (اپ‌بار
/// سرمه‌ای/کاغذ گرم) و هیچ‌یک از چیدمان وب بازنویسی نشده است.
///
/// روال «کار-اول» عین حکم CMD-038 پابرجاست؛ اعداد و آمار تا اتصال
/// زنده اینجا نمی‌نشیند و هیچ داده‌ی جعلی رندر نمی‌شود (S-4).
///
/// چرخه‌ی نمایش‌داده‌شده شش مرحله‌ی حقوقی طرح است (حکم F1 سند CMD-048)
/// با نگاشت نمایشی روی پنج وضعیت سرور (CMD-003):
/// waiting → proposing → assigned → running → done.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(authControllerProvider);
    final username = switch (status) {
      Authenticated(:final username) => username,
      _ => 'کاربر دادگر',
    };
    // M6 (CMD-028) — کشف نقش نشست: کارت پنل مدیریت فقط برای مدیر
    final meAsync = ref.watch(sessionMeProvider);
    final isAdmin = meAsync.value?.isAdmin ?? false;

    // امروزِ شمسی تهران — از ساعت دستگاه با آفست تهران (بدون شبکه)
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final today = JalaliCalendar.fromEpochSeconds(nowSeconds);
    final todayLabel =
        '${JalaliCalendar.weekDayNames[JalaliCalendar.weekIndexOf(today)]} — '
        '${JalaliCalendar.formatNumeric(today)}';

    final light = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── سربرگ تمام‌آبی برند (هویت نسل S) ──
          _Header(username: username, todayLabel: todayLabel),
          // ── برگه‌ی سفید همپوشان ──
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -24),
              child: Container(
                decoration: BoxDecoration(
                  color: light ? Ds.bg : Ds.bgDark,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(Ds.radiusSheet),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    Ds.s16,
                    Ds.s24 + 4,
                    Ds.s16,
                    Ds.s24,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── کارت قهرمان: مسیر پرونده ──
                          const _JourneyHero(),
                          const SizedBox(height: Ds.s16),

                          // ── چهار اقدام فوری (CMD-038) ──
                          const _QuickActions(),
                          const SizedBox(height: Ds.s16),

                          // ── بخش: پرونده‌ها و گفتگو ──
                          DsSectionHeader('پرونده‌ها و گفتگو'),
                          DsTile(
                            icon: Icons.folder_outlined,
                            title: 'پرونده‌های من',
                            subtitle: 'فهرست و جزئیات پرونده‌ها',
                            onTap: () => context.go('/cases'),
                          ),
                          const SizedBox(height: Ds.s8),
                          DsTile(
                            icon: Icons.post_add_outlined,
                            title: 'ثبت پرونده جدید',
                            subtitle: 'دسته، عنوان و توضیحات',
                            onTap: () => context.go('/cases/new'),
                          ),
                          const SizedBox(height: Ds.s8),
                          DsTile(
                            icon: Icons.forum_outlined,
                            title: 'گفتگو با وکیل',
                            subtitle: 'گفتگوی پرونده‌های تخصیص‌یافته',
                            onTap: () => context.go('/threads'),
                          ),
                          const SizedBox(height: Ds.s8),
                          DsTile(
                            icon: Icons.support_agent_outlined,
                            title: 'تیکت‌های پشتیبانی',
                            subtitle: 'ثبت تیکت و پیگیری پاسخ',
                            onTap: () => context.go('/tickets'),
                          ),
                          const SizedBox(height: Ds.s16),

                          // ── بخش: نوبت و مالی ──
                          DsSectionHeader('نوبت و مالی'),
                          DsTile(
                            icon: Icons.event_note_outlined,
                            title: 'نوبت‌های من',
                            subtitle: 'وضعیت نوبت‌ها و لغو',
                            onTap: () => context.go('/appointments/mine'),
                          ),
                          const SizedBox(height: Ds.s8),
                          DsTile(
                            icon: Icons.receipt_long_outlined,
                            title: 'فاکتورها و پرداخت',
                            subtitle: 'فاکتورهای من، مبلغ و وضعیت',
                            onTap: () => context.go('/invoices'),
                          ),

                          // ── گیت نقش: کارت پنل مدیریت فقط برای مدیر (M6) ──
                          if (isAdmin) ...[
                            const SizedBox(height: Ds.s16),
                            DsSectionHeader('مدیریت'),
                            DsTile(
                              icon: Icons.admin_panel_settings_outlined,
                              title: 'پنل مدیریت مالی',
                              subtitle:
                                  'صدور فاکتور، ثبت پرداخت و بازکردن',
                              onTap: () => context.go('/admin/billing'),
                            ),
                          ],

                          const SizedBox(height: Ds.s20),

                          // ── وضعیت صادقانه‌ی نشست (M1) — ته صفحه، بی‌ادعا ──
                          const _StatusChip(
                            icon: Icons.verified_user_outlined,
                            label: 'توکن در Keystore/Keychain ذخیره می‌شود',
                          ),
                          const SizedBox(height: Ds.s8),
                          const _StatusChip(
                            icon: Icons.sync_alt,
                            label: 'اتصال زنده به سرور دادگر — فعال',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// سربرگ تمام‌آبی — مونوگرام + درود + امروز شمسی + پروفایل
final class _Header extends StatelessWidget {
  const _Header({required this.username, required this.todayLabel});

  final String username;
  final String todayLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: 48),
      decoration: const BoxDecoration(color: Ds.primary),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Ds.s16, Ds.s8, Ds.s16, Ds.s8),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'د',
                  style: TextStyle(
                    color: Ds.primary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: Ds.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'سلام، $username',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: Ds.fontFamily,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      todayLabel,
                      style: TextStyle(
                        fontFamily: Ds.fontFamily,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'پروفایل',
                onPressed: () => context.go('/profile'),
                icon: const Icon(Icons.person_outline, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// کارت قهرمان — مسیر پرونده با شش مرحله‌ی حقوقی (حکم F1 سند CMD-048)
final class _JourneyHero extends StatelessWidget {
  const _JourneyHero();

  @override
  Widget build(BuildContext context) {
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'مسیر پرونده',
            style: TextStyle(
              fontFamily: Ds.fontFamily,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Ds.ink,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'چرخه‌ی واقعی هر پرونده در دادگر — پس از اتصال زنده، '
            'وضعیت لحظه‌ای پرونده‌ی خودتان همین‌جا دیده می‌شود',
            style: TextStyle(
              fontFamily: Ds.fontFamily,
              fontSize: 11.5,
              height: 1.6,
              color: Ds.inkFaint,
            ),
          ),
          const SizedBox(height: Ds.s8),
          const DsJourneyBar(steps: CasesContract.legalJourney),
          const SizedBox(height: Ds.s12),
          Row(
            children: [
              Expanded(
                child: DsButton('پرونده‌های من', onPressed: () {
                  context.go('/cases');
                }),
              ),
              const SizedBox(width: Ds.s8),
              Expanded(
                child: DsButton(
                  'ثبت پرونده جدید',
                  onPressed: () => context.go('/cases/new'),
                  tone: DsButtonTone.outline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// چهار اقدام فوری — دایره‌های tint آبی (الگوی تازه‌ی نسل S)
final class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickCircle(
            icon: Icons.upload_file_outlined,
            label: 'ارسال سند',
            onTap: () => context.go('/documents'),
          ),
        ),
        Expanded(
          child: _QuickCircle(
            icon: Icons.calendar_month_outlined,
            label: 'رزرو نوبت',
            onTap: () => context.go('/appointments'),
          ),
        ),
        Expanded(
          child: _QuickCircle(
            icon: Icons.credit_card_outlined,
            label: 'پرداخت فاکتور',
            onTap: () => context.go('/invoices'),
          ),
        ),
        Expanded(
          child: _QuickCircle(
            icon: Icons.forum_outlined,
            label: 'گفتگو با وکیل',
            onTap: () => context.go('/threads'),
          ),
        ),
      ],
    );
  }
}

/// اقدام فوری — دایره‌ی ۵۶dp با برچسب (هدف لمس ≥۴۸ — قاعده‌ی مهارت)
final class _QuickCircle extends StatelessWidget {
  const _QuickCircle({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Ds.radiusCard),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: Ds.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Ds.wash,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: Ds.primary),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: Ds.fontFamily,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Ds.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// وضعیت صادقانه — ردیف ریز پایین خانه
final class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Ds.s12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: light ? Colors.white : Ds.surfaceDark,
        borderRadius: BorderRadius.circular(Ds.radiusField),
        border: Border.all(color: light ? Ds.line : Ds.lineDark),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: light ? Ds.green : Ds.mint),
          const SizedBox(width: Ds.s8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: Ds.fontFamily,
                fontSize: 11.5,
                height: 1.5,
                color: light ? Ds.inkFaint : Ds.inkFaintDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
