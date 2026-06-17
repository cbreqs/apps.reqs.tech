import '../models/receipt_data.dart';

/// Collapse spaces inside date-like strings so "98/13/ 2025" → "98/13/2025",
/// then fix obvious OCR single-digit misreads in the month field (9→0, 1→1, etc.)
String _cleanDate(String raw) {
  // Remove spaces within the date string
  var d = raw.replaceAll(RegExp(r'\s+'), '');
  // Fix month: if month part > 12, leading digit is likely OCR noise → strip it
  final m = RegExp(r'^(\d{1,2})([/-])(\d{1,2})([/-])(\d{2,4})$').firstMatch(d);
  if (m != null) {
    var month = int.tryParse(m.group(1)!) ?? 0;
    final sep1 = m.group(2)!;
    final day = m.group(3)!;
    final sep2 = m.group(4)!;
    final year = m.group(5)!;
    if (month > 12) {
      // Take last digit only (e.g. 98 → 8)
      month = month % 10;
    }
    d = '${month.toString().padLeft(2, '0')}$sep1$day$sep2$year';
  }
  return d;
}

/// Regex corrections for Missouri city names — handles OCR-inserted spaces.
final _cityPatterns = <RegExp, String>{
  RegExp(r'p\s*e\s*c\s*u\s*l\s*i\s*a\s*r', caseSensitive: false): 'Peculiar',
};

/// Normalise a city name: fix OCR-fragmented words and apply known corrections.
String _cleanCity(String raw) {
  final trimmed = raw.trim();
  for (final entry in _cityPatterns.entries) {
    if (entry.key.hasMatch(trimmed)) return entry.value;
  }
  return trimmed;
}

/// Exact matches to skip as seller names.
const _skipSellerExact = {
  'sale', 'fuel sale', 'purchase', 'inside', 'outside', 'credit', 'debit',
  'cash', 'change', 'subtotal', 'total', 'tax', 'approved', 'authorized',
  'declined', 'void', 'refund',
};

/// Prefixes — skip any line whose lowercase content starts with one of these.
const _skipSellerPrefixes = [
  'transaction', 'pump', 'gallons', 'price', 'amount', 'invoice',
  'receipt #', 'receipt#', 'order #', 'order#', 'terminal', 'merchant',
  'auth', 'batch', 'seq', 'item', 'qty', 'unit',
];

bool _shouldSkipAsSeller(String line) {
  final lower = line.toLowerCase().trim();
  if (_skipSellerExact.contains(lower)) return true;
  for (final prefix in _skipSellerPrefixes) {
    if (lower.startsWith(prefix)) return true;
  }
  return false;
}

/// Known chain name patterns → canonical name.
/// Uses regex so OCR noise around the core word still matches.
final _sellerPatterns = <RegExp, String>{
  RegExp(r'fly\s*ing', caseSensitive: false):             'Flying J',
  RegExp(r'casey',          caseSensitive: false):        "Casey's",
  RegExp(r'quik\s*trip|qt\b', caseSensitive: false):     'QuikTrip',
  RegExp(r'phillips\s*66',  caseSensitive: false):        'Phillips 66',
  RegExp(r'bp\b',           caseSensitive: false):        'BP',
  RegExp(r'shell\b',        caseSensitive: false):        'Shell',
  RegExp(r'chevron\b',      caseSensitive: false):        'Chevron',
  RegExp(r'kwik\s*trip',    caseSensitive: false):        'Kwik Trip',
  RegExp(r'love.s\s*travel|loves\s*travel', caseSensitive: false): "Love's Travel Stop",
  RegExp(r'pilot\b',        caseSensitive: false):        'Pilot',
  RegExp(r'murphy\b',       caseSensitive: false):        'Murphy USA',
  RegExp(r'sam.s\s*club',   caseSensitive: false):        "Sam's Club",
  RegExp(r'costco\b',       caseSensitive: false):        'Costco',
  RegExp(r'walmart\b',      caseSensitive: false):        'Walmart',
  RegExp(r'circle\s*k',     caseSensitive: false):        'Circle K',
  RegExp(r'kum\s*&\s*go|kum\s*and\s*go', caseSensitive: false): 'Kum & Go',
};

/// Try to match a line against known chain patterns.
/// Returns the canonical name if matched, null otherwise.
String? _matchKnownChain(String line) {
  for (final entry in _sellerPatterns.entries) {
    if (entry.key.hasMatch(line)) return entry.value;
  }
  return null;
}

