import 'package:firebase_database/firebase_database.dart';

class DatabaseService {
  static Future<Map<String, bool>> loadData() async {
    final dataSnapshot = await FirebaseDatabase.instance.ref('attendees').get();
    if (dataSnapshot.exists) {
      Map<String, dynamic> data = dataSnapshot.value as Map<String, dynamic>;
      return data.cast<String, bool>();
    }
    return {};
  }

  static void addOrUpdate(String key, bool value) async {
    await FirebaseDatabase.instance.ref('attendees/$key').set(value);
  }

  static void remove(String key) async {
    await FirebaseDatabase.instance.ref('attendees/$key').remove();
  }
}
