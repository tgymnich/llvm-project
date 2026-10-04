; RUN: llc -mtriple=amdgpu12.00 -mcpu=gfx1200 -global-isel=0 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=CHECK,WAVE32 --implicit-check-not=ds_swizzle --implicit-check-not=ds_permute
; RUN: llc -mtriple=amdgpu12.00 -mcpu=gfx1200 -global-isel=1 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=CHECK,WAVE32 --implicit-check-not=ds_swizzle --implicit-check-not=ds_permute
; RUN: llc -mtriple=amdgpu12.00 -mcpu=gfx1200 -mattr=+wavefrontsize64 -global-isel=0 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=CHECK,WAVE64 --implicit-check-not=ds_swizzle --implicit-check-not=ds_permute
; RUN: llc -mtriple=amdgpu12.00 -mcpu=gfx1200 -mattr=+wavefrontsize64 -global-isel=1 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=CHECK,WAVE64 --implicit-check-not=ds_swizzle --implicit-check-not=ds_permute
; RUN: llc -mtriple=amdgpu12.50 -mcpu=gfx1250 -global-isel=0 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=CHECK,WAVE32 --implicit-check-not=ds_swizzle --implicit-check-not=ds_permute
; RUN: llc -mtriple=amdgpu12.50 -mcpu=gfx1250 -global-isel=1 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=CHECK,WAVE32 --implicit-check-not=ds_swizzle --implicit-check-not=ds_permute
; RUN: llc -mtriple=amdgpu12.00 -mcpu=gfx1200 -mattr=-salu-float -verify-machineinstrs < %s | FileCheck %s --check-prefix=NOSALU

define void @fadd(float %value, ptr addrspace(1) %out) {
; CHECK-LABEL: fadd:
; CHECK: v_add_f32_dpp [[PARTIAL:v.+]], {{v.+}}, {{v.+}} row_shr:8
; CHECK-DAG: v_readlane_b32 [[ROW0:s.+]], [[PARTIAL]], 15
; CHECK-DAG: v_readlane_b32 [[ROW1:s.+]], [[PARTIAL]], 31
; WAVE64-DAG: v_readlane_b32 [[ROW2:s.+]], [[PARTIAL]], 47
; WAVE64-DAG: v_readlane_b32 [[ROW3:s.+]], [[PARTIAL]], 63
; CHECK: s_add_f32 [[LOWER:s.+]], [[ROW1]], [[ROW0]]
; WAVE64: s_add_f32 [[UPPER:s.+]], [[ROW3]], [[ROW2]]
; WAVE64: s_add_f32 [[RESULT:s.+]], [[UPPER]], [[LOWER]]
; WAVE32: v_mov_b32_e32 [[STORE:v.+]], [[LOWER]]
; WAVE64: v_mov_b32_e32 [[STORE:v.+]], [[RESULT]]
; CHECK: global_store_b32 {{.+}}, [[STORE]], off
; CHECK: {{s_setpc_b64|s_set_pc_i64}}
; NOSALU-LABEL: fadd:
; NOSALU: ds_swizzle_b32
; NOSALU-NOT: s_add_f32
; NOSALU: s_setpc_b64
  %result = call float @llvm.amdgcn.wave.reduce.fadd(float %value, i32 2)
  store float %result, ptr addrspace(1) %out
  ret void
}

define void @fsub(float %value, ptr addrspace(1) %out) {
; CHECK-LABEL: fsub:
; CHECK: v_add_f32_dpp [[PARTIAL:v.+]], {{v.+}}, {{v.+}} row_shr:8
; CHECK-DAG: v_readlane_b32 [[ROW0:s.+]], [[PARTIAL]], 15
; CHECK-DAG: v_readlane_b32 [[ROW1:s.+]], [[PARTIAL]], 31
; WAVE64-DAG: v_readlane_b32 [[ROW2:s.+]], [[PARTIAL]], 47
; WAVE64-DAG: v_readlane_b32 [[ROW3:s.+]], [[PARTIAL]], 63
; CHECK: s_add_f32 [[LOWER:s.+]], [[ROW1]], [[ROW0]]
; WAVE64: s_add_f32 [[UPPER:s.+]], [[ROW3]], [[ROW2]]
; WAVE64: s_add_f32 [[SUM:s.+]], [[UPPER]], [[LOWER]]
; WAVE32: s_sub_f32 [[RESULT:s.+]], 0, [[LOWER]]
; WAVE64: s_sub_f32 [[RESULT:s.+]], 0, [[SUM]]
; CHECK: v_mov_b32_e32 [[STORE:v.+]], [[RESULT]]
; CHECK: global_store_b32 {{.+}}, [[STORE]], off
; NOSALU-LABEL: fsub:
; NOSALU: ds_swizzle_b32
; NOSALU-NOT: s_add_f32
; NOSALU: s_setpc_b64
  %result = call float @llvm.amdgcn.wave.reduce.fsub(float %value, i32 2)
  store float %result, ptr addrspace(1) %out
  ret void
}

