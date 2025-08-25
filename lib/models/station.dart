class Station {
  final String id;
  final String name;
  final String hotline;
  final String streetAddress;
  final String city;
  final String region;

  Station({
    required this.id,
    required this.name,
    required this.hotline,
    required this.streetAddress,
    required this.city,
    required this.region,
  });

  factory Station.fromMap(String id, Map<dynamic, dynamic> map) {
    return Station(
      id: id,
      name: map['name'] ?? 'Unknown Station',
      hotline: map['hotline'] ?? 'No hotline',
      streetAddress: map['streetAddress'] ?? '',
      city: map['city'] ?? '',
      region: map['region'] ?? '',
    );
  }

  String get fullAddress {
    return [streetAddress, city, region].where((part) => part.isNotEmpty).join(', ');
  }
}
