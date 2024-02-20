; RUN: opt < %s -S -passes="cgscc(openmp-opt-postlink-cgscc),ipsccp,simplifycfg" | FileCheck %s

target triple = "nvptx64"

%struct.ident_t = type { i32, i32, i32, i32, ptr }
%struct.KernelEnvironmentTy = type { %struct.ConfigurationEnvironmentTy, ptr, ptr }
%struct.ConfigurationEnvironmentTy = type { i8, i8, i8, i32, i32, i32, i32, i32, i32, i32, i32 }
%struct.KernelLaunchEnvironmentTy = type { i32, i32, ptr, i32 }

@test_kernel_environment = weak_odr protected local_unnamed_addr constant %struct.KernelEnvironmentTy { %struct.ConfigurationEnvironmentTy { i8 0, i8 0, i8 2, i32 1, i32 512, i32 1, i32 1, i32 1, i32 0, i32 0, i32 0 }, ptr null, ptr null }

declare void @__ompx_split()

declare i32 @__kmpc_target_init(ptr, ptr)
declare void @__kmpc_target_deinit()

define void @test(ptr %launch_env, ptr %tid_addr, ptr %ptr1, ptr %ptr2, ptr %dyn) "kernel" "omp_target_thread_limit"="32" "omp_target_num_teams"="1" {
  entry:
    %i = call i32 @__kmpc_target_init(ptr @test_kernel_environment, ptr %dyn)
    %tid = load i64, ptr %tid_addr
    %arrayidx1 = getelementptr inbounds double, ptr %ptr1, i64 %tid
    %arrayidx2 = getelementptr inbounds double, ptr %ptr2, i64 %tid
    %val1 = load double, ptr %arrayidx1
    %val2 = load double, ptr %arrayidx2
    %mul = fmul double %val1, %val2    
    %cmp = icmp ult i64 0, %tid
    br i1 %cmp, label %if, label %end
  if:
    call void @__ompx_split()
    store double %mul, ptr %arrayidx1
    br label %end
  end:
    %mul1 = fmul double %mul, %mul
    store double %mul1, ptr %arrayidx1
    call void @__kmpc_target_deinit()
    ret void
}

!llvm.module.flags = !{!3, !4}

!3 = !{i32 7, !"openmp", i32 51}
!4 = !{i32 7, !"openmp-device", i32 51}


