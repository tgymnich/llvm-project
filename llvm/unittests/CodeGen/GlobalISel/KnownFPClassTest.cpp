//===- KnownFPClassTest.cpp -----------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "GISelMITest.h"
#include "llvm/ADT/FloatingPointMode.h"
#include "llvm/CodeGen/GlobalISel/GISelValueTracking.h"
#include "llvm/CodeGen/GlobalISel/MachineIRBuilder.h"
#include "gtest/gtest.h"
#include <optional>

// Most of the single-register TestFPClass* cases previously living here have
// been ported to MIR-based tests driven by the `print<gisel-value-tracking>`
// printer pass (see
// llvm/test/CodeGen/AArch64/GlobalISel/knownfpclass-basic.mir and
// llvm/test/CodeGen/AArch64/GlobalISel/knownfpclass-ops.mir). Only tests that
// cannot be expressed by the printer (e.g. those that rely on restricted
// InterestedClasses masks via isKnownNeverInfinity() and friends) remain in
// this unit-test file.

// TestFPClassFPowIInf keeps its C++ form because case 3
// (`powi(zero_or_nan, nonneg)`) only proves `isKnownNeverInfinity()` under a
// restricted `fcInf` interest mask; with the full `fcAllFlags` query used by
// the printer, the result is `fcAllFlags` (unknown) so that behaviour cannot
// be observed via the MIR printer path.
TEST_F(AArch64GISelMITest, TestFPClassFPowIInf) {
  StringRef MIRString = R"(
    %ptr:_(p0) = G_IMPLICIT_DEF
    %load:_(s32) = G_LOAD %ptr(p0) :: (load (s32))
    %val:_(s32) = G_FREEZE %load
    %x:_(s32) = G_LOAD %ptr(p0) :: (load (s32))
    %finite:_(s32) = ninf G_FNEG %val
    %normal:_(s32) = G_FCONSTANT float 2.0
    %zero_or_nan:_(s32) = G_FREM %val, %val
    %nonneg_mask:_(s32) = G_CONSTANT i32 2147483647
    %nonneg:_(s32) = G_AND %x, %nonneg_mask
    %one:_(s32) = G_CONSTANT i32 1
    %two:_(s32) = G_CONSTANT i32 2
    %negone:_(s32) = G_CONSTANT i32 -1
    %fpowi0:_(s32) = G_FPOWI %finite, %one
    %copy_fpowi0:_(s32) = COPY %fpowi0
    %fpowi1:_(s32) = G_FPOWI %finite, %two
    %copy_fpowi1:_(s32) = COPY %fpowi1
    %fpowi2:_(s32) = G_FPOWI %normal, %negone
    %copy_fpowi2:_(s32) = COPY %fpowi2
    %fpowi3:_(s32) = G_FPOWI %zero_or_nan, %nonneg
    %copy_fpowi3:_(s32) = COPY %fpowi3
)";

  setUp(MIRString);
  if (!TM)
    GTEST_SKIP();

  GISelValueTracking Info(*MF);

  // powi(finite, 1)  -->  ~fcInf
  Register CopyReg0 = Copies[Copies.size() - 4];
  MachineInstr *FinalCopy0 = MRI->getVRegDef(CopyReg0);
  Register SrcReg0 = FinalCopy0->getOperand(1).getReg();
  KnownFPClass Known0 = Info.computeKnownFPClass(SrcReg0, fcAllFlags);
  KnownFPClass KnownInf0 = Info.computeKnownFPClass(SrcReg0, fcInf);
  EXPECT_EQ(~fcInf, Known0.KnownFPClasses);
  EXPECT_EQ(std::nullopt, Known0.SignBit);
  EXPECT_TRUE(KnownInf0.isKnownNeverInfinity());

  // powi(finite, 2)  -->  fcPositive | fcNan
  Register CopyReg1 = Copies[Copies.size() - 3];
  MachineInstr *FinalCopy1 = MRI->getVRegDef(CopyReg1);
  Register SrcReg1 = FinalCopy1->getOperand(1).getReg();
  KnownFPClass Known1 = Info.computeKnownFPClass(SrcReg1, fcAllFlags);
  KnownFPClass KnownInf1 = Info.computeKnownFPClass(SrcReg1, fcInf);
  EXPECT_EQ(fcPositive | fcNan, Known1.KnownFPClasses);
  EXPECT_EQ(std::nullopt, Known1.SignBit);
  EXPECT_FALSE(KnownInf1.isKnownNeverInfinity());

  // powi(normal, -1)  -->  fcPosFinite
  Register CopyReg2 = Copies[Copies.size() - 2];
  MachineInstr *FinalCopy2 = MRI->getVRegDef(CopyReg2);
  Register SrcReg2 = FinalCopy2->getOperand(1).getReg();
  KnownFPClass Known2 = Info.computeKnownFPClass(SrcReg2, fcAllFlags);
  KnownFPClass KnownInf2 = Info.computeKnownFPClass(SrcReg2, fcInf);
  EXPECT_EQ(fcPosFinite, Known2.KnownFPClasses);
  EXPECT_EQ(false, Known2.SignBit);
  EXPECT_TRUE(KnownInf2.isKnownNeverInfinity());

  // powi(zero_or_nan, nonneg)  -->  ~fcInf
  Register CopyReg3 = Copies[Copies.size() - 1];
  MachineInstr *FinalCopy3 = MRI->getVRegDef(CopyReg3);
  Register SrcReg3 = FinalCopy3->getOperand(1).getReg();
  KnownFPClass KnownInf3 = Info.computeKnownFPClass(SrcReg3, fcInf);
  EXPECT_TRUE(KnownInf3.isKnownNeverInfinity());

  // TODO: Add powi(0/nan, exp), exp > 0  -->  fcNan | fcZero | fcPosNormal
}
