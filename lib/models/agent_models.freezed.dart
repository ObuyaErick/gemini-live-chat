// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'agent_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SuggestedQuestion {

 String get category; String get icon;@JsonKey(name: 'question_text') String get questionText;@FlexibleIntConverter()@JsonKey(name: 'display_order') int get displayOrder;
/// Create a copy of SuggestedQuestion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SuggestedQuestionCopyWith<SuggestedQuestion> get copyWith => _$SuggestedQuestionCopyWithImpl<SuggestedQuestion>(this as SuggestedQuestion, _$identity);

  /// Serializes this SuggestedQuestion to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SuggestedQuestion&&(identical(other.category, category) || other.category == category)&&(identical(other.icon, icon) || other.icon == icon)&&(identical(other.questionText, questionText) || other.questionText == questionText)&&(identical(other.displayOrder, displayOrder) || other.displayOrder == displayOrder));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,category,icon,questionText,displayOrder);

@override
String toString() {
  return 'SuggestedQuestion(category: $category, icon: $icon, questionText: $questionText, displayOrder: $displayOrder)';
}


}

/// @nodoc
abstract mixin class $SuggestedQuestionCopyWith<$Res>  {
  factory $SuggestedQuestionCopyWith(SuggestedQuestion value, $Res Function(SuggestedQuestion) _then) = _$SuggestedQuestionCopyWithImpl;
@useResult
$Res call({
 String category, String icon,@JsonKey(name: 'question_text') String questionText,@FlexibleIntConverter()@JsonKey(name: 'display_order') int displayOrder
});




}
/// @nodoc
class _$SuggestedQuestionCopyWithImpl<$Res>
    implements $SuggestedQuestionCopyWith<$Res> {
  _$SuggestedQuestionCopyWithImpl(this._self, this._then);

  final SuggestedQuestion _self;
  final $Res Function(SuggestedQuestion) _then;

/// Create a copy of SuggestedQuestion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? category = null,Object? icon = null,Object? questionText = null,Object? displayOrder = null,}) {
  return _then(_self.copyWith(
category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,icon: null == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as String,questionText: null == questionText ? _self.questionText : questionText // ignore: cast_nullable_to_non_nullable
as String,displayOrder: null == displayOrder ? _self.displayOrder : displayOrder // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [SuggestedQuestion].
extension SuggestedQuestionPatterns on SuggestedQuestion {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SuggestedQuestion value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SuggestedQuestion() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SuggestedQuestion value)  $default,){
final _that = this;
switch (_that) {
case _SuggestedQuestion():
return $default(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SuggestedQuestion value)?  $default,){
final _that = this;
switch (_that) {
case _SuggestedQuestion() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String category,  String icon, @JsonKey(name: 'question_text')  String questionText, @FlexibleIntConverter()@JsonKey(name: 'display_order')  int displayOrder)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SuggestedQuestion() when $default != null:
return $default(_that.category,_that.icon,_that.questionText,_that.displayOrder);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String category,  String icon, @JsonKey(name: 'question_text')  String questionText, @FlexibleIntConverter()@JsonKey(name: 'display_order')  int displayOrder)  $default,) {final _that = this;
switch (_that) {
case _SuggestedQuestion():
return $default(_that.category,_that.icon,_that.questionText,_that.displayOrder);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String category,  String icon, @JsonKey(name: 'question_text')  String questionText, @FlexibleIntConverter()@JsonKey(name: 'display_order')  int displayOrder)?  $default,) {final _that = this;
switch (_that) {
case _SuggestedQuestion() when $default != null:
return $default(_that.category,_that.icon,_that.questionText,_that.displayOrder);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SuggestedQuestion implements SuggestedQuestion {
  const _SuggestedQuestion({required this.category, required this.icon, @JsonKey(name: 'question_text') required this.questionText, @FlexibleIntConverter()@JsonKey(name: 'display_order') required this.displayOrder});
  factory _SuggestedQuestion.fromJson(Map<String, dynamic> json) => _$SuggestedQuestionFromJson(json);

@override final  String category;
@override final  String icon;
@override@JsonKey(name: 'question_text') final  String questionText;
@override@FlexibleIntConverter()@JsonKey(name: 'display_order') final  int displayOrder;

/// Create a copy of SuggestedQuestion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SuggestedQuestionCopyWith<_SuggestedQuestion> get copyWith => __$SuggestedQuestionCopyWithImpl<_SuggestedQuestion>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SuggestedQuestionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SuggestedQuestion&&(identical(other.category, category) || other.category == category)&&(identical(other.icon, icon) || other.icon == icon)&&(identical(other.questionText, questionText) || other.questionText == questionText)&&(identical(other.displayOrder, displayOrder) || other.displayOrder == displayOrder));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,category,icon,questionText,displayOrder);

@override
String toString() {
  return 'SuggestedQuestion(category: $category, icon: $icon, questionText: $questionText, displayOrder: $displayOrder)';
}


}

/// @nodoc
abstract mixin class _$SuggestedQuestionCopyWith<$Res> implements $SuggestedQuestionCopyWith<$Res> {
  factory _$SuggestedQuestionCopyWith(_SuggestedQuestion value, $Res Function(_SuggestedQuestion) _then) = __$SuggestedQuestionCopyWithImpl;
@override @useResult
$Res call({
 String category, String icon,@JsonKey(name: 'question_text') String questionText,@FlexibleIntConverter()@JsonKey(name: 'display_order') int displayOrder
});




}
/// @nodoc
class __$SuggestedQuestionCopyWithImpl<$Res>
    implements _$SuggestedQuestionCopyWith<$Res> {
  __$SuggestedQuestionCopyWithImpl(this._self, this._then);

  final _SuggestedQuestion _self;
  final $Res Function(_SuggestedQuestion) _then;

/// Create a copy of SuggestedQuestion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? category = null,Object? icon = null,Object? questionText = null,Object? displayOrder = null,}) {
  return _then(_SuggestedQuestion(
category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,icon: null == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as String,questionText: null == questionText ? _self.questionText : questionText // ignore: cast_nullable_to_non_nullable
as String,displayOrder: null == displayOrder ? _self.displayOrder : displayOrder // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$AgentTool {

@JsonKey(name: 'tool_id') String get toolId;@JsonKey(name: 'tool_name') String get toolName;@JsonKey(name: 'tool_description') String get toolDescription;@JsonKey(name: 'tool_type') AgentToolType get toolType;/// Often a stringified JSON schema in your current data.
@JsonKey(name: 'tool_parameters') String? get toolParameters;@JsonKey(name: 'tool_query_template') String? get toolQueryTemplate;@JsonKey(name: 'tool_python_code') String? get toolPythonCode;@JsonKey(name: 'tool_system_message') String? get toolSystemMessage;@JsonKey(name: 'tool_result_instructions') String? get toolResultInstructions;@JsonKey(name: 'tool_action_endpoint') String? get toolActionEndpoint;@JsonKey(name: 'tool_action_method') String? get toolActionMethod;/// Some agents have this as `"false"` / `null`.
@FlexibleBoolConverter()@JsonKey(name: 'tool_requires_confirmation') bool? get toolRequiresConfirmation;@FlexibleIntConverter()@JsonKey(name: 'tool_order') int get toolOrder;
/// Create a copy of AgentTool
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentToolCopyWith<AgentTool> get copyWith => _$AgentToolCopyWithImpl<AgentTool>(this as AgentTool, _$identity);

  /// Serializes this AgentTool to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentTool&&(identical(other.toolId, toolId) || other.toolId == toolId)&&(identical(other.toolName, toolName) || other.toolName == toolName)&&(identical(other.toolDescription, toolDescription) || other.toolDescription == toolDescription)&&(identical(other.toolType, toolType) || other.toolType == toolType)&&(identical(other.toolParameters, toolParameters) || other.toolParameters == toolParameters)&&(identical(other.toolQueryTemplate, toolQueryTemplate) || other.toolQueryTemplate == toolQueryTemplate)&&(identical(other.toolPythonCode, toolPythonCode) || other.toolPythonCode == toolPythonCode)&&(identical(other.toolSystemMessage, toolSystemMessage) || other.toolSystemMessage == toolSystemMessage)&&(identical(other.toolResultInstructions, toolResultInstructions) || other.toolResultInstructions == toolResultInstructions)&&(identical(other.toolActionEndpoint, toolActionEndpoint) || other.toolActionEndpoint == toolActionEndpoint)&&(identical(other.toolActionMethod, toolActionMethod) || other.toolActionMethod == toolActionMethod)&&(identical(other.toolRequiresConfirmation, toolRequiresConfirmation) || other.toolRequiresConfirmation == toolRequiresConfirmation)&&(identical(other.toolOrder, toolOrder) || other.toolOrder == toolOrder));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,toolId,toolName,toolDescription,toolType,toolParameters,toolQueryTemplate,toolPythonCode,toolSystemMessage,toolResultInstructions,toolActionEndpoint,toolActionMethod,toolRequiresConfirmation,toolOrder);

@override
String toString() {
  return 'AgentTool(toolId: $toolId, toolName: $toolName, toolDescription: $toolDescription, toolType: $toolType, toolParameters: $toolParameters, toolQueryTemplate: $toolQueryTemplate, toolPythonCode: $toolPythonCode, toolSystemMessage: $toolSystemMessage, toolResultInstructions: $toolResultInstructions, toolActionEndpoint: $toolActionEndpoint, toolActionMethod: $toolActionMethod, toolRequiresConfirmation: $toolRequiresConfirmation, toolOrder: $toolOrder)';
}


}

/// @nodoc
abstract mixin class $AgentToolCopyWith<$Res>  {
  factory $AgentToolCopyWith(AgentTool value, $Res Function(AgentTool) _then) = _$AgentToolCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'tool_id') String toolId,@JsonKey(name: 'tool_name') String toolName,@JsonKey(name: 'tool_description') String toolDescription,@JsonKey(name: 'tool_type') AgentToolType toolType,@JsonKey(name: 'tool_parameters') String? toolParameters,@JsonKey(name: 'tool_query_template') String? toolQueryTemplate,@JsonKey(name: 'tool_python_code') String? toolPythonCode,@JsonKey(name: 'tool_system_message') String? toolSystemMessage,@JsonKey(name: 'tool_result_instructions') String? toolResultInstructions,@JsonKey(name: 'tool_action_endpoint') String? toolActionEndpoint,@JsonKey(name: 'tool_action_method') String? toolActionMethod,@FlexibleBoolConverter()@JsonKey(name: 'tool_requires_confirmation') bool? toolRequiresConfirmation,@FlexibleIntConverter()@JsonKey(name: 'tool_order') int toolOrder
});




}
/// @nodoc
class _$AgentToolCopyWithImpl<$Res>
    implements $AgentToolCopyWith<$Res> {
  _$AgentToolCopyWithImpl(this._self, this._then);

  final AgentTool _self;
  final $Res Function(AgentTool) _then;

/// Create a copy of AgentTool
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? toolId = null,Object? toolName = null,Object? toolDescription = null,Object? toolType = null,Object? toolParameters = freezed,Object? toolQueryTemplate = freezed,Object? toolPythonCode = freezed,Object? toolSystemMessage = freezed,Object? toolResultInstructions = freezed,Object? toolActionEndpoint = freezed,Object? toolActionMethod = freezed,Object? toolRequiresConfirmation = freezed,Object? toolOrder = null,}) {
  return _then(_self.copyWith(
toolId: null == toolId ? _self.toolId : toolId // ignore: cast_nullable_to_non_nullable
as String,toolName: null == toolName ? _self.toolName : toolName // ignore: cast_nullable_to_non_nullable
as String,toolDescription: null == toolDescription ? _self.toolDescription : toolDescription // ignore: cast_nullable_to_non_nullable
as String,toolType: null == toolType ? _self.toolType : toolType // ignore: cast_nullable_to_non_nullable
as AgentToolType,toolParameters: freezed == toolParameters ? _self.toolParameters : toolParameters // ignore: cast_nullable_to_non_nullable
as String?,toolQueryTemplate: freezed == toolQueryTemplate ? _self.toolQueryTemplate : toolQueryTemplate // ignore: cast_nullable_to_non_nullable
as String?,toolPythonCode: freezed == toolPythonCode ? _self.toolPythonCode : toolPythonCode // ignore: cast_nullable_to_non_nullable
as String?,toolSystemMessage: freezed == toolSystemMessage ? _self.toolSystemMessage : toolSystemMessage // ignore: cast_nullable_to_non_nullable
as String?,toolResultInstructions: freezed == toolResultInstructions ? _self.toolResultInstructions : toolResultInstructions // ignore: cast_nullable_to_non_nullable
as String?,toolActionEndpoint: freezed == toolActionEndpoint ? _self.toolActionEndpoint : toolActionEndpoint // ignore: cast_nullable_to_non_nullable
as String?,toolActionMethod: freezed == toolActionMethod ? _self.toolActionMethod : toolActionMethod // ignore: cast_nullable_to_non_nullable
as String?,toolRequiresConfirmation: freezed == toolRequiresConfirmation ? _self.toolRequiresConfirmation : toolRequiresConfirmation // ignore: cast_nullable_to_non_nullable
as bool?,toolOrder: null == toolOrder ? _self.toolOrder : toolOrder // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [AgentTool].
extension AgentToolPatterns on AgentTool {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgentTool value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgentTool() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgentTool value)  $default,){
final _that = this;
switch (_that) {
case _AgentTool():
return $default(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgentTool value)?  $default,){
final _that = this;
switch (_that) {
case _AgentTool() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'tool_id')  String toolId, @JsonKey(name: 'tool_name')  String toolName, @JsonKey(name: 'tool_description')  String toolDescription, @JsonKey(name: 'tool_type')  AgentToolType toolType, @JsonKey(name: 'tool_parameters')  String? toolParameters, @JsonKey(name: 'tool_query_template')  String? toolQueryTemplate, @JsonKey(name: 'tool_python_code')  String? toolPythonCode, @JsonKey(name: 'tool_system_message')  String? toolSystemMessage, @JsonKey(name: 'tool_result_instructions')  String? toolResultInstructions, @JsonKey(name: 'tool_action_endpoint')  String? toolActionEndpoint, @JsonKey(name: 'tool_action_method')  String? toolActionMethod, @FlexibleBoolConverter()@JsonKey(name: 'tool_requires_confirmation')  bool? toolRequiresConfirmation, @FlexibleIntConverter()@JsonKey(name: 'tool_order')  int toolOrder)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgentTool() when $default != null:
return $default(_that.toolId,_that.toolName,_that.toolDescription,_that.toolType,_that.toolParameters,_that.toolQueryTemplate,_that.toolPythonCode,_that.toolSystemMessage,_that.toolResultInstructions,_that.toolActionEndpoint,_that.toolActionMethod,_that.toolRequiresConfirmation,_that.toolOrder);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'tool_id')  String toolId, @JsonKey(name: 'tool_name')  String toolName, @JsonKey(name: 'tool_description')  String toolDescription, @JsonKey(name: 'tool_type')  AgentToolType toolType, @JsonKey(name: 'tool_parameters')  String? toolParameters, @JsonKey(name: 'tool_query_template')  String? toolQueryTemplate, @JsonKey(name: 'tool_python_code')  String? toolPythonCode, @JsonKey(name: 'tool_system_message')  String? toolSystemMessage, @JsonKey(name: 'tool_result_instructions')  String? toolResultInstructions, @JsonKey(name: 'tool_action_endpoint')  String? toolActionEndpoint, @JsonKey(name: 'tool_action_method')  String? toolActionMethod, @FlexibleBoolConverter()@JsonKey(name: 'tool_requires_confirmation')  bool? toolRequiresConfirmation, @FlexibleIntConverter()@JsonKey(name: 'tool_order')  int toolOrder)  $default,) {final _that = this;
switch (_that) {
case _AgentTool():
return $default(_that.toolId,_that.toolName,_that.toolDescription,_that.toolType,_that.toolParameters,_that.toolQueryTemplate,_that.toolPythonCode,_that.toolSystemMessage,_that.toolResultInstructions,_that.toolActionEndpoint,_that.toolActionMethod,_that.toolRequiresConfirmation,_that.toolOrder);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'tool_id')  String toolId, @JsonKey(name: 'tool_name')  String toolName, @JsonKey(name: 'tool_description')  String toolDescription, @JsonKey(name: 'tool_type')  AgentToolType toolType, @JsonKey(name: 'tool_parameters')  String? toolParameters, @JsonKey(name: 'tool_query_template')  String? toolQueryTemplate, @JsonKey(name: 'tool_python_code')  String? toolPythonCode, @JsonKey(name: 'tool_system_message')  String? toolSystemMessage, @JsonKey(name: 'tool_result_instructions')  String? toolResultInstructions, @JsonKey(name: 'tool_action_endpoint')  String? toolActionEndpoint, @JsonKey(name: 'tool_action_method')  String? toolActionMethod, @FlexibleBoolConverter()@JsonKey(name: 'tool_requires_confirmation')  bool? toolRequiresConfirmation, @FlexibleIntConverter()@JsonKey(name: 'tool_order')  int toolOrder)?  $default,) {final _that = this;
switch (_that) {
case _AgentTool() when $default != null:
return $default(_that.toolId,_that.toolName,_that.toolDescription,_that.toolType,_that.toolParameters,_that.toolQueryTemplate,_that.toolPythonCode,_that.toolSystemMessage,_that.toolResultInstructions,_that.toolActionEndpoint,_that.toolActionMethod,_that.toolRequiresConfirmation,_that.toolOrder);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AgentTool implements AgentTool {
  const _AgentTool({@JsonKey(name: 'tool_id') required this.toolId, @JsonKey(name: 'tool_name') required this.toolName, @JsonKey(name: 'tool_description') required this.toolDescription, @JsonKey(name: 'tool_type') required this.toolType, @JsonKey(name: 'tool_parameters') this.toolParameters, @JsonKey(name: 'tool_query_template') this.toolQueryTemplate, @JsonKey(name: 'tool_python_code') this.toolPythonCode, @JsonKey(name: 'tool_system_message') this.toolSystemMessage, @JsonKey(name: 'tool_result_instructions') this.toolResultInstructions, @JsonKey(name: 'tool_action_endpoint') this.toolActionEndpoint, @JsonKey(name: 'tool_action_method') this.toolActionMethod, @FlexibleBoolConverter()@JsonKey(name: 'tool_requires_confirmation') this.toolRequiresConfirmation, @FlexibleIntConverter()@JsonKey(name: 'tool_order') required this.toolOrder});
  factory _AgentTool.fromJson(Map<String, dynamic> json) => _$AgentToolFromJson(json);

@override@JsonKey(name: 'tool_id') final  String toolId;
@override@JsonKey(name: 'tool_name') final  String toolName;
@override@JsonKey(name: 'tool_description') final  String toolDescription;
@override@JsonKey(name: 'tool_type') final  AgentToolType toolType;
/// Often a stringified JSON schema in your current data.
@override@JsonKey(name: 'tool_parameters') final  String? toolParameters;
@override@JsonKey(name: 'tool_query_template') final  String? toolQueryTemplate;
@override@JsonKey(name: 'tool_python_code') final  String? toolPythonCode;
@override@JsonKey(name: 'tool_system_message') final  String? toolSystemMessage;
@override@JsonKey(name: 'tool_result_instructions') final  String? toolResultInstructions;
@override@JsonKey(name: 'tool_action_endpoint') final  String? toolActionEndpoint;
@override@JsonKey(name: 'tool_action_method') final  String? toolActionMethod;
/// Some agents have this as `"false"` / `null`.
@override@FlexibleBoolConverter()@JsonKey(name: 'tool_requires_confirmation') final  bool? toolRequiresConfirmation;
@override@FlexibleIntConverter()@JsonKey(name: 'tool_order') final  int toolOrder;

/// Create a copy of AgentTool
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgentToolCopyWith<_AgentTool> get copyWith => __$AgentToolCopyWithImpl<_AgentTool>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentToolToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgentTool&&(identical(other.toolId, toolId) || other.toolId == toolId)&&(identical(other.toolName, toolName) || other.toolName == toolName)&&(identical(other.toolDescription, toolDescription) || other.toolDescription == toolDescription)&&(identical(other.toolType, toolType) || other.toolType == toolType)&&(identical(other.toolParameters, toolParameters) || other.toolParameters == toolParameters)&&(identical(other.toolQueryTemplate, toolQueryTemplate) || other.toolQueryTemplate == toolQueryTemplate)&&(identical(other.toolPythonCode, toolPythonCode) || other.toolPythonCode == toolPythonCode)&&(identical(other.toolSystemMessage, toolSystemMessage) || other.toolSystemMessage == toolSystemMessage)&&(identical(other.toolResultInstructions, toolResultInstructions) || other.toolResultInstructions == toolResultInstructions)&&(identical(other.toolActionEndpoint, toolActionEndpoint) || other.toolActionEndpoint == toolActionEndpoint)&&(identical(other.toolActionMethod, toolActionMethod) || other.toolActionMethod == toolActionMethod)&&(identical(other.toolRequiresConfirmation, toolRequiresConfirmation) || other.toolRequiresConfirmation == toolRequiresConfirmation)&&(identical(other.toolOrder, toolOrder) || other.toolOrder == toolOrder));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,toolId,toolName,toolDescription,toolType,toolParameters,toolQueryTemplate,toolPythonCode,toolSystemMessage,toolResultInstructions,toolActionEndpoint,toolActionMethod,toolRequiresConfirmation,toolOrder);

@override
String toString() {
  return 'AgentTool(toolId: $toolId, toolName: $toolName, toolDescription: $toolDescription, toolType: $toolType, toolParameters: $toolParameters, toolQueryTemplate: $toolQueryTemplate, toolPythonCode: $toolPythonCode, toolSystemMessage: $toolSystemMessage, toolResultInstructions: $toolResultInstructions, toolActionEndpoint: $toolActionEndpoint, toolActionMethod: $toolActionMethod, toolRequiresConfirmation: $toolRequiresConfirmation, toolOrder: $toolOrder)';
}


}

/// @nodoc
abstract mixin class _$AgentToolCopyWith<$Res> implements $AgentToolCopyWith<$Res> {
  factory _$AgentToolCopyWith(_AgentTool value, $Res Function(_AgentTool) _then) = __$AgentToolCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'tool_id') String toolId,@JsonKey(name: 'tool_name') String toolName,@JsonKey(name: 'tool_description') String toolDescription,@JsonKey(name: 'tool_type') AgentToolType toolType,@JsonKey(name: 'tool_parameters') String? toolParameters,@JsonKey(name: 'tool_query_template') String? toolQueryTemplate,@JsonKey(name: 'tool_python_code') String? toolPythonCode,@JsonKey(name: 'tool_system_message') String? toolSystemMessage,@JsonKey(name: 'tool_result_instructions') String? toolResultInstructions,@JsonKey(name: 'tool_action_endpoint') String? toolActionEndpoint,@JsonKey(name: 'tool_action_method') String? toolActionMethod,@FlexibleBoolConverter()@JsonKey(name: 'tool_requires_confirmation') bool? toolRequiresConfirmation,@FlexibleIntConverter()@JsonKey(name: 'tool_order') int toolOrder
});




}
/// @nodoc
class __$AgentToolCopyWithImpl<$Res>
    implements _$AgentToolCopyWith<$Res> {
  __$AgentToolCopyWithImpl(this._self, this._then);

  final _AgentTool _self;
  final $Res Function(_AgentTool) _then;

/// Create a copy of AgentTool
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? toolId = null,Object? toolName = null,Object? toolDescription = null,Object? toolType = null,Object? toolParameters = freezed,Object? toolQueryTemplate = freezed,Object? toolPythonCode = freezed,Object? toolSystemMessage = freezed,Object? toolResultInstructions = freezed,Object? toolActionEndpoint = freezed,Object? toolActionMethod = freezed,Object? toolRequiresConfirmation = freezed,Object? toolOrder = null,}) {
  return _then(_AgentTool(
toolId: null == toolId ? _self.toolId : toolId // ignore: cast_nullable_to_non_nullable
as String,toolName: null == toolName ? _self.toolName : toolName // ignore: cast_nullable_to_non_nullable
as String,toolDescription: null == toolDescription ? _self.toolDescription : toolDescription // ignore: cast_nullable_to_non_nullable
as String,toolType: null == toolType ? _self.toolType : toolType // ignore: cast_nullable_to_non_nullable
as AgentToolType,toolParameters: freezed == toolParameters ? _self.toolParameters : toolParameters // ignore: cast_nullable_to_non_nullable
as String?,toolQueryTemplate: freezed == toolQueryTemplate ? _self.toolQueryTemplate : toolQueryTemplate // ignore: cast_nullable_to_non_nullable
as String?,toolPythonCode: freezed == toolPythonCode ? _self.toolPythonCode : toolPythonCode // ignore: cast_nullable_to_non_nullable
as String?,toolSystemMessage: freezed == toolSystemMessage ? _self.toolSystemMessage : toolSystemMessage // ignore: cast_nullable_to_non_nullable
as String?,toolResultInstructions: freezed == toolResultInstructions ? _self.toolResultInstructions : toolResultInstructions // ignore: cast_nullable_to_non_nullable
as String?,toolActionEndpoint: freezed == toolActionEndpoint ? _self.toolActionEndpoint : toolActionEndpoint // ignore: cast_nullable_to_non_nullable
as String?,toolActionMethod: freezed == toolActionMethod ? _self.toolActionMethod : toolActionMethod // ignore: cast_nullable_to_non_nullable
as String?,toolRequiresConfirmation: freezed == toolRequiresConfirmation ? _self.toolRequiresConfirmation : toolRequiresConfirmation // ignore: cast_nullable_to_non_nullable
as bool?,toolOrder: null == toolOrder ? _self.toolOrder : toolOrder // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$DataSource {

@JsonKey(name: 'data_source_id') String get dataSourceId;@JsonKey(name: 'source_type') String get sourceType;@JsonKey(name: 'source_reference') String get sourceReference;@JsonKey(name: 'source_description') String? get sourceDescription;
/// Create a copy of DataSource
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DataSourceCopyWith<DataSource> get copyWith => _$DataSourceCopyWithImpl<DataSource>(this as DataSource, _$identity);

  /// Serializes this DataSource to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DataSource&&(identical(other.dataSourceId, dataSourceId) || other.dataSourceId == dataSourceId)&&(identical(other.sourceType, sourceType) || other.sourceType == sourceType)&&(identical(other.sourceReference, sourceReference) || other.sourceReference == sourceReference)&&(identical(other.sourceDescription, sourceDescription) || other.sourceDescription == sourceDescription));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,dataSourceId,sourceType,sourceReference,sourceDescription);

@override
String toString() {
  return 'DataSource(dataSourceId: $dataSourceId, sourceType: $sourceType, sourceReference: $sourceReference, sourceDescription: $sourceDescription)';
}


}

/// @nodoc
abstract mixin class $DataSourceCopyWith<$Res>  {
  factory $DataSourceCopyWith(DataSource value, $Res Function(DataSource) _then) = _$DataSourceCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'data_source_id') String dataSourceId,@JsonKey(name: 'source_type') String sourceType,@JsonKey(name: 'source_reference') String sourceReference,@JsonKey(name: 'source_description') String? sourceDescription
});




}
/// @nodoc
class _$DataSourceCopyWithImpl<$Res>
    implements $DataSourceCopyWith<$Res> {
  _$DataSourceCopyWithImpl(this._self, this._then);

  final DataSource _self;
  final $Res Function(DataSource) _then;

/// Create a copy of DataSource
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? dataSourceId = null,Object? sourceType = null,Object? sourceReference = null,Object? sourceDescription = freezed,}) {
  return _then(_self.copyWith(
dataSourceId: null == dataSourceId ? _self.dataSourceId : dataSourceId // ignore: cast_nullable_to_non_nullable
as String,sourceType: null == sourceType ? _self.sourceType : sourceType // ignore: cast_nullable_to_non_nullable
as String,sourceReference: null == sourceReference ? _self.sourceReference : sourceReference // ignore: cast_nullable_to_non_nullable
as String,sourceDescription: freezed == sourceDescription ? _self.sourceDescription : sourceDescription // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [DataSource].
extension DataSourcePatterns on DataSource {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DataSource value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DataSource() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DataSource value)  $default,){
final _that = this;
switch (_that) {
case _DataSource():
return $default(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DataSource value)?  $default,){
final _that = this;
switch (_that) {
case _DataSource() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'data_source_id')  String dataSourceId, @JsonKey(name: 'source_type')  String sourceType, @JsonKey(name: 'source_reference')  String sourceReference, @JsonKey(name: 'source_description')  String? sourceDescription)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DataSource() when $default != null:
return $default(_that.dataSourceId,_that.sourceType,_that.sourceReference,_that.sourceDescription);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'data_source_id')  String dataSourceId, @JsonKey(name: 'source_type')  String sourceType, @JsonKey(name: 'source_reference')  String sourceReference, @JsonKey(name: 'source_description')  String? sourceDescription)  $default,) {final _that = this;
switch (_that) {
case _DataSource():
return $default(_that.dataSourceId,_that.sourceType,_that.sourceReference,_that.sourceDescription);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'data_source_id')  String dataSourceId, @JsonKey(name: 'source_type')  String sourceType, @JsonKey(name: 'source_reference')  String sourceReference, @JsonKey(name: 'source_description')  String? sourceDescription)?  $default,) {final _that = this;
switch (_that) {
case _DataSource() when $default != null:
return $default(_that.dataSourceId,_that.sourceType,_that.sourceReference,_that.sourceDescription);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DataSource implements DataSource {
  const _DataSource({@JsonKey(name: 'data_source_id') required this.dataSourceId, @JsonKey(name: 'source_type') required this.sourceType, @JsonKey(name: 'source_reference') required this.sourceReference, @JsonKey(name: 'source_description') this.sourceDescription});
  factory _DataSource.fromJson(Map<String, dynamic> json) => _$DataSourceFromJson(json);

@override@JsonKey(name: 'data_source_id') final  String dataSourceId;
@override@JsonKey(name: 'source_type') final  String sourceType;
@override@JsonKey(name: 'source_reference') final  String sourceReference;
@override@JsonKey(name: 'source_description') final  String? sourceDescription;

/// Create a copy of DataSource
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DataSourceCopyWith<_DataSource> get copyWith => __$DataSourceCopyWithImpl<_DataSource>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DataSourceToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DataSource&&(identical(other.dataSourceId, dataSourceId) || other.dataSourceId == dataSourceId)&&(identical(other.sourceType, sourceType) || other.sourceType == sourceType)&&(identical(other.sourceReference, sourceReference) || other.sourceReference == sourceReference)&&(identical(other.sourceDescription, sourceDescription) || other.sourceDescription == sourceDescription));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,dataSourceId,sourceType,sourceReference,sourceDescription);

@override
String toString() {
  return 'DataSource(dataSourceId: $dataSourceId, sourceType: $sourceType, sourceReference: $sourceReference, sourceDescription: $sourceDescription)';
}


}