; CHECK: define void @test(ptr %launch_env, ptr %tid_addr, ptr %ptr1, ptr %ptr2, ptr %dyn)
; CHECK-NEXT: entry:
; CHECK-NEXT:   %i = call i32 @__kmpc_target_init(ptr @test_kernel_environment, ptr %dyn)
; CHECK-NEXT:   %tid = load i64, ptr %tid_addr
; CHECK-NEXT:   %arrayidx1 = getelementptr inbounds double, ptr %ptr1, i64 %tid
; CHECK-NEXT:   %arrayidx2 = getelementptr inbounds double, ptr %ptr2, i64 %tid
; CHECK-NEXT:   %val1 = load double, ptr %arrayidx1
; CHECK-NEXT:   %val2 = load double, ptr %arrayidx2
; CHECK-NEXT:   %mul = fmul double %val1, %val2
; CHECK-NEXT:   %cmp = icmp ult i64 0, %tid
; CHECK-NEXT:   br i1 %cmp, label %CacheStore, label %end
;
; CHECK: end:                                              ; preds = %entry
; CHECK-NEXT:   %mul1 = fmul double %mul, %mul
; CHECK-NEXT:   store double %mul1, ptr %arrayidx1
; CHECK-NEXT:   call void @__kmpc_target_deinit()
; CHECK-NEXT:   ret void
;
; CHECK: CacheStore:                                       ; preds = %entry
; CHECK-NEXT:   %0 = getelementptr inbounds %struct.KernelLaunchEnvironmentTy.0, ptr %launch_env, i32 0, i32 3
; CHECK-NEXT:   %1 = load ptr, ptr %0
; CHECK-NEXT:   %contcount.ptr = getelementptr inbounds i32, ptr %1, i32 0
; CHECK-NEXT:   %cacheidx = atomicrmw add ptr %contcount.ptr, i32 1 acquire
; CHECK-NEXT:   %2 = getelementptr inbounds %struct.KernelLaunchEnvironmentTy.0, ptr %launch_env, i32 0, i32 4
; CHECK-NEXT:   %3 = load ptr, ptr %2
; CHECK-NEXT:   %4 = getelementptr inbounds ptr, ptr %3, i32 0
; CHECK-NEXT:   %cache.out.ptr = load ptr, ptr %4
; CHECK-NEXT:   %val2.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-NEXT:   %5 = getelementptr inbounds %cache_cell, ptr %val2.cacheidx, i32 0, i32 0
; CHECK-NEXT:   store double %val2, ptr %5
; CHECK-NEXT:   %val1.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-NEXT:   %6 = getelementptr inbounds %cache_cell, ptr %val1.cacheidx, i32 0, i32 1
; CHECK-NEXT:   store double %val1, ptr %6
; CHECK-NEXT:   %tid.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-NEXT:   %7 = getelementptr inbounds %cache_cell, ptr %tid.cacheidx, i32 0, i32 2
; CHECK-NEXT:   store i64 %tid, ptr %7
; CHECK-NEXT:   call void asm sideeffect "exit;", ""()
; CHECK-NEXT:   unreachable
; CHECK-NEXT: }
;
; CHECK: define void @test_contd_0(ptr %launch_env, ptr %tid_addr, ptr %ptr1, ptr %ptr2, ptr %dyn)
; CHECK-NEXT: entry:
; CHECK-NEXT:   %0 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
; CHECK-NEXT:   %1 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
; CHECK-NEXT:   %2 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
; CHECK-NEXT:   %3 = mul i32 %1, %2
; CHECK-NEXT:   %gtid = add i32 %0, %3
; CHECK-NEXT:   %4 = getelementptr inbounds %struct.KernelLaunchEnvironmentTy.0, ptr %launch_env, i32 0, i32 3
; CHECK-NEXT:   %5 = load ptr, ptr %4
; CHECK-NEXT:   %contcount.in.ptr = getelementptr inbounds i32, ptr %5, i32 1
; CHECK-NEXT:   %contcount.in = load i32, ptr %contcount.in.ptr
; CHECK-NEXT:   %6 = icmp ult i32 %gtid, %contcount.in
; CHECK-NEXT:   br i1 %6, label %CacheRemat, label %ThreadExit
;
; CHECK: ThreadExit:                                       ; preds = %entry
; CHECK-NEXT:   call void asm sideeffect "exit;", ""()
; CHECK-NEXT:   unreachable
;
; CHECK: CacheRemat:                                       ; preds = %entry
; CHECK-NEXT:   %7 = getelementptr inbounds %struct.KernelLaunchEnvironmentTy.0, ptr %launch_env, i32 0, i32 4
; CHECK-NEXT:   %8 = load ptr, ptr %7
; CHECK-NEXT:   %9 = getelementptr inbounds ptr, ptr %8, i32 1
; CHECK-NEXT:   %cache.in.ptr = load ptr, ptr %9
; CHECK-NEXT:   %val2.cacheidx1 = getelementptr inbounds %cache_cell, ptr %cache.in.ptr, i32 %gtid
; CHECK-NEXT:   %10 = getelementptr inbounds %cache_cell, ptr %val2.cacheidx1, i32 0, i32 0
; CHECK-NEXT:   %11 = load double, ptr %10
; CHECK-NEXT:   %val1.cacheidx2 = getelementptr inbounds %cache_cell, ptr %cache.in.ptr, i32 %gtid
; CHECK-NEXT:   %12 = getelementptr inbounds %cache_cell, ptr %val1.cacheidx2, i32 0, i32 1
; CHECK-NEXT:   %13 = load double, ptr %12
; CHECK-NEXT:   %tid.cacheidx3 = getelementptr inbounds %cache_cell, ptr %cache.in.ptr, i32 %gtid
; CHECK-NEXT:   %14 = getelementptr inbounds %cache_cell, ptr %tid.cacheidx3, i32 0, i32 2
; CHECK-NEXT:   %15 = load i64, ptr %14
; CHECK-NEXT:   %16 = getelementptr inbounds double, ptr %ptr1, i64 %15
; CHECK-NEXT:   %17 = fmul double %13, %11
; CHECK-NEXT:   store double %17, ptr %16
; CHECK-NEXT:   %mul1 = fmul double %17, %17
; CHECK-NEXT:   store double %mul1, ptr %16
; CHECK-NEXT:   call void @__kmpc_target_deinit()
; CHECK-NEXT:   ret void
; CHECK-NEXT: }