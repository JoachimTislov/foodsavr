import 'package:freezed_annotation/freezed_annotation.dart';

import '../utils/collection_types.dart';

part 'collection_model.freezed.dart';
part 'collection_model.g.dart';

@freezed
abstract class Collection with _$Collection {
  const Collection._();
  const factory Collection({
    required String id,
    required String name,
    required List<String> productIds,
    required String userId,
    String? description,
    @Default(CollectionType.inventory) CollectionType type,
  }) = _Collection;

  Map<String, dynamic> toFirestoreRest() {
    return {
      'id': {'stringValue': id},
      'name': {'stringValue': name},
      'productIds': {
        'arrayValue': {
          'values': productIds
              .map((id) => {'integerValue': id.toString()})
              .toList(),
        },
      },
      'userId': {'stringValue': userId},
      'description': {'stringValue': description ?? ''},
      'type': {'stringValue': type.name},
    };
  }

  factory Collection.fromJson(Map<String, dynamic> json) =>
      _$CollectionFromJson(json);
}
