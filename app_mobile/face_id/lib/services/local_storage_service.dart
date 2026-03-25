import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/user_model.dart';

class LocalStorageService {
  LocalStorageService._();
  static final LocalStorageService instance = LocalStorageService._();

  Future<File> _localFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'users.json');
    return File(path);
  }

  Future<List<UserModel>> loadAll() async {
    try {
      final file = await _localFile();
      if (!await file.exists()) return <UserModel>[];
      final content = await file.readAsString();
      final List<dynamic> data = jsonDecode(content);
      return data.map((e) => UserModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      return <UserModel>[];
    }
  }

  Future<void> saveAll(List<UserModel> users) async {
    final file = await _localFile();
    final json = jsonEncode(users.map((u) => u.toJson()).toList());
    await file.writeAsString(json, flush: true);
  }

  Future<void> addOrUpdate(UserModel user) async {
    final users = await loadAll();
    final idx = users.indexWhere((u) => u.id == user.id);
    if (idx >= 0) {
      users[idx] = user;
    } else {
      users.add(user);
    }
    await saveAll(users);
  }

  Future<void> delete(String id) async {
    final users = await loadAll();
    users.removeWhere((u) => u.id == id);
    await saveAll(users);
  }
}
