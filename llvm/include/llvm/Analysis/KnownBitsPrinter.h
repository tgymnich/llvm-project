//===- KnownBitsPrinter.h - Printer for computeKnownBits --------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_ANALYSIS_KNOWNBITSPRINTER_H
#define LLVM_ANALYSIS_KNOWNBITSPRINTER_H

#include "llvm/IR/PassManager.h"
#include "llvm/Support/Compiler.h"

namespace llvm {

class raw_ostream;

/// Print known bits, sign bits and known-never-zero for every integer or
/// pointer typed argument and instruction of a function.
class KnownBitsPrinterPass
    : public RequiredPassInfoMixin<KnownBitsPrinterPass> {
  raw_ostream &OS;

public:
  explicit KnownBitsPrinterPass(raw_ostream &OS) : OS(OS) {}

  LLVM_ABI PreservedAnalyses run(Function &F, FunctionAnalysisManager &AM);
};

} // end namespace llvm

#endif // LLVM_ANALYSIS_KNOWNBITSPRINTER_H
