/// Filer type drives which fields are shown in the profile form
/// and which fields appear on the generated Form 4923-H.
enum FilerType { individual, business }

/// Profile is stored via flutter_secure_storage (sensitive fields)
/// and shared_preferences (non-sensitive fields).
///
/// Sensitive fields (never logged or sent to analytics):
///   ssn, spouseSsn, fein, bankRoutingNumber, bankAccountNumber
class Profile {
  final FilerType filerType;

  // Individual fields
  final String firstName;
  final String lastName;
  final String middleInitial;
  final String ssn; // encrypted at rest via flutter_secure_storage
  final String spouseName;
  final String spouseSsn; // encrypted at rest

  // Business fields
  final String businessName;
  final String fein; // encrypted at rest

  // Shared fields
  final String address;
  final String city;
  final String state;
  final String zip;
  final String email;
  final String phone;
  final String fax;

  // Optional direct deposit (all encrypted at rest)
  final String bankRoutingNumber;
  final String bankAccountNumber;
  final BankAccountType? bankAccountType;

  const Profile({
    this.filerType = FilerType.individual,
    this.firstName = '',
    this.lastName = '',
    this.middleInitial = '',
    this.ssn = '',
    this.spouseName = '',
    this.spouseSsn = '',
    this.businessName = '',
    this.fein = '',
    this.address = '',
    this.city = '',
    this.state = 'MO',
    this.zip = '',
    this.email = '',
    this.phone = '',
    this.fax = '',
    this.bankRoutingNumber = '',
    this.bankAccountNumber = '',
    this.bankAccountType,
  });

  /// Display name shown in the app header
  String get displayName {
    if (filerType == FilerType.business) {
      return businessName.isNotEmpty ? businessName : 'Business';
    }
    final parts = [firstName, lastName].where((s) => s.isNotEmpty);
    return parts.isNotEmpty ? parts.join(' ') : 'My Profile';
  }

  bool get isComplete {
    if (filerType == FilerType.individual) {
      return firstName.isNotEmpty &&
          lastName.isNotEmpty &&
          ssn.isNotEmpty &&
          address.isNotEmpty &&
          city.isNotEmpty &&
          zip.isNotEmpty;
    } else {
      return businessName.isNotEmpty &&
          fein.isNotEmpty &&
          address.isNotEmpty &&
          city.isNotEmpty &&
          zip.isNotEmpty;
    }
  }

  Profile copyWith({
    FilerType? filerType,
    String? firstName,
    String? lastName,
    String? middleInitial,
    String? ssn,
    String? spouseName,
    String? spouseSsn,
    String? businessName,
    String? fein,
    String? address,
    String? city,
    String? state,
    String? zip,
    String? email,
    String? phone,
    String? fax,
    String? bankRoutingNumber,
    String? bankAccountNumber,
    BankAccountType? bankAccountType,
  }) {
    return Profile(
      filerType: filerType ?? this.filerType,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      middleInitial: middleInitial ?? this.middleInitial,
      ssn: ssn ?? this.ssn,
      spouseName: spouseName ?? this.spouseName,
      spouseSsn: spouseSsn ?? this.spouseSsn,
      businessName: businessName ?? this.businessName,
      fein: fein ?? this.fein,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      zip: zip ?? this.zip,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      fax: fax ?? this.fax,
      bankRoutingNumber: bankRoutingNumber ?? this.bankRoutingNumber,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankAccountType: bankAccountType ?? this.bankAccountType,
    );
  }

  /// Non-sensitive fields only — safe to store in SharedPreferences.
  Map<String, dynamic> toPrefsJson() => {
        'filerType': filerType.name,
        'firstName': firstName,
        'lastName': lastName,
        'middleInitial': middleInitial,
        'spouseName': spouseName,
        'businessName': businessName,
        'address': address,
        'city': city,
        'state': state,
        'zip': zip,
        'email': email,
        'phone': phone,
        'fax': fax,
        'bankAccountType': bankAccountType?.name,
      };

  factory Profile.fromPrefsJson(Map<String, dynamic> json) => Profile(
        filerType: FilerType.values.byName(
            json['filerType'] as String? ?? FilerType.individual.name),
        firstName: json['firstName'] as String? ?? '',
        lastName: json['lastName'] as String? ?? '',
        middleInitial: json['middleInitial'] as String? ?? '',
        spouseName: json['spouseName'] as String? ?? '',
        businessName: json['businessName'] as String? ?? '',
        address: json['address'] as String? ?? '',
        city: json['city'] as String? ?? '',
        state: json['state'] as String? ?? 'MO',
        zip: json['zip'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        fax: json['fax'] as String? ?? '',
        bankAccountType: json['bankAccountType'] != null
            ? BankAccountType.values.byName(json['bankAccountType'] as String)
            : null,
      );

  /// Sensitive fields — must be stored in flutter_secure_storage (Android Keystore-backed).
  Map<String, String> toSecureJson() => {
        'ssn': ssn,
        'spouseSsn': spouseSsn,
        'fein': fein,
        'bankRoutingNumber': bankRoutingNumber,
        'bankAccountNumber': bankAccountNumber,
      };

  /// Merges secure-storage values into an existing Profile loaded from prefs.
  Profile withSecureFields(Map<String, String> secure) => copyWith(
        ssn: secure['ssn'] ?? ssn,
        spouseSsn: secure['spouseSsn'] ?? spouseSsn,
        fein: secure['fein'] ?? fein,
        bankRoutingNumber: secure['bankRoutingNumber'] ?? bankRoutingNumber,
        bankAccountNumber: secure['bankAccountNumber'] ?? bankAccountNumber,
      );
}

enum BankAccountType { checking, savings }
