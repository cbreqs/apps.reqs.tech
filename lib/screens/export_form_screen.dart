import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../app/theme.dart' show MogasColors, mogasTheme, mogasDarkTheme, MogasColors2;
import '../models/profile.dart';
import '../providers/providers.dart';
import '../services/form_4923h_generator.dart';

class ExportFormScreen extends ConsumerStatefulWidget {
  const ExportFormScreen({super.key});

  @override
  ConsumerState<ExportFormScreen> createState() => _ExportFormScreenState();
}

class _ExportFormScreenState extends ConsumerState<ExportFormScreen> {
  bool _generating = false;
  bool _disclaimerAccepted = false;

  // Filing period: the year prior to the July–Sept filing window.
  // e.g. filing in 2026 covers fuel purchased in 2025.
  int get _taxYear => DateTime.now().year - 1;

  Future<bool> _showDisclaimer() async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.gavel_outlined, color: Theme.of(ctx).colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Before You Export'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            'You are responsible for verifying the accuracy of all '
            'information submitted to the Missouri Department of Revenue '
            'on Form 4923-H.\n\n'
            'MOgas MOmoney helps you organize and calculate your refund '
            'claim, but does not independently verify seller names, '
            'addresses, ZIP codes, gallons, or your personal filing '
            'information. Errors or omissions in your submission are '
            'your responsibility.\n\n'
            'By continuing, you confirm that you have reviewed your '
            'receipts and profile information and that they are accurate '
            'to the best of your knowledge.',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('I Understand'),
          ),
        ],
      ),
    );
    return accepted == true;
  }

  Future<void> _generate({required bool share}) async {
    if (!_disclaimerAccepted) {
      final accepted = await _showDisclaimer();
      if (!accepted) return;
      _disclaimerAccepted = true;
    }
    final profile = ref.read(profileProvider);
    final vehiclesAsync = ref.read(vehicleProvider);
    final db = ref.read(dbProvider);

    if (!profile.isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Complete your profile before generating the form.'),
          action: SnackBarAction(
            label: 'Go',
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
        ),
      );
      return;
    }

    final vehicles = vehiclesAsync.valueOrNull ?? [];
    if (vehicles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one eligible vehicle first.')),
      );
      return;
    }

    setState(() => _generating = true);

    final receipts = await db.getAllReceipts();
    final doc = await Form4923HGenerator.generate(
      profile: profile,
      vehicles: vehicles,
      receipts: receipts,
      taxYear: _taxYear,
    );
    final bytes = await doc.save();

    if (!mounted) return;
    setState(() => _generating = false);

    if (share) {
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'MO_Form4923H_$_taxYear.pdf',
      );
    } else {
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'MO Form 4923-H - $_taxYear',
        format: PdfPageFormat.letter,
        usePrinterSettings: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final vehiclesAsync = ref.watch(vehicleProvider);
    final summaryAsync = ref.watch(refundSummaryProvider);

    final vehicles = vehiclesAsync.valueOrNull ?? [];
    final eligibleVehicles = vehicles.where((v) => v.isEligible).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Export Form 4923-H')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Profile status ──────────────────────────────────────────────
          _StatusTile(
            icon: Icons.person_outline,
            label: 'Filer Profile',
            value: profile.isComplete ? profile.displayName : 'Incomplete',
            ok: profile.isComplete,
            onTap: () => Navigator.pushNamed(context, '/profile'),
          ),
          const SizedBox(height: 8),

          // ── Vehicle count ───────────────────────────────────────────────
          _StatusTile(
            icon: Icons.directions_car_outlined,
            label: 'Eligible Vehicles',
            value: '${eligibleVehicles.length} vehicle${eligibleVehicles.length == 1 ? '' : 's'}',
            ok: eligibleVehicles.isNotEmpty,
            onTap: () => Navigator.pushNamed(context, '/vehicles'),
          ),
          const SizedBox(height: 8),

          // ── Refund summary ──────────────────────────────────────────────
          summaryAsync.when(
            loading: () => const _SummaryCardShimmer(),
            error: (e, _) => Text('Error: $e'),
            data: (summary) => _SummaryCard(
              gallons: summary.totalEligibleGallons,
              refund: summary.estimatedRefund,
              taxYear: _taxYear,
            ),
          ),

          const SizedBox(height: 24),

          // ── Filing window banner ────────────────────────────────────────
          _FilingWindowBanner(taxYear: _taxYear),

          const SizedBox(height: 24),

          // ── Action buttons ──────────────────────────────────────────────
          ElevatedButton.icon(
            icon: _generating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.preview_outlined),
            label: Text(_generating ? 'Generating…' : 'Preview PDF'),
            onPressed: _generating ? null : () => _generate(share: false),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.share_outlined),
            label: const Text('Save / Share PDF'),
            onPressed: _generating ? null : () => _generate(share: true),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),

          const SizedBox(height: 24),

          // ── Disclaimer ──────────────────────────────────────────────────
          Builder(builder: (context) {
            final primary = Theme.of(context).colorScheme.primary;
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 14, color: primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Review the generated form before submitting. '
                      'Sign and mail with original receipts attached to: '
                      'Missouri Department of Revenue, PO Box 800, Jefferson City, MO 65105-0800.',
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StatusTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool ok;
  final VoidCallback onTap;

  const _StatusTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.ok,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      tileColor: context.col.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
            color: ok ? context.col.subtleBorder : context.col.crimson,
            width: ok ? 1 : 1.5),
      ),
      leading: Icon(icon, color: context.col.primary),
      title: Text(label,
          style: TextStyle(fontSize: 13, color: context.col.labelText)),
      subtitle: Text(value,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ok ? context.col.primary : context.col.crimson)),
      trailing: Icon(
        ok ? Icons.check_circle_outline : Icons.warning_amber_outlined,
        color: ok ? Colors.green : context.col.crimson,
        size: 20,
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final double gallons;
  final double refund;
  final int taxYear;

  const _SummaryCard({
    required this.gallons,
    required this.refund,
    required this.taxYear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.col.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat(label: 'Tax Year', value: '$taxYear'),
          _divider(),
          _Stat(label: 'Eligible Gallons', value: gallons.toStringAsFixed(3)),
          _divider(),
          _Stat(
            label: 'Estimated Refund',
            value: '\$${refund.toStringAsFixed(2)}',
            highlight: true,
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 40, color: Colors.white24);
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _Stat({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
              fontSize: highlight ? 22 : 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            )),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: context.col.onPrimary.withValues(alpha: 0.6))),
      ],
    );
  }
}

class _SummaryCardShimmer extends StatelessWidget {
  const _SummaryCardShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _FilingWindowBanner extends StatelessWidget {
  final int taxYear;
  const _FilingWindowBanner({required this.taxYear});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isOpen = now.month >= 7 && now.month <= 9;

    final col = context.col;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isOpen
            ? col.crimson.withValues(alpha: 0.1)
            : col.subtleFill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOpen ? col.crimson.withValues(alpha: 0.5) : col.divider,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isOpen ? Icons.event_available : Icons.event_outlined,
            color: isOpen ? col.crimson : col.mutedText,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isOpen
                  ? 'Filing window is open — submit by September 30, 2026. Eligible receipts: July 1, 2025 – June 30, 2026.'
                  : 'Filing window: July 1 – September 30, 2026. Eligible receipts: July 1, 2025 – June 30, 2026.',
              style: TextStyle(
                fontSize: 12,
                color: isOpen ? col.crimson : col.labelText,
                fontWeight: isOpen ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
