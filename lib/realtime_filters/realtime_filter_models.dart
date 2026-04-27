import 'package:flutter/material.dart';

enum RealtimeFilterType {
  losAngeles,
  aestheticBlur,
  lowLight,
  blackAndWhite,
  ultraHd,
}

class RealtimeFilterParameterDefinition {
  final String id;
  final String label;
  final double min;
  final double max;
  final double defaultValue;

  const RealtimeFilterParameterDefinition({
    required this.id,
    required this.label,
    required this.min,
    required this.max,
    required this.defaultValue,
  });
}

class RealtimeFilterDefinition {
  final RealtimeFilterType type;
  final String title;
  final String shortTitle;
  final String description;
  final IconData icon;
  final String shaderAssetKey;
  final List<RealtimeFilterParameterDefinition> parameters;

  const RealtimeFilterDefinition({
    required this.type,
    required this.title,
    required this.shortTitle,
    required this.description,
    required this.icon,
    required this.shaderAssetKey,
    this.parameters = const <RealtimeFilterParameterDefinition>[],
  });
}

class RealtimeFilterLayer {
  final RealtimeFilterType type;
  final bool enabled;
  final double intensity;
  final Map<String, double> parameters;

  const RealtimeFilterLayer({
    required this.type,
    this.enabled = false,
    this.intensity = 0.7,
    this.parameters = const <String, double>{},
  });

  factory RealtimeFilterLayer.defaults(RealtimeFilterType type) {
    final definition = realtimeFilterDefinitionFor(type);
    return RealtimeFilterLayer(
      type: type,
      parameters: <String, double>{
        for (final parameter in definition.parameters)
          parameter.id: parameter.defaultValue,
      },
    );
  }

  RealtimeFilterLayer copyWith({
    bool? enabled,
    double? intensity,
    Map<String, double>? parameters,
  }) {
    return RealtimeFilterLayer(
      type: type,
      enabled: enabled ?? this.enabled,
      intensity: intensity ?? this.intensity,
      parameters: parameters ?? this.parameters,
    );
  }

  double parameterValue(String parameterId) {
    if (parameters.containsKey(parameterId)) {
      return parameters[parameterId]!;
    }

    final definition = realtimeFilterDefinitionFor(type);
    for (final parameter in definition.parameters) {
      if (parameter.id == parameterId) {
        return parameter.defaultValue;
      }
    }
    return 0.0;
  }
}

const RealtimeFilterParameterDefinition blackWhiteBrightnessParameter =
    RealtimeFilterParameterDefinition(
      id: 'brightness',
      label: 'Brightness',
      min: -0.25,
      max: 0.25,
      defaultValue: 0.0,
    );

const List<RealtimeFilterDefinition>
realtimeFilterDefinitions = <RealtimeFilterDefinition>[
  RealtimeFilterDefinition(
    type: RealtimeFilterType.losAngeles,
    title: 'Los Angeles',
    shortTitle: 'L.A.',
    description:
        'Warm highlights, orange glow, lifted contrast, film grain, and a light vignette.',
    icon: Icons.wb_sunny_rounded,
    shaderAssetKey: 'shaders/los_angeles_effect.frag',
  ),
  RealtimeFilterDefinition(
    type: RealtimeFilterType.aestheticBlur,
    title: 'Aesthetic Blur',
    shortTitle: 'Blur',
    description:
        'Edge-aware subject preservation with background blur, skin smoothing, and a soft brightness lift.',
    icon: Icons.blur_on_rounded,
    shaderAssetKey: 'shaders/aesthetic_blur_effect.frag',
  ),
  RealtimeFilterDefinition(
    type: RealtimeFilterType.lowLight,
    title: 'Low Light Mode',
    shortTitle: 'Night',
    description:
        'Exposure lift, shadow denoise, detail recovery, and restrained edge sharpening for darker scenes.',
    icon: Icons.nights_stay_rounded,
    shaderAssetKey: 'shaders/low_light_effect.frag',
  ),
  RealtimeFilterDefinition(
    type: RealtimeFilterType.blackAndWhite,
    title: 'Black and White',
    shortTitle: 'B&W',
    description:
        'True grayscale conversion with a stronger contrast curve, optional grain, and brightness control.',
    icon: Icons.contrast_rounded,
    shaderAssetKey: 'shaders/black_white_effect.frag',
    parameters: <RealtimeFilterParameterDefinition>[
      blackWhiteBrightnessParameter,
    ],
  ),
  RealtimeFilterDefinition(
    type: RealtimeFilterType.ultraHd,
    title: '8K Ultra HD Effect',
    shortTitle: '8K',
    description:
        'Perceived super-resolution detail enhancement with clarity and texture sharpening.',
    icon: Icons.high_quality_rounded,
    shaderAssetKey: 'shaders/ultra_hd_effect.frag',
  ),
];

RealtimeFilterDefinition realtimeFilterDefinitionFor(RealtimeFilterType type) {
  return realtimeFilterDefinitions.firstWhere(
    (definition) => definition.type == type,
  );
}

List<RealtimeFilterLayer> buildDefaultRealtimeFilterStack() {
  return RealtimeFilterType.values
      .map(RealtimeFilterLayer.defaults)
      .toList(growable: true);
}
