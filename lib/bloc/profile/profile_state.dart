sealed class ProfileState {
  const ProfileState();
}

final class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

final class ProfileSaving extends ProfileState {
  const ProfileSaving();
}

final class ProfileSaved extends ProfileState {
  const ProfileSaved();
}

final class ProfileFailure extends ProfileState {
  final String message;
  const ProfileFailure(this.message);
}
