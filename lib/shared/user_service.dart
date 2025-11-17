import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String?> getUserRole() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final doc = await _firestore.collection('users').doc(uid).get();
    return doc['role'];
  }

  Future<DocumentSnapshot> getUserData() async {
    final uid = _auth.currentUser?.uid;
    return _firestore.collection('users').doc(uid!).get();
  }
}
