import 'package:firebase_auth/firebase_auth.dart';

sealed class AuthStatusState {
  const AuthStatusState();
}

final class AuthStatusLoading extends AuthStatusState {
  const AuthStatusLoading();
}

final class AuthStatusAuthenticated extends AuthStatusState {
  final User user;
  const AuthStatusAuthenticated(this.user);
}

final class AuthStatusUnauthenticated extends AuthStatusState {
  const AuthStatusUnauthenticated();
}

final class AuthStatusFailure extends AuthStatusState {
  final String message;
  const AuthStatusFailure(this.message);
}
