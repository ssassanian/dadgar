import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/time/jalali.dart';
import '../../design/journey_bar.dart';
import '../../design/tokens.dart';
import '../auth/application/auth_controller.dart';
import '../auth/application/session_controller.dart';

/// صفحه‌ی خانه M7 (CMD-040) — بازطراحی تاییدشده‌ی مدیر (CMD-038):
/// روال «کار-اول» — عنصر امضایی «مسیر پرونده» قهرمان صفحه، سه اقدام
/// فوری، سپس پنل‌های نقشه‌ی امکان؛ اعداد و آمار تا اتصال زنده (D-6)
/// اینجا نمی‌نشیند و هیچ داده‌ی جعلی رندر نمی‌شود (S-4).
///
/// چرخه‌ی نمایش‌داده‌شده پنج مرحله‌ی واقعی قرارداد سرور (CMD-003) است:
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('دادگر'),
        actions: [
          IconButton(
            tooltip: 'پروفایل',
            onPressed: () => context.go('/profile'),
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DadgarTokens.s16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── درود + امروز شمسی ──
                Text(
                  'سلام، $username',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: DadgarTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  todayLabel,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: DadgarTokens.textSecondary,
                  ),
                ),
                const SizedBox(height: DadgarTokens.s16),

                // ── کارت قهرمان: مسیر پرونده (عنصر امضایی) ──
                const _JourneyHero(),
                const SizedBox(height: DadgarTokens.s16),

                // ── سه اقدام فوری (CMD-038) ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.upload_file_outlined,
                        label: 'ارسال سند',
                        onTap: () => context.go('/documents'),
                      ),
                    ),
                    const SizedBox(width: DadgarTokens.s8),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.calendar_month_outlined,
                        label: 'رزرو نوبت',
                        onTap: () => context.go('/appointments'),
                      ),
                    ),
                    const SizedBox(width: DadgarTokens.s8),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.credit_card_outlined,
                        label: 'پرداخت فاکتور',
                        onTap: () => context.go('/invoices'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DadgarTokens.s16),

                // ── پنل: پرونده‌ها و گفتگو ──
                _PanelCard(
                  title: 'پرونده‌ها و گفتگو',
                  children: [
                    _ActionCard(
                      icon: Icons.folder_outlined,
                      title: 'پرونده‌های من',
                      subtitle: 'فهرست و جزئیات پرونده‌ها (M2)',
                      onTap: () => context.go('/cases'),
                    ),
                    _ActionCard(
                      icon: Icons.post_add_outlined,
                      title: 'ثبت پرونده جدید',
                      subtitle: 'دسته، عنوان و توضیحات (M2)',
                      onTap: () => context.go('/cases/new'),
                    ),
                    _ActionCard(
                      icon: Icons.forum_outlined,
                      title: 'گفتگو با وکیل',
                      subtitle: 'گفتگوی پرونده‌های تخصیص‌یافته (M5)',
                      onTap: () => context.go('/threads'),
                    ),
                    _ActionCard(
                      icon: Icons.support_agent_outlined,
                      title: 'تیکت‌های پشتیبانی',
                      subtitle: 'ثبت تیکت و پیگیری پاسخ (M5)',
                      onTap: () => context.go('/tickets'),
                    ),
                  ],
                ),
                const SizedBox(height: DadgarTokens.s12),

                // ── پنل: نوبت و مالی ──
                _PanelCard(
                  title: 'نوبت و مالی',
                  children: [
                    _ActionCard(
                      icon: Icons.event_note_outlined,
                      title: 'نوبت‌های من',
                      subtitle: 'وضعیت نوبت‌ها و لغو (M3)',
                      onTap: () => context.go('/appointments/mine'),
                    ),
                    _ActionCard(
                      icon: Icons.receipt_long_outlined,
                      title: 'صورتحساب‌ها و پرداخت',
                      subtitle: 'فاکتورهای من، مبلغ و وضعیت (M4)',
                      onTap: () => context.go('/invoices'),
                    ),
                  ],
                ),

                // ── گیت نقش: کارت پنل مدیریت فقط برای مدیر (M6) ──
                if (isAdmin) ...[
                  const SizedBox(height: DadgarTokens.s12),
                  _ActionCard(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'پنل مدیریت مالی',
                    subtitle: 'صدور فاکتور، ثبت پرداخت و بازکردن (M6)',
                    onTap: () => context.go('/admin/billing'),
                  ),
                ],

                const SizedBox(height: DadgarTokens.s16),

                // ── وضعیت صادقانه‌ی نشست (M1) — ته صفحه، بی‌ادعا ──
                const _StatusChip(
                  icon: Icons.verified_user_outlined,
                  label: 'توکن در Keystore/Keychain ذخیره می‌شود (§۸)',
                ),
                const SizedBox(height: DadgarTokens.s8),
                const _StatusChip(
                  icon: Icons.sync_alt,
                  label: 'اتصال زنده به سرور: در انتظار حکم D-6',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// کارت قهرمان — مسیر پرونده با پنج مرحله‌ی واقعی قرارداد سرور؛
/// تا اتصال زنده نوار خنثی است و دکمه‌ها به ماژول‌های واقعی می‌روند.
final class _JourneyHero extends StatelessWidget {
  const _JourneyHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DadgarTokens.s16),
      decoration: BoxDecoration(
        color: DadgarTokens.surface,
        borderRadius: BorderRadius.circular(DadgarTokens.radius),
        border: Border.all(
          color: DadgarTokens.textSecondary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'مسیر پرونده',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: DadgarTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'چرخه‌ی واقعی هر پرونده در دادگر — پس از اتصال زنده، '
            'وضعیت لحظه‌ای پرونده‌ی خودتان همین‌جا دیده می‌شود',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.6,
              color: DadgarTokens.textSecondary,
            ),
          ),
          const SizedBox(height: DadgarTokens.s12),
          const DadgarJourneyBar(
            steps: ['ثبت', 'پیشنهاد', 'تخصیص', 'در حال انجام', 'پایان'],
          ),
          const SizedBox(height: DadgarTokens.s12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => context.go('/cases'),
                  style: FilledButton.styleFrom(
                    backgroundColor: DadgarTokens.primary,
                    foregroundColor: DadgarTokens.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      vertical: DadgarTokens.s12,
                    ),
                  ),
                  child: const Text('پرونده‌های من'),
                ),
              ),
              const SizedBox(width: DadgarTokens.s8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.go('/cases/new'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: DadgarTokens.textPrimary,
                    side: BorderSide(
                      color: DadgarTokens.textSecondary
                          .withValues(alpha: 0.35),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: DadgarTokens.s12,
                    ),
                  ),
                  child: const Text('ثبت پرونده جدید'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// اقدام فوری خانه — کاشی آیکونی ۴۴px+ (CMD-038)
final class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DadgarTokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DadgarTokens.radius),
        side: BorderSide(
          color: DadgarTokens.textSecondary.withValues(alpha: 0.2),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DadgarTokens.s8,
            vertical: DadgarTokens.s12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: DadgarTokens.primary),
              const SizedBox(height: DadgarTokens.s4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: DadgarTokens.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// پنل گروهی — سربرگ + کارت‌های اقدام هم‌خانواده (CMD-038)
final class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DadgarTokens.s12),
      decoration: BoxDecoration(
        color: DadgarTokens.surface,
        borderRadius: BorderRadius.circular(DadgarTokens.radius),
        border: Border.all(
          color: DadgarTokens.textSecondary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              right: DadgarTokens.s4,
              bottom: DadgarTokens.s8,
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: DadgarTokens.textPrimary,
              ),
            ),
          ),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: DadgarTokens.s8),
            children[i],
          ],
        ],
      ),
    );
  }
}

final class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: DadgarTokens.s12,
        vertical: DadgarTokens.s8,
      ),
      decoration: BoxDecoration(
        color: DadgarTokens.surface,
        borderRadius: BorderRadius.circular(DadgarTokens.radius),
        border: Border.all(
          color: DadgarTokens.textSecondary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: DadgarTokens.accent),
          const SizedBox(width: DadgarTokens.s8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: DadgarTokens.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// کارت اقدام — همان M1 با فاصله‌گذاری پنلی
final class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DadgarTokens.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DadgarTokens.radius),
        side: BorderSide(
          color: DadgarTokens.textSecondary.withValues(alpha: 0.2),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(DadgarTokens.s12),
          child: Row(
            children: [
              Icon(icon, size: 22, color: DadgarTokens.primary),
              const SizedBox(width: DadgarTokens.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: DadgarTokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: DadgarTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_left,
                size: 20,
                color: DadgarTokens.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
