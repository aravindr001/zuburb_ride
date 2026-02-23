sealed class RideRatingState {
  final int rating;
  const RideRatingState({required this.rating});
}

final class RideRatingEditing extends RideRatingState {
  const RideRatingEditing({required super.rating});
}

final class RideRatingSubmitting extends RideRatingState {
  const RideRatingSubmitting({required super.rating});
}

final class RideRatingSubmitted extends RideRatingState {
  const RideRatingSubmitted({required super.rating});
}

final class RideRatingFailure extends RideRatingState {
  final String message;
  const RideRatingFailure({required super.rating, required this.message});
}
