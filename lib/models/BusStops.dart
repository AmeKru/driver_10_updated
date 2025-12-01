/*
* Copyright 2021 Amazon.com, Inc. or its affiliates. All Rights Reserved.
*
* Licensed under the Apache License, Version 2.0 (the "License").
* You may not use this file except in compliance with the License.
* A copy of the License is located at
*
*  http://aws.amazon.com/apache2.0
*
* or in the "license" file accompanying this file. This file is distributed
* on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
* express or implied. See the License for the specific language governing
* permissions and limitations under the License.
*/

// NOTE: This file is generated and may not follow lint rules defined in your app
// Generated files can be excluded from analysis in analysis_options.yaml
// For more info, see: https://dart.dev/guides/language/analysis-options#excluding-code-from-analysis

// ignore_for_file: public_member_api_docs, annotate_overrides, dead_code, dead_codepublic_member_api_docs, depend_on_referenced_packages, file_names, library_private_types_in_public_api, no_leading_underscores_for_library_prefixes, no_leading_underscores_for_local_identifiers, non_constant_identifier_names, null_check_on_nullable_type_parameter, override_on_non_overriding_member, prefer_adjacent_string_concatenation, prefer_const_constructors, prefer_if_null_operators, prefer_interpolation_to_compose_strings, slash_for_doc_comments, sort_child_properties_last, unnecessary_const, unnecessary_constructor_name, unnecessary_late, unnecessary_new, unnecessary_null_aware_assignments, unnecessary_nullable_for_final_variable_declarations, unnecessary_string_interpolations, use_build_context_synchronously

import 'ModelProvider.dart';
import 'package:amplify_core/amplify_core.dart' as amplify_core;


/** This is an auto generated class representing the BusStops type in your schema. */
class BusStops extends amplify_core.Model {
  static const classType = const _BusStopsModelType();
  final String id;
  final String? _BusStop;
  final int? _StopNo;
  final double? _Lat;
  final double? _Lon;
  final String? _Description;
  final amplify_core.TemporalDateTime? _createdAt;
  final amplify_core.TemporalDateTime? _updatedAt;

  @override
  getInstanceType() => classType;
  
  @Deprecated('[getId] is being deprecated in favor of custom primary key feature. Use getter [modelIdentifier] to get model identifier.')
  @override
  String getId() => id;
  
  BusStopsModelIdentifier get modelIdentifier {
      return BusStopsModelIdentifier(
        id: id
      );
  }
  
