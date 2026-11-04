/// پوسته‌ی ناوبری «دادگر S» — داک شناور (CMD-051؛ کد تازه از صفر)
///
/// حکم CMD-050/051: طراحی موبایل از صفر و موبایل‌بومی؛ تنها پالت برند
/// وب مشترک است. این پوسته جایگزین NavigationBar استاندارد M3 نسل قبل
/// شده است: داک گردِ شناور با قرص انتخاب آبی الکتریکی — الگویی که
/// نه در وب دادگر هست و نه در نسل قبلی اپ.
///
/// ساختار ناوبری عین طرح تاییدشده‌ی CMD-041/044 می‌ماند: پنج مقصد
/// ریشه‌ای (خانه/پرونده‌ها/نوبت/فاکتور/پروفایل) با StatefulShellRoute؛
/// نقطه‌ی «فاکتور پرداخت‌نشده» از داده‌ی واقعی سرور (S-4).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/tokens.dart';
import 'providers.dart';

/// یک مقصد داک — برچسب/آیکون/مسیر (ترتیب = ترتیب شاخه‌های روتر)
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

/// داک شناور نسل S — سفید گردِ ۲۴ با قرص انتخاب آبی؛ هدف لمس ≥۴۸dp
final class DsDock extends StatelessWidget {
  const DsDock({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.pendingInvoices,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  /// تعداد فاکتور پرداخت‌نشده‌ی واقعی (S-4؛ صفر = بدون نقطه)
  final int pendingInvoices;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final light = scheme.brightness == Brightness.light;
    final dockColor = light ? Ds.surface : Ds.surfaceDark;
    final idle = light ? Ds.inkSoft : Ds.inkSoftDark;

    return SafeArea(
      top: false,
      child: Container(
        // CMD-052 — ترمیم باگ کشف‌شده با رندر گولدن: Center درون InkWell
        // با constraints بسته‌ی اسلات bottomNavigationBar تا کل ارتفاع
        // صفحه منبسط می‌شد و بدنه صفر می‌گرفت؛ ارتفاع داک اکنون صریح است:
        // ۴۸ محتوا + ۱۲ padding + ۲ border = ۶۲.
        height: 62,
        margin: const EdgeInsets.fromLTRB(Ds.s16, Ds.s4, Ds.s16, Ds.s12),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: dockColor,
          borderRadius: BorderRadius.circular(Ds.radiusSheet),
          border: Border.all(
            color: light ? Ds.line : Ds.lineDark,
          ),
          boxShadow: Ds.cardShadow,
        ),
        child: Row(
          children: [
            for (var i = 0; i < _kTabs.length; i++)
              Expanded(child: _dockItem(context, i, idle)),
          ],
        ),
      ),
    );
  }

  Widget _dockItem(BuildContext context, int i, Color idle) {
    final tab = _kTabs[i];
    final selected = i == currentIndex;
    final scheme = Theme.of(context).colorScheme;
    final light = scheme.brightness == Brightness.light;
    final accent = light ? Ds.primary : Ds.cyan;
    final onAccent = light ? Ds.onPrimary : Ds.bgDark;

    // داک فقط‌آیکونی (الگوی داک native): قرص انتخاب ۴۴×۴۴؛ نام مقصد
    // برای دسترس‌پذیری در Semantics/Tooltip هست (قاعده‌ی مهارت:
    // «کنترل فقط‌آیکونی باید نام دسترس‌پذیر داشته باشد»).
    final iconWidget = Icon(
      selected ? tab.selected : tab.icon,
      size: 22,
      color: selected ? onAccent : idle,
    );

    final content = Tooltip(
      message: tab.label,
      triggerMode: TooltipTriggerMode.longPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(Ds.radiusChip),
        ),
        child: tab.location == '/invoices' && pendingInvoices > 0 && !selected
            ? Badge(
                smallSize: 8,
                backgroundColor: light ? Ds.error : Ds.rose,
                child: iconWidget,
              )
            : iconWidget,
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      child: InkWell(
        key: ValueKey<String>('dock-${tab.location}'),
        onTap: () => onDestinationSelected(i),
        borderRadius: BorderRadius.circular(Ds.radiusChip),
        child: Center(child: content),
      ),
    );
  }
}

/// بدنه = شاخه‌ی فعال (StatefulShellRoute.indexedStack) + داک شناور
final class DadgarTabShell extends ConsumerWidget {
  const DadgarTabShell({super.key, required this.navigationShell});

  /// پوسته‌ی ناوبری که go_router به سازنده می‌دهد
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // تماشای وضعیت مالی → بارگذاری یک‌باره‌ی فاکتورهای کاربر → نقطه‌ی
    // داک همیشه از داده‌ی واقعی سرور (عین رفتار نسل قبل، پوسته‌ی تازه)
    final pendingCount = ref.watch(billingControllerProvider).pendingCount;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DsDock(
        currentIndex: navigationShell.currentIndex,
        onDestinationSelected: (int i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
        pendingInvoices: pendingCount,
      ),
    );
  }
}
