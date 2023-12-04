; RUN: opt < %s -S -passes="openmp-opt-postlink,simplifycfg" | FileCheck %s

target triple = "nvptx64"

%struct.ident_t = type { i32, i32, i32, i32, ptr }
%struct.KernelEnvironmentTy = type { %struct.ConfigurationEnvironmentTy, ptr, ptr }
%struct.ConfigurationEnvironmentTy = type { i8, i8, i8, i32, i32, i32, i32, i32, i32, i32 }

@test_kernel_environment = weak_odr protected local_unnamed_addr constant %struct.KernelEnvironmentTy { %struct.ConfigurationEnvironmentTy { i8 0, i8 0, i8 2, i32 1, i32 512, i32 1, i32 1, i32 1, i32 0, i32 0 }, ptr null, ptr null }

declare i32 @__kmpc_target_init(ptr, ptr)
declare void @__kmpc_target_deinit()

declare void @__ompx_split()

define void @test(ptr %tid_addr, ptr %ptr, ptr %dyn) "kernel" "omp_target_thread_limit"="32" "omp_target_num_teams"="1" {
  entry:
    %i = call i32 @__kmpc_target_init(ptr @test_kernel_environment, ptr %dyn)
    %tid = load i64, ptr %tid_addr
    %ptry = alloca double
    %idxy = getelementptr inbounds double, ptr %ptr, i64 9
    %valy = load double, ptr %idxy
    store double %valy, ptr %ptry

    %arrayidx = getelementptr inbounds double, ptr %ptr, i64 %tid
    %cmp = icmp ult i64 0, %tid
    br i1 %cmp, label %if, label %end
  if:
    call void @__ompx_split()
    %val1 = load double, ptr %arrayidx
    %y = load double, ptr %ptry
    %add = fadd double %val1, %y
    store double %add, ptr %arrayidx
    br label %end
  end:
    %val2 = load double, ptr %arrayidx
    %mul = fmul double %val2, %val2
    store double %mul, ptr %arrayidx
    call void @__kmpc_target_deinit()
    ret void
}

!llvm.module.flags = !{!3, !4}

!3 = !{i32 7, !"openmp", i32 51}
!4 = !{i32 7, !"openmp-device", i32 51}


; CHECK: define void @test(ptr %tid_addr, ptr %ptr, ptr %dyn)
; CHECK-NEXT: entry:
; CHECK-NEXT:   %i = call i32 @__kmpc_target_init(ptr @test_kernel_environment, ptr %dyn)
; CHECK-NEXT:   %tid = load i64, ptr %tid_addr
; CHECK-NEXT:   %ptry = alloca double
; CHECK-NEXT:   %idxy = getelementptr inbounds double, ptr %ptr, i64 9
; CHECK-NEXT:   %valy = load double, ptr %idxy
; CHECK-NEXT:   store double %valy, ptr %ptry
; CHECK-NEXT:   %arrayidx = getelementptr inbounds double, ptr %ptr, i64 %tid
; CHECK-NEXT:   %cmp = icmp ult i64 0, %tid
; CHECK-NEXT:   br i1 %cmp, label %if, label %end
;
; CHECK: if:                                               ; preds = %entry
; CHECK-NEXT:   %cacheidx = atomicrmw add ptr @test_cont_count, i64 1 acquire
; CHECK-NEXT:   %ptry.cacheidx = getelementptr inbounds [32 x %cache_cell], ptr @test_cont_cache, i64 %cacheidx, i64 0
; CHECK-NEXT:   %0 = load double, ptr %ptry
; CHECK-NEXT:   store double %0, ptr %ptry.cacheidx
; CHECK-NEXT:   call void asm sideeffect "exit;", ""()
; CHECK-NEXT:   unreachable
;
; CHECK: end:                                              ; preds = %entry
; CHECK-NEXT:   %val2 = load double, ptr %arrayidx
; CHECK-NEXT:   %mul = fmul double %val2, %val2
; CHECK-NEXT:   store double %mul, ptr %arrayidx
; CHECK-NEXT:   call void @__kmpc_target_deinit()
; CHECK-NEXT:   ret void
; CHECK-NEXT: }
;
; CHECK: define void @test_contd_0(ptr %tid_addr, ptr %ptr, ptr %dyn)
; CHECK-NEXT: entry:
; CHECK-NEXT:   %0 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
; CHECK-NEXT:   %1 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
; CHECK-NEXT:   %2 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
; CHECK-NEXT:   %3 = mul i32 %1, %2
; CHECK-NEXT:   %gtid = add i32 %0, %3
; CHECK-NEXT:   %i = call i32 @__kmpc_target_init(ptr @test_kernel_environment, ptr %dyn)
; CHECK-NEXT:   %tid = load i64, ptr %tid_addr
; CHECK-NEXT:   %ptry = alloca double
; CHECK-NEXT:   %ptry.cacheidx = getelementptr inbounds [32 x %cache_cell], ptr @test_cont_cache, i32 %gtid, i64 0
; CHECK-NEXT:   %4 = load double, ptr %ptry.cacheidx
; CHECK-NEXT:   store double %4, ptr %ptry
; CHECK-NEXT:   %idxy = getelementptr inbounds double, ptr %ptr, i64 9
; CHECK-NEXT:   %valy = load double, ptr %idxy
; CHECK-NEXT:   store double %valy, ptr %ptry
; CHECK-NEXT:   %arrayidx = getelementptr inbounds double, ptr %ptr, i64 %tid
; CHECK-NEXT:   %cmp = icmp ult i64 0, %tid
; CHECK-NEXT:   br i1 %cmp, label %if, label %end
;
; CHECK: if:                                               ; preds = %entry
; CHECK-NEXT:   %val1 = load double, ptr %arrayidx
; CHECK-NEXT:   %y = load double, ptr %ptry
; CHECK-NEXT:   %add = fadd double %val1, %y
; CHECK-NEXT:   store double %add, ptr %arrayidx
; CHECK-NEXT:   br label %end
;
; CHECK: end:                                              ; preds = %if, %entry
; CHECK-NEXT:   %val2 = load double, ptr %arrayidx
; CHECK-NEXT:   %mul = fmul double %val2, %val2
; CHECK-NEXT:   store double %mul, ptr %arrayidx
; CHECK-NEXT:   call void @__kmpc_target_deinit()
; CHECK-NEXT:   ret void
; CHECK-NEXT: }