class UserModel {
  final String id;
  final String? email;
  final String? fullName;
  final Map<String, dynamic> rawData;

  UserModel({
    required this.id,
    this.email,
    this.fullName,
    required this.rawData,
  });

  factory UserModel.fromJson(Map<dynamic, dynamic> json) {
    final raw = Map<String, dynamic>.from(json);

    String resolvedId = '';
    for (final key in ['id', 'user_id', 'userId', 'uid']) {
      if (raw[key] != null && raw[key].toString().isNotEmpty) {
        resolvedId = raw[key].toString();
        break;
      }
    }

    String? resolvedEmail;
    for (final key in ['email', 'e', 'mail']) {
      if (raw[key] is String && (raw[key] as String).isNotEmpty) {
        resolvedEmail = raw[key] as String;
        break;
      }
    }

    String? resolvedName;
    final nameCandidates = [
      raw['full_name'],
      raw['fullName'],
      raw['name'],
      if (raw['first_name'] != null && raw['last_name'] != null)
        '${raw['first_name']} ${raw['last_name']}',
    ];
    for (final value in nameCandidates) {
      if (value is String && value.trim().isNotEmpty) {
        resolvedName = value.trim();
        break;
      }
    }

    return UserModel(
      id: resolvedId,
      email: resolvedEmail,
      fullName: resolvedName,
      rawData: raw,
    );
  }

  UserModel copyWith(Map<String, dynamic> newData) {
    final merged = Map<String, dynamic>.from(rawData)..addAll(newData);
    return UserModel.fromJson(merged);
  }

  Map<String, dynamic> toJson() => rawData;
}

class SessionModel {
  final String accessToken;
  final UserModel user;

  SessionModel({required this.accessToken, required this.user});

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      accessToken: json['access_token'] as String? ?? '',
      user: UserModel.fromJson((json['user'] as Map?) ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
    'access_token': accessToken,
    'user': user.toJson(),
  };
}