/// @nodoc
abstract mixin class _$DataSourceCopyWith<$Res> implements $DataSourceCopyWith<$Res> {
  factory _$DataSourceCopyWith(_DataSource value, $Res Function(_DataSource) _then) = __$DataSourceCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'data_source_id') String dataSourceId,@JsonKey(name: 'source_type') String sourceType,@JsonKey(name: 'source_reference') String sourceReference,@JsonKey(name: 'source_description') String? sourceDescription
});




}
/// @nodoc
class __$DataSourceCopyWithImpl<$Res>
    implements _$DataSourceCopyWith<$Res> {
  __$DataSourceCopyWithImpl(this._self, this._then);

  final _DataSource _self;
  final $Res Function(_DataSource) _then;

/// Create a copy of DataSource
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? dataSourceId = null,Object? sourceType = null,Object? sourceReference = null,Object? sourceDescription = freezed,}) {
  return _then(_DataSource(
dataSourceId: null == dataSourceId ? _self.dataSourceId : dataSourceId // ignore: cast_nullable_to_non_nullable
as String,sourceType: null == sourceType ? _self.sourceType : sourceType // ignore: cast_nullable_to_non_nullable
as String,sourceReference: null == sourceReference ? _self.sourceReference : sourceReference // ignore: cast_nullable_to_non_nullable
as String,sourceDescription: freezed == sourceDescription ? _self.sourceDescription : sourceDescription // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$Agent {

@JsonKey(name: 'agent_id') String get agentId; List<String> get accounts;@FlexibleBoolConverter()@JsonKey(name: 'is_global') bool get isGlobal;@JsonKey(name: 'status') AgentStatus get status;@JsonKey(name: 'agent_name') String get agentName;@JsonKey(name: 'agent_subtitle') String? get agentSubtitle;@JsonKey(name: 'agent_description') String? get agentDescription;@JsonKey(name: 'agent_image_url') String? get agentImageUrl;@JsonKey(name: 'agent_profile_text') String? get agentProfileText;@JsonKey(name: 'agent_instructions') String? get agentInstructions;@JsonKey(name: 'agent_welcome_message') String? get agentWelcomeMessage;@JsonKey(name: 'model_id') String? get modelId;@FlexibleDoubleConverter()@JsonKey(name: 'temperature') double? get temperature;@FlexibleIntConverter()@JsonKey(name: 'display_order') int? get displayOrder;@JsonKey(name: 'suggested_questions') List<SuggestedQuestion> get suggestedQuestions; List<AgentTool> get tools;@JsonKey(name: 'data_sources') List<DataSource> get dataSources;
/// Create a copy of Agent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentCopyWith<Agent> get copyWith => _$AgentCopyWithImpl<Agent>(this as Agent, _$identity);

  /// Serializes this Agent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Agent&&(identical(other.agentId, agentId) || other.agentId == agentId)&&const DeepCollectionEquality().equals(other.accounts, accounts)&&(identical(other.isGlobal, isGlobal) || other.isGlobal == isGlobal)&&(identical(other.status, status) || other.status == status)&&(identical(other.agentName, agentName) || other.agentName == agentName)&&(identical(other.agentSubtitle, agentSubtitle) || other.agentSubtitle == agentSubtitle)&&(identical(other.agentDescription, agentDescription) || other.agentDescription == agentDescription)&&(identical(other.agentImageUrl, agentImageUrl) || other.agentImageUrl == agentImageUrl)&&(identical(other.agentProfileText, agentProfileText) || other.agentProfileText == agentProfileText)&&(identical(other.agentInstructions, agentInstructions) || other.agentInstructions == agentInstructions)&&(identical(other.agentWelcomeMessage, agentWelcomeMessage) || other.agentWelcomeMessage == agentWelcomeMessage)&&(identical(other.modelId, modelId) || other.modelId == modelId)&&(identical(other.temperature, temperature) || other.temperature == temperature)&&(identical(other.displayOrder, displayOrder) || other.displayOrder == displayOrder)&&const DeepCollectionEquality().equals(other.suggestedQuestions, suggestedQuestions)&&const DeepCollectionEquality().equals(other.tools, tools)&&const DeepCollectionEquality().equals(other.dataSources, dataSources));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,agentId,const DeepCollectionEquality().hash(accounts),isGlobal,status,agentName,agentSubtitle,agentDescription,agentImageUrl,agentProfileText,agentInstructions,agentWelcomeMessage,modelId,temperature,displayOrder,const DeepCollectionEquality().hash(suggestedQuestions),const DeepCollectionEquality().hash(tools),const DeepCollectionEquality().hash(dataSources));

@override
String toString() {
  return 'Agent(agentId: $agentId, accounts: $accounts, isGlobal: $isGlobal, status: $status, agentName: $agentName, agentSubtitle: $agentSubtitle, agentDescription: $agentDescription, agentImageUrl: $agentImageUrl, agentProfileText: $agentProfileText, agentInstructions: $agentInstructions, agentWelcomeMessage: $agentWelcomeMessage, modelId: $modelId, temperature: $temperature, displayOrder: $displayOrder, suggestedQuestions: $suggestedQuestions, tools: $tools, dataSources: $dataSources)';
}


}

/// @nodoc
abstract mixin class $AgentCopyWith<$Res>  {
  factory $AgentCopyWith(Agent value, $Res Function(Agent) _then) = _$AgentCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'agent_id') String agentId, List<String> accounts,@FlexibleBoolConverter()@JsonKey(name: 'is_global') bool isGlobal,@JsonKey(name: 'status') AgentStatus status,@JsonKey(name: 'agent_name') String agentName,@JsonKey(name: 'agent_subtitle') String? agentSubtitle,@JsonKey(name: 'agent_description') String? agentDescription,@JsonKey(name: 'agent_image_url') String? agentImageUrl,@JsonKey(name: 'agent_profile_text') String? agentProfileText,@JsonKey(name: 'agent_instructions') String? agentInstructions,@JsonKey(name: 'agent_welcome_message') String? agentWelcomeMessage,@JsonKey(name: 'model_id') String? modelId,@FlexibleDoubleConverter()@JsonKey(name: 'temperature') double? temperature,@FlexibleIntConverter()@JsonKey(name: 'display_order') int? displayOrder,@JsonKey(name: 'suggested_questions') List<SuggestedQuestion> suggestedQuestions, List<AgentTool> tools,@JsonKey(name: 'data_sources') List<DataSource> dataSources
});




}
/// @nodoc
class _$AgentCopyWithImpl<$Res>
    implements $AgentCopyWith<$Res> {
  _$AgentCopyWithImpl(this._self, this._then);

  final Agent _self;
  final $Res Function(Agent) _then;

/// Create a copy of Agent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? agentId = null,Object? accounts = null,Object? isGlobal = null,Object? status = null,Object? agentName = null,Object? agentSubtitle = freezed,Object? agentDescription = freezed,Object? agentImageUrl = freezed,Object? agentProfileText = freezed,Object? agentInstructions = freezed,Object? agentWelcomeMessage = freezed,Object? modelId = freezed,Object? temperature = freezed,Object? displayOrder = freezed,Object? suggestedQuestions = null,Object? tools = null,Object? dataSources = null,}) {
  return _then(_self.copyWith(
agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,accounts: null == accounts ? _self.accounts : accounts // ignore: cast_nullable_to_non_nullable
as List<String>,isGlobal: null == isGlobal ? _self.isGlobal : isGlobal // ignore: cast_nullable_to_non_nullable
as bool,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AgentStatus,agentName: null == agentName ? _self.agentName : agentName // ignore: cast_nullable_to_non_nullable
as String,agentSubtitle: freezed == agentSubtitle ? _self.agentSubtitle : agentSubtitle // ignore: cast_nullable_to_non_nullable
as String?,agentDescription: freezed == agentDescription ? _self.agentDescription : agentDescription // ignore: cast_nullable_to_non_nullable
as String?,agentImageUrl: freezed == agentImageUrl ? _self.agentImageUrl : agentImageUrl // ignore: cast_nullable_to_non_nullable
as String?,agentProfileText: freezed == agentProfileText ? _self.agentProfileText : agentProfileText // ignore: cast_nullable_to_non_nullable
as String?,agentInstructions: freezed == agentInstructions ? _self.agentInstructions : agentInstructions // ignore: cast_nullable_to_non_nullable
as String?,agentWelcomeMessage: freezed == agentWelcomeMessage ? _self.agentWelcomeMessage : agentWelcomeMessage // ignore: cast_nullable_to_non_nullable
as String?,modelId: freezed == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String?,temperature: freezed == temperature ? _self.temperature : temperature // ignore: cast_nullable_to_non_nullable
as double?,displayOrder: freezed == displayOrder ? _self.displayOrder : displayOrder // ignore: cast_nullable_to_non_nullable
as int?,suggestedQuestions: null == suggestedQuestions ? _self.suggestedQuestions : suggestedQuestions // ignore: cast_nullable_to_non_nullable
as List<SuggestedQuestion>,tools: null == tools ? _self.tools : tools // ignore: cast_nullable_to_non_nullable
as List<AgentTool>,dataSources: null == dataSources ? _self.dataSources : dataSources // ignore: cast_nullable_to_non_nullable
as List<DataSource>,
  ));
}

}


