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


/** This is an auto generated class representing the TripList type in your schema. */
class TripList extends amplify_core.Model {
  static const classType = const _TripListModelType();
  final String id;
  final String? _MRTStation;
  final TripTimeOfDay? _TripTime;
  final int? _TripNo;
  final amplify_core.TemporalDateTime? _DepartureTime;
  final amplify_core.TemporalDateTime? _createdAt;
  final amplify_core.TemporalDateTime? _updatedAt;

  @override
  getInstanceType() => classType;
  
  @Deprecated('[getId] is being deprecated in favor of custom primary key feature. Use getter [modelIdentifier] to get model identifier.')
  @override
  String getId() => id;
  
  TripListModelIdentifier get modelIdentifier {
      return TripListModelIdentifier(
        id: id
      );
  }
  
  String get MRTStation {
    try {
      return _MRTStation!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  TripTimeOfDay get TripTime {
    try {
      return _TripTime!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  int get TripNo {
    try {
      return _TripNo!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  amplify_core.TemporalDateTime get DepartureTime {
    try {
      return _DepartureTime!;
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
  
  const TripList._internal({required this.id, required MRTStation, required TripTime, required TripNo, required DepartureTime, createdAt, updatedAt}): _MRTStation = MRTStation, _TripTime = TripTime, _TripNo = TripNo, _DepartureTime = DepartureTime, _createdAt = createdAt, _updatedAt = updatedAt;
  
  factory TripList({String? id, required String MRTStation, required TripTimeOfDay TripTime, required int TripNo, required amplify_core.TemporalDateTime DepartureTime}) {
    return TripList._internal(
      id: id == null ? amplify_core.UUID.getUUID() : id,
      MRTStation: MRTStation,
      TripTime: TripTime,
      TripNo: TripNo,
      DepartureTime: DepartureTime);
  }
  
  bool equals(Object other) {
    return this == other;
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is TripList &&
      id == other.id &&
      _MRTStation == other._MRTStation &&
      _TripTime == other._TripTime &&
      _TripNo == other._TripNo &&
      _DepartureTime == other._DepartureTime;
  }
  
  @override
  int get hashCode => toString().hashCode;
  
  @override
  String toString() {
    var buffer = new StringBuffer();
    
    buffer.write("TripList {");
    buffer.write("id=" + "$id" + ", ");
    buffer.write("MRTStation=" + "$_MRTStation" + ", ");
    buffer.write("TripTime=" + (_TripTime != null ? amplify_core.enumToString(_TripTime)! : "null") + ", ");
    buffer.write("TripNo=" + (_TripNo != null ? _TripNo!.toString() : "null") + ", ");
    buffer.write("DepartureTime=" + (_DepartureTime != null ? _DepartureTime!.format() : "null") + ", ");
    buffer.write("createdAt=" + (_createdAt != null ? _createdAt!.format() : "null") + ", ");
    buffer.write("updatedAt=" + (_updatedAt != null ? _updatedAt!.format() : "null"));
    buffer.write("}");
    
    return buffer.toString();
  }
  
  TripList copyWith({String? MRTStation, TripTimeOfDay? TripTime, int? TripNo, amplify_core.TemporalDateTime? DepartureTime}) {
    return TripList._internal(
      id: id,
      MRTStation: MRTStation ?? this.MRTStation,
      TripTime: TripTime ?? this.TripTime,
      TripNo: TripNo ?? this.TripNo,
      DepartureTime: DepartureTime ?? this.DepartureTime);
  }
  
  TripList copyWithModelFieldValues({
    ModelFieldValue<String>? MRTStation,
    ModelFieldValue<TripTimeOfDay>? TripTime,
    ModelFieldValue<int>? TripNo,
    ModelFieldValue<amplify_core.TemporalDateTime>? DepartureTime
  }) {
    return TripList._internal(
      id: id,
      MRTStation: MRTStation == null ? this.MRTStation : MRTStation.value,
      TripTime: TripTime == null ? this.TripTime : TripTime.value,
      TripNo: TripNo == null ? this.TripNo : TripNo.value,
      DepartureTime: DepartureTime == null ? this.DepartureTime : DepartureTime.value
    );
  }
  
  TripList.fromJson(Map<String, dynamic> json)  
    : id = json['id'],
      _MRTStation = json['MRTStation'],
      _TripTime = amplify_core.enumFromString<TripTimeOfDay>(json['TripTime'], TripTimeOfDay.values),
      _TripNo = (json['TripNo'] as num?)?.toInt(),
      _DepartureTime = json['DepartureTime'] != null ? amplify_core.TemporalDateTime.fromString(json['DepartureTime']) : null,
      _createdAt = json['createdAt'] != null ? amplify_core.TemporalDateTime.fromString(json['createdAt']) : null,
      _updatedAt = json['updatedAt'] != null ? amplify_core.TemporalDateTime.fromString(json['updatedAt']) : null;
  
  Map<String, dynamic> toJson() => {
    'id': id, 'MRTStation': _MRTStation, 'TripTime': amplify_core.enumToString(_TripTime), 'TripNo': _TripNo, 'DepartureTime': _DepartureTime?.format(), 'createdAt': _createdAt?.format(), 'updatedAt': _updatedAt?.format()
  };
  
  Map<String, Object?> toMap() => {
    'id': id,
    'MRTStation': _MRTStation,
    'TripTime': _TripTime,
    'TripNo': _TripNo,
    'DepartureTime': _DepartureTime,
    'createdAt': _createdAt,
    'updatedAt': _updatedAt
  };

  static final amplify_core.QueryModelIdentifier<TripListModelIdentifier> MODEL_IDENTIFIER = amplify_core.QueryModelIdentifier<TripListModelIdentifier>();
  static final ID = amplify_core.QueryField(fieldName: "id");
  static final MRTSTATION = amplify_core.QueryField(fieldName: "MRTStation");
  static final TRIPTIME = amplify_core.QueryField(fieldName: "TripTime");
  static final TRIPNO = amplify_core.QueryField(fieldName: "TripNo");
  static final DEPARTURETIME = amplify_core.QueryField(fieldName: "DepartureTime");
  static var schema = amplify_core.Model.defineSchema(define: (amplify_core.ModelSchemaDefinition modelSchemaDefinition) {
    modelSchemaDefinition.name = "TripList";
    modelSchemaDefinition.pluralName = "TripLists";
    
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
    
    modelSchemaDefinition.indexes = [
      amplify_core.ModelIndex(fields: const ["MRTStation", "TripTime"], name: "FilterByStationAndTime")
    ];
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.id());
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: TripList.MRTSTATION,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: TripList.TRIPTIME,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.enumeration)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: TripList.TRIPNO,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.int)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: TripList.DEPARTURETIME,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)
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

class _TripListModelType extends amplify_core.ModelType<TripList> {
  const _TripListModelType();
  
  @override
  TripList fromJson(Map<String, dynamic> jsonData) {
    return TripList.fromJson(jsonData);
  }
  
  @override
  String modelName() {
    return 'TripList';
  }
}

/**
 * This is an auto generated class representing the model identifier
 * of [TripList] in your schema.
 */
class TripListModelIdentifier implements amplify_core.ModelIdentifier<TripList> {
  final String id;

  /** Create an instance of TripListModelIdentifier using [id] the primary key. */
  const TripListModelIdentifier({
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
  String toString() => 'TripListModelIdentifier(id: $id)';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    
    return other is TripListModelIdentifier &&
      id == other.id;
  }
  
  @override
  int get hashCode =>
    id.hashCode;
}