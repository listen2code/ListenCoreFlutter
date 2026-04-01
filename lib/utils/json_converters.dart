import 'package:freezed_annotation/freezed_annotation.dart';

class ToStringConverter implements JsonConverter<String?, dynamic> {
  const ToStringConverter();

  @override
  String? fromJson(dynamic json) => json?.toString();

  @override
  dynamic toJson(String? object) => object;
}
