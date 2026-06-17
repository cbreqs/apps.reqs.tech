import 'package:flutter/material.dart';
import '../app/theme.dart';

/// Generic autocomplete field for receipt entry.
/// Shows all [options] immediately on focus, then filters as the user types.
/// Use [SellerAutocomplete], [CityAutocomplete], or [ZipAutocomplete]
/// for the pre-configured versions.
class ReceiptFieldAutocomplete extends StatelessWidget {
  final TextEditingController controller;
  final List<String> options;
  final String label;
  final TextInputType keyboardType;
  final IconData leadingIcon;
  final bool showDropdownIcon;

  const ReceiptFieldAutocomplete({
    super.key,
    required this.controller,
    required this.options,
    required this.label,
    this.keyboardType = TextInputType.text,
    this.leadingIcon = Icons.history,
    this.showDropdownIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: controller.text),
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.toLowerCase().trim();
        // Show all options on empty/focus; filter when typing
        if (query.isEmpty) return options;
        return options.where((s) => s.toLowerCase().contains(query)).toList();
      },
      onSelected: (value) => controller.text = value,
      fieldViewBuilder: (context, fieldController, focusNode, onSubmitted) {
        fieldController.text = controller.text;
        fieldController.addListener(
            () => controller.text = fieldController.text);
        return TextField(
          controller: fieldController,
          focusNode: focusNode,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            suffixIcon: (!showDropdownIcon || options.isEmpty)
                ? null
                : const Icon(Icons.arrow_drop_down,
                    size: 18, color: Colors.grey),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          // UnconstrainedBox lets us escape the field-width constraint
          // that Autocomplete imposes on the options panel.
          child: UnconstrainedBox(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 220,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: options.length,
                    itemBuilder: (context, i) {
                      final value = options.elementAt(i);
                      return ListTile(
                        dense: true,
                        leading: Icon(leadingIcon,
                            size: 16, color: MogasColors.navy),
                        title: Text(value,
                            style: const TextStyle(fontSize: 14)),
                        onTap: () => onSelected(value),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Missouri gas station seed list ───────────────────────────────────────────
// Common chains found in Missouri. Merged with the user's scan history so
// familiar names appear even before the user has scanned them.
const _moStations = [
  'Break Time',
  'BP',
  "Casey's",
  'Cenex',
  'Chevron',
  'Circle K',
  'Citgo',
  'Conoco',
  'Fast Lane',
  'Flying J',
  'Kum & Go',
  "Love's Travel Stop",
  'MFA Oil',
  'Mobile',
  'Moto Mart',
  'Murphy USA',
  'Onvo',
  'Phillips 66',
  'Pilot',
  'QuikTrip',
  'Road Ranger',
  'Shell',
  'Sinclair',
  'Sunoco',
  'Valero',
  'Walmart',
];

// ── Convenience wrappers ──────────────────────────────────────────────────────

class SellerAutocomplete extends StatelessWidget {
  final TextEditingController controller;
  final List<String> knownSellers;

  const SellerAutocomplete({
    super.key,
    required this.controller,
    required this.knownSellers,
  });

  @override
  Widget build(BuildContext context) {
    // Merge seed list with user history, deduplicating case-insensitively,
    // with user history first so their real names take precedence.
    final seen = <String>{};
    final merged = <String>[];
    for (final s in [...knownSellers, ..._moStations]) {
      if (seen.add(s.toLowerCase())) merged.add(s);
    }
    return ReceiptFieldAutocomplete(
      controller: controller,
      options: merged,
      label: 'Seller Name',
      leadingIcon: Icons.local_gas_station,
    );
  }
}

class CityAutocomplete extends StatelessWidget {
  final TextEditingController controller;
  final List<String> knownCities;

  const CityAutocomplete({
    super.key,
    required this.controller,
    required this.knownCities,
  });

  @override
  Widget build(BuildContext context) => ReceiptFieldAutocomplete(
        controller: controller,
        options: knownCities,
        label: 'City',
        leadingIcon: Icons.location_city,
        showDropdownIcon: false,
      );
}

class ZipAutocomplete extends StatelessWidget {
  final TextEditingController controller;
  final List<String> knownZips;

  const ZipAutocomplete({
    super.key,
    required this.controller,
    required this.knownZips,
  });

  @override
  Widget build(BuildContext context) => ReceiptFieldAutocomplete(
        controller: controller,
        options: knownZips,
        label: 'ZIP',
        keyboardType: TextInputType.number,
        leadingIcon: Icons.pin_drop_outlined,
        showDropdownIcon: false,
      );
}
