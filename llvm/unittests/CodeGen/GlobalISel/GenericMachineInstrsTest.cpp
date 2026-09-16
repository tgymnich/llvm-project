//===- GenericMachineInstrsTest.cpp --------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "llvm/CodeGen/GlobalISel/GenericMachineInstrs.h"
#include "GISelMITest.h"

template <typename WrapperT>
static void expectOpcodes(MachineIRBuilder &B, ArrayRef<unsigned> Opcodes) {
  for (unsigned Opcode : Opcodes) {
    MachineInstr *MI = B.buildInstr(Opcode).getInstr();
    EXPECT_TRUE(isa<WrapperT>(MI)) << Opcode;
    MI->eraseFromParent();
  }
}

TEST_F(AMDGPUGISelMITest, GenericMachineInstrWrapperCoverage) {
  setUp();
  if (!TM)
    GTEST_SKIP();

  expectOpcodes<GIntUnaryOp>(
      B, {TargetOpcode::G_ABS, TargetOpcode::G_BITREVERSE,
          TargetOpcode::G_BSWAP, TargetOpcode::G_CTLS, TargetOpcode::G_CTLZ,
          TargetOpcode::G_CTLZ_ZERO_POISON, TargetOpcode::G_CTPOP,
          TargetOpcode::G_CTTZ, TargetOpcode::G_CTTZ_ZERO_POISON});
  expectOpcodes<GFunnelShift>(B, {TargetOpcode::G_FSHL, TargetOpcode::G_FSHR});
  expectOpcodes<GRotate>(B, {TargetOpcode::G_ROTL, TargetOpcode::G_ROTR});

  expectOpcodes<GIntBinOp>(B,
                           {TargetOpcode::G_ABDS, TargetOpcode::G_ABDU,
                            TargetOpcode::G_SADDSAT, TargetOpcode::G_UADDSAT,
                            TargetOpcode::G_SSUBSAT, TargetOpcode::G_USUBSAT,
                            TargetOpcode::G_SAVGCEIL, TargetOpcode::G_SAVGFLOOR,
                            TargetOpcode::G_UAVGCEIL, TargetOpcode::G_UAVGFLOOR,
                            TargetOpcode::G_SMULH, TargetOpcode::G_UMULH});
  expectOpcodes<GBitfieldExtract>(B,
                                  {TargetOpcode::G_SBFX, TargetOpcode::G_UBFX});
  expectOpcodes<GFixedPointOp>(
      B, {TargetOpcode::G_SDIVFIX, TargetOpcode::G_SDIVFIXSAT,
          TargetOpcode::G_SMULFIX, TargetOpcode::G_SMULFIXSAT,
          TargetOpcode::G_UDIVFIX, TargetOpcode::G_UDIVFIXSAT,
          TargetOpcode::G_UMULFIX, TargetOpcode::G_UMULFIXSAT});

  expectOpcodes<GFPUnaryOp>(
      B, {TargetOpcode::G_FABS,          TargetOpcode::G_FACOS,
          TargetOpcode::G_FASIN,         TargetOpcode::G_FATAN,
          TargetOpcode::G_FCANONICALIZE, TargetOpcode::G_FCEIL,
          TargetOpcode::G_FCOS,          TargetOpcode::G_FCOSH,
          TargetOpcode::G_FEXP,          TargetOpcode::G_FEXP2,
          TargetOpcode::G_FEXP10,        TargetOpcode::G_FFLOOR,
          TargetOpcode::G_FLOG,          TargetOpcode::G_FLOG2,
          TargetOpcode::G_FLOG10,        TargetOpcode::G_FNEARBYINT,
          TargetOpcode::G_FNEG,          TargetOpcode::G_FRINT,
          TargetOpcode::G_FSIN,          TargetOpcode::G_FSINH,
          TargetOpcode::G_FSQRT,         TargetOpcode::G_FTAN,
          TargetOpcode::G_FTANH,         TargetOpcode::G_LROUND,
          TargetOpcode::G_LLROUND});
  expectOpcodes<GFBinOp>(B,
                         {TargetOpcode::G_FATAN2, TargetOpcode::G_FCOPYSIGN,
                          TargetOpcode::G_FLDEXP, TargetOpcode::G_FMAXIMUMNUM,
                          TargetOpcode::G_FMINIMUMNUM, TargetOpcode::G_FPOWI,
                          TargetOpcode::G_FREM});
  expectOpcodes<GFMulAdd>(B, {TargetOpcode::G_FMA, TargetOpcode::G_FMAD});
  expectOpcodes<GFPMultiResultOp>(
      B,
      {TargetOpcode::G_FFREXP, TargetOpcode::G_FMODF, TargetOpcode::G_FSINCOS});
  expectOpcodes<GIsFPClass>(B, {TargetOpcode::G_IS_FPCLASS});

  expectOpcodes<GSeqVecReduce>(B, {TargetOpcode::G_VECREDUCE_SEQ_FADD,
                                   TargetOpcode::G_VECREDUCE_SEQ_FMUL});
  expectOpcodes<GVectorCompress>(B, {TargetOpcode::G_VECTOR_COMPRESS});
}

TEST_F(AMDGPUGISelMITest, BranchWrapperAccessors) {
  setUp();
  if (!TM)
    GTEST_SKIP();

  GBr *Br = cast<GBr>(B.buildBr(*EntryMBB).getInstr());
  EXPECT_EQ(Br->getTargetMBB(), EntryMBB);
  Br->eraseFromParent();

  Register Target = MRI->createGenericVirtualRegister(LLT::pointer(0, 64));
  B.buildUndef(Target);
  GBrIndirect *BrIndirect =
      cast<GBrIndirect>(B.buildBrIndirect(Target).getInstr());
  EXPECT_EQ(BrIndirect->getTargetReg(), Target);
  BrIndirect->eraseFromParent();

  Register Index = MRI->createGenericVirtualRegister(LLT::scalar(64));
  B.buildUndef(Index);
  constexpr unsigned JumpTableIndex = 7;
  GBrJT *BrJT =
      cast<GBrJT>(B.buildBrJT(Target, JumpTableIndex, Index).getInstr());
  EXPECT_EQ(BrJT->getJumpTableReg(), Target);
  EXPECT_EQ(BrJT->getJumpTableIndex(), JumpTableIndex);
  EXPECT_EQ(BrJT->getIndexReg(), Index);
}
