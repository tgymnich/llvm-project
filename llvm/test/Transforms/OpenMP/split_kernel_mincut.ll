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
    %add = fmul double %val1, %val2    
    store double %add, ptr %arrayidx2
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
; CHECK-CACHE: CacheStore:                                       ; preds = %entry
; CHECK-CACHE-NEXT:   %0 = getelementptr inbounds %struct.KernelLaunchEnvironmentTy.0, ptr %launch_env, i32 0, i32 3
; CHECK-CACHE-NEXT:   %1 = load ptr, ptr %0
; CHECK-CACHE-NEXT:   %contcount.ptr = getelementptr inbounds i32, ptr %1, i32 0
; CHECK-CACHE-NEXT:   %cacheidx = atomicrmw add ptr %contcount.ptr, i32 1 acquire
; CHECK-CACHE-NEXT:   %2 = getelementptr inbounds %struct.KernelLaunchEnvironmentTy.0, ptr %launch_env, i32 0, i32 4
; CHECK-CACHE-NEXT:   %3 = load ptr, ptr %2
; CHECK-CACHE-NEXT:   %4 = getelementptr inbounds ptr, ptr %3, i32 0
; CHECK-CACHE-NEXT:   %cache.out.ptr = load ptr, ptr %4
; CHECK-CACHE-NEXT:   %arrayidx2.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-CACHE-NEXT:   %5 = getelementptr inbounds %cache_cell, ptr %arrayidx2.cacheidx, i32 0, i32 0
; CHECK-CACHE-NEXT:   store ptr %arrayidx2, ptr %5
; CHECK-CACHE-NEXT:   %arrayidx1.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-CACHE-NEXT:   %6 = getelementptr inbounds %cache_cell, ptr %arrayidx1.cacheidx, i32 0, i32 1
; CHECK-CACHE-NEXT:   store ptr %arrayidx1, ptr %6
; CHECK-CACHE-NEXT:   %val1.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-CACHE-NEXT:   %7 = getelementptr inbounds %cache_cell, ptr %val1.cacheidx, i32 0, i32 2
; CHECK-CACHE-NEXT:   store double %val1, ptr %7
; CHECK-CACHE-NEXT:   %val2.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-CACHE-NEXT:   %8 = getelementptr inbounds %cache_cell, ptr %val2.cacheidx, i32 0, i32 3
; CHECK-CACHE-NEXT:   store double %val2, ptr %8
; CHECK-CACHE-NEXT:   %mul.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-CACHE-NEXT:   %9 = getelementptr inbounds %cache_cell, ptr %mul.cacheidx, i32 0, i32 4
; CHECK-CACHE-NEXT:   store double %mul, ptr %9
; CHECK-CACHE-NEXT:   call void asm sideeffect "exit;", ""()
; CHECK-CACHE-NEXT:   unreachable
; CHECK-CACHE-NEXT: }
;
; CHECK-RECOMPUTE: CacheStore:                                       ; preds = %entry
; CHECK-RECOMPUTE-NEXT:   %0 = getelementptr inbounds %struct.KernelLaunchEnvironmentTy.0, ptr %launch_env, i32 0, i32 3
; CHECK-RECOMPUTE-NEXT:   %1 = load ptr, ptr %0
; CHECK-RECOMPUTE-NEXT:   %contcount.ptr = getelementptr inbounds i32, ptr %1, i32 0
; CHECK-RECOMPUTE-NEXT:   %cacheidx = atomicrmw add ptr %contcount.ptr, i32 1 acquire
; CHECK-RECOMPUTE-NEXT:   %2 = getelementptr inbounds %struct.KernelLaunchEnvironmentTy.0, ptr %launch_env, i32 0, i32 4
; CHECK-RECOMPUTE-NEXT:   %3 = load ptr, ptr %2
; CHECK-RECOMPUTE-NEXT:   %4 = getelementptr inbounds ptr, ptr %3, i32 0
; CHECK-RECOMPUTE-NEXT:   %cache.out.ptr = load ptr, ptr %4
; CHECK-RECOMPUTE-NEXT:   %val2.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-RECOMPUTE-NEXT:   %5 = getelementptr inbounds %cache_cell, ptr %val2.cacheidx, i32 0, i32 0
; CHECK-RECOMPUTE-NEXT:   store double %val2, ptr %5
; CHECK-RECOMPUTE-NEXT:   %val1.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-RECOMPUTE-NEXT:   %6 = getelementptr inbounds %cache_cell, ptr %val1.cacheidx, i32 0, i32 1
; CHECK-RECOMPUTE-NEXT:   store double %val1, ptr %6
; CHECK-RECOMPUTE-NEXT:   %tid.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-RECOMPUTE-NEXT:   %7 = getelementptr inbounds %cache_cell, ptr %tid.cacheidx, i32 0, i32 2
; CHECK-RECOMPUTE-NEXT:   store i64 %tid, ptr %7
; CHECK-RECOMPUTE-NEXT:   call void asm sideeffect "exit;", ""()
; CHECK-RECOMPUTE-NEXT:   unreachable
; CHECK-RECOMPUTE-NEXT: }
;
; CHECK-MINCUT: CacheStore:                                       ; preds = %entry
; CHECK-MINCUT-NEXT:   %0 = getelementptr inbounds %struct.KernelLaunchEnvironmentTy.0, ptr %launch_env, i32 0, i32 3
; CHECK-MINCUT-NEXT:   %1 = load ptr, ptr %0
; CHECK-MINCUT-NEXT:   %contcount.ptr = getelementptr inbounds i32, ptr %1, i32 0
; CHECK-MINCUT-NEXT:   %cacheidx = atomicrmw add ptr %contcount.ptr, i32 1 acquire
; CHECK-MINCUT-NEXT:   %2 = getelementptr inbounds %struct.KernelLaunchEnvironmentTy.0, ptr %launch_env, i32 0, i32 4
; CHECK-MINCUT-NEXT:   %3 = load ptr, ptr %2
; CHECK-MINCUT-NEXT:   %4 = getelementptr inbounds ptr, ptr %3, i32 0
; CHECK-MINCUT-NEXT:   %cache.out.ptr = load ptr, ptr %4
; CHECK-MINCUT-NEXT:   %tid.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-MINCUT-NEXT:   %5 = getelementptr inbounds %cache_cell, ptr %tid.cacheidx, i32 0, i32 0
; CHECK-MINCUT-NEXT:   store i64 %tid, ptr %5
; CHECK-MINCUT-NEXT:   %val1.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-MINCUT-NEXT:   %6 = getelementptr inbounds %cache_cell, ptr %val1.cacheidx, i32 0, i32 1
; CHECK-MINCUT-NEXT:   store double %val1, ptr %6
; CHECK-MINCUT-NEXT:   %val2.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-MINCUT-NEXT:   %7 = getelementptr inbounds %cache_cell, ptr %val2.cacheidx, i32 0, i32 2
; CHECK-MINCUT-NEXT:   store double %val2, ptr %7
; CHECK-MINCUT-NEXT:   call void asm sideeffect "exit;", ""()
; CHECK-MINCUT-NEXT:   unreachable
; CHECK-MINCUT-NEXT: }
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
; CHECK-CACHE: CacheRemat:                                       ; preds = %entry
; CHECK-CACHE-NEXT:   %7 = getelementptr inbounds %struct.KernelLaunchEnvironmentTy.0, ptr %launch_env, i32 0, i32 4
; CHECK-CACHE-NEXT:   %8 = load ptr, ptr %7
; CHECK-CACHE-NEXT:   %9 = getelementptr inbounds ptr, ptr %8, i32 1
; CHECK-CACHE-NEXT:   %cache.in.ptr = load ptr, ptr %9
; CHECK-CACHE-NEXT:   %arrayidx2.cacheidx1 = getelementptr inbounds %cache_cell, ptr %cache.in.ptr, i32 %gtid
; CHECK-CACHE-NEXT:   %10 = getelementptr inbounds %cache_cell, ptr %arrayidx2.cacheidx1, i32 0, i32 0
; CHECK-CACHE-NEXT:   %11 = load ptr, ptr %10
; CHECK-CACHE-NEXT:   %arrayidx1.cacheidx2 = getelementptr inbounds %cache_cell, ptr %cache.in.ptr, i32 %gtid
; CHECK-CACHE-NEXT:   %12 = getelementptr inbounds %cache_cell, ptr %arrayidx1.cacheidx2, i32 0, i32 1
; CHECK-CACHE-NEXT:   %13 = load ptr, ptr %12
; CHECK-CACHE-NEXT:   %val1.cacheidx3 = getelementptr inbounds %cache_cell, ptr %cache.in.ptr, i32 %gtid
; CHECK-CACHE-NEXT:   %14 = getelementptr inbounds %cache_cell, ptr %val1.cacheidx3, i32 0, i32 2
; CHECK-CACHE-NEXT:   %15 = load double, ptr %14
; CHECK-CACHE-NEXT:   %val2.cacheidx4 = getelementptr inbounds %cache_cell, ptr %cache.in.ptr, i32 %gtid
; CHECK-CACHE-NEXT:   %16 = getelementptr inbounds %cache_cell, ptr %val2.cacheidx4, i32 0, i32 3
; CHECK-CACHE-NEXT:   %17 = load double, ptr %16
; CHECK-CACHE-NEXT:   %mul.cacheidx5 = getelementptr inbounds %cache_cell, ptr %cache.in.ptr, i32 %gtid
; CHECK-CACHE-NEXT:   %18 = getelementptr inbounds %cache_cell, ptr %mul.cacheidx5, i32 0, i32 4
; CHECK-CACHE-NEXT:   %19 = load double, ptr %18
; CHECK-CACHE-NEXT:   store double %19, ptr %13
; CHECK-CACHE-NEXT:   %add = fmul double %15, %17
; CHECK-CACHE-NEXT:   store double %add, ptr %11
; CHECK-CACHE-NEXT:   %mul1 = fmul double %19, %19
; CHECK-CACHE-NEXT:   store double %mul1, ptr %13
; CHECK-CACHE-NEXT:   call void @__kmpc_target_deinit()
; CHECK-CACHE-NEXT:   ret void
; CHECK-CACHE-NEXT: }
;
; CHECK-RECOMPUTE: CacheRemat:                                       ; preds = %entry
; CHECK-RECOMPUTE-NEXT:   %7 = getelementptr inbounds %struct.KernelLaunchEnvironmentTy.0, ptr %launch_env, i32 0, i32 4
; CHECK-RECOMPUTE-NEXT:   %8 = load ptr, ptr %7
; CHECK-RECOMPUTE-NEXT:   %9 = getelementptr inbounds ptr, ptr %8, i32 1
; CHECK-RECOMPUTE-NEXT:   %cache.in.ptr = load ptr, ptr %9
; CHECK-RECOMPUTE-NEXT:   %val2.cacheidx1 = getelementptr inbounds %cache_cell, ptr %cache.in.ptr, i32 %gtid
; CHECK-RECOMPUTE-NEXT:   %10 = getelementptr inbounds %cache_cell, ptr %val2.cacheidx1, i32 0, i32 0
; CHECK-RECOMPUTE-NEXT:   %11 = load double, ptr %10
; CHECK-RECOMPUTE-NEXT:   %val1.cacheidx2 = getelementptr inbounds %cache_cell, ptr %cache.in.ptr, i32 %gtid
; CHECK-RECOMPUTE-NEXT:   %12 = getelementptr inbounds %cache_cell, ptr %val1.cacheidx2, i32 0, i32 1
; CHECK-RECOMPUTE-NEXT:   %13 = load double, ptr %12
; CHECK-RECOMPUTE-NEXT:   %tid.cacheidx3 = getelementptr inbounds %cache_cell, ptr %cache.in.ptr, i32 %gtid
; CHECK-RECOMPUTE-NEXT:   %14 = getelementptr inbounds %cache_cell, ptr %tid.cacheidx3, i32 0, i32 2
; CHECK-RECOMPUTE-NEXT:   %15 = load i64, ptr %14
; CHECK-RECOMPUTE-NEXT:   %16 = getelementptr inbounds double, ptr %ptr2, i64 %15
; CHECK-RECOMPUTE-NEXT:   %17 = getelementptr inbounds double, ptr %ptr1, i64 %15
; CHECK-RECOMPUTE-NEXT:   %18 = fmul double %13, %11
; CHECK-RECOMPUTE-NEXT:   store double %18, ptr %17
; CHECK-RECOMPUTE-NEXT:   %add = fmul double %13, %11
; CHECK-RECOMPUTE-NEXT:   store double %add, ptr %16
; CHECK-RECOMPUTE-NEXT:   %mul1 = fmul double %18, %18
; CHECK-RECOMPUTE-NEXT:   store double %mul1, ptr %17
; CHECK-RECOMPUTE-NEXT:   call void @__kmpc_target_deinit()
; CHECK-RECOMPUTE-NEXT:   ret void
; CHECK-RECOMPUTE-NEXT: }
;
; CHECK-MINCUT: CacheRemat:                                       ; preds = %entry
; CHECK-MINCUT-NEXT:   %7 = getelementptr inbounds %struct.KernelLaunchEnvironmentTy.0, ptr %launch_env, i32 0, i32 4
; CHECK-MINCUT-NEXT:   %8 = load ptr, ptr %7
; CHECK-MINCUT-NEXT:   %9 = getelementptr inbounds ptr, ptr %8, i32 1
; CHECK-MINCUT-NEXT:   %cache.in.ptr = load ptr, ptr %9
; CHECK-MINCUT-NEXT:   %tid.cacheidx1 = getelementptr inbounds %cache_cell, ptr %cache.in.ptr, i32 %gtid
; CHECK-MINCUT-NEXT:   %10 = getelementptr inbounds %cache_cell, ptr %tid.cacheidx1, i32 0, i32 0
; CHECK-MINCUT-NEXT:   %11 = load i64, ptr %10
; CHECK-MINCUT-NEXT:   %val1.cacheidx2 = getelementptr inbounds %cache_cell, ptr %cache.in.ptr, i32 %gtid
; CHECK-MINCUT-NEXT:   %12 = getelementptr inbounds %cache_cell, ptr %val1.cacheidx2, i32 0, i32 1
; CHECK-MINCUT-NEXT:   %13 = load double, ptr %12
; CHECK-MINCUT-NEXT:   %val2.cacheidx3 = getelementptr inbounds %cache_cell, ptr %cache.in.ptr, i32 %gtid
; CHECK-MINCUT-NEXT:   %14 = getelementptr inbounds %cache_cell, ptr %val2.cacheidx3, i32 0, i32 2
; CHECK-MINCUT-NEXT:   %15 = load double, ptr %14
; CHECK-MINCUT-NEXT:   %16 = getelementptr inbounds double, ptr %ptr2, i64 %11
; CHECK-MINCUT-NEXT:   %17 = getelementptr inbounds double, ptr %ptr1, i64 %11
; CHECK-MINCUT-NEXT:   %18 = fmul double %13, %15
; CHECK-MINCUT-NEXT:   store double %18, ptr %17
; CHECK-MINCUT-NEXT:   %add = fmul double %13, %15
; CHECK-MINCUT-NEXT:   store double %add, ptr %16
; CHECK-MINCUT-NEXT:   %mul1 = fmul double %18, %18
; CHECK-MINCUT-NEXT:   store double %mul1, ptr %17
; CHECK-MINCUT-NEXT:   call void @__kmpc_target_deinit()
; CHECK-MINCUT-NEXT:   ret void
; CHECK-MINCUT-NEXT: }