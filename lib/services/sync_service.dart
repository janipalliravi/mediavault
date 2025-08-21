import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/media_item.dart';

class SyncService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('media_items');

  Future<void> pushItem(String uid, MediaItem item) async {
    final data = item.toMap()..remove('id');
    if (item.id != null) {
      await _col(uid).doc(item.id.toString()).set({
        ...data,
        'updatedAt': item.updatedAt?.toIso8601String(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> deleteItem(String uid, int id) async {
    await _col(uid).doc(id.toString()).delete();
  }

  Future<List<MediaItem>> pullAll(String uid) async {
    final snap = await _col(uid).get();
    return snap.docs.map((d) {
      final m = d.data();
      return MediaItem.fromMap({...m, 'id': int.tryParse(d.id)});
    }).toList();
  }
}
