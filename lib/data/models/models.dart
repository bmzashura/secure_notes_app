// lib/data/models/models.dart

class User {
  final String id;
  final String email;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['user_id'] as String,
      email: json['email'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class Note {
  final String id;
  final String? titleEncrypted;
  final String iv;
  final String salt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Decrypted fields (local only)
  final String? decryptedTitle;
  final String? decryptedContent;

  Note({
    required this.id,
    this.titleEncrypted,
    required this.iv,
    required this.salt,
    required this.createdAt,
    required this.updatedAt,
    this.decryptedTitle,
    this.decryptedContent,
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String,
      titleEncrypted: json['title_encrypted'] as String?,
      iv: json['iv'] as String,
      salt: json['salt'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Note copyWith({
    String? id,
    String? titleEncrypted,
    String? iv,
    String? salt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? decryptedTitle,
    String? decryptedContent,
  }) {
    return Note(
      id: id ?? this.id,
      titleEncrypted: titleEncrypted ?? this.titleEncrypted,
      iv: iv ?? this.iv,
      salt: salt ?? this.salt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      decryptedTitle: decryptedTitle ?? this.decryptedTitle,
      decryptedContent: decryptedContent ?? this.decryptedContent,
    );
  }
}

class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final String userId;

  AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      userId: json['user_id'] as String,
    );
  }
}
