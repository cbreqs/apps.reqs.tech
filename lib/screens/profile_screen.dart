import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme.dart';
import '../models/profile.dart';
import '../providers/providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  bool _bankExpanded = false;

  // Filer type
  late FilerType _filerType;

  // Individual
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _middleCtrl = TextEditingController();
  final _ssnCtrl = TextEditingController();
  final _spouseNameCtrl = TextEditingController();
  final _spouseSsnCtrl = TextEditingController();

  // Business
  final _businessNameCtrl = TextEditingController();
  final _feinCtrl = TextEditingController();

  // Shared
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController(text: 'MO');
  final _zipCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // Bank
  final _routingCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  BankAccountType? _bankAccountType;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider);
    _loadFrom(profile);
  }

  void _loadFrom(Profile p) {
    _filerType = p.filerType;
    _firstNameCtrl.text = p.firstName;
    _lastNameCtrl.text = p.lastName;
    _middleCtrl.text = p.middleInitial;
    _ssnCtrl.text = p.ssn;
    _spouseNameCtrl.text = p.spouseName;
    _spouseSsnCtrl.text = p.spouseSsn;
    _businessNameCtrl.text = p.businessName;
    _feinCtrl.text = p.fein;
    _addressCtrl.text = p.address;
    _cityCtrl.text = p.city;
    _stateCtrl.text = p.state.isNotEmpty ? p.state : 'MO';
    _zipCtrl.text = p.zip;
    _emailCtrl.text = p.email;
    _phoneCtrl.text = p.phone;
    _routingCtrl.text = p.bankRoutingNumber;
    _accountCtrl.text = p.bankAccountNumber;
    _bankAccountType = p.bankAccountType;
    if (p.bankRoutingNumber.isNotEmpty || p.bankAccountNumber.isNotEmpty) {
      _bankExpanded = true;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _firstNameCtrl, _lastNameCtrl, _middleCtrl, _ssnCtrl,
      _spouseNameCtrl, _spouseSsnCtrl, _businessNameCtrl, _feinCtrl,
      _addressCtrl, _cityCtrl, _stateCtrl, _zipCtrl,
      _emailCtrl, _phoneCtrl, _routingCtrl, _accountCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final profile = Profile(
      filerType: _filerType,
      firstName: _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      middleInitial: _middleCtrl.text.trim(),
      ssn: _ssnCtrl.text.trim(),
      spouseName: _spouseNameCtrl.text.trim(),
      spouseSsn: _spouseSsnCtrl.text.trim(),
      businessName: _businessNameCtrl.text.trim(),
      fein: _feinCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      state: _stateCtrl.text.trim(),
      zip: _zipCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      fax: '',
      bankRoutingNumber: _routingCtrl.text.trim(),
      bankAccountNumber: _accountCtrl.text.trim(),
      bankAccountType: _bankAccountType,
    );

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    await ref.read(profileProvider.notifier).save(profile);

    setState(() => _saving = false);
    messenger.showSnackBar(
      const SnackBar(content: Text('Profile saved')),
    );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Save',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Appearance ───────────────────────────────────────────────
            _SectionHeader(label: 'Appearance'),
            const SizedBox(height: 10),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('Auto'),
                  icon: Icon(Icons.brightness_auto_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode_outlined),
                ),
              ],
              selected: {ref.watch(themeModeProvider)},
              onSelectionChanged: (selection) =>
                  ref.read(themeModeProvider.notifier).setMode(selection.first),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // ── Filer Type ───────────────────────────────────────────────
            _SectionHeader(label: 'Filer Type'),
            const SizedBox(height: 8),
            SegmentedButton<FilerType>(
              segments: const [
                ButtonSegment(
                    value: FilerType.individual,
                    label: Text('Individual'),
                    icon: Icon(Icons.person_outline)),
                ButtonSegment(
                    value: FilerType.business,
                    label: Text('Business'),
                    icon: Icon(Icons.business_outlined)),
              ],
              selected: {_filerType},
              onSelectionChanged: (s) => setState(() => _filerType = s.first),
              style: ButtonStyle(
                iconColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected)
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.primary),
              ),
            ),

            const SizedBox(height: 24),

            // ── Identity ─────────────────────────────────────────────────
            if (_filerType == FilerType.individual) ...[
              _SectionHeader(label: 'Identity'),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    flex: 3,
                    child: _Field(
                        label: 'First Name',
                        ctrl: _firstNameCtrl,
                        required: true)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 64,
                  child: _Field(label: 'M.I.', ctrl: _middleCtrl),
                ),
                const SizedBox(width: 8),
                Expanded(
                    flex: 3,
                    child: _Field(
                        label: 'Last Name',
                        ctrl: _lastNameCtrl,
                        required: true)),
              ]),
              const SizedBox(height: 12),
              _SsnField(label: 'Social Security Number', ctrl: _ssnCtrl),
              const _LocalOnlyHint(),
              const SizedBox(height: 20),
              _SectionHeader(label: 'Spouse (optional)'),
              const SizedBox(height: 12),
              _Field(label: 'Spouse Full Name', ctrl: _spouseNameCtrl),
              const SizedBox(height: 12),
              _SsnField(
                  label: "Spouse's Social Security Number",
                  ctrl: _spouseSsnCtrl),
              const _LocalOnlyHint(),
            ] else ...[
              _SectionHeader(label: 'Business Identity'),
              const SizedBox(height: 12),
              _Field(
                  label: 'Business Name',
                  ctrl: _businessNameCtrl,
                  required: true),
              const SizedBox(height: 12),
              _Field(
                  label: 'Federal EIN (XX-XXXXXXX)',
                  ctrl: _feinCtrl,
                  required: true,
                  keyboardType: TextInputType.number),
              const _LocalOnlyHint(),
            ],

            const SizedBox(height: 24),

            // ── Mailing Address ──────────────────────────────────────────
            _SectionHeader(label: 'Mailing Address'),
            const SizedBox(height: 12),
            _Field(
                label: 'Street Address',
                ctrl: _addressCtrl,
                required: true),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  flex: 3,
                  child: _Field(
                      label: 'City', ctrl: _cityCtrl, required: true)),
              const SizedBox(width: 8),
              SizedBox(
                width: 64,
                child: _Field(label: 'State', ctrl: _stateCtrl),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: _Field(
                    label: 'ZIP',
                    ctrl: _zipCtrl,
                    required: true,
                    keyboardType: TextInputType.number),
              ),
            ]),

            const SizedBox(height: 24),

            // ── Contact ──────────────────────────────────────────────────
            _SectionHeader(label: 'Contact'),
            const SizedBox(height: 12),
            _PhoneField(ctrl: _phoneCtrl),
            const SizedBox(height: 12),
            _EmailField(ctrl: _emailCtrl),
            const SizedBox(height: 12),
            const SizedBox(height: 24),

            // ── Direct Deposit (optional) ────────────────────────────────
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _bankExpanded = !_bankExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Icon(Icons.account_balance_outlined,
                      color: context.col.primary, size: 18),
                  const SizedBox(width: 8),
                  _SectionHeader(label: 'Direct Deposit (optional)'),
                  const Spacer(),
                  Icon(
                    _bankExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: context.col.primary,
                  ),
                ]),
              ),
            ),

            if (_bankExpanded) ...[
              const SizedBox(height: 12),
              _Field(
                  label: 'Routing Number',
                  ctrl: _routingCtrl,
                  keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              _Field(
                  label: 'Account Number',
                  ctrl: _accountCtrl,
                  keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              SegmentedButton<BankAccountType>(
                segments: const [
                  ButtonSegment(
                      value: BankAccountType.checking,
                      label: Text('Checking')),
                  ButtonSegment(
                      value: BankAccountType.savings,
                      label: Text('Savings')),
                ],
                selected: _bankAccountType != null
                    ? {_bankAccountType!}
                    : <BankAccountType>{},
                emptySelectionAllowed: true,
                onSelectionChanged: (s) => setState(
                    () => _bankAccountType = s.isEmpty ? null : s.first),
              ),
            ],

            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: context.col.onPrimary))
                  : const Text('Save Profile'),
            ),

            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.col.subtleFill,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline, size: 16, color: context.col.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your information — including SSNs and bank details — is stored '
                      'only on this device and is never transmitted or shared. '
                      'It is used solely to populate your Missouri Form 4923-H for printing.',
                      style: TextStyle(fontSize: 12, color: context.col.labelText),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: TextStyle(
            color: context.col.primary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 0.5));
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final bool required;
  final TextInputType keyboardType;

  const _Field({
    required this.label,
    required this.ctrl,
    this.required = false,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label, isDense: true),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
    );
  }
}

