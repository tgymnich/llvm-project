//===----------------------------------------------------------------------===//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//===----------------------------------------------------------------------===//

#include "AMDGPUUnitTests.h"
#include "llvm/CodeGen/SelectionDAG.h"
#include "llvm/IR/IntrinsicsAMDGPU.h"

using namespace llvm;

class AMDGPUSelectionDAGTest : public AMDGPUCodeGenTestBase {
protected:
  std::unique_ptr<SelectionDAG> DAG;

  void SetUp() override {
    setUpImpl("amdgcn-amd-amdhsa", "gfx950", "");
    ASSERT_TRUE(TM);
    ASSERT_TRUE(parseMIR("--- |\n  define void @f() { ret void }\n...\n"
                         "---\nname: f\nbody: |\n  bb.0:\n...\n"));
    DAG = std::make_unique<SelectionDAG>(*TM, CodeGenOptLevel::None);
    DAG->init(getMF("f"), nullptr, nullptr, nullptr, nullptr, nullptr, nullptr);
  }

  SDValue matrix(Intrinsic::ID IID, SDValue A, SDValue B, SDValue C) {
    SDValue ID = DAG->getConstant(IID, SDLoc(), MVT::i32);
    SmallVector<SDValue> Ops = {ID, A, B, C};
    if (IID != Intrinsic::amdgcn_wmma_f32_16x16x16_f16) {
      SDValue Zero = DAG->getConstant(0, SDLoc(), MVT::i32);
      Ops.append(3, Zero);
    }
    return DAG->getNode(ISD::INTRINSIC_WO_CHAIN, SDLoc(), C.getValueType(),
                        Ops);
  }

  SDValue splat(EVT VT, const APFloat &Value) {
    SDValue Elt = DAG->getConstantFP(Value, SDLoc(), VT.getScalarType());
    SmallVector<SDValue> Elts(VT.getVectorNumElements(), Elt);
    return DAG->getBuildVector(VT, SDLoc(), Elts);
  }
};

TEST_F(AMDGPUSelectionDAGTest, MatrixKnownFPClass) {
  const Intrinsic::ID IDs[] = {Intrinsic::amdgcn_mfma_f32_32x32x4f16,
                               Intrinsic::amdgcn_mfma_f32_16x16x4f16,
                               Intrinsic::amdgcn_mfma_f32_4x4x4f16,
                               Intrinsic::amdgcn_mfma_f32_32x32x8f16,
                               Intrinsic::amdgcn_mfma_f32_16x16x16f16,
                               Intrinsic::amdgcn_mfma_f32_16x16x32_f16,
                               Intrinsic::amdgcn_mfma_f32_32x32x16_f16,
                               Intrinsic::amdgcn_wmma_f32_16x16x16_f16};
  const unsigned SrcElts[] = {4, 4, 4, 4, 4, 8, 8, 8};
  const unsigned DstElts[] = {32, 16, 4, 16, 4, 4, 16, 4};
  const uint32_t Accumulators[] = {
      0,          0x80000000, 0x3f800000, 1,          0x7effffff, 0xfeffffff,
      0x7f000000, 0xff000000, 0x7f7fffff, 0x7f800000, 0x7fc00000};
  for (unsigned I = 0; I != std::size(IDs); ++I) {
    EVT ABVT = EVT::getVectorVT(Context, MVT::f16, SrcElts[I]);
    EVT CDVT = EVT::getVectorVT(Context, MVT::f32, DstElts[I]);
    SDValue A = splat(ABVT, APFloat::getLargest(APFloat::IEEEhalf()));
    SDValue B = A;
    for (uint32_t Bits : Accumulators) {
      SCOPED_TRACE(Bits);
      SDValue C = splat(CDVT, APFloat(APFloat::IEEEsingle(), APInt(32, Bits)));
      SDValue D = matrix(IDs[I], A, B, C);
      bool Finite = (Bits & 0x7fffffff) <= 0x7effffff;
      KnownFPClass Known = DAG->computeKnownFPClass(D, fcAllFlags);
      EXPECT_EQ(Known.getKnownFPClasses(), Finite ? fcFinite : fcAllFlags);
      EXPECT_EQ(DAG->isKnownNeverNaN(D), Finite);
      APInt Demanded(CDVT.getVectorNumElements(), 1);
      EXPECT_EQ(
          DAG->computeKnownFPClass(D, Demanded, fcInf).isKnownNeverInfinity(),
          Finite);
    }

    SDValue C = splat(CDVT, APFloat(0.0f));
    SDValue NaN = splat(ABVT, APFloat::getQNaN(APFloat::IEEEhalf()));
    EXPECT_TRUE(DAG->computeKnownFPClass(matrix(IDs[I], NaN, B, C), fcAllFlags)
                    .isUnknown());
    SDValue Undef = DAG->getUNDEF(ABVT);
    EXPECT_TRUE(
        DAG->computeKnownFPClass(matrix(IDs[I], Undef, B, C), fcAllFlags)
            .isUnknown());
    SDValue Large = DAG->getConstantFP(
        APFloat::getLargest(APFloat::IEEEsingle()), SDLoc(), MVT::f32);
    SmallVector<SDValue> Elts(CDVT.getVectorNumElements(), C.getOperand(0));
    Elts.back() = Large;
    SDValue Mixed = DAG->getBuildVector(CDVT, SDLoc(), Elts);
    SDValue D = matrix(IDs[I], A, B, Mixed);
    APInt Demanded(CDVT.getVectorNumElements(), 1);
    EXPECT_TRUE(DAG->computeKnownFPClass(D, Demanded, fcAllFlags).isUnknown());
  }
}