define void @fmin(float %value, ptr addrspace(1) %out) {
; CHECK-LABEL: fmin:
; CHECK-DAG: v_readlane_b32 [[ROW0:s.+]], {{.+}}, 15
; CHECK-DAG: v_readlane_b32 [[ROW1:s.+]], {{.+}}, 31
; WAVE64-DAG: v_readlane_b32 {{.+}}, {{.+}}, 47
; WAVE64-DAG: v_readlane_b32 {{.+}}, {{.+}}, 63
; CHECK: s_min_num_f32 {{.+}}, [[ROW1]], [[ROW0]]
; WAVE64: s_min_num_f32
; WAVE64: s_min_num_f32
; CHECK: global_store_b32
; NOSALU-LABEL: fmin:
; NOSALU: ds_swizzle_b32
; NOSALU-NOT: s_min_num_f32
; NOSALU: s_setpc_b64
  %result = call float @llvm.amdgcn.wave.reduce.fmin(float %value, i32 2)
  store float %result, ptr addrspace(1) %out
  ret void
}

define void @fmax(float %value, ptr addrspace(1) %out) {
; CHECK-LABEL: fmax:
; CHECK-DAG: v_readlane_b32 [[ROW0:s.+]], {{.+}}, 15
; CHECK-DAG: v_readlane_b32 [[ROW1:s.+]], {{.+}}, 31
; WAVE64-DAG: v_readlane_b32 {{.+}}, {{.+}}, 47
; WAVE64-DAG: v_readlane_b32 {{.+}}, {{.+}}, 63
; CHECK: s_max_num_f32 {{.+}}, [[ROW1]], [[ROW0]]
; WAVE64: s_max_num_f32
; WAVE64: s_max_num_f32
; CHECK: global_store_b32
; NOSALU-LABEL: fmax:
; NOSALU: ds_swizzle_b32
; NOSALU-NOT: s_max_num_f32
; NOSALU: s_setpc_b64
  %result = call float @llvm.amdgcn.wave.reduce.fmax(float %value, i32 2)
  store float %result, ptr addrspace(1) %out
  ret void
}

declare float @llvm.amdgcn.wave.reduce.fadd(float, i32)
declare float @llvm.amdgcn.wave.reduce.fsub(float, i32)
declare float @llvm.amdgcn.wave.reduce.fmin(float, i32)
declare float @llvm.amdgcn.wave.reduce.fmax(float, i32)

define void @add(i32 %value, ptr addrspace(1) %out) {
; CHECK-LABEL: add:
; CHECK-DAG: v_readlane_b32 {{.+}}, {{.+}}, 15
; CHECK-DAG: v_readlane_b32 {{.+}}, {{.+}}, 31
; WAVE64-DAG: v_readlane_b32 {{.+}}, {{.+}}, 47
; WAVE64-DAG: v_readlane_b32 {{.+}}, {{.+}}, 63
; CHECK: s_add_co_i32
; WAVE64: s_add_co_i32
; WAVE64: s_add_co_i32
; CHECK: global_store_b32
  %result = call i32 @llvm.amdgcn.wave.reduce.add(i32 %value, i32 2)
  store i32 %result, ptr addrspace(1) %out
  ret void
}

declare i32 @llvm.amdgcn.wave.reduce.add(i32, i32)

define void @sub(i32 %value, ptr addrspace(1) %out) {
; CHECK-LABEL: sub:
; CHECK-DAG: v_readlane_b32 {{.+}}, {{.+}}, 15
; CHECK-DAG: v_readlane_b32 {{.+}}, {{.+}}, 31
; WAVE64-DAG: v_readlane_b32 {{.+}}, {{.+}}, 47
; WAVE64-DAG: v_readlane_b32 {{.+}}, {{.+}}, 63
; CHECK: s_add_co_i32
; WAVE64: s_add_co_i32
; WAVE64: s_add_co_i32
; CHECK: s_sub_co_i32 {{.+}}, 0, {{.+}}
; CHECK: global_store_b32
  %result = call i32 @llvm.amdgcn.wave.reduce.sub(i32 %value, i32 2)
  store i32 %result, ptr addrspace(1) %out
  ret void
}

declare i32 @llvm.amdgcn.wave.reduce.sub(i32, i32)

define void @min(i32 %value, ptr addrspace(1) %out) {
; CHECK-LABEL: min:
; CHECK-DAG: v_readlane_b32 {{.+}}, {{.+}}, 15
; CHECK-DAG: v_readlane_b32 {{.+}}, {{.+}}, 31
; WAVE64-DAG: v_readlane_b32 {{.+}}, {{.+}}, 47
; WAVE64-DAG: v_readlane_b32 {{.+}}, {{.+}}, 63
; CHECK: s_min_i32
; WAVE64: s_min_i32
; WAVE64: s_min_i32
; CHECK: global_store_b32
  %result = call i32 @llvm.amdgcn.wave.reduce.min(i32 %value, i32 2)
  store i32 %result, ptr addrspace(1) %out
  ret void
}

declare i32 @llvm.amdgcn.wave.reduce.min(i32, i32)

