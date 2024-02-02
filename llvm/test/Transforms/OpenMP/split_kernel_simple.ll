; RUN: opt < %s -S -passes="cgscc(openmp-opt-postlink-cgscc),ipsccp,simplifycfg" | FileCheck %s

target datalayout = "e-i64:64-i128:128-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

%struct.KernelEnvironmentTy = type { %struct.ConfigurationEnvironmentTy, ptr, ptr }
%struct.ConfigurationEnvironmentTy = type { i8, i8, i8, i32, i32, i32, i32, i32, i32, i32, i32 }

@__omp_offloading_test_kernel_environment = weak_odr protected local_unnamed_addr constant %struct.KernelEnvironmentTy { %struct.ConfigurationEnvironmentTy { i8 0, i8 0, i8 2, i32 1, i32 512, i32 1, i32 1, i32 0, i32 0, i32 0, i32 0 }, ptr null, ptr null }

declare noundef i32 @llvm.nvvm.read.ptx.sreg.tid.x() #0

declare noundef i32 @llvm.nvvm.read.ptx.sreg.ntid.x() #0

declare void @llvm.assume(i1 noundef) #2

declare noundef i32 @llvm.nvvm.read.ptx.sreg.ctaid.x() #0

declare noundef i32 @llvm.nvvm.read.ptx.sreg.nctaid.x() #0

declare double @llvm.fmuladd.f64(double, double, double) #0

declare void @__ompx_split() local_unnamed_addr #1

define weak_odr protected void @__omp_offloading_test(ptr noalias noundef %arg, ptr noundef %arg1) local_unnamed_addr #3 {
entry:
  %i = tail call noundef i32 @llvm.nvvm.read.ptx.sreg.tid.x() #4
  %i2 = tail call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x() #4
  %i3 = tail call i32 @llvm.nvvm.read.ptx.sreg.nctaid.x() #5
  %i4 = icmp ult i32 %i2, %i3
  tail call void @llvm.assume(i1 noundef %i4) #6
  %i5 = tail call i32 @llvm.nvvm.read.ptx.sreg.ntid.x() #5
  %i6 = mul nsw i32 %i5, %i2
  %i7 = add nsw i32 %i6, %i
  %i8 = srem i32 %i7, 6
  %i9 = icmp eq i32 %i8, 0
  br i1 %i9, label %bb2, label %bb1

bb1:                                              ; preds = %entry
  %i11 = sext i32 %i7 to i64
  %i12 = getelementptr inbounds double, ptr %arg1, i64 %i11
  %i13 = load double, ptr %i12
  %i14 = tail call double @llvm.fmuladd.f64(double %i13, double %i13, double 2.000000e+00)
  store double %i14, ptr %i12
  br label %exit

bb2:                                              ; preds = %entry
  tail call void @__ompx_split() #7
  %i16 = sext i32 %i7 to i64
  %i17 = getelementptr inbounds double, ptr %arg1, i64 %i16
  %i18 = load double, ptr %i17
  %i19 = tail call double @llvm.fmuladd.f64(double %i18, double %i18, double 3.000000e+00)
  store double %i19, ptr %i17
  br label %exit

exit:                                             ; preds = %bb2, %bb1
  ret void
}

attributes #0 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #1 = { convergent "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="sm_86" "target-features"="+ptx81,+sm_86" }
attributes #2 = { nocallback nofree nosync nounwind willreturn memory(inaccessiblemem: write) }
attributes #3 = { alwaysinline norecurse nounwind "frame-pointer"="all" "kernel" "no-trapping-math"="true" "omp_target_num_teams"="1" "omp_target_thread_limit"="512" "stack-protector-buffer-size"="8" "target-cpu"="sm_86" "target-features"="+ptx81,+sm_86" }
attributes #4 = { nofree nosync willreturn "llvm.assume"="ompx_no_call_asm" }
attributes #5 = { nosync "llvm.assume"="ompx_no_call_asm" }
attributes #6 = { memory(write) "llvm.assume"="ompx_no_call_asm" }
attributes #7 = { convergent nounwind }

