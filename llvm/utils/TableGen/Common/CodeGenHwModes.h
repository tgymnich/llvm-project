//===--- CodeGenHwModes.h ---------------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
// Classes to parse and store HW mode information for instruction selection.
//===----------------------------------------------------------------------===//

#ifndef LLVM_UTILS_TABLEGEN_COMMON_CODEGENHWMODES_H
#define LLVM_UTILS_TABLEGEN_COMMON_CODEGENHWMODES_H

#include "SubtargetFeatureInfo.h"
#include "llvm/ADT/ArrayRef.h"
#include "llvm/ADT/DenseMap.h"
#include "llvm/ADT/StringRef.h"
#include <cassert>
#include <map>
#include <set>
#include <string>
#include <utility>
#include <vector>

// HwModeId -> list of predicates (definition)

namespace llvm {
class Record;
class RecordKeeper;

struct CodeGenHwModes;

struct HwModePredicates {
  std::set<SubtargetFeatureLiteral> FeaturesSet;
  std::set<std::set<SubtargetFeatureLiteral>> AnyOfFeatureSets;
  bool HasNonAsmPredicates = false;

  HwModePredicates() = default;
  HwModePredicates(ArrayRef<const Record *> Preds);

  static HwModePredicates createForDefaultMode(const CodeGenHwModes &CGH);
  void add(const HwModePredicates &Other);
  bool isSelfContradictory();
  bool conflictsWith(const HwModePredicates &Other) const;
};

struct HwMode {
  HwMode(const Record *R);
  HwMode(std::string Name, std::vector<const Record *> Predicates)
      : Name(std::move(Name)), Predicates(std::move(Predicates)) {}
  std::string Name;
  std::vector<const Record *> Predicates;
  bool Independent = false;
  void dump() const;
};

struct HwModeSelect {
  HwModeSelect(const Record *R, CodeGenHwModes &CGH);
  using PairType = std::pair<unsigned, const Record *>;
  std::vector<PairType> Items;
  void dump() const;
};

struct CodeGenHwModes {
  enum : unsigned { DefaultMode = 0 };
  static StringRef DefaultModeName;

  CodeGenHwModes(const RecordKeeper &R);
  unsigned getHwModeId(const Record *R) const;
  const HwMode &getMode(unsigned Id) const {
    assert(Id != 0 && "Mode id of 0 is reserved for the default mode");
    return Modes[Id - 1];
  }
  StringRef getModeName(unsigned Id, bool IncludeDefault = false) const {
    if (IncludeDefault && Id == CodeGenHwModes::DefaultMode)
      return DefaultModeName;
    return getMode(Id).Name;
  }
  const HwModeSelect &getHwModeSelect(const Record *R) const;
  const HwModePredicates &getModePredicates(unsigned ModeId) const;
  const Record *resolveModeSelect(const Record *SelectRec,
                                  ArrayRef<const Record *> PatPreds) const;
  const std::map<const Record *, HwModeSelect> &getHwModeSelects() const {
    return ModeSelects;
  }
  unsigned getNumModeIds() const { return Modes.size() + 1; }
  /// Number of modes defined in the .td files. Ids above this belong to
  /// combinations of simultaneously active modes synthesized by TableGen.
  unsigned getNumDefinedModes() const { return NumDefinedModes; }
  /// Bit set of the defined modes (bit Id - 1) that are active in mode \p Id.
  unsigned getModeBits(unsigned Id) const {
    assert(Id != 0 && "Mode id of 0 is reserved for the default mode");
    return ModeBits[Id - 1];
  }
  /// Return a C++ expression that is true iff \p Id is the active mode.
  std::string getModeCheck(unsigned Id) const;
  void dump() const;

private:
  void addCombinedModes();

  const RecordKeeper &Records;
  unsigned NumDefinedModes = 0;
  bool HasIndependentModes = false;
  std::vector<unsigned> ModeBits;
  DenseMap<const Record *, unsigned> ModeIds; // HwMode Record -> HwModeId
  std::vector<HwMode> Modes;
  std::map<const Record *, HwModeSelect> ModeSelects;
  mutable std::vector<HwModePredicates> PredicatesByMode;
};
} // namespace llvm

#endif // LLVM_UTILS_TABLEGEN_COMMON_CODEGENHWMODES_H
