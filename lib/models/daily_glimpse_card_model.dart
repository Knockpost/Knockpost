import 'package:flutter/foundation.dart';

class DailyGlimpseCard {
  final String id; // Typically format: "{userId}_{yyyy-MM-dd}"
  final String userId;
  final DateTime date; // Calendar date, stripped of time
  final List<String> glimpseIds;
  final DateTime createdAt;
  final DateTime? expiresAt;

  const DailyGlimpseCard({
    required this.id,
    required this.userId,
    required this.date,
    required this.glimpseIds,
    required this.createdAt,
    this.expiresAt,
  });

  DailyGlimpseCard copyWith({
    String? id,
    String? userId,
    DateTime? date,
    List<String>? glimpseIds,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return DailyGlimpseCard(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      glimpseIds: glimpseIds ?? this.glimpseIds,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DailyGlimpseCard &&
        other.id == id &&
        other.userId == userId &&
        other.date == date &&
        listEquals(other.glimpseIds, glimpseIds);
  }

  @override
  int get hashCode {
    return id.hashCode ^ userId.hashCode ^ date.hashCode ^ glimpseIds.hashCode;
  }
}
