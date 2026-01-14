/// User model representing a user in the system
class User {
  final String id;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String? nationalId;
  final String? dateOfBirth;
  final String? selfiePath;
  final String? idDocumentPath;
  final bool faceVerified;
  final String? googleId;
  final DateTime? createdAt;

  User({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    this.nationalId,
    this.dateOfBirth,
    this.selfiePath,
    this.idDocumentPath,
    this.faceVerified = false,
    this.googleId,
    this.createdAt,
  });

  /// Create User from JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString() ?? '',
      nationalId: json['national_id']?.toString(),
      dateOfBirth: json['date_of_birth']?.toString(),
      selfiePath: json['selfie_path']?.toString(),
      idDocumentPath: json['id_document_path']?.toString(),
      faceVerified: json['face_verified'] == true || json['face_verified'] == 1,
      googleId: json['google_id']?.toString(),
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  /// Convert User to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'phone_number': phoneNumber,
      'national_id': nationalId,
      'date_of_birth': dateOfBirth,
      'selfie_path': selfiePath,
      'id_document_path': idDocumentPath,
      'face_verified': faceVerified,
      'google_id': googleId,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  /// Create copy with updated fields
  User copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phoneNumber,
    String? nationalId,
    String? dateOfBirth,
    String? selfiePath,
    String? idDocumentPath,
    bool? faceVerified,
    String? googleId,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      nationalId: nationalId ?? this.nationalId,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      selfiePath: selfiePath ?? this.selfiePath,
      idDocumentPath: idDocumentPath ?? this.idDocumentPath,
      faceVerified: faceVerified ?? this.faceVerified,
      googleId: googleId ?? this.googleId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
