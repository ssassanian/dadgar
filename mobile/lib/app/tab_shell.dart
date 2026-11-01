/// پوسته‌ی ناوبری پنج‌تبی اپ دادگر — CMD-044 (اجرای توصیه‌ی F2 بازرسی CMD-042)
///
/// ترجمه‌ی مستقیم طرح تاییدشده‌ی CMD-041: تب‌بار فقط روی پنج صفحه‌ی ریشه
/// (خانه/پرونده‌ها/نوبت/فاکتور/پروفایل — عین `tabbar()` در prototype.html)؛
/// صفحه‌های جزئیات و ثانویه تمام‌صفحه با بازگشت پشته‌ای و بدون تب‌بار.
///
/// نقطه‌ی «فاکتور پرداخت‌نشده» روی تب فاکتور از داده‌ی واقعی سرور می‌آید
/// (S-4 — صفر داده‌ی جعلی) — اجرای توصیه‌ی F12 سمت کد. کنترلر مالی در
/// نخستین تماشا یک‌بار بارگذاری می‌شود و پس از پرداخت (setInvoiceStatus)
/// نقطه به‌صورت زنده حذف می‌شود — عین رفتار پروتوتایپ.
///
/// قواعد خود طرح (CMD-042 F4/F5) از تولد رعایت است: لمس مقصدها ≥۴۸dp
/// (استاندارد M3) و برچسب‌ها ۱۲sp+ (پیش‌فرض M3).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/tokens.dart';
import 'providers.dart';

/// یک تب نوار پایین — برچسب/آیکون/مقصد (ترتیب = ترتیب شاخه‌های روتر)
typedef _Tab = ({String label, IconData icon, IconData selected, String location});

const List<_Tab> _kTabs = <_Tab>[
  (label: 'خانه', icon: Icons.home_outlined, selected: Icons.home, location: '/'),
  (
    label: 'پرونده‌ها',
    icon: Icons.folder_outlined,
    selected: Icons.folder,
    location: '/cases',
  ),
  (
    label: 'نوبت',
    icon: Icons.event_outlined,
    selected: Icons.event,
    location: '/appointments',
  ),
  (
    label: 'فاکتور',
    icon: Icons.receipt_long_outlined,
    selected: Icons.receipt_long,
    location: '/invoices',
  ),
  (
    label: 'پروفایل',
    icon: Icons.person_outline,
    selected: Icons.person,
    location: '/profile',
  ),
];

/// بدنه = شاخه‌ی فعال (StatefulShellRoute.indexedStack) + نوار پایین پنج‌تبی
final class DadgarTabShell extends ConsumerWidget {
  const DadgarTabShell({super.key, required this.navigationShell});

  /// پوسته‌ی ناوبری که go_router به سازنده می‌دهد
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // تماشای وضعیت مالی → بارگذاری یک‌باره‌ی فاکتورهای کاربر (build کنترلر
    // خودش microtask بارگذاری دارد) → نقطه‌ی تب فاکتور همیشه داده‌ی واقعی
    final pendingCount = ref.watch(billingControllerProvider).pendingCount;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (int i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
        destinations: <Widget>[
          for (var i = 0; i < _kTabs.length; i++)
            NavigationDestination(
              icon: _tabIcon(
                _kTabs[i],
                pendingCount: pendingCount,
                selected: false,
              ),
              selectedIcon: _tabIcon(
                _kTabs[i],
                pendingCount: pendingCount,
                selected: true,
              ),
              label: _kTabs[i].label,
              tooltip: _kTabs[i].label,
            ),
        ],
      ),
    );
  }

  /// آیکون تب — فقط تب فاکتور با فاکتور پرداخت‌نشده نقطه‌ی قرمز دارد (F12)
  Widget _tabIcon(
    _Tab tab, {
    required int pendingCount,
    required bool selected,
  }) {
    final icon = Icon(selected ? tab.selected : tab.icon);
    if (tab.location != '/invoices' || pendingCount == 0) {
      return icon;
    }
    return Badge(
      smallSize: 8,
      backgroundColor: DadgarTokens.error,
      child: icon,
    );
  }
}
