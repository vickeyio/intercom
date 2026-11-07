import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../features/intercom/domain/entities/intercom_role.dart';

final roleProvider = StateProvider<IntercomRole?>((ref) => null);

final userIdProvider = FutureProvider<String>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final existing = prefs.getString('intercom_user_id');
  if (existing != null && existing.isNotEmpty) return existing;

  final id = const Uuid().v4();
  await prefs.setString('intercom_user_id', id);
  return id;
});

