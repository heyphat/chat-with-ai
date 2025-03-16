import 'chat.dart';

/// A class that standardizes token usage across different AI providers
class TokenUsage {
  // Token counts
  final int? promptTokens; // Input tokens
  final int? completionTokens; // Output tokens
  final int? totalTokens; // Total tokens used

  // Cost information
  final double? promptCost; // Cost for input tokens
  final double? completionCost; // Cost for output tokens
  final double? totalCost; // Total cost

  // Source provider information
  final AIProvider provider;
  final String model;

  // Raw provider response (useful for debugging or showing provider-specific info)
  final Map<String, dynamic>? rawProviderData;

  TokenUsage({
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
    this.promptCost,
    this.completionCost,
    this.totalCost,
    required this.provider,
    required this.model,
    this.rawProviderData,
  });

  factory TokenUsage.fromJson(Map<String, dynamic> json) {
    return TokenUsage(
      promptTokens: json['promptTokens'],
      completionTokens: json['completionTokens'],
      totalTokens: json['totalTokens'],
      promptCost:
          json['promptCost'] != null
              ? (json['promptCost'] as num).toDouble()
              : null,
      completionCost:
          json['completionCost'] != null
              ? (json['completionCost'] as num).toDouble()
              : null,
      totalCost:
          json['totalCost'] != null
              ? (json['totalCost'] as num).toDouble()
              : null,
      provider: AIProvider.values.byName(json['provider']),
      model: json['model'],
      rawProviderData:
          json['rawProviderData'] != null
              ? Map<String, dynamic>.from(json['rawProviderData'])
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'promptTokens': promptTokens,
      'completionTokens': completionTokens,
      'totalTokens': totalTokens,
      'promptCost': promptCost,
      'completionCost': completionCost,
      'totalCost': totalCost,
      'provider': provider.name,
      'model': model,
      'rawProviderData': rawProviderData,
    };
  }

  // Helper method to create TokenUsage from OpenAI response
  static TokenUsage? fromOpenAI(
    Map<String, dynamic> response,
    String model, {
    Map<String, double>? costPerThousandTokens,
  }) {
    try {
      // Debug the response structure
      print('OpenAI response keys: ${response.keys.toList()}');

      // Different OpenAI API versions and endpoints might structure the response differently
      Map<String, dynamic>? usage;

      // Check all possible locations for usage data
      if (response['usage'] is Map<String, dynamic>) {
        usage = response['usage'] as Map<String, dynamic>;
      } else if (response['response'] is Map<String, dynamic> &&
          response['response']['usage'] is Map<String, dynamic>) {
        usage = response['response']['usage'] as Map<String, dynamic>;
      } else if (response['result'] is Map<String, dynamic> &&
          response['result']['usage'] is Map<String, dynamic>) {
        usage = response['result']['usage'] as Map<String, dynamic>;
      }

      // If still no usage data, look for alternative field names
      if (usage == null) {
        if (response['token_usage'] is Map<String, dynamic>) {
          usage = response['token_usage'] as Map<String, dynamic>;
        } else if (response['tokenUsage'] is Map<String, dynamic>) {
          usage = response['tokenUsage'] as Map<String, dynamic>;
        }
      }

      if (usage == null) {
        return null;
      }

      // Try to extract token counts, handling different possible field names
      int? promptTokens = _extractTokenCount(usage, [
        'prompt_tokens',
        'promptTokens',
        'input_tokens',
        'inputTokens',
      ]);

      int? completionTokens = _extractTokenCount(usage, [
        'completion_tokens',
        'completionTokens',
        'output_tokens',
        'outputTokens',
      ]);

      int? totalTokens = _extractTokenCount(usage, [
        'total_tokens',
        'totalTokens',
      ]);

      // If we have prompt and completion but no total, calculate it
      if (totalTokens == null &&
          promptTokens != null &&
          completionTokens != null) {
        totalTokens = promptTokens + completionTokens;
      }

      // If essential token information is missing, return null
      if (promptTokens == null &&
          completionTokens == null &&
          totalTokens == null) {
        print('No token count information found in usage data');
        return null;
      }

      // Calculate costs if rates are provided
      double? promptCost, completionCost, totalCost;
      if (costPerThousandTokens != null) {
        final String modelKey =
            costPerThousandTokens.containsKey(model) ? model : 'default';

        final promptRate =
            costPerThousandTokens['${modelKey}_prompt'] ??
            costPerThousandTokens['default_prompt'] ??
            0;
        final completionRate =
            costPerThousandTokens['${modelKey}_completion'] ??
            costPerThousandTokens['default_completion'] ??
            0;

        // Calculate costs only if token values are available
        if (promptTokens != null) {
          promptCost = (promptTokens / 1000) * promptRate;
        }

        if (completionTokens != null) {
          completionCost = (completionTokens / 1000) * completionRate;
        }

        // Calculate total cost either from individual costs or from total tokens
        if (promptCost != null && completionCost != null) {
          totalCost = promptCost + completionCost;
        } else if (totalTokens != null) {
          // Fallback calculation using average rate if we only have total tokens
          final avgRate = (promptRate + completionRate) / 2;
          totalCost = (totalTokens / 1000) * avgRate;
        }
      }

      return TokenUsage(
        promptTokens: promptTokens,
        completionTokens: completionTokens,
        totalTokens: totalTokens,
        promptCost: promptCost,
        completionCost: completionCost,
        totalCost: totalCost,
        provider: AIProvider.openai,
        model: model,
        rawProviderData: usage,
      );
    } catch (e) {
      // If we encounter any exceptions during parsing, return null
      print('Error parsing OpenAI token usage: $e');
      return null;
    }
  }

