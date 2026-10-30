/// تولید PDF فاکتور — M6 (CMD-028)
///
/// تصمیم باز CMD-005 («خروجی PDF فاکتور») با حکم CMD-028 بسته شد: دامنه‌ی
/// این گام فقط موبایل است (خروجی PDF وب نیازمند حکم جداگانه است).
///
/// پیاده‌سازی: بسته‌ی استاندارد `pdf` با فونت باندل‌شده‌ی Vazirmatn (OFL —
/// از M0 در اپ هست) و Directionality راست‌به‌چپ. هیچ سرویس/داده‌ی جدیدی از
/// سرور خواسته نمی‌شود — ورودی همان مدل Invoice موجود است.
///
/// تست‌پذیری: فونت‌ها تزریقی‌اند (ByteData) — تست واحد بدون rootBundle کار
/// می‌کند و فقط خروجی بایت‌های %PDF را راستی‌آزمایی می‌کند.
library;

import 'dart:typed_data';

import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/time/jalali.dart';
import '../data/billing_contract.dart';
import '../domain/invoice_models.dart';

abstract final class InvoicePdf {
  /// فونت‌های باندل‌شده‌ی اپ از M0 — مجوز OFL (پیوست pubspec)
  static const String assetRegular =
      'assets/fonts/vazirmatn/Vazirmatn-Regular.ttf';
  static const String assetBold = 'assets/fonts/vazirmatn/Vazirmatn-Bold.ttf';

  /// نام فایل خروجی — ساده و بی‌تاریخ تا مسیر share پایدار بماند
  static String fileName(Invoice invoice) => 'dadgar-invoice-${invoice.id}.pdf';

  /// بارگذاری فونت‌ها از باندل (فقط runtime اپ — تست‌ها تزریق می‌کنند)
  static Future<(ByteData regular, ByteData bold)> loadFonts() async {
    final regular = await rootBundle.load(assetRegular);
    final bold = await rootBundle.load(assetBold);
    return (regular, bold);
  }

  /// ساخت بایت‌های PDF — خالص و بدون پلتفرم (آینده‌وار؛ ذخیره‌ی بسته async است)
  static Future<Uint8List> build({
    required Invoice invoice,
    required ByteData regular,
    required ByteData bold,
    String? brandLine,
  }) {
    final base = pw.Font.ttf(regular);
    final boldFont = pw.Font.ttf(bold);
    final created = JalaliCalendar.fromEpochSeconds(invoice.createdAt);

    final rows = <(String, String)>[
      ('شماره فاکتور', BillingContract.toPersianDigits(invoice.id)),
      ('تاریخ صدور', JalaliCalendar.formatNumeric(created)),
      ('مبلغ', BillingContract.formatToman(invoice.amount)),
      ('وضعیت', invoice.statusValue.labelFa),
      if (invoice.paidAt != null)
        (
          'تاریخ پرداخت',
          JalaliCalendar.formatNumeric(
            JalaliCalendar.fromEpochSeconds(invoice.paidAt!),
          ),
        ),
      if (invoice.caseId != null)
        ('پرونده‌ی متصل', BillingContract.toPersianDigits(invoice.caseId!)),
      if (invoice.clientName.isNotEmpty) ('مشتری', invoice.clientName),
      if (invoice.lawyerName.isNotEmpty) ('وکیل پرونده', invoice.lawyerName),
    ];

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: base, bold: boldFont),
    );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 56),
        build: (context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                  'مؤسسه حقوقی دادگر',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 20,
                    color: PdfColor.fromInt(0xFF14345B),
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'صورتحساب رسمی سامانه',
                  style: pw.TextStyle(
                    font: base,
                    fontSize: 12,
                    color: PdfColor.fromInt(0xFF5A5F66),
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                if (brandLine != null && brandLine.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    brandLine,
                    style: pw.TextStyle(
                      font: base,
                      fontSize: 10,
                      color: PdfColor.fromInt(0xFF5A5F66),
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
                pw.SizedBox(height: 24),
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                      color: PdfColor.fromInt(0xFF14345B),
                      width: 1,
                    ),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(8),
                    ),
                  ),
                  padding: const pw.EdgeInsets.all(16),
                  child: pw.Column(
                    children: [
                      for (final (label, value) in rows)
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 5),
                          child: pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                label,
                                style: pw.TextStyle(
                                  font: boldFont,
                                  fontSize: 11,
                                  color: PdfColor.fromInt(0xFF14345B),
                                ),
                              ),
                              pw.Text(
                                value,
                                style: pw.TextStyle(
                                  font: base,
                                  fontSize: 12,
                                  color: PdfColor.fromInt(0xFF20242B),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                pw.Spacer(),
                pw.Text(
                  'این فاکتور به‌همراه سابقه‌ی پرداخت در سامانه‌ی دادگر ثبت '
                  'شده است؛ اعتبار مبلغ بر اساس ثبت سرور است.',
                  style: pw.TextStyle(
                    font: base,
                    fontSize: 9,
                    color: PdfColor.fromInt(0xFF5A5F66),
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );

    return doc.save();
  }
}