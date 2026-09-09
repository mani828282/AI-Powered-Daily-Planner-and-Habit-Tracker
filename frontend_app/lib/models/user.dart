class User {
  final int userId;
  final String phoneNumber;
  final String fullName;
  final String? email;
  final String? profilePicture;

  User({
    required this.userId,
    required this.phoneNumber,
    required this.fullName,
    this.email,
    this.profilePicture,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'],
      phoneNumber: json['phone_number'],
      fullName: json['full_name'],
      email: json['email'],
      profilePicture: json['profile_picture'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'phone_number': phoneNumber,
      'full_name': fullName,
      'email': email,
      'profile_picture': profilePicture,
    };
  }
}