/// Adds pattern-matching-related methods to [Agent].
extension AgentPatterns on Agent {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Agent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Agent() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Agent value)  $default,){
final _that = this;
switch (_that) {
case _Agent():
return $default(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Agent value)?  $default,){
final _that = this;
switch (_that) {
case _Agent() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'agent_id')  String agentId,  List<String> accounts, @FlexibleBoolConverter()@JsonKey(name: 'is_global')  bool isGlobal, @JsonKey(name: 'status')  AgentStatus status, @JsonKey(name: 'agent_name')  String agentName, @JsonKey(name: 'agent_subtitle')  String? agentSubtitle, @JsonKey(name: 'agent_description')  String? agentDescription, @JsonKey(name: 'agent_image_url')  String? agentImageUrl, @JsonKey(name: 'agent_profile_text')  String? agentProfileText, @JsonKey(name: 'agent_instructions')  String? agentInstructions, @JsonKey(name: 'agent_welcome_message')  String? agentWelcomeMessage, @JsonKey(name: 'model_id')  String? modelId, @FlexibleDoubleConverter()@JsonKey(name: 'temperature')  double? temperature, @FlexibleIntConverter()@JsonKey(name: 'display_order')  int? displayOrder, @JsonKey(name: 'suggested_questions')  List<SuggestedQuestion> suggestedQuestions,  List<AgentTool> tools, @JsonKey(name: 'data_sources')  List<DataSource> dataSources)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Agent() when $default != null:
return $default(_that.agentId,_that.accounts,_that.isGlobal,_that.status,_that.agentName,_that.agentSubtitle,_that.agentDescription,_that.agentImageUrl,_that.agentProfileText,_that.agentInstructions,_that.agentWelcomeMessage,_that.modelId,_that.temperature,_that.displayOrder,_that.suggestedQuestions,_that.tools,_that.dataSources);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'agent_id')  String agentId,  List<String> accounts, @FlexibleBoolConverter()@JsonKey(name: 'is_global')  bool isGlobal, @JsonKey(name: 'status')  AgentStatus status, @JsonKey(name: 'agent_name')  String agentName, @JsonKey(name: 'agent_subtitle')  String? agentSubtitle, @JsonKey(name: 'agent_description')  String? agentDescription, @JsonKey(name: 'agent_image_url')  String? agentImageUrl, @JsonKey(name: 'agent_profile_text')  String? agentProfileText, @JsonKey(name: 'agent_instructions')  String? agentInstructions, @JsonKey(name: 'agent_welcome_message')  String? agentWelcomeMessage, @JsonKey(name: 'model_id')  String? modelId, @FlexibleDoubleConverter()@JsonKey(name: 'temperature')  double? temperature, @FlexibleIntConverter()@JsonKey(name: 'display_order')  int? displayOrder, @JsonKey(name: 'suggested_questions')  List<SuggestedQuestion> suggestedQuestions,  List<AgentTool> tools, @JsonKey(name: 'data_sources')  List<DataSource> dataSources)  $default,) {final _that = this;
switch (_that) {
case _Agent():
return $default(_that.agentId,_that.accounts,_that.isGlobal,_that.status,_that.agentName,_that.agentSubtitle,_that.agentDescription,_that.agentImageUrl,_that.agentProfileText,_that.agentInstructions,_that.agentWelcomeMessage,_that.modelId,_that.temperature,_that.displayOrder,_that.suggestedQuestions,_that.tools,_that.dataSources);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'agent_id')  String agentId,  List<String> accounts, @FlexibleBoolConverter()@JsonKey(name: 'is_global')  bool isGlobal, @JsonKey(name: 'status')  AgentStatus status, @JsonKey(name: 'agent_name')  String agentName, @JsonKey(name: 'agent_subtitle')  String? agentSubtitle, @JsonKey(name: 'agent_description')  String? agentDescription, @JsonKey(name: 'agent_image_url')  String? agentImageUrl, @JsonKey(name: 'agent_profile_text')  String? agentProfileText, @JsonKey(name: 'agent_instructions')  String? agentInstructions, @JsonKey(name: 'agent_welcome_message')  String? agentWelcomeMessage, @JsonKey(name: 'model_id')  String? modelId, @FlexibleDoubleConverter()@JsonKey(name: 'temperature')  double? temperature, @FlexibleIntConverter()@JsonKey(name: 'display_order')  int? displayOrder, @JsonKey(name: 'suggested_questions')  List<SuggestedQuestion> suggestedQuestions,  List<AgentTool> tools, @JsonKey(name: 'data_sources')  List<DataSource> dataSources)?  $default,) {final _that = this;
switch (_that) {
case _Agent() when $default != null:
return $default(_that.agentId,_that.accounts,_that.isGlobal,_that.status,_that.agentName,_that.agentSubtitle,_that.agentDescription,_that.agentImageUrl,_that.agentProfileText,_that.agentInstructions,_that.agentWelcomeMessage,_that.modelId,_that.temperature,_that.displayOrder,_that.suggestedQuestions,_that.tools,_that.dataSources);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Agent implements Agent {
  const _Agent({@JsonKey(name: 'agent_id') required this.agentId, final  List<String> accounts = const <String>[], @FlexibleBoolConverter()@JsonKey(name: 'is_global') required this.isGlobal, @JsonKey(name: 'status') required this.status, @JsonKey(name: 'agent_name') required this.agentName, @JsonKey(name: 'agent_subtitle') this.agentSubtitle, @JsonKey(name: 'agent_description') this.agentDescription, @JsonKey(name: 'agent_image_url') this.agentImageUrl, @JsonKey(name: 'agent_profile_text') this.agentProfileText, @JsonKey(name: 'agent_instructions') this.agentInstructions, @JsonKey(name: 'agent_welcome_message') this.agentWelcomeMessage, @JsonKey(name: 'model_id') this.modelId, @FlexibleDoubleConverter()@JsonKey(name: 'temperature') this.temperature, @FlexibleIntConverter()@JsonKey(name: 'display_order') this.displayOrder, @JsonKey(name: 'suggested_questions') final  List<SuggestedQuestion> suggestedQuestions = const <SuggestedQuestion>[], final  List<AgentTool> tools = const <AgentTool>[], @JsonKey(name: 'data_sources') final  List<DataSource> dataSources = const <DataSource>[]}): _accounts = accounts,_suggestedQuestions = suggestedQuestions,_tools = tools,_dataSources = dataSources;
  factory _Agent.fromJson(Map<String, dynamic> json) => _$AgentFromJson(json);

@override@JsonKey(name: 'agent_id') final  String agentId;
 final  List<String> _accounts;
@override@JsonKey() List<String> get accounts {
  if (_accounts is EqualUnmodifiableListView) return _accounts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_accounts);
}

@override@FlexibleBoolConverter()@JsonKey(name: 'is_global') final  bool isGlobal;
@override@JsonKey(name: 'status') final  AgentStatus status;
@override@JsonKey(name: 'agent_name') final  String agentName;
@override@JsonKey(name: 'agent_subtitle') final  String? agentSubtitle;
@override@JsonKey(name: 'agent_description') final  String? agentDescription;
@override@JsonKey(name: 'agent_image_url') final  String? agentImageUrl;
@override@JsonKey(name: 'agent_profile_text') final  String? agentProfileText;
@override@JsonKey(name: 'agent_instructions') final  String? agentInstructions;
@override@JsonKey(name: 'agent_welcome_message') final  String? agentWelcomeMessage;
@override@JsonKey(name: 'model_id') final  String? modelId;
@override@FlexibleDoubleConverter()@JsonKey(name: 'temperature') final  double? temperature;
@override@FlexibleIntConverter()@JsonKey(name: 'display_order') final  int? displayOrder;
 final  List<SuggestedQuestion> _suggestedQuestions;
@override@JsonKey(name: 'suggested_questions') List<SuggestedQuestion> get suggestedQuestions {
  if (_suggestedQuestions is EqualUnmodifiableListView) return _suggestedQuestions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_suggestedQuestions);
}

 final  List<AgentTool> _tools;
@override@JsonKey() List<AgentTool> get tools {
  if (_tools is EqualUnmodifiableListView) return _tools;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tools);
}

 final  List<DataSource> _dataSources;