!llvm.ident = !{!0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !1}
!llvm.module.flags = !{!2, !3, !4, !5, !6, !7, !8, !9}
!nvvm.annotations = !{!10, !11, !12, !13}
!omp_offload.info = !{!14}
!nvvmir.version = !{!15}

!0 = !{!"clang version 18.0.0git (git@github.com:tgymnich/llvm-project.git e9b78a0b34fe6b87e043d88419c1d2ab7ce8c05a)"}
!1 = !{!"clang version 3.8.0 (tags/RELEASE_380/final)"}
!2 = !{i32 1, !"wchar_size", i32 4}
!3 = !{i32 7, !"openmp", i32 51}
!4 = !{i32 7, !"openmp-device", i32 51}
!5 = !{i32 8, !"PIC Level", i32 2}
!6 = !{i32 7, !"frame-pointer", i32 2}
!7 = !{i32 1, !"ThinLTO", i32 0}
!8 = !{i32 1, !"EnableSplitLTOUnit", i32 1}
!9 = !{i32 2, !"SDK Version", [2 x i32] [i32 12, i32 1]}
!10 = !{ptr @__omp_offloading_test, !"maxclusterrank", i32 1}
!11 = !{ptr @__omp_offloading_test, !"minctasm", i32 1}
!12 = !{ptr @__omp_offloading_test, !"maxntidx", i32 512}
!13 = !{ptr @__omp_offloading_test, !"kernel", i32 1}
!14 = !{i32 0, i32 64769, i32 2753303, !"test", i32 25, i32 0, i32 0}
!15 = !{i32 2, i32 0}


