; RUN: opt < %s -S -passes="cgscc(openmp-opt-postlink-cgscc),ipsccp,simplifycfg" --split-kernel-remat-mode=cache | FileCheck %s --check-prefix=CHECK-CACHE
; RUN: opt < %s -S -passes="cgscc(openmp-opt-postlink-cgscc),ipsccp,simplifycfg" --split-kernel-remat-mode=recompute | FileCheck %s --check-prefix=CHECK-RECOMPUTE
; RUN: opt < %s -S -passes="cgscc(openmp-opt-postlink-cgscc),ipsccp,simplifycfg" --split-kernel-remat-mode=mincut | FileCheck %s --check-prefix=CHECK-MINCUT

target triple = "nvptx64"

%struct.ident_t = type { i32, i32, i32, i32, ptr }
%struct.KernelEnvironmentTy = type { %struct.ConfigurationEnvironmentTy, ptr, ptr }
%struct.ConfigurationEnvironmentTy = type { i8, i8, i8, i32, i32, i32, i32, i32, i32, i32, i32 }
%struct.KernelLaunchEnvironmentTy = type { i32, i32, ptr, i32 }

@test_kernel_environment = weak_odr protected local_unnamed_addr constant %struct.KernelEnvironmentTy { %struct.ConfigurationEnvironmentTy { i8 0, i8 0, i8 2, i32 1, i32 512, i32 1, i32 1, i32 1, i32 0, i32 0, i32 0 }, ptr null, ptr null }

declare void @__ompx_split()

declare i32 @__kmpc_target_init(ptr, ptr)
declare void @__kmpc_target_deinit()

define void @test(ptr %launch_env, ptr %tid_addr, ptr %ptr, ptr %dyn) "kernel" "omp_target_thread_limit"="32" "omp_target_num_teams"="1" {
  entry:
    %i = call i32 @__kmpc_target_init(ptr @test_kernel_environment, ptr %dyn)
    %tid = load i64, ptr %tid_addr
    %arrayidx = getelementptr inbounds double, ptr %ptr, i64 %tid
    %val = load double, ptr %arrayidx
    %sub = fsub double %val, 1.0
    %add = fadd double %val, 2.0
    %mul = fmul double %val, 3.0
    %div = fmul double %val, 4.0
    %cmp = icmp ult i64 0, %tid
    br i1 %cmp, label %if, label %end
  if:
    call void @__ompx_split()
    %res1 = fmul double %sub, %add
    %res2 = fmul double %res1, %mul
    %res3 = fmul double %res2, %div
    store double %res3, ptr %arrayidx
    br label %end
  end:
    %mul1 = fmul double %val, %val
    store double %mul1, ptr %arrayidx
    call void @__kmpc_target_deinit()
    ret void
}

!llvm.module.flags = !{!3, !4}

!3 = !{i32 7, !"openmp", i32 51}
!4 = !{i32 7, !"openmp-device", i32 51}