@override@JsonKey(name: 'data_sources') List<DataSource> get dataSources {
  if (_dataSources is EqualUnmodifiableListView) return _dataSources;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_dataSources);
}


/// Create a copy of Agent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgentCopyWith<_Agent> get copyWith => __$AgentCopyWithImpl<_Agent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Agent&&(identical(other.agentId, agentId) || other.agentId == agentId)&&const DeepCollectionEquality().equals(other._accounts, _accounts)&&(identical(other.isGlobal, isGlobal) || other.isGlobal == isGlobal)&&(identical(other.status, status) || other.status == status)&&(identical(other.agentName, agentName) || other.agentName == agentName)&&(identical(other.agentSubtitle, agentSubtitle) || other.agentSubtitle == agentSubtitle)&&(identical(other.agentDescription, agentDescription) || other.agentDescription == agentDescription)&&(identical(other.agentImageUrl, agentImageUrl) || other.agentImageUrl == agentImageUrl)&&(identical(other.agentProfileText, agentProfileText) || other.agentProfileText == agentProfileText)&&(identical(other.agentInstructions, agentInstructions) || other.agentInstructions == agentInstructions)&&(identical(other.agentWelcomeMessage, agentWelcomeMessage) || other.agentWelcomeMessage == agentWelcomeMessage)&&(identical(other.modelId, modelId) || other.modelId == modelId)&&(identical(other.temperature, temperature) || other.temperature == temperature)&&(identical(other.displayOrder, displayOrder) || other.displayOrder == displayOrder)&&const DeepCollectionEquality().equals(other._suggestedQuestions, _suggestedQuestions)&&const DeepCollectionEquality().equals(other._tools, _tools)&&const DeepCollectionEquality().equals(other._dataSources, _dataSources));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,agentId,const DeepCollectionEquality().hash(_accounts),isGlobal,status,agentName,agentSubtitle,agentDescription,agentImageUrl,agentProfileText,agentInstructions,agentWelcomeMessage,modelId,temperature,displayOrder,const DeepCollectionEquality().hash(_suggestedQuestions),const DeepCollectionEquality().hash(_tools),const DeepCollectionEquality().hash(_dataSources));