; CHECK: define weak_odr protected void @__omp_offloading_test(ptr noalias noundef %arg, ptr noundef %arg1)
; CHECK-NEXT: entry:
; CHECK-NEXT:   %i5 = tail call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
; CHECK-NEXT:   %i3 = tail call i32 @llvm.nvvm.read.ptx.sreg.nctaid.x()
; CHECK-NEXT:   %i2 = tail call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
; CHECK-NEXT:   %i = tail call noundef i32 @llvm.nvvm.read.ptx.sreg.tid.x()
; CHECK-NEXT:   %i4 = icmp ult i32 %i2, %i3
; CHECK-NEXT:   tail call void @llvm.assume(i1 noundef %i4)
; CHECK-NEXT:   %i6 = mul nsw i32 %i5, %i2
; CHECK-NEXT:   %i7 = add nsw i32 %i6, %i
; CHECK-NEXT:   %i8 = srem i32 %i7, 6
; CHECK-NEXT:   %i9 = icmp eq i32 %i8, 0
; CHECK-NEXT:   br i1 %i9, label %CacheStore, label %bb1
;
; CHECK: bb1:                                              ; preds = %entry
; CHECK-NEXT:   %i11 = sext i32 %i7 to i64
; CHECK-NEXT:   %i12 = getelementptr inbounds double, ptr %arg1, i64 %i11
; CHECK-NEXT:   %i13 = load double, ptr %i12
; CHECK-NEXT:   %i14 = tail call double @llvm.fmuladd.f64(double %i13, double %i13, double 2.000000e+00)
; CHECK-NEXT:   store double %i14, ptr %i12
; CHECK-NEXT:   ret void
;
; CHECK: CacheStore:                                       ; preds = %entry
; CHECK-NEXT:   %0 = getelementptr inbounds %struct.KernelLaunchEnvironmentTy.0, ptr %arg, i32 0, i32 3
; CHECK-NEXT:   %1 = load ptr, ptr %0
; CHECK-NEXT:   %contcount.ptr = getelementptr inbounds i32, ptr %1, i32 0
; CHECK-NEXT:   %cacheidx = atomicrmw add ptr %contcount.ptr, i32 1 acquire
; CHECK-NEXT:   %2 = getelementptr inbounds %struct.KernelLaunchEnvironmentTy.0, ptr %arg, i32 0, i32 4
; CHECK-NEXT:   %3 = load ptr, ptr %2
; CHECK-NEXT:   %4 = getelementptr inbounds ptr, ptr %3, i32 0
; CHECK-NEXT:   %cache.out.ptr = load ptr, ptr %4
; CHECK-NEXT:   %i.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-NEXT:   %5 = getelementptr inbounds %cache_cell, ptr %i.cacheidx, i32 0, i32 0
; CHECK-NEXT:   store i32 %i, ptr %5
; CHECK-NEXT:   %i2.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-NEXT:   %6 = getelementptr inbounds %cache_cell, ptr %i2.cacheidx, i32 0, i32 1
; CHECK-NEXT:   store i32 %i2, ptr %6
; CHECK-NEXT:   %i5.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-NEXT:   %7 = getelementptr inbounds %cache_cell, ptr %i5.cacheidx, i32 0, i32 2
; CHECK-NEXT:   store i32 %i5, ptr %7
; CHECK-NEXT:   call void asm sideeffect "exit;", ""()
; CHECK-NEXT:   unreachable
; CHECK-NEXT: }
;
; CHECK: define weak_odr protected void @__omp_offloading_test_contd_0(ptr noalias noundef %arg, ptr noundef %arg1)
; CHECK-NEXT: entry:
; CHECK-NEXT:   %0 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
; CHECK-NEXT:   %1 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
; CHECK-NEXT:   %2 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
; CHECK-NEXT:   %3 = mul i32 %1, %2
; CHECK-NEXT:   %gtid = add i32 %0, %3
; CHECK-NEXT:   %4 = getelementptr inbounds %struct.KernelLaunchEnvironmentTy.0, ptr %arg, i32 0, i32 3
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
; CHECK-NEXT:   %7 = getelementptr inbounds %struct.KernelLaunchEnvironmentTy.0, ptr %arg, i32 0, i32 4
; CHECK-NEXT:   %8 = load ptr, ptr %7
; CHECK-NEXT:   %9 = getelementptr inbounds ptr, ptr %8, i32 1
; CHECK-NEXT:   %cache.in.ptr = load ptr, ptr %9
; CHECK-NEXT:   %i.cacheidx1 = getelementptr inbounds %cache_cell, ptr %cache.in.ptr, i32 %gtid
; CHECK-NEXT:   %10 = getelementptr inbounds %cache_cell, ptr %i.cacheidx1, i32 0, i32 0
; CHECK-NEXT:   %11 = load i32, ptr %10
; CHECK-NEXT:   %i2.cacheidx2 = getelementptr inbounds %cache_cell, ptr %cache.in.ptr, i32 %gtid
; CHECK-NEXT:   %12 = getelementptr inbounds %cache_cell, ptr %i2.cacheidx2, i32 0, i32 1
; CHECK-NEXT:   %13 = load i32, ptr %12
; CHECK-NEXT:   %i5.cacheidx3 = getelementptr inbounds %cache_cell, ptr %cache.in.ptr, i32 %gtid
; CHECK-NEXT:   %14 = getelementptr inbounds %cache_cell, ptr %i5.cacheidx3, i32 0, i32 2
; CHECK-NEXT:   %15 = load i32, ptr %14
; CHECK-NEXT:   %16 = mul nsw i32 %15, %13
; CHECK-NEXT:   %17 = add nsw i32 %16, %11
; CHECK-NEXT:   %i16 = sext i32 %17 to i64
; CHECK-NEXT:   %i17 = getelementptr inbounds double, ptr %arg1, i64 %i16
; CHECK-NEXT:   %i18 = load double, ptr %i17
; CHECK-NEXT:   %i19 = tail call double @llvm.fmuladd.f64(double %i18, double %i18, double 3.000000e+00)
; CHECK-NEXT:   store double %i19, ptr %i17
; CHECK-NEXT:   ret void
; CHECK-NEXT: }