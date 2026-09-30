class UserModel {
  final int id;
  final String email;
  final String fullName;
  final String? phone;
  final String role;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    required this.role,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json["id"] ?? 0,
      email: json["email"] ?? "",
      fullName: json["full_name"] ?? "",
      phone: json["phone"],
      role: json["role"] ?? "SHOPKEEPER",
    );
  }
}

class ShopModel {
  final int id;
  final String name;
  final String ownerName;
  final String phone;
  final String? address;
  final String? gstin;
  final String currency;
  final String currencySymbol;

  ShopModel({
    required this.id,
    required this.name,
    required this.ownerName,
    required this.phone,
    this.address,
    this.gstin,
    this.currency = "INR",
    this.currencySymbol = "₹",
  });

  factory ShopModel.fromJson(Map<String, dynamic> json) {
    return ShopModel(
      id: json["id"] ?? 0,
      name: json["name"] ?? "",
      ownerName: json["owner_name"] ?? "",
      phone: json["phone"] ?? "",
      address: json["address"],
      gstin: json["gstin"],
      currency: json["currency"] ?? "INR",
      currencySymbol: json["currency_symbol"] ?? "₹",
    );
  }
}
