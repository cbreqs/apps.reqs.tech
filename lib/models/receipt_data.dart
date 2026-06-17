class ReceiptData {
  final String? date;
  final String? gallons;
  final String? total;
  final String? fuelType;
  final String? seller;
  final String? street;
  final String? city;
  final String? state;
  final String? zip;

  ReceiptData({
    this.date,
    this.gallons,
    this.total,
    this.fuelType,
    this.seller,
    this.street,
    this.city,
    this.state,
    this.zip,
  });

  factory ReceiptData.fromJson(Map<String, dynamic> json) {
    return ReceiptData(
      date: json['date'] as String?,
      gallons: json['gallons'] as String?,
      total: json['total'] as String?,
      fuelType: json['fuelType'] as String?,
      seller: json['seller'] as String?,
      street: json['street'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      zip: json['zip'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'gallons': gallons,
        'total': total,
        'fuelType': fuelType,
        'seller': seller,
        'street': street,
        'city': city,
        'state': state,
        'zip': zip,
      };
}
