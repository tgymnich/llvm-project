; RUN: opt -passes=instcombine -S %s | FileCheck %s
; RUN: opt -passes=instcombine -S %s -denormal-fp-math=preserve-sign | FileCheck %s
; RUN: opt -passes=instcombine -S %s -denormal-fp-math=positive-zero | FileCheck %s

define i1 @finite_32x32x4f16() {
; CHECK-LABEL: @finite_32x32x4f16(
; CHECK: ret i1 false
  %d = call <32 x float> @llvm.amdgcn.mfma.f32.32x32x4f16(<4 x half> splat (half 65504.0), <4 x half> splat (half -65504.0), <32 x float> zeroinitializer, i32 0, i32 0, i32 0)
  %elt = extractelement <32 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @finite_16x16x4f16() {
; CHECK-LABEL: @finite_16x16x4f16(
; CHECK: ret i1 false
  %d = call <16 x float> @llvm.amdgcn.mfma.f32.16x16x4f16(<4 x half> splat (half 65504.0), <4 x half> splat (half -65504.0), <16 x float> zeroinitializer, i32 0, i32 0, i32 0)
  %elt = extractelement <16 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @finite_4x4x4f16() {
; CHECK-LABEL: @finite_4x4x4f16(
; CHECK: ret i1 false
  %d = call <4 x float> @llvm.amdgcn.mfma.f32.4x4x4f16(<4 x half> splat (half 65504.0), <4 x half> splat (half -65504.0), <4 x float> zeroinitializer, i32 0, i32 0, i32 0)
  %elt = extractelement <4 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @finite_32x32x8f16() {
; CHECK-LABEL: @finite_32x32x8f16(
; CHECK: ret i1 false
  %d = call <16 x float> @llvm.amdgcn.mfma.f32.32x32x8f16(<4 x half> splat (half 65504.0), <4 x half> splat (half -65504.0), <16 x float> zeroinitializer, i32 0, i32 0, i32 0)
  %elt = extractelement <16 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @finite_16x16x16f16() {
; CHECK-LABEL: @finite_16x16x16f16(
; CHECK: ret i1 false
  %d = call <4 x float> @llvm.amdgcn.mfma.f32.16x16x16f16(<4 x half> splat (half 65504.0), <4 x half> splat (half -65504.0), <4 x float> zeroinitializer, i32 0, i32 0, i32 0)
  %elt = extractelement <4 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @finite_16x16x32_f16() {
; CHECK-LABEL: @finite_16x16x32_f16(
; CHECK: ret i1 false
  %d = call <4 x float> @llvm.amdgcn.mfma.f32.16x16x32.f16(<8 x half> splat (half 65504.0), <8 x half> splat (half -65504.0), <4 x float> zeroinitializer, i32 0, i32 0, i32 0)
  %elt = extractelement <4 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @finite_32x32x16_f16() {
; CHECK-LABEL: @finite_32x32x16_f16(
; CHECK: ret i1 false
  %d = call <16 x float> @llvm.amdgcn.mfma.f32.32x32x16.f16(<8 x half> splat (half 65504.0), <8 x half> splat (half -65504.0), <16 x float> zeroinitializer, i32 0, i32 0, i32 0)
  %elt = extractelement <16 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @nan_a() {
; CHECK-LABEL: @nan_a(
; CHECK: fcmp ueq float
  %d = call <4 x float> @llvm.amdgcn.mfma.f32.16x16x16f16(<4 x half> splat (half 0xH7E00), <4 x half> zeroinitializer, <4 x float> zeroinitializer, i32 0, i32 0, i32 0)
  %elt = extractelement <4 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @inf_b() {
; CHECK-LABEL: @inf_b(
; CHECK: fcmp ueq float
  %d = call <4 x float> @llvm.amdgcn.mfma.f32.16x16x16f16(<4 x half> zeroinitializer, <4 x half> splat (half 0xH7C00), <4 x float> zeroinitializer, i32 0, i32 0, i32 0)
  %elt = extractelement <4 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @nonzero_c() {
; CHECK-LABEL: @nonzero_c(
; CHECK: ret i1 false
  %d = call <4 x float> @llvm.amdgcn.mfma.f32.16x16x16f16(<4 x half> splat (half 1.0), <4 x half> splat (half 1.0), <4 x float> splat (float 1.0), i32 0, i32 0, i32 0)
  %elt = extractelement <4 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @poison_element() {
; CHECK-LABEL: @poison_element(
; CHECK: fcmp ueq float
  %d = call <4 x float> @llvm.amdgcn.mfma.f32.16x16x16f16(<4 x half> <half 1.0, half 1.0, half 1.0, half poison>, <4 x half> splat (half 1.0), <4 x float> zeroinitializer, i32 0, i32 0, i32 0)
  %elt = extractelement <4 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @dynamic_a(<4 x half> %a) {
; CHECK-LABEL: @dynamic_a(
; CHECK: fcmp ueq float
  %d = call <4 x float> @llvm.amdgcn.mfma.f32.16x16x16f16(<4 x half> %a, <4 x half> splat (half 1.0), <4 x float> zeroinitializer, i32 0, i32 0, i32 0)
  %elt = extractelement <4 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @finite_non_splat() {
; CHECK-LABEL: @finite_non_splat(
; CHECK: ret i1 false
  %d = call <4 x float> @llvm.amdgcn.mfma.f32.16x16x16f16(<4 x half> <half 65504.0, half -65504.0, half 0.0, half 0xH0001>, <4 x half> <half -1.0, half 0.0, half 1.0, half 2.0>, <4 x float> zeroinitializer, i32 1, i32 1, i32 1)
  %elt = extractelement <4 x float> %d, i32 3
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @undemanded_nan() {
; CHECK-LABEL: @undemanded_nan(
; CHECK: fcmp ueq float
  %d = call <4 x float> @llvm.amdgcn.mfma.f32.16x16x16f16(<4 x half> <half 1.0, half 1.0, half 1.0, half 0xH7E00>, <4 x half> splat (half 1.0), <4 x float> zeroinitializer, i32 0, i32 0, i32 0)
  %elt = extractelement <4 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @bf16_not_finite() {
; CHECK-LABEL: @bf16_not_finite(
; CHECK: fcmp ueq float
  %d = call <4 x float> @llvm.amdgcn.mfma.f32.16x16x32.bf16(<8 x bfloat> splat (bfloat 0xR7F7F), <8 x bfloat> splat (bfloat 0xR7F7F), <4 x float> zeroinitializer, i32 0, i32 0, i32 0)
  %elt = extractelement <4 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @lane_local_finite(<4 x half> %a, i1 %cond) {
; CHECK-LABEL: @lane_local_finite(
; CHECK: fcmp ueq float
  br i1 %cond, label %matrix, label %exit
matrix:
  %finite = call <4 x i1> @llvm.is.fpclass.v4f16(<4 x half> %a, i32 504)
  %all = call i1 @llvm.vector.reduce.and.v4i1(<4 x i1> %finite)
  call void @llvm.assume(i1 %all)
  %d = call <4 x float> @llvm.amdgcn.mfma.f32.16x16x16f16(<4 x half> %a, <4 x half> splat (half 1.0), <4 x float> zeroinitializer, i32 0, i32 0, i32 0)
  %elt = extractelement <4 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
exit:
  ret i1 false
}

define i1 @finite_zero_inputs() {
; CHECK-LABEL: @finite_zero_inputs(
; CHECK: ret i1 false
  %d = call <4 x float> @llvm.amdgcn.mfma.f32.16x16x16f16(<4 x half> zeroinitializer, <4 x half> zeroinitializer, <4 x float> zeroinitializer, i32 0, i32 0, i32 0)
  %elt = extractelement <4 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @negative_zero_c() {
; CHECK-LABEL: @negative_zero_c(
; CHECK: ret i1 false
  %d = call <4 x float> @llvm.amdgcn.mfma.f32.16x16x16f16(<4 x half> splat (half 65504.0), <4 x half> splat (half -65504.0), <4 x float> splat (float -0.0), i32 0, i32 0, i32 0)
  %elt = extractelement <4 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @wmma_wave32() {
; CHECK-LABEL: @wmma_wave32(
; CHECK: ret i1 false
  %d = call <8 x float> @llvm.amdgcn.wmma.f32.16x16x16.f16.v8f32.v16f16(<16 x half> splat (half 65504.0), <16 x half> splat (half -65504.0), <8 x float> zeroinitializer)
  %elt = extractelement <8 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @wmma_wave64() {
; CHECK-LABEL: @wmma_wave64(
; CHECK: ret i1 false
  %d = call <4 x float> @llvm.amdgcn.wmma.f32.16x16x16.f16.v4f32.v16f16(<16 x half> splat (half 65504.0), <16 x half> splat (half -65504.0), <4 x float> splat (float -0.0))
  %elt = extractelement <4 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @wmma_gfx12_wave32() {
; CHECK-LABEL: @wmma_gfx12_wave32(
; CHECK: ret i1 false
  %d = call <8 x float> @llvm.amdgcn.wmma.f32.16x16x16.f16.v8f32.v8f16(<8 x half> splat (half 65504.0), <8 x half> splat (half -65504.0), <8 x float> zeroinitializer)
  %elt = extractelement <8 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @wmma_gfx12_wave64() {
; CHECK-LABEL: @wmma_gfx12_wave64(
; CHECK: ret i1 false
  %d = call <4 x float> @llvm.amdgcn.wmma.f32.16x16x16.f16.v4f32.v8f16(<8 x half> splat (half 65504.0), <8 x half> splat (half -65504.0), <4 x float> zeroinitializer)
  %elt = extractelement <4 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @wmma_nan() {
; CHECK-LABEL: @wmma_nan(
; CHECK: fcmp ueq float
  %d = call <8 x float> @llvm.amdgcn.wmma.f32.16x16x16.f16.v8f32.v16f16(<16 x half> splat (half 0xH7E00), <16 x half> zeroinitializer, <8 x float> zeroinitializer)
  %elt = extractelement <8 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @wmma_inf() {
; CHECK-LABEL: @wmma_inf(
; CHECK: fcmp ueq float
  %d = call <8 x float> @llvm.amdgcn.wmma.f32.16x16x16.f16.v8f32.v16f16(<16 x half> zeroinitializer, <16 x half> splat (half 0xH7C00), <8 x float> zeroinitializer)
  %elt = extractelement <8 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @wmma_nonzero_c() {
; CHECK-LABEL: @wmma_nonzero_c(
; CHECK: ret i1 false
  %d = call <8 x float> @llvm.amdgcn.wmma.f32.16x16x16.f16.v8f32.v16f16(<16 x half> splat (half 1.0), <16 x half> splat (half 1.0), <8 x float> splat (float 1.0))
  %elt = extractelement <8 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @wmma_dynamic_a(<16 x half> %a) {
; CHECK-LABEL: @wmma_dynamic_a(
; CHECK: fcmp ueq float
  %d = call <8 x float> @llvm.amdgcn.wmma.f32.16x16x16.f16.v8f32.v16f16(<16 x half> %a, <16 x half> splat (half 1.0), <8 x float> zeroinitializer)
  %elt = extractelement <8 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @wmma_mixed_nan() {
; CHECK-LABEL: @wmma_mixed_nan(
; CHECK: fcmp ueq float
  %d = call <4 x float> @llvm.amdgcn.wmma.f32.16x16x16.f16.v4f32.v8f16(<8 x half> <half 1.0, half 1.0, half 1.0, half 1.0, half 1.0, half 1.0, half 1.0, half 0xH7E00>, <8 x half> splat (half 1.0), <4 x float> zeroinitializer)
  %elt = extractelement <4 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @wmma_bf16_overflow() {
; CHECK-LABEL: @wmma_bf16_overflow(
; CHECK: fcmp ueq float
  %d = call <8 x float> @llvm.amdgcn.wmma.f32.16x16x16.bf16.v8f32.v16i16(<16 x i16> splat (i16 32639), <16 x i16> splat (i16 32639), <8 x float> zeroinitializer)
  %elt = extractelement <8 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @wmma_f16_overflow() {
; CHECK-LABEL: @wmma_f16_overflow(
; CHECK: fcmp ueq half
  %d = call <16 x half> @llvm.amdgcn.wmma.f16.16x16x16.f16.v16f16(<16 x half> splat (half 65504.0), <16 x half> splat (half 65504.0), <16 x half> zeroinitializer, i1 false)
  %elt = extractelement <16 x half> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f16(half %elt, i32 519)
  ret i1 %class
}

define i1 @mfma_f32_overflow() {
; CHECK-LABEL: @mfma_f32_overflow(
; CHECK: fcmp ueq float
  %d = call <4 x float> @llvm.amdgcn.mfma.f32.16x16x4f32(float 0x47EFFFFFE0000000, float 0x47EFFFFFE0000000, <4 x float> zeroinitializer, i32 0, i32 0, i32 0)
  %elt = extractelement <4 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @mfma_accumulator_limit() {
; CHECK-LABEL: @mfma_accumulator_limit(
; CHECK: ret i1 false
  %d = call <4 x float> @llvm.amdgcn.mfma.f32.16x16x16f16(<4 x half> splat (half 65504.0), <4 x half> splat (half -65504.0), <4 x float> splat (float 0x47DFFFFFE0000000), i32 0, i32 0, i32 0)
  %elt = extractelement <4 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @mfma_negative_accumulator_limit() {
; CHECK-LABEL: @mfma_negative_accumulator_limit(
; CHECK: ret i1 false
  %d = call <4 x float> @llvm.amdgcn.mfma.f32.16x16x16f16(<4 x half> splat (half 65504.0), <4 x half> splat (half -65504.0), <4 x float> splat (float 0xC7DFFFFFE0000000), i32 0, i32 0, i32 0)
  %elt = extractelement <4 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @mfma_above_accumulator_limit() {
; CHECK-LABEL: @mfma_above_accumulator_limit(
; CHECK: fcmp ueq float
  %d = call <4 x float> @llvm.amdgcn.mfma.f32.16x16x16f16(<4 x half> splat (half 65504.0), <4 x half> splat (half -65504.0), <4 x float> splat (float 0x47E0000000000000), i32 0, i32 0, i32 0)
  %elt = extractelement <4 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @mfma_below_negative_accumulator_limit() {
; CHECK-LABEL: @mfma_below_negative_accumulator_limit(
; CHECK: fcmp ueq float
  %d = call <4 x float> @llvm.amdgcn.mfma.f32.16x16x16f16(<4 x half> splat (half 65504.0), <4 x half> splat (half -65504.0), <4 x float> splat (float 0xC7E0000000000000), i32 0, i32 0, i32 0)
  %elt = extractelement <4 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @mfma_max_accumulator() {
; CHECK-LABEL: @mfma_max_accumulator(
; CHECK: fcmp ueq float
  %d = call <4 x float> @llvm.amdgcn.mfma.f32.16x16x16f16(<4 x half> splat (half 65504.0), <4 x half> splat (half -65504.0), <4 x float> splat (float 0x47EFFFFFE0000000), i32 0, i32 0, i32 0)
  %elt = extractelement <4 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @mfma_nan_accumulator() {
; CHECK-LABEL: @mfma_nan_accumulator(
; CHECK: fcmp ueq float
  %d = call <4 x float> @llvm.amdgcn.mfma.f32.16x16x16f16(<4 x half> splat (half 65504.0), <4 x half> splat (half -65504.0), <4 x float> splat (float 0x7FF8000000000000), i32 0, i32 0, i32 0)
  %elt = extractelement <4 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @mfma_inf_accumulator() {
; CHECK-LABEL: @mfma_inf_accumulator(
; CHECK: fcmp ueq float
  %d = call <4 x float> @llvm.amdgcn.mfma.f32.16x16x16f16(<4 x half> splat (half 65504.0), <4 x half> splat (half -65504.0), <4 x float> splat (float 0x7FF0000000000000), i32 0, i32 0, i32 0)
  %elt = extractelement <4 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @mfma_subnormal_accumulator() {
; CHECK-LABEL: @mfma_subnormal_accumulator(
; CHECK: ret i1 false
  %d = call <4 x float> @llvm.amdgcn.mfma.f32.16x16x16f16(<4 x half> splat (half 65504.0), <4 x half> splat (half -65504.0), <4 x float> splat (float 0x36A0000000000000), i32 0, i32 0, i32 0)
  %elt = extractelement <4 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @mfma_dynamic_accumulator(<4 x float> %c) {
; CHECK-LABEL: @mfma_dynamic_accumulator(
; CHECK: fcmp ueq float
  %d = call <4 x float> @llvm.amdgcn.mfma.f32.16x16x16f16(<4 x half> splat (half 65504.0), <4 x half> splat (half -65504.0), <4 x float> %c, i32 0, i32 0, i32 0)
  %elt = extractelement <4 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @mfma_mixed_accumulator() {
; CHECK-LABEL: @mfma_mixed_accumulator(
; CHECK: ret i1 false
  %d = call <4 x float> @llvm.amdgcn.mfma.f32.16x16x16f16(<4 x half> splat (half 65504.0), <4 x half> splat (half -65504.0), <4 x float> <float 1.0, float -1.0, float 0x47DFFFFFE0000000, float 0xC7DFFFFFE0000000>, i32 0, i32 0, i32 0)
  %elt = extractelement <4 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @mfma_undemanded_large_accumulator() {
; CHECK-LABEL: @mfma_undemanded_large_accumulator(
; CHECK: fcmp ueq float
  %d = call <4 x float> @llvm.amdgcn.mfma.f32.16x16x16f16(<4 x half> splat (half 65504.0), <4 x half> splat (half -65504.0), <4 x float> <float 1.0, float 1.0, float 1.0, float 0x47EFFFFFE0000000>, i32 0, i32 0, i32 0)
  %elt = extractelement <4 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @wmma_accumulator_limit() {
; CHECK-LABEL: @wmma_accumulator_limit(
; CHECK: ret i1 false
  %d = call <4 x float> @llvm.amdgcn.wmma.f32.16x16x16.f16.v4f32.v8f16(<8 x half> splat (half 65504.0), <8 x half> splat (half -65504.0), <4 x float> splat (float 0x47DFFFFFE0000000))
  %elt = extractelement <4 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @wmma_negative_accumulator_limit() {
; CHECK-LABEL: @wmma_negative_accumulator_limit(
; CHECK: ret i1 false
  %d = call <4 x float> @llvm.amdgcn.wmma.f32.16x16x16.f16.v4f32.v8f16(<8 x half> splat (half 65504.0), <8 x half> splat (half -65504.0), <4 x float> splat (float 0xC7DFFFFFE0000000))
  %elt = extractelement <4 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @wmma_above_accumulator_limit() {
; CHECK-LABEL: @wmma_above_accumulator_limit(
; CHECK: fcmp ueq float
  %d = call <4 x float> @llvm.amdgcn.wmma.f32.16x16x16.f16.v4f32.v8f16(<8 x half> splat (half 65504.0), <8 x half> splat (half -65504.0), <4 x float> splat (float 0x47E0000000000000))
  %elt = extractelement <4 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @wmma_below_negative_accumulator_limit() {
; CHECK-LABEL: @wmma_below_negative_accumulator_limit(
; CHECK: fcmp ueq float
  %d = call <4 x float> @llvm.amdgcn.wmma.f32.16x16x16.f16.v4f32.v8f16(<8 x half> splat (half 65504.0), <8 x half> splat (half -65504.0), <4 x float> splat (float 0xC7E0000000000000))
  %elt = extractelement <4 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @wmma_max_accumulator() {
; CHECK-LABEL: @wmma_max_accumulator(
; CHECK: fcmp ueq float
  %d = call <4 x float> @llvm.amdgcn.wmma.f32.16x16x16.f16.v4f32.v8f16(<8 x half> splat (half 65504.0), <8 x half> splat (half -65504.0), <4 x float> splat (float 0x47EFFFFFE0000000))
  %elt = extractelement <4 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @wmma_nan_accumulator() {
; CHECK-LABEL: @wmma_nan_accumulator(
; CHECK: fcmp ueq float
  %d = call <4 x float> @llvm.amdgcn.wmma.f32.16x16x16.f16.v4f32.v8f16(<8 x half> splat (half 65504.0), <8 x half> splat (half -65504.0), <4 x float> splat (float 0x7FF8000000000000))
  %elt = extractelement <4 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @wmma_inf_accumulator() {
; CHECK-LABEL: @wmma_inf_accumulator(
; CHECK: fcmp ueq float
  %d = call <4 x float> @llvm.amdgcn.wmma.f32.16x16x16.f16.v4f32.v8f16(<8 x half> splat (half 65504.0), <8 x half> splat (half -65504.0), <4 x float> splat (float 0x7FF0000000000000))
  %elt = extractelement <4 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @wmma_subnormal_accumulator() {
; CHECK-LABEL: @wmma_subnormal_accumulator(
; CHECK: ret i1 false
  %d = call <4 x float> @llvm.amdgcn.wmma.f32.16x16x16.f16.v4f32.v8f16(<8 x half> splat (half 65504.0), <8 x half> splat (half -65504.0), <4 x float> splat (float 0x36A0000000000000))
  %elt = extractelement <4 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @wmma_dynamic_accumulator(<4 x float> %c) {
; CHECK-LABEL: @wmma_dynamic_accumulator(
; CHECK: fcmp ueq float
  %d = call <4 x float> @llvm.amdgcn.wmma.f32.16x16x16.f16.v4f32.v8f16(<8 x half> splat (half 65504.0), <8 x half> splat (half -65504.0), <4 x float> %c)
  %elt = extractelement <4 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @wmma_mixed_accumulator() {
; CHECK-LABEL: @wmma_mixed_accumulator(
; CHECK: ret i1 false
  %d = call <4 x float> @llvm.amdgcn.wmma.f32.16x16x16.f16.v4f32.v8f16(<8 x half> splat (half 65504.0), <8 x half> splat (half -65504.0), <4 x float> <float 1.0, float -1.0, float 0x47DFFFFFE0000000, float 0xC7DFFFFFE0000000>)
  %elt = extractelement <4 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}

define i1 @wmma_undemanded_large_accumulator() {
; CHECK-LABEL: @wmma_undemanded_large_accumulator(
; CHECK: fcmp ueq float
  %d = call <4 x float> @llvm.amdgcn.wmma.f32.16x16x16.f16.v4f32.v8f16(<8 x half> splat (half 65504.0), <8 x half> splat (half -65504.0), <4 x float> <float 1.0, float 1.0, float 1.0, float 0x47EFFFFFE0000000>)
  %elt = extractelement <4 x float> %d, i32 0
  %class = call i1 @llvm.is.fpclass.f32(float %elt, i32 519)
  ret i1 %class
}
