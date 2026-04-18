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
// InterestedClasses masks via isKnownNeverInfinity() and friends), plus tests
// added after that migration, remain in this unit-test file.

TEST_F(AArch64GISelMITest, TestFPClassFLogDeduceSubnormalOrNegativeZero) {
  StringRef MIRString = R"(
    %ptr:_(p0) = G_IMPLICIT_DEF
    %val:_(s32) = G_LOAD %ptr(p0) :: (load (s32))
    %flog:_(s32) = G_FLOG %val
    %copy_flog:_(s32) = COPY %flog
)";

  setUp(MIRString);
  if (!TM)
    GTEST_SKIP();

  Register CopyReg = Copies[Copies.size() - 1];
  MachineInstr *FinalCopy = MRI->getVRegDef(CopyReg);
  Register SrcReg = FinalCopy->getOperand(1).getReg();

  GISelValueTracking Info(*MF);
  KnownFPClass Known =
      Info.computeKnownFPClass(SrcReg, fcNegZero | fcSubnormal);

  EXPECT_EQ(~(fcNegZero | fcSubnormal), Known.getKnownFPClasses());
  EXPECT_EQ(std::nullopt, Known.getSignBit());
}

TEST_F(AArch64GISelMITest, TestFPClassFPowPos) {
  StringRef MIRString = R"(
    %ptr:_(p0) = G_IMPLICIT_DEF
    %val:_(s32) = G_LOAD %ptr(p0) :: (load (s32))
    %exp:_(s32) = G_LOAD %ptr(p0) :: (load (s32))
    %fabs:_(s32) = G_FABS %val
    %fpow:_(s32) = G_FPOW %fabs, %exp
    %copy_fpow:_(s32) = COPY %fpow
)";

  setUp(MIRString);
  if (!TM)
    GTEST_SKIP();

  Register CopyReg = Copies[Copies.size() - 1];
  MachineInstr *FinalCopy = MRI->getVRegDef(CopyReg);
  Register SrcReg = FinalCopy->getOperand(1).getReg();

  GISelValueTracking Info(*MF);
  KnownFPClass Known = Info.computeKnownFPClass(SrcReg);

  EXPECT_EQ(fcPositive | fcNan, Known.getKnownFPClasses());
  EXPECT_EQ(std::nullopt, Known.getSignBit());
  EXPECT_TRUE(Info.isKnownNeverNaN(SrcReg, true));
}

TEST_F(AArch64GISelMITest, TestFPClassFPowPosNNaN) {
  StringRef MIRString = R"(
    %ptr:_(p0) = G_IMPLICIT_DEF
    %val:_(s32) = G_LOAD %ptr(p0) :: (load (s32))
    %exp:_(s32) = G_LOAD %ptr(p0) :: (load (s32))
    %fabs:_(s32) = nnan G_FABS %val
    %fabs_exp:_(s32) = nnan G_FABS %exp
    %fpow:_(s32) = G_FPOW %fabs, %fabs_exp
    %copy_fpow:_(s32) = COPY %fpow
)";

  setUp(MIRString);
  if (!TM)
    GTEST_SKIP();

  Register CopyReg = Copies[Copies.size() - 1];
  MachineInstr *FinalCopy = MRI->getVRegDef(CopyReg);
  Register SrcReg = FinalCopy->getOperand(1).getReg();

  GISelValueTracking Info(*MF);
  KnownFPClass Known = Info.computeKnownFPClass(SrcReg);

  EXPECT_EQ(fcPositive, Known.getKnownFPClasses());
  EXPECT_EQ(false, Known.getSignBit());
}

TEST_F(AArch64GISelMITest, TestFPClassFDivSqrt) {
  // The only negative value sqrt(x) can produce is -0.0, so the only negative
  // value 1.0 / sqrt(x) can produce is -Inf.
  StringRef MIRString = R"(
    %ptr:_(p0) = G_IMPLICIT_DEF
    %x:_(s32) = G_LOAD %ptr(p0) :: (load (s32))
    %sqrt:_(s32) = G_FSQRT %x
    %one:_(s32) = G_FCONSTANT float 1.0
    %fdiv:_(s32) = G_FDIV %one, %sqrt
    %copy_fdiv:_(s32) = COPY %fdiv
)";

  setUp(MIRString);
  if (!TM)
    GTEST_SKIP();

  Register CopyReg = Copies[Copies.size() - 1];
  MachineInstr *FinalCopy = MRI->getVRegDef(CopyReg);
  Register SrcReg = FinalCopy->getOperand(1).getReg();

  GISelValueTracking Info(*MF);
  KnownFPClass Known = Info.computeKnownFPClass(SrcReg);

  EXPECT_EQ(fcAllFlags & ~(fcNegNormal | fcNegSubnormal),
            Known.getKnownFPClasses());
  EXPECT_EQ(std::nullopt, Known.getSignBit());
}