@override
String toString() {
  return 'Agent(agentId: $agentId, accounts: $accounts, isGlobal: $isGlobal, status: $status, agentName: $agentName, agentSubtitle: $agentSubtitle, agentDescription: $agentDescription, agentImageUrl: $agentImageUrl, agentProfileText: $agentProfileText, agentInstructions: $agentInstructions, agentWelcomeMessage: $agentWelcomeMessage, modelId: $modelId, temperature: $temperature, displayOrder: $displayOrder, suggestedQuestions: $suggestedQuestions, tools: $tools, dataSources: $dataSources)';
}


}

/// @nodoc
abstract mixin class _$AgentCopyWith<$Res> implements $AgentCopyWith<$Res> {
  factory _$AgentCopyWith(_Agent value, $Res Function(_Agent) _then) = __$AgentCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'agent_id') String agentId, List<String> accounts,@FlexibleBoolConverter()@JsonKey(name: 'is_global') bool isGlobal,@JsonKey(name: 'status') AgentStatus status,@JsonKey(name: 'agent_name') String agentName,@JsonKey(name: 'agent_subtitle') String? agentSubtitle,@JsonKey(name: 'agent_description') String? agentDescription,@JsonKey(name: 'agent_image_url') String? agentImageUrl,@JsonKey(name: 'agent_profile_text') String? agentProfileText,@JsonKey(name: 'agent_instructions') String? agentInstructions,@JsonKey(name: 'agent_welcome_message') String? agentWelcomeMessage,@JsonKey(name: 'model_id') String? modelId,@FlexibleDoubleConverter()@JsonKey(name: 'temperature') double? temperature,@FlexibleIntConverter()@JsonKey(name: 'display_order') int? displayOrder,@JsonKey(name: 'suggested_questions') List<SuggestedQuestion> suggestedQuestions, List<AgentTool> tools,@JsonKey(name: 'data_sources') List<DataSource> dataSources
});




}
/// @nodoc
class __$AgentCopyWithImpl<$Res>
    implements _$AgentCopyWith<$Res> {
  __$AgentCopyWithImpl(this._self, this._then);

  final _Agent _self;
  final $Res Function(_Agent) _then;

/// Create a copy of Agent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? agentId = null,Object? accounts = null,Object? isGlobal = null,Object? status = null,Object? agentName = null,Object? agentSubtitle = freezed,Object? agentDescription = freezed,Object? agentImageUrl = freezed,Object? agentProfileText = freezed,Object? agentInstructions = freezed,Object? agentWelcomeMessage = freezed,Object? modelId = freezed,Object? temperature = freezed,Object? displayOrder = freezed,Object? suggestedQuestions = null,Object? tools = null,Object? dataSources = null,}) {
  return _then(_Agent(
agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,accounts: null == accounts ? _self._accounts : accounts // ignore: cast_nullable_to_non_nullable
as List<String>,isGlobal: null == isGlobal ? _self.isGlobal : isGlobal // ignore: cast_nullable_to_non_nullable
as bool,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AgentStatus,agentName: null == agentName ? _self.agentName : agentName // ignore: cast_nullable_to_non_nullable
as String,agentSubtitle: freezed == agentSubtitle ? _self.agentSubtitle : agentSubtitle // ignore: cast_nullable_to_non_nullable
as String?,agentDescription: freezed == agentDescription ? _self.agentDescription : agentDescription // ignore: cast_nullable_to_non_nullable
as String?,agentImageUrl: freezed == agentImageUrl ? _self.agentImageUrl : agentImageUrl // ignore: cast_nullable_to_non_nullable
as String?,agentProfileText: freezed == agentProfileText ? _self.agentProfileText : agentProfileText // ignore: cast_nullable_to_non_nullable
as String?,agentInstructions: freezed == agentInstructions ? _self.agentInstructions : agentInstructions // ignore: cast_nullable_to_non_nullable
as String?,agentWelcomeMessage: freezed == agentWelcomeMessage ? _self.agentWelcomeMessage : agentWelcomeMessage // ignore: cast_nullable_to_non_nullable
as String?,modelId: freezed == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String?,temperature: freezed == temperature ? _self.temperature : temperature // ignore: cast_nullable_to_non_nullable
as double?,displayOrder: freezed == displayOrder ? _self.displayOrder : displayOrder // ignore: cast_nullable_to_non_nullable
as int?,suggestedQuestions: null == suggestedQuestions ? _self._suggestedQuestions : suggestedQuestions // ignore: cast_nullable_to_non_nullable
as List<SuggestedQuestion>,tools: null == tools ? _self._tools : tools // ignore: cast_nullable_to_non_nullable
as List<AgentTool>,dataSources: null == dataSources ? _self._dataSources : dataSources // ignore: cast_nullable_to_non_nullable
as List<DataSource>,
  ));
}


}

// dart format on