  // Helper method to extract token count from different possible field names
  static int? _extractTokenCount(
    Map<String, dynamic> data,
    List<String> possibleKeys,
  ) {
    for (final key in possibleKeys) {
      if (data.containsKey(key) && data[key] is num) {
        return (data[key] as num).toInt();
      }
    }
    return null;
  }

  // Helper method to create TokenUsage from Anthropic response
  static TokenUsage? fromAnthropic(
    Map<String, dynamic> response,
    String model, {
    Map<String, double>? costPerThousandTokens,
  }) {
    if (response['usage'] == null) return null;

    final usage = response['usage'];
    final promptTokens = usage['input_tokens'] as int;
    final completionTokens = usage['output_tokens'] as int;
    final totalTokens = (promptTokens + completionTokens);

    // Calculate costs if rates are provided
    double? promptCost, completionCost, totalCost;
    if (costPerThousandTokens != null) {
      final String modelKey =
          costPerThousandTokens.containsKey(model) ? model : 'default';

      final promptRate =
          costPerThousandTokens['${modelKey}_input'] ??
          costPerThousandTokens['default_input'] ??
          0;
      final completionRate =
          costPerThousandTokens['${modelKey}_output'] ??
          costPerThousandTokens['default_output'] ??
          0;

      promptCost = (promptTokens / 1000) * promptRate;
      completionCost = (completionTokens / 1000) * completionRate;
      totalCost = promptCost + completionCost;
    }

    return TokenUsage(
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: totalTokens,
      promptCost: promptCost,
      completionCost: completionCost,
      totalCost: totalCost,
      provider: AIProvider.anthropic,
      model: model,
      rawProviderData: usage,
    );
  }

  // Helper method to create TokenUsage from Gemini response
  static TokenUsage? fromGemini(
    Map<String, dynamic> response,
    String model, {
    Map<String, double>? costPerThousandTokens,
  }) {
    if (response['usageMetadata'] == null) return null;

    final usage = response['usageMetadata'];
    final promptTokens = usage['promptTokenCount'] as int;
    final completionTokens = usage['candidatesTokenCount'] as int;
    final totalTokens = usage['totalTokenCount'] as int;

    // Calculate costs if rates are provided
    double? promptCost, completionCost, totalCost;
    if (costPerThousandTokens != null) {
      final String modelKey =
          costPerThousandTokens.containsKey(model) ? model : 'default';

      final promptRate =
          costPerThousandTokens['${modelKey}_prompt'] ??
          costPerThousandTokens['default_prompt'] ??
          0;
      final completionRate =
          costPerThousandTokens['${modelKey}_completion'] ??
          costPerThousandTokens['default_completion'] ??
          0;

      promptCost = (promptTokens / 1000) * promptRate;
      completionCost = (completionTokens / 1000) * completionRate;
      totalCost = promptCost + completionCost;
    }

    return TokenUsage(
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: totalTokens,
      promptCost: promptCost,
      completionCost: completionCost,
      totalCost: totalCost,
      provider: AIProvider.gemini,
      model: model,
      rawProviderData: usage,
    );
  }
}

/// A class for managing pricing information across different AI models
class TokenPricing {
  // Map of model name to pricing per 1000 tokens
  final Map<String, double> pricePerThousandTokens;

  TokenPricing({required this.pricePerThousandTokens});

  // Get cost for a specific model and token count
  double calculateCost(String model, int tokens, {bool isPrompt = true}) {
    final String modelKey =
        pricePerThousandTokens.containsKey(model) ? model : 'default';

    final String pricingKey =
        isPrompt ? '${modelKey}_prompt' : '${modelKey}_completion';

    final double rate =
        pricePerThousandTokens[pricingKey] ??
        pricePerThousandTokens['default_${isPrompt ? 'prompt' : 'completion'}'] ??
        0;

    return (tokens / 1000) * rate;
  }

  // Factory method to create default pricing
  factory TokenPricing.defaultPricing() {
    return TokenPricing(
      pricePerThousandTokens: {
        // OpenAI
        'gpt-3.5-turbo_prompt': 0.0005,
        'gpt-3.5-turbo_completion': 0.0015,
        'gpt-4_prompt': 0.03,
        'gpt-4_completion': 0.06,
        'gpt-4-turbo_prompt': 0.01,
        'gpt-4-turbo_completion': 0.03,

        // Anthropic
        'claude-3-opus_input': 0.015,
        'claude-3-opus_output': 0.075,
        'claude-3-sonnet_input': 0.003,
        'claude-3-sonnet_output': 0.015,
        'claude-3-haiku_input': 0.00025,
        'claude-3-haiku_output': 0.00125,

        // Gemini
        'gemini-pro_prompt': 0.00125,
        'gemini-pro_completion': 0.00375,
        'gemini-ultra_prompt': 0.01,
        'gemini-ultra_completion': 0.03,

        // Default fallback rates
        'default_prompt': 0.001,
        'default_completion': 0.002,
      },
    );
  }
}