; CHECK: define void @test(ptr %launch_env, ptr %tid_addr, ptr %ptr, ptr %dyn)
; CHECK-NEXT: entry:
; CHECK-NEXT:   %i = call i32 @__kmpc_target_init(ptr @test_kernel_environment, ptr %dyn)
; CHECK-NEXT:   %tid = load i64, ptr %tid_addr
; CHECK-NEXT:   %arrayidx = getelementptr inbounds double, ptr %ptr, i64 %tid
; CHECK-NEXT:   %val = load double, ptr %arrayidx
; CHECK-NEXT:   %sub = fsub double %val, 1.000000e+00
; CHECK-NEXT:   %add = fadd double %val, 2.000000e+00
; CHECK-NEXT:   %mul = fmul double %val, 3.000000e+00
; CHECK-NEXT:   %div = fmul double %val, 4.000000e+00
; CHECK-NEXT:   %cmp = icmp ult i64 0, %tid
; CHECK-NEXT:   br i1 %cmp, label %CacheStore, label %end
;
; CHECK: end:                                              ; preds = %entry
; CHECK-NEXT:   %mul1 = fmul double %val, %val
; CHECK-NEXT:   store double %mul1, ptr %arrayidx
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
; CHECK-CACHE-NEXT:   %arrayidx.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-CACHE-NEXT:   %5 = getelementptr inbounds %cache_cell, ptr %arrayidx.cacheidx, i32 0, i32 0
; CHECK-CACHE-NEXT:   store ptr %arrayidx, ptr %5
; CHECK-CACHE-NEXT:   %val.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-CACHE-NEXT:   %6 = getelementptr inbounds %cache_cell, ptr %val.cacheidx, i32 0, i32 1
; CHECK-CACHE-NEXT:   store double %val, ptr %6
; CHECK-CACHE-NEXT:   %div.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-CACHE-NEXT:   %7 = getelementptr inbounds %cache_cell, ptr %div.cacheidx, i32 0, i32 2
; CHECK-CACHE-NEXT:   store double %div, ptr %7
; CHECK-CACHE-NEXT:   %mul.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-CACHE-NEXT:   %8 = getelementptr inbounds %cache_cell, ptr %mul.cacheidx, i32 0, i32 3
; CHECK-CACHE-NEXT:   store double %mul, ptr %8
; CHECK-CACHE-NEXT:   %add.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-CACHE-NEXT:   %9 = getelementptr inbounds %cache_cell, ptr %add.cacheidx, i32 0, i32 4
; CHECK-CACHE-NEXT:   store double %add, ptr %9
; CHECK-CACHE-NEXT:   %sub.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-CACHE-NEXT:   %10 = getelementptr inbounds %cache_cell, ptr %sub.cacheidx, i32 0, i32 5
; CHECK-CACHE-NEXT:   store double %sub, ptr %10
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
; CHECK-RECOMPUTE-NEXT:   %val.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-RECOMPUTE-NEXT:   %5 = getelementptr inbounds %cache_cell, ptr %val.cacheidx, i32 0, i32 0
; CHECK-RECOMPUTE-NEXT:   store double %val, ptr %5
; CHECK-RECOMPUTE-NEXT:   %tid.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-RECOMPUTE-NEXT:   %6 = getelementptr inbounds %cache_cell, ptr %tid.cacheidx, i32 0, i32 1
; CHECK-RECOMPUTE-NEXT:   store i64 %tid, ptr %6
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
; CHECK-MINCUT-NEXT:   %val.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-MINCUT-NEXT:   %6 = getelementptr inbounds %cache_cell, ptr %val.cacheidx, i32 0, i32 1
; CHECK-MINCUT-NEXT:   store double %val, ptr %6
; CHECK-MINCUT-NEXT:   call void asm sideeffect "exit;", ""()
; CHECK-MINCUT-NEXT:   unreachable
; CHECK-MINCUT-NEXT: }
;
;
; CHECK: define void @test_contd_0(ptr %launch_env, ptr %tid_addr, ptr %ptr, ptr %dyn)
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
; CHECK-CACHE-NEXT:   %arrayidx.cacheidx1 = getelementptr inbounds %cache_cell, ptr %cache.in.ptr, i32 %gtid
; CHECK-CACHE-NEXT:   %10 = getelementptr inbounds %cache_cell, ptr %arrayidx.cacheidx1, i32 0, i32 0
; CHECK-CACHE-NEXT:   %11 = load ptr, ptr %10
; CHECK-CACHE-NEXT:   %val.cacheidx2 = getelementptr inbounds %cache_cell, ptr %cache.in.ptr, i32 %gtid
; CHECK-CACHE-NEXT:   %12 = getelementptr inbounds %cache_cell, ptr %val.cacheidx2, i32 0, i32 1
; CHECK-CACHE-NEXT:   %13 = load double, ptr %12
; CHECK-CACHE-NEXT:   %div.cacheidx3 = getelementptr inbounds %cache_cell, ptr %cache.in.ptr, i32 %gtid
; CHECK-CACHE-NEXT:   %14 = getelementptr inbounds %cache_cell, ptr %div.cacheidx3, i32 0, i32 2
; CHECK-CACHE-NEXT:   %15 = load double, ptr %14
; CHECK-CACHE-NEXT:   %mul.cacheidx4 = getelementptr inbounds %cache_cell, ptr %cache.in.ptr, i32 %gtid
; CHECK-CACHE-NEXT:   %16 = getelementptr inbounds %cache_cell, ptr %mul.cacheidx4, i32 0, i32 3
; CHECK-CACHE-NEXT:   %17 = load double, ptr %16
; CHECK-CACHE-NEXT:   %add.cacheidx5 = getelementptr inbounds %cache_cell, ptr %cache.in.ptr, i32 %gtid
; CHECK-CACHE-NEXT:   %18 = getelementptr inbounds %cache_cell, ptr %add.cacheidx5, i32 0, i32 4
; CHECK-CACHE-NEXT:   %19 = load double, ptr %18
; CHECK-CACHE-NEXT:   %sub.cacheidx6 = getelementptr inbounds %cache_cell, ptr %cache.in.ptr, i32 %gtid
; CHECK-CACHE-NEXT:   %20 = getelementptr inbounds %cache_cell, ptr %sub.cacheidx6, i32 0, i32 5
; CHECK-CACHE-NEXT:   %21 = load double, ptr %20
; CHECK-CACHE-NEXT:   %res1 = fmul double %21, %19
; CHECK-CACHE-NEXT:   %res2 = fmul double %res1, %17
; CHECK-CACHE-NEXT:   %res3 = fmul double %res2, %15
; CHECK-CACHE-NEXT:   store double %res3, ptr %11
; CHECK-CACHE-NEXT:   %mul1 = fmul double %13, %13
; CHECK-CACHE-NEXT:   store double %mul1, ptr %11
; CHECK-CACHE-NEXT:   call void @__kmpc_target_deinit()
; CHECK-CACHE-NEXT:   ret void
; CHECK-CACHE-NEXT: }
;
; CHECK-RECOMPUTE: CacheRemat:                                       ; preds = %entry
; CHECK-RECOMPUTE-NEXT:   %7 = getelementptr inbounds %struct.KernelLaunchEnvironmentTy.0, ptr %launch_env, i32 0, i32 4
; CHECK-RECOMPUTE-NEXT:   %8 = load ptr, ptr %7
; CHECK-RECOMPUTE-NEXT:   %9 = getelementptr inbounds ptr, ptr %8, i32 1
; CHECK-RECOMPUTE-NEXT:   %cache.in.ptr = load ptr, ptr %9
; CHECK-RECOMPUTE-NEXT:   %val.cacheidx1 = getelementptr inbounds %cache_cell, ptr %cache.in.ptr, i32 %gtid
; CHECK-RECOMPUTE-NEXT:   %10 = getelementptr inbounds %cache_cell, ptr %val.cacheidx1, i32 0, i32 0
; CHECK-RECOMPUTE-NEXT:   %11 = load double, ptr %10
; CHECK-RECOMPUTE-NEXT:   %tid.cacheidx2 = getelementptr inbounds %cache_cell, ptr %cache.in.ptr, i32 %gtid
; CHECK-RECOMPUTE-NEXT:   %12 = getelementptr inbounds %cache_cell, ptr %tid.cacheidx2, i32 0, i32 1
; CHECK-RECOMPUTE-NEXT:   %13 = load i64, ptr %12
; CHECK-RECOMPUTE-NEXT:   %14 = getelementptr inbounds double, ptr %ptr, i64 %13
; CHECK-RECOMPUTE-NEXT:   %15 = fmul double %11, 4.000000e+00
; CHECK-RECOMPUTE-NEXT:   %16 = fmul double %11, 3.000000e+00
; CHECK-RECOMPUTE-NEXT:   %17 = fadd double %11, 2.000000e+00
; CHECK-RECOMPUTE-NEXT:   %18 = fsub double %11, 1.000000e+00
; CHECK-RECOMPUTE-NEXT:   %res1 = fmul double %18, %17
; CHECK-RECOMPUTE-NEXT:   %res2 = fmul double %res1, %16
; CHECK-RECOMPUTE-NEXT:   %res3 = fmul double %res2, %15
; CHECK-RECOMPUTE-NEXT:   store double %res3, ptr %14
; CHECK-RECOMPUTE-NEXT:   %mul1 = fmul double %11, %11
; CHECK-RECOMPUTE-NEXT:   store double %mul1, ptr %14
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
; CHECK-MINCUT-NEXT:   %val.cacheidx2 = getelementptr inbounds %cache_cell, ptr %cache.in.ptr, i32 %gtid
; CHECK-MINCUT-NEXT:   %12 = getelementptr inbounds %cache_cell, ptr %val.cacheidx2, i32 0, i32 1
; CHECK-MINCUT-NEXT:   %13 = load double, ptr %12
; CHECK-MINCUT-NEXT:   %14 = getelementptr inbounds double, ptr %ptr, i64 %11
; CHECK-MINCUT-NEXT:   %15 = fmul double %13, 4.000000e+00
; CHECK-MINCUT-NEXT:   %16 = fmul double %13, 3.000000e+00
; CHECK-MINCUT-NEXT:   %17 = fadd double %13, 2.000000e+00
; CHECK-MINCUT-NEXT:   %18 = fsub double %13, 1.000000e+00
; CHECK-MINCUT-NEXT:   %res1 = fmul double %18, %17
; CHECK-MINCUT-NEXT:   %res2 = fmul double %res1, %16
; CHECK-MINCUT-NEXT:   %res3 = fmul double %res2, %15
; CHECK-MINCUT-NEXT:   store double %res3, ptr %14
; CHECK-MINCUT-NEXT:   %mul1 = fmul double %13, %13
; CHECK-MINCUT-NEXT:   store double %mul1, ptr %14
; CHECK-MINCUT-NEXT:   call void @__kmpc_target_deinit()
; CHECK-MINCUT-NEXT:   ret void
; CHECK-MINCUT-NEXT: }