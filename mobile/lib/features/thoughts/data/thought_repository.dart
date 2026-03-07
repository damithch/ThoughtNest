import 'package:cloud_firestore/cloud_firestore.dart';

import 'thought.dart';

class ThoughtRepository {
  ThoughtRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _thoughtsRef(String userId) {
    return _firestore.collection('users').doc(userId).collection('thoughts');
  }

  Stream<List<Thought>> watchThoughts(String userId) {
    return _thoughtsRef(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Thought(
          id: doc.id,
          content: (data['content'] ?? '') as String,
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          tags: ((data['tags'] ?? const <String>[]) as List)
              .map((e) => e.toString())
              .toList(),
          mood: Thought.moodFromString((data['mood'] ?? Mood.neutral.name).toString()),
        );
      }).toList();
    });
  }

  Future<void> addThought({
    required String userId,
    required String content,
    required Mood mood,
    required List<String> tags,
  }) async {
    await _thoughtsRef(userId).add({
      'content': content.trim(),
      'mood': mood.name,
      'tags': tags,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteThought({
    required String userId,
    required String thoughtId,
  }) async {
    await _thoughtsRef(userId).doc(thoughtId).delete();
  }
}
