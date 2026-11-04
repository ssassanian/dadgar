/// تست تولید PDF فاکتور — M6 (CMD-028)
///
/// فونت‌ها از فایل‌های واقعی باندل خوانده می‌شوند (Vazirmatn OFL از M0) تا
/// خروجی واقعی RTL فارسی راستی‌آزمایی شود؛ فقط ساختار %PDF بررسی می‌شود.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:dadgar_mobile/features/billing/domain/invoice_models.dart';
import 'package:dadgar_mobile/features/billing/pdf/invoice_pdf.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final regular =
      ByteData.view(File('assets/fonts/vazirmatn/Vazirmatn-Regular.ttf')
          .readAsBytesSync()
          .buffer);
  final bold = ByteData.view(
      File('assets/fonts/vazirmatn/Vazirmatn-Bold.ttf')
          .readAsBytesSync()
          .buffer);

  Invoice invoice({
    String status = 'pending',
    int? paidAt,
    int? caseId,
    String clientName = '',
    String lawyerName = '',
  }) =>
      Invoice(
        id: 19,
        amount: 25000000,
        status: status,
        createdAt: 1792701000, // ۱۴۰۵/۰۸/۰۸ تهران
        paidAt: paidAt,
        caseId: caseId,
        clientName: clientName,
        lawyerName: lawyerName,
      );

  group('InvoicePdf — ساخت بایت‌های PDF', () {
    test('خروجی واقعی %PDF با هدر معتبر', () async {
      final bytes = await InvoicePdf.build(
        invoice: invoice(status: 'paid', paidAt: 1792787400, caseId: 7),
        regular: regular,
        bold: bold,
      );

      expect(bytes, isNotEmpty);
      final header = String.fromCharCodes(bytes.take(12));
      expect(header, startsWith('%PDF-'));
      // ساختار چندبخشی واقعی — نسخه‌ی PDF در هدر (مثل %PDF-1.7)
      expect(header, startsWith('%PDF-1.'));
    });

    test('نام فایل — الگوی ثابت با شناسه‌ی فاکتور', () {
      expect(InvoicePdf.fileName(invoice()), 'dadgar-invoice-19.pdf');
    });

    test('حجم خروجی منطقی (فونت ساب‌ست + محتوا) — نه خالی نه ابَرحجیم', () async {
      final bytes = await InvoicePdf.build(
        invoice: invoice(clientName: 'مشتری تست', lawyerName: 'وکیل تست'),
        regular: regular,
        bold: bold,
      );
      // PDF با فونت embed معمولا بین چند کیلوبایت تا چند صد کیلوبایت
      expect(bytes.lengthInBytes, greaterThan(1000));
      expect(bytes.lengthInBytes, lessThan(2 * 1024 * 1024));
    });

    test('دو ساخت متوالی — هر دو معتبر (بدون state نشتی)', () async {
      final a = await InvoicePdf.build(
        invoice: invoice(),
        regular: regular,
        bold: bold,
      );
      final b = await InvoicePdf.build(
        invoice: invoice(status: 'paid', paidAt: 1792787400),
        regular: regular,
        bold: bold,
      );
      expect(String.fromCharCodes(a.take(12)), startsWith('%PDF-1.'));
      expect(String.fromCharCodes(b.take(12)), startsWith('%PDF-1.'));
    });
  });
}
