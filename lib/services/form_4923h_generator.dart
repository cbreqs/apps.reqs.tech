import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/fuel_receipt.dart';
import '../models/profile.dart';
import '../models/vehicle.dart';

/// Generates a print-ready PDF modeled on Missouri Form 4923-H
/// (Claim for Highway Motor Fuel Refund, Section 142.822 RSMo).
class Form4923HGenerator {
  static const double _ratePerGallon = 0.125;

  // Missouri flag palette
  static final _navy = PdfColor.fromHex('#002868');
  static final _crimson = PdfColor.fromHex('#B22234');
  static final _gold = PdfColor.fromHex('#C8960C');
  static final _surface = PdfColor.fromHex('#EDE9E4');

  /// Generate and return the PDF document.
  /// Structure matches the official Form 4923-H:
  ///   Page 1  — Main form: filer info, VIN summary table, totals, signature
  ///   Pages 2+ — One worksheet per vehicle with individual receipt rows
  static Future<pw.Document> generate({
    required Profile profile,
    required List<Vehicle> vehicles,
    required List<FuelReceipt> receipts,
    required int taxYear,
  }) async {
    final doc = pw.Document(
      title: 'Missouri Form 4923-H',
      author: profile.displayName,
    );

    final eligibleVehicles = vehicles.where((v) => v.isEligible).toList();
    final eligibleVins = eligibleVehicles.map((v) => v.vin).toSet();
    final eligibleReceipts =
        receipts.where((r) => eligibleVins.contains(r.vehicleId)).toList();

    final Map<String, List<FuelReceipt>> byVehicle = {};
    for (final v in eligibleVehicles) {
      final vReceipts =
          eligibleReceipts.where((r) => r.vehicleId == v.vin).toList();
      if (vReceipts.isNotEmpty) byVehicle[v.vin] = vReceipts;
    }

    final totalGallons =
        eligibleReceipts.fold(0.0, (sum, r) => sum + r.gallonsValue);
    final totalRefund = totalGallons * _ratePerGallon;

    // ── Page 1: Main Form 4923-H ──────────────────────────────────────────
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        header: (ctx) => _buildHeader(taxYear, ctx),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          pw.SizedBox(height: 8),
          _filerSection(profile),
          pw.SizedBox(height: 12),
          _instructionNote(),
          pw.SizedBox(height: 14),
          _vinSummaryTable(eligibleVehicles, byVehicle),
          pw.SizedBox(height: 14),
          _totalsSection(totalGallons, totalRefund),
          pw.SizedBox(height: 14),
          if (profile.bankRoutingNumber.isNotEmpty) ...[
            _directDepositSection(profile),
            pw.SizedBox(height: 14),
          ],
          _certificationSection(profile, taxYear),
        ],
      ),
    );

    // ── Pages 2+: One worksheet per vehicle ───────────────────────────────
    int worksheetIndex = 1;
    final totalWorksheets = byVehicle.length;
    for (final vehicle in eligibleVehicles) {
      final vReceipts = byVehicle[vehicle.vin];
      if (vReceipts == null || vReceipts.isEmpty) continue;

      final vGallons =
          vReceipts.fold(0.0, (sum, r) => sum + r.gallonsValue);

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
          header: (ctx) =>
              _buildWorksheetHeader(vehicle, worksheetIndex, totalWorksheets, ctx),
          footer: (ctx) => _buildFooter(ctx),
          build: (ctx) => [
            pw.SizedBox(height: 8),
            _worksheetTable(vReceipts),
            pw.SizedBox(height: 8),
            _worksheetTotalRow(vGallons),
            pw.SizedBox(height: 10),
            pw.Text(
              'Claim must be postmarked July 1 – September 30, 2026 '
              'and must accompany Form 4923-H.',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
            ),
          ],
        ),
      );
      worksheetIndex++;
    }

    return doc;
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  static pw.Widget _buildHeader(int taxYear, pw.Context ctx) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _navy,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'MISSOURI DEPARTMENT OF REVENUE',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 9,
                  letterSpacing: 1.2,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Claim for Highway Motor Fuel Refund',
                style: pw.TextStyle(
                  color: PdfColor.fromHex('#C8960C'),
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Section 142.822 RSMo  |  Rate: \$0.125 per gallon',
                style: const pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 8,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Form 4923-H',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: _crimson,
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(3)),
                ),
                child: pw.Text(
                  'Tax Year $taxYear',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────────

  static pw.Widget _buildFooter(pw.Context ctx) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
      ),
      padding: const pw.EdgeInsets.only(top: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Filing period: July 1 - September 30  |  Mail to: Missouri Department of Revenue, PO Box 800, Jefferson City, MO 65105',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
          pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  // ── Filer Info ─────────────────────────────────────────────────────────────

  static pw.Widget _filerSection(Profile profile) {
    final isIndividual = profile.filerType == FilerType.individual;

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _navy, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Section title bar
          pw.Container(
            width: double.infinity,
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: pw.BoxDecoration(
              color: _navy,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(3),
                topRight: pw.Radius.circular(3),
              ),
            ),
            child: pw.Text(
              'CLAIMANT INFORMATION',
              style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.8),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(children: [
                  _labeledField(
                    label: isIndividual ? 'Name' : 'Business Name',
                    value: isIndividual
                        ? [
                            profile.lastName,
                            profile.firstName,
                            profile.middleInitial
                          ]
                            .where((s) => s.isNotEmpty)
                            .join(', ')
                        : profile.businessName,
                    flex: 3,
                  ),
                  pw.SizedBox(width: 8),
                  _labeledField(
                    label: isIndividual ? 'SSN' : 'FEIN',
                    value: isIndividual ? _maskSsn(profile.ssn) : profile.fein,
                    flex: 2,
                  ),
                ]),
                pw.SizedBox(height: 6),
                pw.Row(children: [
                  _labeledField(
                      label: 'Street Address',
                      value: profile.address,
                      flex: 3),
                  pw.SizedBox(width: 8),
                  _labeledField(label: 'City', value: profile.city, flex: 2),
                  pw.SizedBox(width: 8),
                  _labeledField(
                      label: 'State', value: profile.state, flex: 1),
                  pw.SizedBox(width: 8),
                  _labeledField(
                      label: 'ZIP', value: profile.zip, flex: 1),
                ]),
                if (profile.phone.isNotEmpty || profile.email.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  pw.Row(children: [
                    if (profile.phone.isNotEmpty)
                      _labeledField(
                          label: 'Phone', value: profile.phone, flex: 2),
                    if (profile.phone.isNotEmpty) pw.SizedBox(width: 8),
                    if (profile.email.isNotEmpty)
                      _labeledField(
                          label: 'Email', value: profile.email, flex: 3),
                  ]),
                ],
                if (isIndividual && profile.spouseName.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  pw.Row(children: [
                    _labeledField(
                        label: 'Spouse Name',
                        value: profile.spouseName,
                        flex: 3),
                    pw.SizedBox(width: 8),
                    _labeledField(
                        label: "Spouse SSN",
                        value: _maskSsn(profile.spouseSsn),
                        flex: 2),
                  ]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Instruction note ───────────────────────────────────────────────────────

  static pw.Widget _instructionNote() {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: _surface,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Text(
        'List all fuel purchases made for highway use only. Vehicles must have a gross weight of 26,000 lbs or less. '
        'Attach copies of receipts or invoices. Refund rate: \$0.125 per gallon (Section 142.822 RSMo).',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
      ),
    );
  }

  // ── VIN Summary Table (main form, Lines 1-10) ──────────────────────────────

  static pw.Widget _vinSummaryTable(
    List<Vehicle> vehicles,
    Map<String, List<FuelReceipt>> byVehicle,
  ) {
    final hStyle = pw.TextStyle(
        color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold);

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: _navy),
        children: [
          _th('#', hStyle),
          _th('Vehicle Identification Number (VIN)', hStyle),
          _th('Year / Make / Model', hStyle),
          _th('Fuel Type', hStyle),
          _th('≤26,000 lbs', hStyle, align: pw.TextAlign.center),
          _th('Total Gallons', hStyle, align: pw.TextAlign.right),
          _th('Refund', hStyle, align: pw.TextAlign.right),
        ],
      ),
    ];

    int lineNum = 1;
    bool shade = false;
    for (final v in vehicles) {
      final vReceipts = byVehicle[v.vin] ?? [];
      if (vReceipts.isEmpty) continue;
      final gallons = vReceipts.fold(0.0, (s, r) => s + r.gallonsValue);
      final refund = gallons * _ratePerGallon;
      final bg = shade ? _surface : PdfColors.white;
      shade = !shade;
      rows.add(pw.TableRow(
        decoration: pw.BoxDecoration(color: bg),
        children: [
          _td('$lineNum.'),
          _td(v.vin),
          _td('${v.year} ${v.makeModel}'),
          _td(v.fuelType.displayName),
          _td('✓', align: pw.TextAlign.center),
          _td(gallons.toStringAsFixed(3), align: pw.TextAlign.right),
          _td('\$${refund.toStringAsFixed(2)}',
              align: pw.TextAlign.right, color: _gold, bold: true),
        ],
      ));
      lineNum++;
    }

    return pw.Table(
      columnWidths: const {
        0: pw.FixedColumnWidth(20),
        1: pw.FlexColumnWidth(2.5),
        2: pw.FlexColumnWidth(2.0),
        3: pw.FlexColumnWidth(1.2),
        4: pw.FixedColumnWidth(48),
        5: pw.FlexColumnWidth(1.2),
        6: pw.FlexColumnWidth(1.2),
      },
      border: pw.TableBorder(
        horizontalInside:
            const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        left: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        right: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        bottom: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
      ),
      children: rows,
    );
  }

  // ── Worksheet header (per-vehicle pages) ───────────────────────────────────

  static pw.Widget _buildWorksheetHeader(
      Vehicle vehicle, int index, int total, pw.Context ctx) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _navy,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('MISSOURI DEPARTMENT OF REVENUE',
                  style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 9,
                      letterSpacing: 1.2,
                      fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 3),
              pw.Text('Worksheet of Missouri Motor Fuel Tax Paid by Vehicle',
                  style: pw.TextStyle(
                      color: _gold,
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 2),
              pw.Text(
                  'VIN: ${vehicle.vin}  |  ${vehicle.year} ${vehicle.makeModel}  |  ${vehicle.fuelType.displayName}',
                  style: const pw.TextStyle(
                      color: PdfColors.white, fontSize: 8)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Form 4923-H Worksheet',
                  style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(
                    color: _crimson,
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(3))),
                child: pw.Text('Vehicle $index of $total',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Worksheet receipt table (per-vehicle pages) ────────────────────────────

  static const Map<int, pw.TableColumnWidth> _worksheetColWidths = {
    0: pw.FlexColumnWidth(1.6), // Date
    1: pw.FlexColumnWidth(2.0), // Seller Name
    2: pw.FlexColumnWidth(2.0), // Street Address
    3: pw.FlexColumnWidth(1.4), // City
    4: pw.FixedColumnWidth(24), // State
    5: pw.FixedColumnWidth(40), // ZIP
    6: pw.FlexColumnWidth(1.2), // Gallons
  };

  static pw.Widget _worksheetTable(List<FuelReceipt> receipts) {
    final hStyle = pw.TextStyle(
        color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold);

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: _navy),
        children: [
          _th('Date', hStyle),
          _th('Seller Name', hStyle),
          _th('Street Address', hStyle),
          _th('City', hStyle),
          _th('ST', hStyle, align: pw.TextAlign.center),
          _th('ZIP', hStyle),
          _th('Gallons', hStyle, align: pw.TextAlign.right),
        ],
      ),
    ];

    bool shade = false;
    for (final r in receipts) {
      final bg = shade ? _surface : PdfColors.white;
      shade = !shade;
      rows.add(pw.TableRow(
        decoration: pw.BoxDecoration(color: bg),
        children: [
          _td(r.date),
          _td(r.sellerName),
          _td(r.sellerStreet),
          _td(r.sellerCity),
          _td(r.sellerState, align: pw.TextAlign.center),
          _td(r.sellerZip),
          _td(r.gallons, align: pw.TextAlign.right),
        ],
      ));
    }

    return pw.Table(
      columnWidths: _worksheetColWidths,
      border: pw.TableBorder(
        horizontalInside:
            const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        left: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        right: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        bottom: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
      ),
      children: rows,
    );
  }

  static pw.Widget _worksheetTotalRow(double gallons) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: pw.BoxDecoration(
            color: _navy,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Row(children: [
            pw.Text('Total Gallons:',
                style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(width: 12),
            pw.Text(gallons.toStringAsFixed(3),
                style: pw.TextStyle(
                    color: _gold,
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold)),
          ]),
        ),
      ],
    );
  }

  // ── Totals ─────────────────────────────────────────────────────────────────

  static pw.Widget _totalsSection(double gallons, double refund) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 260,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _navy, width: 0.8),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Column(
            children: [
              _totalRow('Total Eligible Gallons',
                  '${gallons.toStringAsFixed(3)} gal', false),
              _totalRow(
                  'Refund Rate', '\$0.125 per gallon', false),
              _totalRow(
                'Estimated Refund',
                '\$${refund.toStringAsFixed(2)}',
                true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _totalRow(String label, String value, bool highlight) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: highlight ? _gold : null,
        border: const pw.Border(
            bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight:
                    highlight ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: highlight ? PdfColors.white : PdfColors.grey800,
              )),
          pw.Text(value,
              style: pw.TextStyle(
                fontSize: highlight ? 12 : 9,
                fontWeight: pw.FontWeight.bold,
                color: highlight ? PdfColors.white : _navy,
              )),
        ],
      ),
    );
  }

  // ── Direct Deposit ─────────────────────────────────────────────────────────

  static pw.Widget _directDepositSection(Profile profile) {
    return _sectionBox(
      title: 'DIRECT DEPOSIT (OPTIONAL)',
      child: pw.Row(children: [
        _labeledField(label: 'Routing Number',
            value: profile.bankRoutingNumber, flex: 2),
        pw.SizedBox(width: 8),
        _labeledField(label: 'Account Number',
            value: profile.bankAccountNumber, flex: 2),
        pw.SizedBox(width: 8),
        _labeledField(
            label: 'Account Type',
            value: profile.bankAccountType?.name.toUpperCase() ?? '',
            flex: 1),
      ]),
    );
  }

  // ── Certification ──────────────────────────────────────────────────────────
  // NOTE: We do NOT use _sectionBox here because pw.MultiPage cannot render
  // content inside a bordered Container that spans a page break — the box
  // shows up but its children disappear. Inline widgets work fine.

  static pw.Widget _certificationSection(Profile profile, int taxYear) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Section title bar (same style as _sectionBox header)
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: pw.BoxDecoration(
            color: _navy,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Text(
            'CERTIFICATION',
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ),
        pw.SizedBox(height: 10),

        pw.Text(
          'Under penalties of perjury, I declare that I have examined this claim, and to the best of my knowledge '
          'and belief it is true, correct, and complete. I certify that the fuel listed above was used exclusively '
          'for highway use in vehicles with a gross weight of 26,000 lbs or less, and that I am entitled to '
          'the refund claimed.',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
        ),
        pw.SizedBox(height: 16),

        pw.Row(children: [
          _signatureLine(label: 'Signature', flex: 3),
          pw.SizedBox(width: 16),
          _signatureLine(label: 'Date', flex: 1),
        ]),
        pw.SizedBox(height: 14),

        pw.Row(children: [
          _signatureLine(
              label: profile.filerType == FilerType.individual
                  ? 'Print Name'
                  : 'Title / Authorized Representative',
              flex: 3),
          pw.SizedBox(width: 16),
          _signatureLine(label: 'Daytime Phone', flex: 1),
        ]),
        pw.SizedBox(height: 12),

        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#E8E4DE'),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Text(
            'Mail completed form with original receipts attached to: '
            'Missouri Department of Revenue, PO Box 800, Jefferson City, MO 65105-0800',
            style: pw.TextStyle(
              fontSize: 8,
              color: _navy,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────

  static pw.Widget _sectionBox(
      {required String title, required pw.Widget child}) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _navy, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: pw.BoxDecoration(
              color: _navy,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(3),
                topRight: pw.Radius.circular(3),
              ),
            ),
            child: pw.Text(
              title,
              style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.8),
            ),
          ),
          pw.Padding(padding: const pw.EdgeInsets.all(10), child: child),
        ],
      ),
    );
  }

  static pw.Widget _labeledField(
      {required String label, required String value, required int flex}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label.toUpperCase(),
              style: const pw.TextStyle(
                  fontSize: 6.5,
                  color: PdfColors.grey600,
                  letterSpacing: 0.4)),
          pw.SizedBox(height: 2),
          pw.Container(
            width: double.infinity,
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey400)),
            ),
            child: pw.Text(
              value.isNotEmpty ? value : ' ',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _signatureLine(
      {required String label, required int flex}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            height: 24,
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey700)),
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(label,
              style: const pw.TextStyle(
                  fontSize: 7, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  static pw.Widget _th(String text, pw.TextStyle style,
      {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(text, style: style, textAlign: align),
    );
  }

  static pw.Widget _td(String text,
      {pw.TextAlign align = pw.TextAlign.left,
      PdfColor? color,
      bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 8,
          color: color ?? PdfColors.grey900,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  /// Mask SSN for display: XXX-XX-1234
  static String _maskSsn(String ssn) {
    final digits = ssn.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 9) return ssn;
    return 'XXX-XX-${digits.substring(5)}';
  }
}
