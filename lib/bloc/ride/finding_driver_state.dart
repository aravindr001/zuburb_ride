sealed class FindingDriverState {
  const FindingDriverState();
}

final class FindingDriverLoading extends FindingDriverState {
  const FindingDriverLoading();
}

final class FindingDriverSearching extends FindingDriverState {
  const FindingDriverSearching();
}

final class FindingDriverAccepted extends FindingDriverState {
  const FindingDriverAccepted();
}

final class FindingDriverCancelled extends FindingDriverState {
  const FindingDriverCancelled();
}

final class FindingDriverNotFound extends FindingDriverState {
  const FindingDriverNotFound();
}

final class FindingDriverFailure extends FindingDriverState {
  final String message;
  const FindingDriverFailure(this.message);
}
