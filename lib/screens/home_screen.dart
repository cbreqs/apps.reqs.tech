import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../app/theme.dart';
import '../models/vehicle.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final refundAsync = ref.watch(refundSummaryProvider);
    final vehiclesAsync = ref.watch(vehicleProvider);

    // Show getting-started guide while the placeholder vehicle is in place
    final needsSetup = vehiclesAsync.value?.any(
          (v) => v.vin == kDefaultVehicleVin,
        ) ??
        false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MOgas MOmoney'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Getting started guide — shown until real vehicle is set up
            if (needsSetup) ...[
              _GettingStartedCard(),
              const SizedBox(height: 20),
            ],

            // Refund estimate card
            _RefundCard(refundAsync: refundAsync),
            const SizedBox(height: 20),

            // Filing window banner
            _FilingWindowBanner(),
            const SizedBox(height: 24),

            // Action grid
            Text('Quick Actions',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                _ActionCard(
                  icon: Icons.receipt_long,
                  label: 'My Receipts',
                  onTap: () => Navigator.pushNamed(context, '/all-receipts'),
                ),
                _ActionCard(
                  icon: Icons.document_scanner_outlined,
                  label: 'Scan Receipt',
                  onTap: () => Navigator.pushNamed(context, '/scan-receipt'),
                ),
                _ActionCard(
                  icon: Icons.add_box_outlined,
                  label: 'Add Receipt',
                  onTap: () => Navigator.pushNamed(context, '/add-receipt'),
                ),
                _ActionCard(
                  icon: Icons.directions_car_outlined,
                  label: 'Vehicles',
                  onTap: () => Navigator.pushNamed(context, '/vehicles'),
                ),
                _ActionCard(
                  icon: Icons.picture_as_pdf,
                  label: 'Export Form',
                  color: Theme.of(context).colorScheme.secondary,
                  onTap: () => Navigator.pushNamed(context, '/export'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Getting Started guide ─────────────────────────────────────────────────────

class _GettingStartedCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final col = context.col;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.rocket_launch_outlined, color: col.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Getting Started',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: col.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Follow these steps to set up your first refund claim.',
              style: TextStyle(fontSize: 13, color: col.mutedText),
            ),
            const SizedBox(height: 14),
            _SetupStep(
              number: '1',
              icon: Icons.directions_car_outlined,
              label: 'Update your vehicle info',
              detail: 'Add your VIN, year, make, and fuel type.',
              route: '/vehicles',
            ),
            const Divider(height: 20),
            _SetupStep(
              number: '2',
              icon: Icons.document_scanner_outlined,
              label: 'Scan or enter receipts',
              detail: 'Browse a photo of each fuel receipt.',
              route: '/scan-receipt',
            ),
            const Divider(height: 20),
            _SetupStep(
              number: '3',
              icon: Icons.picture_as_pdf,
              label: 'Export your refund form',
              detail: 'Generate Form 4923-H ready to submit.',
              route: '/export',
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupStep extends StatelessWidget {
  final String number;
  final IconData icon;
  final String label;
  final String detail;
  final String route;

  const _SetupStep({
    required this.number,
    required this.icon,
    required this.label,
    required this.detail,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    final col = context.col;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.pushNamed(context, route),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: col.subtleFill,
              child: Text(
                number,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: col.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Icon(icon, size: 18, color: col.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(detail,
                      style:
                          TextStyle(fontSize: 12, color: col.mutedText)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: col.mutedText),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _RefundCard extends StatelessWidget {
  final AsyncValue refundAsync;
  const _RefundCard({required this.refundAsync});

  @override
  Widget build(BuildContext context) {
    final col = context.col;
    return Card(
      color: col.primary,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estimated Refund',
              style: TextStyle(color: col.onPrimary.withValues(alpha: 0.7), fontSize: 13),
            ),
            const SizedBox(height: 6),
            refundAsync.when(
              loading: () => CircularProgressIndicator(
                  color: col.onPrimary, strokeWidth: 2),
              error: (_, _) => Text('\$—',
                  style: TextStyle(
                      color: col.onPrimary,
                      fontSize: 36,
                      fontWeight: FontWeight.bold)),
              data: (summary) => Text(
                '\$${summary.estimatedRefund.toStringAsFixed(2)}',
                style: TextStyle(
                  color: col.onPrimary,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            refundAsync.maybeWhen(
              data: (summary) => Text(
                '${summary.totalEligibleGallons.toStringAsFixed(3)} eligible gallons × \$0.125/gal',
                style: TextStyle(color: col.onPrimary.withValues(alpha: 0.6), fontSize: 12),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilingWindowBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isOpen = now.month >= 7 && now.month <= 9;

    final surface = Theme.of(context).colorScheme.surface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isOpen
            ? context.col.crimson.withValues(alpha: 0.1)
            : surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isOpen
                ? context.col.crimson.withValues(alpha: 0.4)
                : Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Icon(
            isOpen ? Icons.notifications_active : Icons.schedule,
            color: isOpen
                ? context.col.crimson
                : context.col.mutedText,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isOpen
                  ? 'Filing window is open — submit by September 30, 2026. Eligible receipts: July 1, 2025 – June 30, 2026.'
                  : 'Filing window: July 1 – September 30, 2026. Eligible receipts: July 1, 2025 – June 30, 2026.',
              style: TextStyle(
                fontSize: 13,
                color: isOpen
                    ? context.col.crimson
                    : context.col.labelText,
                fontWeight: isOpen ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  // null = use theme primary; pass an explicit color (e.g. crimson) to override
  final Color? color;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: effectiveColor, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: effectiveColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
