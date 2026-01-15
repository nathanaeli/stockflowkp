class TenantAccount {
  final int id;
  final int tenantId;
  final String companyName;
  final String? logoUrl;
  final String? logo;
  final String? phone;
  final String? email;
  final String? address;
  final String currency;
  final String? timezone;
  final String? website;
  final String? description;

  TenantAccount({
    required this.id,
    required this.tenantId,
    required this.companyName,
    this.logoUrl,
    this.logo,
    this.phone,
    this.email,
    this.address,
    required this.currency,
    this.timezone,
    this.website,
    this.description,
  });

  factory TenantAccount.fromJson(Map<String, dynamic> json) {
    return TenantAccount(
      id: json['id'],
      tenantId: json['tenant_id'],
      companyName: json['company_name'],
      logoUrl: json['logo_url'],
      logo: json['logo'],
      phone: json['phone'],
      email: json['email'],
      address: json['address'],
      currency: json['currency'],
      timezone: json['timezone'],
      website: json['website'],
      description: json['description'],
    );
  }
}
