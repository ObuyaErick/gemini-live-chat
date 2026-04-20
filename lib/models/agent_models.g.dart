// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SuggestedQuestion _$SuggestedQuestionFromJson(Map<String, dynamic> json) =>
    _SuggestedQuestion(
      category: json['category'] as String,
      icon: json['icon'] as String,
      questionText: json['question_text'] as String,
      displayOrder: const FlexibleIntConverter().fromJson(
        json['display_order'],
      ),
    );

Map<String, dynamic> _$SuggestedQuestionToJson(
  _SuggestedQuestion instance,
) => <String, dynamic>{
  'category': instance.category,
  'icon': instance.icon,
  'question_text': instance.questionText,
  'display_order': const FlexibleIntConverter().toJson(instance.displayOrder),
};

_AgentTool _$AgentToolFromJson(Map<String, dynamic> json) => _AgentTool(
  toolId: json['tool_id'] as String,
  toolName: json['tool_name'] as String,
  toolDescription: json['tool_description'] as String,
  toolType: $enumDecode(_$AgentToolTypeEnumMap, json['tool_type']),
  toolParameters: json['tool_parameters'] as String?,
  toolQueryTemplate: json['tool_query_template'] as String?,
  toolPythonCode: json['tool_python_code'] as String?,
  toolSystemMessage: json['tool_system_message'] as String?,
  toolResultInstructions: json['tool_result_instructions'] as String?,
  toolActionEndpoint: json['tool_action_endpoint'] as String?,
  toolActionMethod: json['tool_action_method'] as String?,
  toolRequiresConfirmation: const FlexibleBoolConverter().fromJson(
    json['tool_requires_confirmation'],
  ),
  toolOrder: const FlexibleIntConverter().fromJson(json['tool_order']),
);

Map<String, dynamic> _$AgentToolToJson(_AgentTool instance) =>
    <String, dynamic>{
      'tool_id': instance.toolId,
      'tool_name': instance.toolName,
      'tool_description': instance.toolDescription,
      'tool_type': _$AgentToolTypeEnumMap[instance.toolType]!,
      'tool_parameters': instance.toolParameters,
      'tool_query_template': instance.toolQueryTemplate,
      'tool_python_code': instance.toolPythonCode,
      'tool_system_message': instance.toolSystemMessage,
      'tool_result_instructions': instance.toolResultInstructions,
      'tool_action_endpoint': instance.toolActionEndpoint,
      'tool_action_method': instance.toolActionMethod,
      'tool_requires_confirmation': _$JsonConverterToJson<Object?, bool>(
        instance.toolRequiresConfirmation,
        const FlexibleBoolConverter().toJson,
      ),
      'tool_order': const FlexibleIntConverter().toJson(instance.toolOrder),
    };

const _$AgentToolTypeEnumMap = {
  AgentToolType.bigquery: 'bigquery',
  AgentToolType.python: 'python',
  AgentToolType.codeExecution: 'code_execution',
  AgentToolType.action: 'action',
};

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) => value == null ? null : toJson(value);

_DataSource _$DataSourceFromJson(Map<String, dynamic> json) => _DataSource(
  dataSourceId: json['data_source_id'] as String,
  sourceType: json['source_type'] as String,
  sourceReference: json['source_reference'] as String,
  sourceDescription: json['source_description'] as String?,
);

Map<String, dynamic> _$DataSourceToJson(_DataSource instance) =>
    <String, dynamic>{
      'data_source_id': instance.dataSourceId,
      'source_type': instance.sourceType,
      'source_reference': instance.sourceReference,
      'source_description': instance.sourceDescription,
    };

_Agent _$AgentFromJson(Map<String, dynamic> json) => _Agent(
  agentId: json['agent_id'] as String,
  accounts:
      (json['accounts'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  isGlobal: const FlexibleBoolConverter().fromJson(json['is_global']),
  status: $enumDecode(_$AgentStatusEnumMap, json['status']),
  agentName: json['agent_name'] as String,
  agentSubtitle: json['agent_subtitle'] as String?,
  agentDescription: json['agent_description'] as String?,
  agentImageUrl: json['agent_image_url'] as String?,
  agentProfileText: json['agent_profile_text'] as String?,
  agentInstructions: json['agent_instructions'] as String?,
  agentWelcomeMessage: json['agent_welcome_message'] as String?,
  modelId: json['model_id'] as String?,
  temperature: const FlexibleDoubleConverter().fromJson(json['temperature']),
  displayOrder: const FlexibleIntConverter().fromJson(json['display_order']),
  suggestedQuestions:
      (json['suggested_questions'] as List<dynamic>?)
          ?.map((e) => SuggestedQuestion.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <SuggestedQuestion>[],
  tools:
      (json['tools'] as List<dynamic>?)
          ?.map((e) => AgentTool.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <AgentTool>[],
  dataSources:
      (json['data_sources'] as List<dynamic>?)
          ?.map((e) => DataSource.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <DataSource>[],
);

Map<String, dynamic> _$AgentToJson(_Agent instance) => <String, dynamic>{
  'agent_id': instance.agentId,
  'accounts': instance.accounts,
  'is_global': const FlexibleBoolConverter().toJson(instance.isGlobal),
  'status': _$AgentStatusEnumMap[instance.status]!,
  'agent_name': instance.agentName,
  'agent_subtitle': instance.agentSubtitle,
  'agent_description': instance.agentDescription,
  'agent_image_url': instance.agentImageUrl,
  'agent_profile_text': instance.agentProfileText,
  'agent_instructions': instance.agentInstructions,
  'agent_welcome_message': instance.agentWelcomeMessage,
  'model_id': instance.modelId,
  'temperature': _$JsonConverterToJson<Object?, double>(
    instance.temperature,
    const FlexibleDoubleConverter().toJson,
  ),
  'display_order': _$JsonConverterToJson<Object?, int>(
    instance.displayOrder,
    const FlexibleIntConverter().toJson,
  ),
  'suggested_questions': instance.suggestedQuestions,
  'tools': instance.tools,
  'data_sources': instance.dataSources,
};

const _$AgentStatusEnumMap = {
  AgentStatus.active: 'active',
  AgentStatus.comingSoon: 'coming_soon',
  AgentStatus.disabled: 'disabled',
};
