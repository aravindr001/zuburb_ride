import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit() : super(const ProfileInitial());

  Future<void> saveProfile({required String name}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    emit(const ProfileSaving());

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        emit(const ProfileFailure('User not logged in'));
        return;
      }

      await FirebaseFirestore.instance.collection('customers').doc(user.uid).set({
        'name': trimmed,
        'phone': user.phoneNumber,
        'totalRides': 0,
        'currentRideId': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      emit(const ProfileSaved());
    } catch (e) {
      emit(ProfileFailure(e.toString()));
    }
  }
}