  String get BusStop {
    try {
      return _BusStop!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  int get StopNo {
    try {
      return _StopNo!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  double get Lat {
    try {
      return _Lat!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  double get Lon {
    try {
      return _Lon!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  String get Description {
    try {
      return _Description!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  amplify_core.TemporalDateTime? get createdAt {
    return _createdAt;
  }
  
  amplify_core.TemporalDateTime? get updatedAt {
    return _updatedAt;
  }
  
  const BusStops._internal({required this.id, required BusStop, required StopNo, required Lat, required Lon, required Description, createdAt, updatedAt}): _BusStop = BusStop, _StopNo = StopNo, _Lat = Lat, _Lon = Lon, _Description = Description, _createdAt = createdAt, _updatedAt = updatedAt;
  
  factory BusStops({String? id, required String BusStop, required int StopNo, required double Lat, required double Lon, required String Description}) {
    return BusStops._internal(
      id: id == null ? amplify_core.UUID.getUUID() : id,
      BusStop: BusStop,
      StopNo: StopNo,
      Lat: Lat,
      Lon: Lon,
      Description: Description);
  }
  
  bool equals(Object other) {
    return this == other;
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is BusStops &&
      id == other.id &&
      _BusStop == other._BusStop &&
      _StopNo == other._StopNo &&
      _Lat == other._Lat &&
      _Lon == other._Lon &&
      _Description == other._Description;
  }
  
  @override
  int get hashCode => toString().hashCode;
  
  @override
  String toString() {
    var buffer = new StringBuffer();
    
    buffer.write("BusStops {");
    buffer.write("id=" + "$id" + ", ");
    buffer.write("BusStop=" + "$_BusStop" + ", ");
    buffer.write("StopNo=" + (_StopNo != null ? _StopNo!.toString() : "null") + ", ");
    buffer.write("Lat=" + (_Lat != null ? _Lat!.toString() : "null") + ", ");
    buffer.write("Lon=" + (_Lon != null ? _Lon!.toString() : "null") + ", ");
    buffer.write("Description=" + "$_Description" + ", ");
    buffer.write("createdAt=" + (_createdAt != null ? _createdAt!.format() : "null") + ", ");
    buffer.write("updatedAt=" + (_updatedAt != null ? _updatedAt!.format() : "null"));
    buffer.write("}");
    
    return buffer.toString();
  }
  
  BusStops copyWith({String? BusStop, int? StopNo, double? Lat, double? Lon, String? Description}) {
    return BusStops._internal(
      id: id,
      BusStop: BusStop ?? this.BusStop,
      StopNo: StopNo ?? this.StopNo,
      Lat: Lat ?? this.Lat,
      Lon: Lon ?? this.Lon,
      Description: Description ?? this.Description);
  }
  
  BusStops copyWithModelFieldValues({
    ModelFieldValue<String>? BusStop,
    ModelFieldValue<int>? StopNo,
    ModelFieldValue<double>? Lat,
    ModelFieldValue<double>? Lon,
    ModelFieldValue<String>? Description
  }) {
    return BusStops._internal(
      id: id,
      BusStop: BusStop == null ? this.BusStop : BusStop.value,
      StopNo: StopNo == null ? this.StopNo : StopNo.value,
      Lat: Lat == null ? this.Lat : Lat.value,
      Lon: Lon == null ? this.Lon : Lon.value,
      Description: Description == null ? this.Description : Description.value
    );
  }
  
  BusStops.fromJson(Map<String, dynamic> json)  
    : id = json['id'],
      _BusStop = json['BusStop'],
      _StopNo = (json['StopNo'] as num?)?.toInt(),
      _Lat = (json['Lat'] as num?)?.toDouble(),
      _Lon = (json['Lon'] as num?)?.toDouble(),
      _Description = json['Description'],
      _createdAt = json['createdAt'] != null ? amplify_core.TemporalDateTime.fromString(json['createdAt']) : null,
      _updatedAt = json['updatedAt'] != null ? amplify_core.TemporalDateTime.fromString(json['updatedAt']) : null;
  
  Map<String, dynamic> toJson() => {
    'id': id, 'BusStop': _BusStop, 'StopNo': _StopNo, 'Lat': _Lat, 'Lon': _Lon, 'Description': _Description, 'createdAt': _createdAt?.format(), 'updatedAt': _updatedAt?.format()
  };
  
  Map<String, Object?> toMap() => {
    'id': id,
    'BusStop': _BusStop,
    'StopNo': _StopNo,
    'Lat': _Lat,
    'Lon': _Lon,
    'Description': _Description,
    'createdAt': _createdAt,
    'updatedAt': _updatedAt
  };

  static final amplify_core.QueryModelIdentifier<BusStopsModelIdentifier> MODEL_IDENTIFIER = amplify_core.QueryModelIdentifier<BusStopsModelIdentifier>();
  static final ID = amplify_core.QueryField(fieldName: "id");
  static final BUSSTOP = amplify_core.QueryField(fieldName: "BusStop");
  static final STOPNO = amplify_core.QueryField(fieldName: "StopNo");
  static final LAT = amplify_core.QueryField(fieldName: "Lat");
  static final LON = amplify_core.QueryField(fieldName: "Lon");
  static final DESCRIPTION = amplify_core.QueryField(fieldName: "Description");
  static var schema = amplify_core.Model.defineSchema(define: (amplify_core.ModelSchemaDefinition modelSchemaDefinition) {
    modelSchemaDefinition.name = "BusStops";
    modelSchemaDefinition.pluralName = "BusStops";
    
    modelSchemaDefinition.authRules = [
      amplify_core.AuthRule(
        authStrategy: amplify_core.AuthStrategy.PUBLIC,
        provider: amplify_core.AuthRuleProvider.IAM,
        operations: const [
          amplify_core.ModelOperation.READ
        ]),
      amplify_core.AuthRule(
        authStrategy: amplify_core.AuthStrategy.PRIVATE,
        provider: amplify_core.AuthRuleProvider.USERPOOLS,
        operations: const [
          amplify_core.ModelOperation.READ,
          amplify_core.ModelOperation.CREATE,
          amplify_core.ModelOperation.UPDATE,
          amplify_core.ModelOperation.DELETE
        ])
    ];
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.id());
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: BusStops.BUSSTOP,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: BusStops.STOPNO,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.int)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: BusStops.LAT,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.double)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: BusStops.LON,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.double)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: BusStops.DESCRIPTION,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.nonQueryField(
      fieldName: 'createdAt',
      isRequired: false,
      isReadOnly: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.nonQueryField(
      fieldName: 'updatedAt',
      isRequired: false,
      isReadOnly: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)
    ));
  });
}

class _BusStopsModelType extends amplify_core.ModelType<BusStops> {
  const _BusStopsModelType();
  
  @override
  BusStops fromJson(Map<String, dynamic> jsonData) {
    return BusStops.fromJson(jsonData);
  }
  
  @override
  String modelName() {
    return 'BusStops';
  }
}

/**
 * This is an auto generated class representing the model identifier
 * of [BusStops] in your schema.
 */
class BusStopsModelIdentifier implements amplify_core.ModelIdentifier<BusStops> {
  final String id;

  /** Create an instance of BusStopsModelIdentifier using [id] the primary key. */
  const BusStopsModelIdentifier({
    required this.id});
  
  @override
  Map<String, dynamic> serializeAsMap() => (<String, dynamic>{
    'id': id
  });
  
  @override
  List<Map<String, dynamic>> serializeAsList() => serializeAsMap()
    .entries
    .map((entry) => (<String, dynamic>{ entry.key: entry.value }))
    .toList();
  
  @override
  String serializeAsString() => serializeAsMap().values.join('#');
  
  @override
  String toString() => 'BusStopsModelIdentifier(id: $id)';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    
    return other is BusStopsModelIdentifier &&
      id == other.id;
  }
  
  @override
  int get hashCode =>
    id.hashCode;
}