/// Small inline reassurance shown directly under sensitive fields.
class _LocalOnlyHint extends StatelessWidget {
  const _LocalOnlyHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 12, color: context.col.primary),
          const SizedBox(width: 4),
          Text(
            'Stored on this device only — never shared or transmitted.',
            style: TextStyle(fontSize: 11, color: context.col.primary),
          ),
        ],
      ),
    );
  }
}

/// SSN field with obscured text and XXX-XX-XXXX hint.
class _SsnField extends StatefulWidget {
  final String label;
  final TextEditingController ctrl;
  const _SsnField({required this.label, required this.ctrl});

  @override
  State<_SsnField> createState() => _SsnFieldState();
}

class _SsnFieldState extends State<_SsnField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.ctrl,
      obscureText: _obscure,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: 'XXX-XX-XXXX',
        isDense: true,
        suffixIcon: IconButton(
          icon: Icon(
            _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            size: 18,
            color: context.col.primary,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}

/// Email field with basic format validation.
class _EmailField extends StatelessWidget {
  final TextEditingController ctrl;
  const _EmailField({required this.ctrl});

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      keyboardType: TextInputType.emailAddress,
      decoration: const InputDecoration(labelText: 'Email', isDense: true),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return null; // optional field
        if (!_emailRegex.hasMatch(v.trim())) return 'Enter a valid email address';
        return null;
      },
    );
  }
}

/// Phone field that auto-formats to (XXX) XXX-XXXX as the user types.
class _PhoneField extends StatelessWidget {
  final TextEditingController ctrl;
  const _PhoneField({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      keyboardType: TextInputType.phone,
      inputFormatters: [_PhoneInputFormatter()],
      decoration: const InputDecoration(
        labelText: 'Phone',
        hintText: '(XXX) XXX-XXXX',
        isDense: true,
      ),
    );
  }
}

/// Formats digits to (XXX) XXX-XXXX on the fly.
class _PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();

    for (int i = 0; i < digits.length && i < 10; i++) {
      if (i == 0) buffer.write('(');
      if (i == 3) buffer.write(') ');
      if (i == 6) buffer.write('-');
      buffer.write(digits[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
