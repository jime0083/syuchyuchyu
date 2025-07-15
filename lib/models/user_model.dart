import 'package:cloud_firestore/cloud_firestore.dart';

enum SubscriptionStatus { free, premium, trial }

class UserModel {
  final String id;
  final String email;
  final String username; // ユーザー名を追加
  final String profileImageUrl; // プロフィール画像のURLを追加
  final SubscriptionStatus subscriptionStatus;
  final DateTime? trialStartDate;
  final bool trialUsed;
  final DateTime createdAt;
  final String language;

  UserModel({
    required this.id,
    required this.email,
    this.username = '', // デフォルト値を設定
    this.profileImageUrl = '', // デフォルト値を設定
    required this.subscriptionStatus,
    this.trialStartDate,
    required this.trialUsed,
    required this.createdAt,
    required this.language,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      username: data['username'] ?? '', // Firestoreからユーザー名を取得
      profileImageUrl: data['profileImageUrl'] ?? '', // プロフィール画像URLを取得
      subscriptionStatus: _getSubscriptionStatus(data['subscriptionStatus']),
      trialStartDate: data['trialStartDate'] != null
          ? (data['trialStartDate'] as Timestamp).toDate()
          : null,
      trialUsed: data['trialUsed'] ?? false,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      language: data['language'] ?? 'en',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'username': username, // ユーザー名をマップに追加
      'profileImageUrl': profileImageUrl, // プロフィール画像URLをマップに追加
      'subscriptionStatus': _subscriptionStatusToString(subscriptionStatus),
      'trialStartDate': trialStartDate != null
          ? Timestamp.fromDate(trialStartDate!)
          : null,
      'trialUsed': trialUsed,
      'createdAt': Timestamp.fromDate(createdAt),
      'language': language,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? username,
    String? profileImageUrl,
    SubscriptionStatus? subscriptionStatus,
    DateTime? trialStartDate,
    bool? trialUsed,
    DateTime? createdAt,
    String? language,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      trialStartDate: trialStartDate ?? this.trialStartDate,
      trialUsed: trialUsed ?? this.trialUsed,
      createdAt: createdAt ?? this.createdAt,
      language: language ?? this.language,
    );
  }

  static SubscriptionStatus _getSubscriptionStatus(String? status) {
    switch (status) {
      case 'premium':
        return SubscriptionStatus.premium;
      case 'trial':
        return SubscriptionStatus.trial;
      default:
        return SubscriptionStatus.free;
    }
  }

  static String _subscriptionStatusToString(SubscriptionStatus status) {
    switch (status) {
      case SubscriptionStatus.premium:
        return 'premium';
      case SubscriptionStatus.trial:
        return 'trial';
      case SubscriptionStatus.free:
        return 'free';
    }
  }

  bool get isPremium => 
      subscriptionStatus == SubscriptionStatus.premium || 
      subscriptionStatus == SubscriptionStatus.trial;
}
