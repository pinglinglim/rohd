/// Copyright (C) 2021 Intel Corporation
/// SPDX-License-Identifier: BSD-3-Clause
///
/// synth_builder.dart
/// Definition for something that builds synthesis of a module hierarchy
///
/// 2021 August 26
/// Author: Max Korbel <max.korbel@intel.com>
///

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/uniquifier.dart';

/// A generic class which can convert a module into a generated output using a [Synthesizer].
class SynthBuilder {
  /// The top-level [Module] to be synthesized.
  final Module top;

  /// The [Synthesizer] to use for generating an output.
  final Synthesizer synthesizer;

  /// A [Map] from instances of [Module]s to the type that should represent them in
  /// the synthesized output.
  final Map<Module, String> _moduleToInstanceTypeMap = {};

  /// All the [SynthesisResult]s generated by this [SynthBuilder].
  final Set<SynthesisResult> _synthesisResults = {};

  /// [Uniquifier] for instance type names.
  final Uniquifier _instanceTypeUniquifier = Uniquifier();

  SynthBuilder(this.top, this.synthesizer) {
    var modulesToParse = <Module>[top];
    for (var i = 0; i < modulesToParse.length; i++) {
      var moduleI = modulesToParse[i];
      if (!synthesizer.generatesDefinition(moduleI)) continue;
      modulesToParse.addAll(moduleI.subModules);
    }

    // go backwards to start from the bottom (...now we're here)
    // critical to go in this order for caching to work properly
    for (var module in modulesToParse.reversed) {
      if (synthesizer.generatesDefinition(module)) _getInstanceType(module);
    }
  }

  /// Collects a [List] of [String]s representing file contents generated by
  /// the [synthesizer].
  List<String> getFileContents() {
    var fileContents = <String>[];
    for (var synthesisResult in _synthesisResults.toList().reversed) {
      fileContents.add(synthesisResult.toFileContents());
    }
    return fileContents.toSet().toList(); // no dupes!
    //TODO: is this toSet necessary anymore w/ the caching?
  }

  /// Provides an instance type name for [module].
  ///
  /// If a name already exists for [module], it will return the same one.
  /// If another [Module] is equivalent (as determined by comparing the
  /// [SynthesisResult]s), they will both get the same name.
  String _getInstanceType(Module module) {
    if (_moduleToInstanceTypeMap.containsKey(module)) {
      return _moduleToInstanceTypeMap[module]!;
    }
    var newName = module.runtimeType.toString();

    var newSynthesisResult =
        synthesizer.synthesize(module, _moduleToInstanceTypeMap);
    if (_synthesisResults.contains(newSynthesisResult)) {
      // a name for this module already exists
      newName = _moduleToInstanceTypeMap[
          _synthesisResults.lookup(newSynthesisResult)!.module]!;
    } else {
      _synthesisResults.add(newSynthesisResult);
      newName = _instanceTypeUniquifier.getUniqueName(initialName: newName);
    }

    _moduleToInstanceTypeMap[module] = newName;
    return newName;
  }
}