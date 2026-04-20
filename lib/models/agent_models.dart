import 'package:freezed_annotation/freezed_annotation.dart';

part 'agent_models.freezed.dart';
part 'agent_models.g.dart';

/// Accepts `true/false`, `"true"/"false"`, `1/0`, `"1"/"0"`.
class FlexibleBoolConverter implements JsonConverter<bool, Object?> {
  const FlexibleBoolConverter();

  @override
  bool fromJson(Object? json) {
    if (json == null) return false;
    if (json is bool) return json;
    if (json is num) return json != 0;
    if (json is String) {
      final v = json.trim().toLowerCase();
      if (v == 'true' || v == '1') return true;
      if (v == 'false' || v == '0' || v.isEmpty) return false;
    }
    throw FormatException('Cannot parse bool from: $json');
  }

  @override
  Object toJson(bool object) => object;
}

/// Accepts `int`, `double` (lossless), `"123"`.
class FlexibleIntConverter implements JsonConverter<int, Object?> {
  const FlexibleIntConverter();

  @override
  int fromJson(Object? json) {
    if (json == null) return 0;
    if (json is int) return json;
    if (json is double) return json.toInt();
    if (json is num) return json.toInt();
    if (json is String) return int.tryParse(json.trim()) ?? 0;
    throw FormatException('Cannot parse int from: $json');
  }

  @override
  Object toJson(int object) => object;
}

/// Accepts `double`, `int`, `"1.0"`.
class FlexibleDoubleConverter implements JsonConverter<double, Object?> {
  const FlexibleDoubleConverter();

  @override
  double fromJson(Object? json) {
    if (json == null) return 0.0;
    if (json is double) return json;
    if (json is int) return json.toDouble();
    if (json is num) return json.toDouble();
    if (json is String) return double.tryParse(json.trim()) ?? 0.0;
    throw FormatException('Cannot parse double from: $json');
  }

  @override
  Object toJson(double object) => object;
}

enum AgentStatus {
  @JsonValue('active')
  active,
  @JsonValue('coming_soon')
  comingSoon,
  @JsonValue('disabled')
  disabled,
}

enum AgentToolType {
  @JsonValue('bigquery')
  bigquery,
  @JsonValue('python')
  python,
  @JsonValue('code_execution')
  codeExecution,
  @JsonValue('action')
  action,
}

@freezed
sealed class SuggestedQuestion with _$SuggestedQuestion {
  const factory SuggestedQuestion({
    required String category,
    required String icon,
    @JsonKey(name: 'question_text') required String questionText,
    @FlexibleIntConverter() @JsonKey(name: 'display_order') required int displayOrder,
  }) = _SuggestedQuestion;

  factory SuggestedQuestion.fromJson(Map<String, dynamic> json) =>
      _$SuggestedQuestionFromJson(json);
}

@freezed
sealed class AgentTool with _$AgentTool {
  const factory AgentTool({
    @JsonKey(name: 'tool_id') required String toolId,
    @JsonKey(name: 'tool_name') required String toolName,
    @JsonKey(name: 'tool_description') required String toolDescription,
    @JsonKey(name: 'tool_type') required AgentToolType toolType,

    /// Often a stringified JSON schema in your current data.
    @JsonKey(name: 'tool_parameters') String? toolParameters,
    @JsonKey(name: 'tool_query_template') String? toolQueryTemplate,
    @JsonKey(name: 'tool_python_code') String? toolPythonCode,
    @JsonKey(name: 'tool_system_message') String? toolSystemMessage,
    @JsonKey(name: 'tool_result_instructions') String? toolResultInstructions,

    @JsonKey(name: 'tool_action_endpoint') String? toolActionEndpoint,
    @JsonKey(name: 'tool_action_method') String? toolActionMethod,

    /// Some agents have this as `"false"` / `null`.
    @FlexibleBoolConverter()
    @JsonKey(name: 'tool_requires_confirmation')
    bool? toolRequiresConfirmation,

    @FlexibleIntConverter() @JsonKey(name: 'tool_order') required int toolOrder,
  }) = _AgentTool;

  factory AgentTool.fromJson(Map<String, dynamic> json) =>
      _$AgentToolFromJson(json);
}

@freezed
sealed class DataSource with _$DataSource {
  const factory DataSource({
    @JsonKey(name: 'data_source_id') required String dataSourceId,
    @JsonKey(name: 'source_type') required String sourceType,
    @JsonKey(name: 'source_reference') required String sourceReference,
    @JsonKey(name: 'source_description') String? sourceDescription,
  }) = _DataSource;

  factory DataSource.fromJson(Map<String, dynamic> json) =>
      _$DataSourceFromJson(json);
}

@freezed
sealed class Agent with _$Agent {
  const factory Agent({
    @JsonKey(name: 'agent_id') required String agentId,
    @Default(<String>[]) List<String> accounts,
    @FlexibleBoolConverter() @JsonKey(name: 'is_global') required bool isGlobal,
    @JsonKey(name: 'status') required AgentStatus status,
    @JsonKey(name: 'agent_name') required String agentName,
    @JsonKey(name: 'agent_subtitle') String? agentSubtitle,
    @JsonKey(name: 'agent_description') String? agentDescription,
    @JsonKey(name: 'agent_image_url') String? agentImageUrl,
    @JsonKey(name: 'agent_profile_text') String? agentProfileText,
    @JsonKey(name: 'agent_instructions') String? agentInstructions,
    @JsonKey(name: 'agent_welcome_message') String? agentWelcomeMessage,
    @JsonKey(name: 'model_id') String? modelId,
    @FlexibleDoubleConverter() @JsonKey(name: 'temperature') double? temperature,
    @FlexibleIntConverter() @JsonKey(name: 'display_order') int? displayOrder,
    @JsonKey(name: 'suggested_questions')
    @Default(<SuggestedQuestion>[])
    List<SuggestedQuestion> suggestedQuestions,
    @Default(<AgentTool>[]) List<AgentTool> tools,
    @JsonKey(name: 'data_sources')
    @Default(<DataSource>[])
    List<DataSource> dataSources,
  }) = _Agent;

  factory Agent.fromJson(Map<String, dynamic> json) => _$AgentFromJson(json);
}

