import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repository/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc(this.authRepository) : super(AuthInitial()) {
    on<SendOtpEvent>((event, emit) async {
  emit(AuthLoading());

  try {
    final verificationId =
    await authRepository.verifyPhoneNumber(event.phoneNumber);

if (verificationId == "AUTO_VERIFIED") {
  emit(AuthSuccess());
} else {
  emit(OtpSentState(verificationId));
}

  } catch (e) {
    emit(AuthError(e.toString()));
  }
});



    on<VerifyOtpEvent>((event, emit) async {
  emit(AuthLoading());

  try {
    await authRepository.signInWithOtp(
      event.verificationId,
      event.smsCode,
    );

    emit(AuthSuccess());
  } catch (e) {
    emit(AuthError(e.toString()));
  }
});

  }
}
