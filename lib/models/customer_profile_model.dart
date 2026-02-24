import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerProfileModel {
  final String id;
  final List<String> scheduledRideIds;

  const CustomerProfileModel({
    required this.id,
    required this.scheduledRideIds,
  });

  factory CustomerProfileModel.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    final scheduledRaw = data['scheduledRideIds'];

    final scheduledRideIds = scheduledRaw is List
        ? scheduledRaw.whereType<String>().where((id) => id.trim().isNotEmpty).toList(growable: false)
        : const <String>[];

    return CustomerProfileModel(
      id: snapshot.id,
      scheduledRideIds: scheduledRideIds,
    );
  }
}