define void @umin(i32 %value, ptr addrspace(1) %out) {
; CHECK-LABEL: umin:
; CHECK-DAG: v_readlane_b32 {{.+}}, {{.+}}, 15
; CHECK-DAG: v_readlane_b32 {{.+}}, {{.+}}, 31
; WAVE64-DAG: v_readlane_b32 {{.+}}, {{.+}}, 47
; WAVE64-DAG: v_readlane_b32 {{.+}}, {{.+}}, 63
; CHECK: s_min_u32
; WAVE64: s_min_u32
; WAVE64: s_min_u32
; CHECK: global_store_b32
  %result = call i32 @llvm.amdgcn.wave.reduce.umin(i32 %value, i32 2)
  store i32 %result, ptr addrspace(1) %out
  ret void
}

declare i32 @llvm.amdgcn.wave.reduce.umin(i32, i32)

define void @max(i32 %value, ptr addrspace(1) %out) {
; CHECK-LABEL: max:
; CHECK-DAG: v_readlane_b32 {{.+}}, {{.+}}, 15
; CHECK-DAG: v_readlane_b32 {{.+}}, {{.+}}, 31
; WAVE64-DAG: v_readlane_b32 {{.+}}, {{.+}}, 47
; WAVE64-DAG: v_readlane_b32 {{.+}}, {{.+}}, 63
; CHECK: s_max_i32
; WAVE64: s_max_i32
; WAVE64: s_max_i32
; CHECK: global_store_b32
  %result = call i32 @llvm.amdgcn.wave.reduce.max(i32 %value, i32 2)
  store i32 %result, ptr addrspace(1) %out
  ret void
}

declare i32 @llvm.amdgcn.wave.reduce.max(i32, i32)

define void @umax(i32 %value, ptr addrspace(1) %out) {
; CHECK-LABEL: umax:
; CHECK-DAG: v_readlane_b32 {{.+}}, {{.+}}, 15
; CHECK-DAG: v_readlane_b32 {{.+}}, {{.+}}, 31
; WAVE64-DAG: v_readlane_b32 {{.+}}, {{.+}}, 47
; WAVE64-DAG: v_readlane_b32 {{.+}}, {{.+}}, 63
; CHECK: s_max_u32
; WAVE64: s_max_u32
; WAVE64: s_max_u32
; CHECK: global_store_b32
  %result = call i32 @llvm.amdgcn.wave.reduce.umax(i32 %value, i32 2)
  store i32 %result, ptr addrspace(1) %out
  ret void
}

declare i32 @llvm.amdgcn.wave.reduce.umax(i32, i32)

define void @and(i32 %value, ptr addrspace(1) %out) {
; CHECK-LABEL: and:
; CHECK-DAG: v_readlane_b32 {{.+}}, {{.+}}, 15
; CHECK-DAG: v_readlane_b32 {{.+}}, {{.+}}, 31
; WAVE64-DAG: v_readlane_b32 {{.+}}, {{.+}}, 47
; WAVE64-DAG: v_readlane_b32 {{.+}}, {{.+}}, 63
; CHECK: s_and_b32
; WAVE64: s_and_b32
; WAVE64: s_and_b32
; CHECK: global_store_b32
  %result = call i32 @llvm.amdgcn.wave.reduce.and(i32 %value, i32 2)
  store i32 %result, ptr addrspace(1) %out
  ret void
}

declare i32 @llvm.amdgcn.wave.reduce.and(i32, i32)

define void @or(i32 %value, ptr addrspace(1) %out) {
; CHECK-LABEL: or:
; CHECK-DAG: v_readlane_b32 {{.+}}, {{.+}}, 15
; CHECK-DAG: v_readlane_b32 {{.+}}, {{.+}}, 31
; WAVE64-DAG: v_readlane_b32 {{.+}}, {{.+}}, 47
; WAVE64-DAG: v_readlane_b32 {{.+}}, {{.+}}, 63
; CHECK: s_or_b32
; WAVE64: s_or_b32
; WAVE64: s_or_b32
; CHECK: global_store_b32
  %result = call i32 @llvm.amdgcn.wave.reduce.or(i32 %value, i32 2)
  store i32 %result, ptr addrspace(1) %out
  ret void
}

declare i32 @llvm.amdgcn.wave.reduce.or(i32, i32)

define void @xor(i32 %value, ptr addrspace(1) %out) {
; CHECK-LABEL: xor:
; CHECK-DAG: v_readlane_b32 {{.+}}, {{.+}}, 15
; CHECK-DAG: v_readlane_b32 {{.+}}, {{.+}}, 31
; WAVE64-DAG: v_readlane_b32 {{.+}}, {{.+}}, 47
; WAVE64-DAG: v_readlane_b32 {{.+}}, {{.+}}, 63
; CHECK: s_xor_b32
; WAVE64: s_xor_b32
; WAVE64: s_xor_b32
; CHECK: global_store_b32
  %result = call i32 @llvm.amdgcn.wave.reduce.xor(i32 %value, i32 2)
  store i32 %result, ptr addrspace(1) %out
  ret void
}

declare i32 @llvm.amdgcn.wave.reduce.xor(i32, i32)
