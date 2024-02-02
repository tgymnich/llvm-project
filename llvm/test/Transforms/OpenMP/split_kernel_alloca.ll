; RUN: opt < %s -S -passes="cgscc(openmp-opt-postlink-cgscc),ipsccp,simplifycfg" | FileCheck %s

target triple = "nvptx64"

%struct.ident_t = type { i32, i32, i32, i32, ptr }
%struct.KernelEnvironmentTy = type { %struct.ConfigurationEnvironmentTy, ptr, ptr }
%struct.ConfigurationEnvironmentTy = type { i8, i8, i8, i32, i32, i32, i32, i32, i32, i32, i32 }
%struct.KernelLaunchEnvironmentTy = type { i32, i32, ptr, i32 }

@test_kernel_environment = weak_odr protected local_unnamed_addr constant %struct.KernelEnvironmentTy { %struct.ConfigurationEnvironmentTy { i8 0, i8 0, i8 2, i32 1, i32 512, i32 1, i32 1, i32 1, i32 0, i32 0, i32 0 }, ptr null, ptr null }

declare i32 @__kmpc_target_init(ptr, ptr)
declare void @__kmpc_target_deinit()

declare void @__ompx_split()

define void @test(ptr %launch_env, ptr %tid_addr, ptr %ptr, ptr %dyn) "kernel" "omp_target_thread_limit"="32" "omp_target_num_teams"="1" {
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


; CHECK: define void @test(ptr %launch_env, ptr %tid_addr, ptr %ptr, ptr %dyn)
; CHECK-NEXT: entry:
; CHECK-NEXT:   %i = call i32 @__kmpc_target_init(ptr @test_kernel_environment, ptr %dyn)
; CHECK-NEXT:   %tid = load i64, ptr %tid_addr
; CHECK-NEXT:   %ptry = alloca double
; CHECK-NEXT:   %idxy = getelementptr inbounds double, ptr %ptr, i64 9
; CHECK-NEXT:   %valy = load double, ptr %idxy
; CHECK-NEXT:   store double %valy, ptr %ptry
; CHECK-NEXT:   %arrayidx = getelementptr inbounds double, ptr %ptr, i64 %tid
; CHECK-NEXT:   %cmp = icmp ult i64 0, %tid
; CHECK-NEXT:   br i1 %cmp, label %CacheStore, label %end
;
; CHECK: end:                                              ; preds = %entry
; CHECK-NEXT:   %val2 = load double, ptr %arrayidx
; CHECK-NEXT:   %mul = fmul double %val2, %val2
; CHECK-NEXT:   store double %mul, ptr %arrayidx
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
; CHECK-NEXT:   %tid.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-NEXT:   %5 = getelementptr inbounds %cache_cell, ptr %tid.cacheidx, i32 0, i32 0
; CHECK-NEXT:   store i64 %tid, ptr %5
; CHECK-NEXT:   %ptry.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-NEXT:   %6 = getelementptr inbounds %cache_cell, ptr %ptry.cacheidx, i32 0, i32 0
; CHECK-NEXT:   %7 = load double, ptr %ptry
; CHECK-NEXT:   store double %7, ptr %6
; CHECK-NEXT:   call void asm sideeffect "exit;", ""()
; CHECK-NEXT:   unreachable
; CHECK-NEXT: }
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
; CHECK: CacheRemat:                                       ; preds = %entry
; CHECK-NEXT:   %7 = getelementptr inbounds %struct.KernelLaunchEnvironmentTy.0, ptr %launch_env, i32 0, i32 4
; CHECK-NEXT:   %8 = load ptr, ptr %7
; CHECK-NEXT:   %9 = getelementptr inbounds ptr, ptr %8, i32 1
; CHECK-NEXT:   %cache.in.ptr = load ptr, ptr %9
; CHECK-NEXT:   %tid.cacheidx1 = getelementptr inbounds %cache_cell, ptr %cache.in.ptr, i32 %gtid
; CHECK-NEXT:   %10 = getelementptr inbounds %cache_cell, ptr %tid.cacheidx1, i32 0, i32 0
; CHECK-NEXT:   %11 = load i64, ptr %10
; CHECK-NEXT:   %ptry.remat = alloca double
; CHECK-NEXT:   %ptry.cacheidx2 = getelementptr inbounds %cache_cell, ptr %cache.in.ptr, i32 %gtid
; CHECK-NEXT:   %12 = getelementptr inbounds %cache_cell, ptr %ptry.cacheidx2, i32 0, i32 1
; CHECK-NEXT:   %13 = load double, ptr %12
; CHECK-NEXT:   store double %13, ptr %ptry.remat
; CHECK-NEXT:   %14 = getelementptr inbounds double, ptr %ptr, i64 %11
; CHECK-NEXT:   %val1 = load double, ptr %14
; CHECK-NEXT:   %y = load double, ptr %ptry.remat
; CHECK-NEXT:   %add = fadd double %val1, %y
; CHECK-NEXT:   store double %add, ptr %14
; CHECK-NEXT:   %val2 = load double, ptr %14
; CHECK-NEXT:   %mul = fmul double %val2, %val2
; CHECK-NEXT:   store double %mul, ptr %14
; CHECK-NEXT:   call void @__kmpc_target_deinit()
; CHECK-NEXT:   ret void
; CHECK-NEXT: }