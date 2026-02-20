abstract class AuthEvent {}

class SendOtpEvent extends AuthEvent {
  final String phoneNumber;
  SendOtpEvent(this.phoneNumber);
}

class VerifyOtpEvent extends AuthEvent {
  final String verificationId;
  final String smsCode;
  VerifyOtpEvent(this.verificationId, this.smsCode);
}
