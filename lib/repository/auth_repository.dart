import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> verifyPhoneNumber(String phoneNumber) {
  final completer = Completer<String>();

  FirebaseAuth.instance.verifyPhoneNumber(
    phoneNumber: phoneNumber,

    verificationCompleted: (credential) async {
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      if (!completer.isCompleted) {
        completer.complete("AUTO_VERIFIED");
      }
    },

    verificationFailed: (e) {
      if (!completer.isCompleted) {
        completer.completeError(e.message ?? "Verification failed");
      }
    },

    codeSent: (verificationId, resendToken) {
      if (!completer.isCompleted) {
        completer.complete(verificationId);
      }
    },

    codeAutoRetrievalTimeout: (verificationId) {
      if (!completer.isCompleted) {
        completer.complete(verificationId);
      }
    },
  );

  return completer.future;
}




  Future<void> signInWithOtp(
  String verificationId,
  String smsCode,
) async {
  final credential = PhoneAuthProvider.credential(
    verificationId: verificationId,
    smsCode: smsCode,
  );

  final userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);

  final user = userCredential.user;

  if (user != null) {
    await FirebaseFirestore.instance
        .collection("customers")
        .doc(user.uid)
        .set({
      "phone": user.phoneNumber,
      "createdAt": FieldValue.serverTimestamp(),
    });
  }
}



  User? get currentUser => _auth.currentUser;
}