/// Normalise a seller name — collapse OCR-inserted spaces within words.
/// e.g. "Casey 's" → "Casey's", "FLYING J" stays "FLYING J"
String _cleanSeller(String raw) {
  // First check if it matches a known chain (handles OCR noise)
  final known = _matchKnownChain(raw);
  if (known != null) return known;
  // Fix possessives broken by OCR spaces: "Casey 's" → "Casey's"
  return raw.replaceAllMapped(
    RegExp(r"(\w)\s+'s\b"),
    (m) => "${m.group(1)}'s",
  ).replaceAllMapped(
    RegExp(r"(\w)\s+([''`]s)\b"),
    (m) => "${m.group(1)}${m.group(2)}",
  );
}

ReceiptData extractReceiptFields(String text) {
  final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

  String? date;
  String? gallons;
  String? total;
  String? fuelType;
  String? seller;
  String? street;
  String? city;
  String? state = 'MO';
  String? zip;

  bool gallonsLabelSeen = false;
  bool pumpTableSeen = false; // Casey's: "Pump Gallons Price" header seen
  // Collect standalone decimal candidates for pump-style receipts
  final List<String> standaloneDecimals = [];

  for (var line in lines) {
    final lower = line.toLowerCase();
    final trimmed = line.trim();

    // ── Date ──────────────────────────────────────────────────────────────
    // Allow optional spaces inside date (e.g. "08/13/ 2025" from OCR)
    final dateMatch = RegExp(r'\b(\d{1,2}\s*[/-]\s*\d{1,2}\s*[/-]\s*\d{2,4})\b').firstMatch(line);
    if (dateMatch != null) date ??= _cleanDate(dateMatch.group(0)!);

    // ── Gallons ───────────────────────────────────────────────────────────
    // Pattern E (highest confidence): a decimal immediately followed by a
    // gallons unit token — "18.638G", "18.638 G", "12.488 GAL", "12.488 GALLONS".
    // The trailing G/GAL is an explicit unit marker, so this beats every
    // heuristic below. Guarded against price-per-gallon lines, where the number
    // follows the unit ("PRICE/GAL $2.779") rather than preceding it.
    if (gallons == null &&
        !lower.contains('/gal') &&
        !lower.contains('per gal') &&
        !lower.contains('ppg') &&
        !lower.contains('price')) {
      final unit = RegExp(
        r'(\d{1,3}\.\d{2,4})\s*G(?:AL(?:LON)?S?)?\b',
        caseSensitive: false,
      ).firstMatch(line);
      if (unit != null) {
        final val = double.tryParse(unit.group(1)!) ?? 0;
        if (val > 0.1 && val < 500) gallons = unit.group(1);
      }
    }

    // Pattern A: "Gallons: 12.488" on same line (Flying J when OCR keeps it together)
    if (gallons == null &&
        lower.contains('gal') &&
        !lower.contains('/gal') &&
        !lower.contains('per gal') &&
        !lower.contains('price') &&
        !lower.contains('disc') &&
        !lower.contains('saving') &&
        !lower.contains('ppg')) {
      final m = RegExp(r'(\d+\.\d{2,4})').firstMatch(line);
      if (m != null) {
        gallons = m.group(1);
        gallonsLabelSeen = false;
      } else {
        // "Gallons:" label with no value — ML Kit split it, value comes later
        gallonsLabelSeen = true;
      }
    }

    // Detect Casey's "Pump Gallons Price" table header
    if (lower.contains('pump') &&
        lower.contains('gallon') &&
        lower.contains('price')) {
      pumpTableSeen = true;
    }

    // Pattern D: Casey's / pump format — "08 11.001 $ 2.699"
    // Matches anywhere in the line (not just start) to handle ML Kit merging
    // the header and data rows into one string.
    if (gallons == null) {
      // Search anywhere in the line for: integer  decimal  $ decimal
      final caseys = RegExp(r'\b(\d{1,2})\s+(\d{1,3}\.\d{3})\s+\$?\s*(\d+\.\d)').firstMatch(trimmed);
      if (caseys != null) {
        final gallonsCandidate = caseys.group(2)!;
        final priceCandidate   = double.tryParse(caseys.group(3)!) ?? 0;
        final val = double.tryParse(gallonsCandidate) ?? 0;
        // Gallons should be larger than price/gal (e.g. 11.001 > 2.699)
        if (val > 0.1 && val < 500 && val > priceCandidate) {
          gallons = gallonsCandidate;
        }
      }

      // Fallback: if pump header was seen, also try the looser standalone form
      // in case ML Kit drops the "$" (e.g. "08 11.001 2.699")
      if (gallons == null && pumpTableSeen) {
        final loose = RegExp(r'\b\d{1,2}\s+(\d{1,3}\.\d{3})\s+\d+\.\d').firstMatch(trimmed);
        if (loose != null) {
          final val = double.tryParse(loose.group(1)!) ?? 0;
          if (val > 0.1 && val < 500) gallons = loose.group(1);
        }
      }
    }

    // Pattern B: standalone decimal after a "Gallons:" label
    // Flying J: ML Kit reads "Gallons:" then pages later "8.028" alone
    if (gallonsLabelSeen && gallons == null) {
      final m = RegExp(r'^(\d{1,3}\.\d{2,4})$').firstMatch(trimmed);
      if (m != null) {
        final val = double.tryParse(m.group(1)!);
        if (val != null && val > 0.1 && val < 500) {
          gallons = m.group(1);
          gallonsLabelSeen = false;
        }
      }
    }

    // Collect standalone decimals for Pattern C (pump receipts, no label)
    // e.g. Waterway: "12.1076" floats with no "Gallons:" label at all
    if (!lower.contains('price') &&
        !lower.contains('total') &&
        !lower.contains('tax') &&
        !lower.contains('disc') &&
        !lower.contains('bal') &&
        !lower.contains('auth') &&
        !lower.contains('saving') &&
        !RegExp(r'[a-z]', caseSensitive: false).hasMatch(trimmed)) {
      final m = RegExp(r'^(\d{1,3}\.\d{2,4})$').firstMatch(trimmed);
      if (m != null) standaloneDecimals.add(m.group(1)!);
    }

    // ── Total ─────────────────────────────────────────────────────────────
    if (total == null && lower.contains('total')) {
      final m = RegExp(r'\$?\s*(\d{1,4}\.\d{2})').firstMatch(line);
      if (m != null) total = m.group(1);
    }

    // ── Fuel type ─────────────────────────────────────────────────────────
    if (fuelType == null) {
      if (lower.contains('premium diesel'))       fuelType = 'Premium Diesel';
      else if (lower.contains('off-road diesel')) fuelType = 'Off-Road Diesel';
      else if (lower.contains('clear diesel'))    fuelType = 'Clear Diesel';
      else if (lower.contains('dyed diesel'))     fuelType = 'Dyed Diesel';
      else if (lower.contains('diesel'))          fuelType = 'Diesel';
      else if (lower.contains('unleaded') ||
               lower.contains('gasoline') ||
               lower.contains('regular') ||
               lower.contains('premium') ||
               lower.contains('e10'))             fuelType = 'Gasoline';
    }

    // ── ZIP ───────────────────────────────────────────────────────────────
    final zipMatch = RegExp(r'\b(\d{5})\b').firstMatch(line);
    if (zip == null && zipMatch != null) zip = zipMatch.group(1);
  }

  // Pattern C: pump-style receipt with no "Gallons:" label
  // Pick the largest standalone decimal — price/gal is always smaller than gallons
  if (gallons == null && standaloneDecimals.isNotEmpty) {
    final candidates = standaloneDecimals
        .map((s) => double.tryParse(s))
        .whereType<double>()
        .where((v) => v > 1.0 && v < 500)
        .toList()
      ..sort((a, b) => b.compareTo(a)); // descending
    if (candidates.isNotEmpty) {
      gallons = candidates.first.toStringAsFixed(
          standaloneDecimals.first.contains('.') &&
                  standaloneDecimals.first.split('.').last.length >= 4
              ? 4
              : 3);
    }
  }

  for (int i = 0; i < lines.length - 1; i++) {
    final isAddressNumber = RegExp(r'^\d{2,5}\s+[A-Za-z]').hasMatch(lines[i]);
    final nextLineIsCityState = lines[i + 1].contains(',') &&
        RegExp(r'[A-Za-z]').hasMatch(lines[i + 1]);
    if (isAddressNumber && nextLineIsCityState) {
      street ??= lines[i];
      final parts = lines[i + 1].split(',');
      city ??= _cleanCity(parts[0]);
      if (parts.length > 1) {
        final stateZip = parts[1].trim().split(' ');
        state ??= stateZip[0];
        if (stateZip.length > 1 && zip == null) {
          zip = stateZip[1];
        }
      }
      break;
    }
  }

  // Seller: find the first line that looks like a business name —
  // at least 3 chars, mostly letters, not a date/number/address line.
  if (seller == null) {
    for (final line in lines) {
      final clean = line.trim();
      if (clean.length < 3) continue;
      if (RegExp(r'^\d').hasMatch(clean)) continue; // skip lines starting with digits
      if (clean.toLowerCase().contains('thank')) continue;
      if (clean.toLowerCase().contains('receipt')) continue;
      if (clean.toLowerCase().contains('welcome')) continue;
      if (RegExp(r'\d{5}').hasMatch(clean)) continue; // skip zip-code lines
      if (_shouldSkipAsSeller(clean)) continue;
      // Prefer all-caps words (typical station name)
      seller = _cleanSeller(clean);
      break;
    }
    seller ??= lines.isNotEmpty ? _cleanSeller(lines[0]) : null;
  }

  return ReceiptData(
    date: date,
    gallons: gallons,
    total: total,
    fuelType: fuelType,
    seller: seller,
    street: street,
    city: city,
    state: state,
    zip: zip,
  );
}
