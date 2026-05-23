import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'realtime_filter_models.dart';

class RealtimeFilterController extends ChangeNotifier {
  RealtimeFilterController({List<RealtimeFilterLayer>? initialLayers})
    : _layers = List<RealtimeFilterLayer>.from(
        initialLayers ?? buildDefaultRealtimeFilterStack(),
      );

  final List<RealtimeFilterLayer> _layers;

  UnmodifiableListView<RealtimeFilterLayer> get layers =>
      UnmodifiableListView<RealtimeFilterLayer>(_layers);

  List<RealtimeFilterLayer> get activeLayers =>
      _layers.where(_isLayerActive).toList(growable: false);

  bool get hasActiveFilters => _layers.any(_isLayerActive);

  RealtimeFilterLayer layerFor(RealtimeFilterType type) {
    return _layers.firstWhere((layer) => layer.type == type);
  }

  bool isEnabled(RealtimeFilterType type) => layerFor(type).enabled;

  void toggle(RealtimeFilterType type, [bool? enabled]) {
    final index = _indexFor(type);
    final current = _layers[index];
    _layers[index] = current.copyWith(enabled: enabled ?? !current.enabled);
    notifyListeners();
  }

  void setIntensity(RealtimeFilterType type, double intensity) {
    final index = _indexFor(type);
    final current = _layers[index];
    _layers[index] = current.copyWith(intensity: intensity.clamp(0.0, 1.0));
    notifyListeners();
  }

  void setParameter(RealtimeFilterType type, String parameterId, double value) {
    final index = _indexFor(type);
    final current = _layers[index];
    final definition = realtimeFilterDefinitionFor(type);
    final parameterDefinition = definition.parameters.firstWhere(
      (parameter) => parameter.id == parameterId,
    );
    final nextParameters = Map<String, double>.from(current.parameters);
    nextParameters[parameterId] = value.clamp(
      parameterDefinition.min,
      parameterDefinition.max,
    );
    _layers[index] = current.copyWith(parameters: nextParameters);
    notifyListeners();
  }

  void moveLayer(int oldIndex, int newIndex) {
    if (oldIndex == newIndex ||
        oldIndex < 0 ||
        oldIndex >= _layers.length ||
        newIndex < 0 ||
        newIndex >= _layers.length) {
      return;
    }

    final layer = _layers.removeAt(oldIndex);
    _layers.insert(newIndex, layer);
    notifyListeners();
  }

  void reset() {
    _layers
      ..clear()
      ..addAll(buildDefaultRealtimeFilterStack());
    notifyListeners();
  }

  int _indexFor(RealtimeFilterType type) {
    return _layers.indexWhere((layer) => layer.type == type);
  }

  bool _isLayerActive(RealtimeFilterLayer layer) {
    return layer.enabled && layer.intensity > 0.001;
  }
}
