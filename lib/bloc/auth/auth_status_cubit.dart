import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zuburb_ride/repository/auth_repository.dart';

import 'auth_status_state.dart';

class AuthStatusCubit extends Cubit<AuthStatusState> {
  final AuthRepository _authRepository;
  StreamSubscription<User?>? _subscription;

  AuthStatusCubit(this._authRepository) : super(const AuthStatusLoading()) {
    _subscription = FirebaseAuth.instance.authStateChanges().listen(
      (user) {
        if (user == null) {
          emit(const AuthStatusUnauthenticated());
        } else {
          emit(AuthStatusAuthenticated(user));
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        emit(AuthStatusFailure(error.toString()));
      },
    );
  }

  Future<void> signOut() async {
    try {
      await _authRepository.signOut();
    } catch (e) {
      emit(AuthStatusFailure(e.toString()));
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
