//===- KnownBitsPrinter.cpp - Printer for computeKnownBits ----------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "llvm/Analysis/KnownBitsPrinter.h"
#include "llvm/Analysis/AssumptionCache.h"
#include "llvm/Analysis/DomConditionCache.h"
#include "llvm/Analysis/TargetLibraryInfo.h"
#include "llvm/Analysis/ValueTracking.h"
#include "llvm/IR/Dominators.h"
#include "llvm/IR/InstIterator.h"
#include "llvm/IR/Instructions.h"
#include "llvm/Support/KnownBits.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

static bool hasKnownBits(const Value &V) {
  Type *Ty = V.getType();
  return Ty->isIntOrIntVectorTy() || Ty->isPtrOrPtrVectorTy();
}

PreservedAnalyses KnownBitsPrinterPass::run(Function &F,
                                            FunctionAnalysisManager &AM) {
  AssumptionCache &AC = AM.getResult<AssumptionAnalysis>(F);
  DominatorTree &DT = AM.getResult<DominatorTreeAnalysis>(F);
  TargetLibraryInfo &TLI = AM.getResult<TargetLibraryAnalysis>(F);

  // InstCombine reaches dominating branch conditions through a
  // DomConditionCache, so register them here too.
  DomConditionCache DC;
  for (BasicBlock &BB : F)
    if (auto *BI = dyn_cast<CondBrInst>(BB.getTerminator()))
      DC.registerBranch(BI);

  SimplifyQuery SQ(F.getDataLayout(), &TLI, &DT, &AC, /*CXTI=*/nullptr,
                   /*UseInstrInfo=*/true, /*CanUseUndef=*/true, &DC);

  auto Print = [&](const Value &V, const Instruction *CxtI) {
    if (!hasKnownBits(V))
      return;
    SimplifyQuery Q = CxtI ? SQ.getWithInstruction(CxtI) : SQ;
    if (CxtI) {
      // Instructions print with a leading indent already.
      OS << V;
    } else {
      OS << "  ";
      V.printAsOperand(OS);
    }
    OS << " KnownBits:" << computeKnownBits(&V, Q)
       << " SignBits:" << ComputeNumSignBits(&V, Q)
       << " IsKnownNeverZero:" << isKnownNonZero(&V, Q) << '\n';
  };

  OS << "name: ";
  F.printAsOperand(OS, /*PrintType=*/false);
  OS << '\n';

  for (Argument &A : F.args())
    Print(A, /*CxtI=*/nullptr);

  for (Instruction &I : instructions(F))
    Print(I, &I);

  return PreservedAnalyses::all();
}
