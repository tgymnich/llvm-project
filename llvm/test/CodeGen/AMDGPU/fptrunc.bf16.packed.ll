; RUN: split-file %s %t
; RUN: llc -mtriple=amdgpu9.50-amd-amdhsa -global-isel=0 -verify-machineinstrs < %t/vector.ll | \
; RUN:   FileCheck %s --check-prefix=PACK --implicit-check-not=v_cvt_pk_bf16_f32 \
; RUN:   --implicit-check-not=v_perm_b32 --implicit-check-not=v_mov_b16
; RUN: llc -mtriple=amdgpu12.50-amd-amdhsa -global-isel=0 -verify-machineinstrs < %t/vector.ll | \
; RUN:   FileCheck %s --check-prefix=PACK --implicit-check-not=v_cvt_pk_bf16_f32 \
; RUN:   --implicit-check-not=v_perm_b32 --implicit-check-not=v_mov_b16
; RUN: llc -mtriple=amdgpu13.10-amd-amdhsa -global-isel=0 -verify-machineinstrs < %t/vector.ll | \
; RUN:   FileCheck %s --check-prefix=PACK --implicit-check-not=v_cvt_pk_bf16_f32 \
; RUN:   --implicit-check-not=v_perm_b32 --implicit-check-not=v_mov_b16
; RUN: llc -mtriple=amdgpu9.50-amd-amdhsa -global-isel=0 -verify-machineinstrs < %t/mfma.ll | \
; RUN:   FileCheck %s --check-prefix=MFMA --implicit-check-not=v_cvt_pk_bf16_f32 \
; RUN:   --implicit-check-not=v_perm_b32

;--- vector.ll

define <3 x i16> @fptrunc_v3f32_to_v3bf16_bits(<3 x float> %src) {
; PACK-LABEL: fptrunc_v3f32_to_v3bf16_bits:
; PACK-COUNT-2: v_cvt_pk_bf16_f32
  %bf16 = fptrunc <3 x float> %src to <3 x bfloat>
  %bits = bitcast <3 x bfloat> %bf16 to <3 x i16>
  ret <3 x i16> %bits
}

define <4 x i16> @fptrunc_v4f32_to_v4bf16_bits(<4 x float> %src) {
; PACK-LABEL: fptrunc_v4f32_to_v4bf16_bits:
; PACK-DAG: v_cvt_pk_bf16_f32 v0, v0, v1
; PACK-DAG: v_cvt_pk_bf16_f32 v1, v2, v3
  %bf16 = fptrunc <4 x float> %src to <4 x bfloat>
  %bits = bitcast <4 x bfloat> %bf16 to <4 x i16>
  ret <4 x i16> %bits
}

define <4 x i16> @fptrunc_v4f32_abs_to_v4bf16_bits(<4 x float> %src) {
; PACK-LABEL: fptrunc_v4f32_abs_to_v4bf16_bits:
; PACK-DAG: v_cvt_pk_bf16_f32 v0, |v0|, |v1|
; PACK-DAG: v_cvt_pk_bf16_f32 v1, |v2|, |v3|
  %abs = call <4 x float> @llvm.fabs.v4f32(<4 x float> %src)
  %bf16 = fptrunc <4 x float> %abs to <4 x bfloat>
  %bits = bitcast <4 x bfloat> %bf16 to <4 x i16>
  ret <4 x i16> %bits
}

define <6 x i16> @fptrunc_v6f32_to_v6bf16_bits(<6 x float> %src) {
; PACK-LABEL: fptrunc_v6f32_to_v6bf16_bits:
; PACK-COUNT-3: v_cvt_pk_bf16_f32
  %bf16 = fptrunc <6 x float> %src to <6 x bfloat>
  %bits = bitcast <6 x bfloat> %bf16 to <6 x i16>
  ret <6 x i16> %bits
}

define <8 x i16> @fptrunc_v8f32_to_v8bf16_bits(<8 x float> %src) {
; PACK-LABEL: fptrunc_v8f32_to_v8bf16_bits:
; PACK-COUNT-4: v_cvt_pk_bf16_f32
  %bf16 = fptrunc <8 x float> %src to <8 x bfloat>
  %bits = bitcast <8 x bfloat> %bf16 to <8 x i16>
  ret <8 x i16> %bits
}

define <4 x i16> @fptrunc_v4f64_to_v4bf16_bits(<4 x double> %src) {
; PACK-LABEL: fptrunc_v4f64_to_v4bf16_bits:
; PACK: v_cvt_f64_f32
; PACK-COUNT-2: v_cvt_pk_bf16_f32
  %bf16 = fptrunc <4 x double> %src to <4 x bfloat>
  %bits = bitcast <4 x bfloat> %bf16 to <4 x i16>
  ret <4 x i16> %bits
}

;--- mfma.ll

define <4 x float> @fptrunc_v4bf16_mfma(<4 x float> %a, <4 x float> %b, <4 x float> %c) {
; MFMA-LABEL: fptrunc_v4bf16_mfma:
; MFMA-COUNT-4: v_cvt_pk_bf16_f32
; MFMA: v_mfma_f32_16x16x16_bf16
  %a.bf16 = fptrunc <4 x float> %a to <4 x bfloat>
  %b.bf16 = fptrunc <4 x float> %b to <4 x bfloat>
  %a.bits = bitcast <4 x bfloat> %a.bf16 to <4 x i16>
  %b.bits = bitcast <4 x bfloat> %b.bf16 to <4 x i16>
  %r = call <4 x float> @llvm.amdgcn.mfma.f32.16x16x16bf16.1k(<4 x i16> %a.bits, <4 x i16> %b.bits, <4 x float> %c, i32 0, i32 0, i32 0)
  ret <4 x float> %r
}
