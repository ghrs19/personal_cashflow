import 'package:intl/intl.dart';

import 'calc.dart';

class CurrencyOption {
  final String code;
  final String symbol;
  const CurrencyOption(this.code, this.symbol);
}

const currencyOptions = <CurrencyOption>[
  CurrencyOption('IDR', 'Rp'),
  CurrencyOption('USD', '\$'),
  CurrencyOption('SGD', 'S\$'),
  CurrencyOption('MYR', 'RM'),
  CurrencyOption('EUR', '€'),
  CurrencyOption('JPY', '¥'),
  CurrencyOption('GBP', '£'),
  CurrencyOption('AUD', 'A\$'),
];

CurrencyOption currencyByCode(String code) => currencyOptions.firstWhere(
      (c) => c.code == code,
      orElse: () => currencyOptions.first,
    );

/// Formats money using the app language for grouping and the selected
/// currency's symbol/code.
String fmtMoney(double value, {required String lang, required String currencyCode}) {
  final c = currencyByCode(currencyCode);
  final decimals = (currencyCode == 'IDR' || currencyCode == 'JPY') ? 0 : 2;
  final grouped = groupNumber(value.abs(), idLocale: lang == 'id', decimals: decimals);
  final sign = value < 0 ? '-' : '';
  return '$sign${c.symbol} $grouped';
}

String fmtMoneySigned(double value, {required String lang, required String currencyCode}) {
  if (value > 0) return '+${fmtMoney(value, lang: lang, currencyCode: currencyCode)}';
  return fmtMoney(value, lang: lang, currencyCode: currencyCode);
}

String fmtDate(DateTime d, {required String lang, bool withTime = false}) {
  final pattern = withTime ? 'd MMM yyyy • HH:mm' : 'EEEE, d MMM yyyy';
  return DateFormat(pattern, lang == 'id' ? 'id_ID' : 'en_US').format(d);
}

String fmtDateShort(DateTime d, {required String lang}) =>
    DateFormat('d MMM yyyy', lang == 'id' ? 'id_ID' : 'en_US').format(d);

String fmtMonth(DateTime d, {required String lang}) =>
    DateFormat('MMMM yyyy', lang == 'id' ? 'id_ID' : 'en_US').format(d);

String fmtDayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