TEST_F(AArch64GISelMITest, TestFPClassFDivNegSqrtNeg) {
  // The only negative value sqrt(-x) can produce is -0.0, so the only positive
  // value -1.0 / sqrt(-x) can produce is +Inf.
  StringRef MIRString = R"(
    %ptr:_(p0) = G_IMPLICIT_DEF
    %x:_(s32) = G_LOAD %ptr(p0) :: (load (s32))
    %neg_x:_(s32) = G_FNEG %x
    %sqrt:_(s32) = G_FSQRT %neg_x
    %neg_one:_(s32) = G_FCONSTANT float -1.0
    %fdiv:_(s32) = G_FDIV %neg_one, %sqrt
    %copy_fdiv:_(s32) = COPY %fdiv
)";

  setUp(MIRString);
  if (!TM)
    GTEST_SKIP();

  Register CopyReg = Copies[Copies.size() - 1];
  MachineInstr *FinalCopy = MRI->getVRegDef(CopyReg);
  Register SrcReg = FinalCopy->getOperand(1).getReg();

  GISelValueTracking Info(*MF);
  KnownFPClass Known = Info.computeKnownFPClass(SrcReg, fcPositive);

  EXPECT_EQ(fcAllFlags & ~(fcPosNormal | fcPosSubnormal),
            Known.getKnownFPClasses());
  EXPECT_EQ(std::nullopt, Known.getSignBit());
}

TEST_F(AArch64GISelMITest, TestFPClassSqrtFDiv) {
  // sqrt(1.0 / x) may produce -0.0 when x is -Inf, but cannot produce any
  // other negative value or a subnormal value.
  StringRef MIRString = R"(
    %ptr:_(p0) = G_IMPLICIT_DEF
    %x:_(s32) = G_LOAD %ptr(p0) :: (load (s32))
    %one:_(s32) = G_FCONSTANT float 1.0
    %inv:_(s32) = G_FDIV %one, %x
    %sqrt:_(s32) = G_FSQRT %inv
    %copy_sqrt:_(s32) = COPY %sqrt
)";

  setUp(MIRString);
  if (!TM)
    GTEST_SKIP();

  Register CopyReg = Copies[Copies.size() - 1];
  MachineInstr *FinalCopy = MRI->getVRegDef(CopyReg);
  Register SrcReg = FinalCopy->getOperand(1).getReg();

  GISelValueTracking Info(*MF);
  KnownFPClass Known = Info.computeKnownFPClass(SrcReg);

  EXPECT_EQ(fcNan | fcZero | fcPosNormal | fcPosInf, Known.getKnownFPClasses());
  EXPECT_EQ(std::nullopt, Known.getSignBit());
}

TEST_F(AArch64GISelMITest, TestFPClassFAcosPos) {
  // For 0 <= x <= 1, acos returns a non-negative finite value.
  // For x > 1, acos returns NaN.
  StringRef MIRString = R"(
    %ptr:_(p0) = G_IMPLICIT_DEF
    %val:_(s32) = G_LOAD %ptr(p0) :: (load (s32))
    %fabs:_(s32) = nnan ninf G_FABS %val
    %facos:_(s32) = G_FACOS %fabs
    %copy:_(s32) = COPY %facos
)";
  setUp(MIRString);
  if (!TM)
    GTEST_SKIP();
  Register CopyReg = Copies[Copies.size() - 1];
  MachineInstr *FinalCopy = MRI->getVRegDef(CopyReg);
  Register SrcReg = FinalCopy->getOperand(1).getReg();
  GISelValueTracking Info(*MF);
  KnownFPClass Known = Info.computeKnownFPClass(SrcReg);
  EXPECT_EQ(fcPosZero | fcPosNormal | fcQNan, Known.getKnownFPClasses());
  EXPECT_EQ(std::nullopt, Known.getSignBit());
}

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
  EXPECT_EQ(~fcInf, Known0.getKnownFPClasses());
  EXPECT_EQ(std::nullopt, Known0.getSignBit());
  EXPECT_TRUE(KnownInf0.isKnownNeverInfinity());

  // powi(finite, 2)  -->  fcPositive | fcNan
  Register CopyReg1 = Copies[Copies.size() - 3];
  MachineInstr *FinalCopy1 = MRI->getVRegDef(CopyReg1);
  Register SrcReg1 = FinalCopy1->getOperand(1).getReg();
  KnownFPClass Known1 = Info.computeKnownFPClass(SrcReg1, fcAllFlags);
  KnownFPClass KnownInf1 = Info.computeKnownFPClass(SrcReg1, fcInf);
  EXPECT_EQ(fcPositive | fcNan, Known1.getKnownFPClasses());
  EXPECT_EQ(std::nullopt, Known1.getSignBit());
  EXPECT_FALSE(KnownInf1.isKnownNeverInfinity());

  // powi(normal, -1)  -->  fcPosFinite
  Register CopyReg2 = Copies[Copies.size() - 2];
  MachineInstr *FinalCopy2 = MRI->getVRegDef(CopyReg2);
  Register SrcReg2 = FinalCopy2->getOperand(1).getReg();
  KnownFPClass Known2 = Info.computeKnownFPClass(SrcReg2, fcAllFlags);
  KnownFPClass KnownInf2 = Info.computeKnownFPClass(SrcReg2, fcInf);
  EXPECT_EQ(fcPosFinite, Known2.getKnownFPClasses());
  EXPECT_EQ(false, Known2.getSignBit());
  EXPECT_TRUE(KnownInf2.isKnownNeverInfinity());

  // powi(zero_or_nan, nonneg)  -->  ~fcInf
  Register CopyReg3 = Copies[Copies.size() - 1];
  MachineInstr *FinalCopy3 = MRI->getVRegDef(CopyReg3);
  Register SrcReg3 = FinalCopy3->getOperand(1).getReg();
  KnownFPClass KnownInf3 = Info.computeKnownFPClass(SrcReg3, fcInf);
  EXPECT_TRUE(KnownInf3.isKnownNeverInfinity());

  // TODO: Add powi(0/nan, exp), exp > 0  -->  fcNan | fcZero | fcPosNormal
}
