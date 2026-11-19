; RUN: llc -mtriple=amdgpu12.50-amd-amdhsa -verify-machineinstrs < %s | FileCheck %s

; The LDS load overwrites two WMMA result registers read by v_maximum_f32.
define amdgpu_kernel void @fp8_attention(ptr addrspace(3) %lds, ptr addrspace(1) %out,
                                         <16 x i32> %q, <16 x i32> %k, i32 %scale, i32 %count) #0 {
; CHECK-LABEL: fp8_attention:
; CHECK:       v_wmma_scale_f32_16x16x128_f8f6f4 v{{\[}}[[#LO:]]:
; CHECK:       v_maximum_f32 v{{[0-9]+}}, v[[#LO]], v[[#LO+1]]
; CHECK-NOT:   s_wait_alu
; CHECK:       s_wait_alu depctr_va_vdst(1)
; CHECK-NEXT:  ds_load_tr8_b64 v{{\[}}[[#LO]]:[[#LO+1]]],
entry:
  %id = call i32 @llvm.amdgcn.workitem.id.x()
  %base = getelementptr <2 x i32>, ptr addrspace(3) %lds, i32 %id
  %row = getelementptr <8 x float>, ptr addrspace(1) %out, i32 %id
  br label %loop

loop:
  %i = phi i32 [ 0, %entry ], [ %next, %loop ]
  %acc = phi <8 x float> [ zeroinitializer, %entry ], [ %updated, %loop ]
  %tile = getelementptr <2 x i32>, ptr addrspace(3) %base, i32 %i
  %scores0 = call <8 x float> @llvm.amdgcn.wmma.scale.f32.16x16x128.f8f6f4.v8f32.v16i32.v16i32(
      i32 0, <16 x i32> %q, i32 0, <16 x i32> %k, i16 0, <8 x float> %acc,
      i32 0, i32 0, i32 %scale, i32 0, i32 0, i32 %scale, i1 false, i1 false)
  %scores1 = call <8 x float> @llvm.amdgcn.wmma.scale.f32.16x16x128.f8f6f4.v8f32.v16i32.v16i32(
      i32 0, <16 x i32> %q, i32 0, <16 x i32> %k, i16 0, <8 x float> %acc,
      i32 0, i32 0, i32 %scale, i32 1, i32 0, i32 %scale, i1 false, i1 false)
  %frag = call <2 x i32> @llvm.amdgcn.ds.load.tr8.b64.v2i32(ptr addrspace(3) %tile)
  %col0 = shufflevector <8 x float> %scores0, <8 x float> %scores1, <2 x i32> <i32 0, i32 8>
  %col1 = shufflevector <8 x float> %scores0, <8 x float> %scores1, <2 x i32> <i32 1, i32 9>
  %max = call <2 x float> @llvm.maximum.v2f32(<2 x float> %col0, <2 x float> %col1)
  %c = call <8 x float> @llvm.vector.insert.v8f32.v2f32(<8 x float> zeroinitializer, <2 x float> %max, i64 0)
  %packed = call <16 x i32> @llvm.vector.insert.v16i32.v2i32(<16 x i32> zeroinitializer, <2 x i32> %frag, i64 0)
  %updated = call <8 x float> @llvm.amdgcn.wmma.scale.f32.16x16x128.f8f6f4.v8f32.v16i32.v16i32(
      i32 0, <16 x i32> %q, i32 0, <16 x i32> %packed, i16 0, <8 x float> %c,
      i32 0, i32 0, i32 %scale, i32 0, i32 0, i32 %scale, i1 false, i1 false)
  %next = add i32 %i, 1
  %done = icmp eq i32 %next, %count
  br i1 %done, label %exit, label %loop

exit:
  store <8 x float> %updated, ptr addrspace(1) %row, align 16
  ret void
}

declare <8 x float> @llvm.amdgcn.wmma.scale.f32.16x16x128.f8f6f4.v8f32.v16i32.v16i32(
    i32 immarg, <16 x i32>, i32 immarg, <16 x i32>, i16 immarg, <8 x float>,
    i32 immarg, i32 immarg, i32, i32 immarg, i32 immarg, i32, i1 immarg, i1 immarg)
declare <2 x i32> @llvm.amdgcn.ds.load.tr8.b64.v2i32(ptr addrspace(3))
declare i32 @llvm.amdgcn.workitem.id.x()
declare <2 x float> @llvm.maximum.v2f32(<2 x float>, <2 x float>)
declare <8 x float> @llvm.vector.insert.v8f32.v2f32(<8 x float>, <2 x float>, i64 immarg)
declare <16 x i32> @llvm.vector.insert.v16i32.v2i32(<16 x i32>, <2 x i32>, i64 immarg)

attributes #0 = { "amdgpu-expert-scheduling-mode"="true" "amdgpu-sched-strategy"="coexec" }
