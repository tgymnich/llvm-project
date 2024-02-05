; RUN: opt < %s -S -passes="cgscc(openmp-opt-postlink-cgscc),ipsccp,simplifycfg" | FileCheck %s

target datalayout = "e-i64:64-i128:128-v16:16-v32:32-n16:32:64"
target triple = "nvptx64-nvidia-cuda"

%struct.KernelEnvironmentTy = type { %struct.ConfigurationEnvironmentTy, ptr, ptr }
%struct.ConfigurationEnvironmentTy = type { i8, i8, i8, i32, i32, i32, i32, i32, i32, i32, i32 }

@__omp_offloading_daxpy_kernel_environment = weak_odr protected local_unnamed_addr constant %struct.KernelEnvironmentTy { %struct.ConfigurationEnvironmentTy { i8 0, i8 0, i8 2, i32 1, i32 1024, i32 1, i32 1, i32 0, i32 0, i32 0, i32 0 }, ptr null, ptr null }

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef i32 @llvm.nvvm.read.ptx.sreg.tid.x() #0

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef i32 @llvm.nvvm.read.ptx.sreg.ntid.x() #0

; Function Attrs: convergent nocallback nounwind
declare void @llvm.nvvm.barrier0() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef i32 @llvm.nvvm.read.ptx.sreg.ctaid.x() #0

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef i32 @llvm.nvvm.read.ptx.sreg.nctaid.x() #0

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i32 @llvm.smin.i32(i32, i32) #0

; Function Attrs: alwaysinline norecurse nounwind
define weak_odr protected void @__omp_offloading_daxpy(ptr noalias noundef %arg, ptr noundef %arg1, i64 noundef %arg2, ptr noundef %arg3) local_unnamed_addr #2 {
entry:
  %i = tail call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x() #4, !range !16
  %i4 = tail call i32 @llvm.nvvm.read.ptx.sreg.nctaid.x() #5, !range !17
  %i5 = shl nsw i32 %i, 10
  %i6 = or disjoint i32 %i5, 1023
  %i7 = shl nsw i32 %i4, 10
  %i8 = tail call i32 @llvm.smin.i32(i32 %i6, i32 1023), !range !18
  %i9 = icmp slt i32 %i, 1
  br i1 %i9, label %bb, label %bb46

bb:                                               ; preds = %entry
  %i10 = inttoptr i64 %arg2 to ptr
  br label %bb11

bb11:                                             ; preds = %bb41, %bb
  %i12 = phi i32 [ %i8, %bb ], [ %i44, %bb41 ]
  %i13 = phi i32 [ %i5, %bb ], [ %i42, %bb41 ]
  %i14 = zext i32 %i13 to i64
  %i15 = zext i32 %i12 to i64
  %i16 = inttoptr i64 %i14 to ptr
  %i17 = inttoptr i64 %i15 to ptr
  %i18 = tail call noundef i32 @llvm.nvvm.read.ptx.sreg.tid.x() #6
  %i19 = icmp eq i32 %i18, 0
  %i20 = ptrtoint ptr %i16 to i64
  %i21 = ptrtoint ptr %i17 to i64
  %i22 = trunc i64 %i20 to i32
  %i23 = tail call noundef i32 @llvm.nvvm.read.ptx.sreg.tid.x() #4
  %i24 = add nsw i32 %i23, %i22
  %i25 = tail call i32 @llvm.nvvm.read.ptx.sreg.ntid.x() #5
  %i26 = sext i32 %i24 to i64
  %i27 = icmp ugt i64 %i26, %i21
  br i1 %i27, label %bb41, label %bb28

bb28:                                             ; preds = %bb11
  %i29 = bitcast i64 %arg2 to double
  br label %bb30

bb30:                                             ; preds = %bb30, %bb28
  %i31 = phi i64 [ %i26, %bb28 ], [ %i39, %bb30 ]
  %i32 = phi i32 [ %i24, %bb28 ], [ %i38, %bb30 ]
  tail call void @__ompx_split() #7
  %i33 = getelementptr inbounds double, ptr %arg3, i64 %i31
  %i34 = load double, ptr %i33, align 8, !tbaa !19
  %i35 = getelementptr inbounds double, ptr %arg1, i64 %i31
  %i36 = load double, ptr %i35, align 8, !tbaa !19
  %i37 = tail call double @llvm.fmuladd.f64(double %i29, double %i34, double %i36)
  store double %i37, ptr %i35, align 8, !tbaa !19
  %i38 = add nsw i32 %i25, %i32
  %i39 = sext i32 %i38 to i64
  %i40 = icmp ugt i64 %i39, %i21
  br i1 %i40, label %bb41, label %bb30

bb41:                                             ; preds = %bb30, %bb11
  tail call void @llvm.nvvm.barrier0() #8
  %i42 = add nsw i32 %i13, %i7
  %i43 = add nsw i32 %i12, %i7
  %i44 = tail call i32 @llvm.smin.i32(i32 %i43, i32 1023)
  %i45 = icmp slt i32 %i42, 1024
  br i1 %i45, label %bb11, label %bb46

bb46:                                             ; preds = %bb41, %entry
  ret void
}

; Function Attrs: convergent
declare void @__ompx_split() local_unnamed_addr #3

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare double @llvm.fmuladd.f64(double, double, double) #0

attributes #0 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #1 = { convergent nocallback nounwind }
attributes #2 = { alwaysinline norecurse nounwind "frame-pointer"="all" "kernel" "no-trapping-math"="true" "omp_target_num_teams"="1" "omp_target_thread_limit"="1024" "stack-protector-buffer-size"="8" "target-cpu"="sm_86" "target-features"="+ptx81,+sm_86" }
attributes #3 = { convergent "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="sm_86" "target-features"="+ptx81,+sm_86" }
attributes #4 = { nofree nosync willreturn "llvm.assume"="ompx_no_call_asm" }
attributes #5 = { nosync "llvm.assume"="ompx_no_call_asm" }
attributes #6 = { nofree willreturn "llvm.assume"="ompx_no_call_asm" }
attributes #7 = { convergent nounwind }
attributes #8 = { "llvm.assume"="ompx_no_call_asm,ompx_aligned_barrier" }

!llvm.ident = !{!0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !1}
!llvm.module.flags = !{!2, !3, !4, !5, !6, !7, !8, !9}
!nvvm.annotations = !{!10, !11, !12, !13}
!omp_offload.info = !{!14}
!nvvmir.version = !{!15}

!0 = !{!"clang version 19.0.0git (git@github.com:tgymnich/llvm-project.git 28b6d786631efec5a92d5068355fdc2b98d0178a)"}
!1 = !{!"clang version 3.8.0 (tags/RELEASE_380/final)"}
!2 = !{i32 1, !"wchar_size", i32 4}
!3 = !{i32 7, !"openmp", i32 51}
!4 = !{i32 7, !"openmp-device", i32 51}
!5 = !{i32 8, !"PIC Level", i32 2}
!6 = !{i32 7, !"frame-pointer", i32 2}
!7 = !{i32 1, !"ThinLTO", i32 0}
!8 = !{i32 1, !"EnableSplitLTOUnit", i32 1}
!9 = !{i32 2, !"SDK Version", [2 x i32] [i32 12, i32 1]}
!10 = !{ptr @__omp_offloading_daxpy, !"maxclusterrank", i32 1}
!11 = !{ptr @__omp_offloading_daxpy, !"minctasm", i32 1}
!12 = !{ptr @__omp_offloading_daxpy, !"maxntidx", i32 1024}
!13 = !{ptr @__omp_offloading_daxpy, !"kernel", i32 1}
!14 = !{i32 0, i32 64769, i32 2753303, !"daxpy", i32 21, i32 0, i32 0}
!15 = !{i32 2, i32 0}
!16 = !{i32 0, i32 -1}
!17 = !{i32 1, i32 0}
!18 = !{i32 -2147483648, i32 1024}
!19 = !{!20, !20, i64 0}
!20 = !{!"double", !21, i64 0}
!21 = !{!"omnipotent char", !22, i64 0}
!22 = !{!"Simple C/C++ TBAA"}


; CHECK: define weak_odr protected void @__omp_offloading_daxpy(ptr noalias noundef %arg, ptr noundef %arg1, i64 noundef %arg2, ptr noundef %arg3)
; CHECK-NEXT: entry:
; CHECK-NEXT:   %i25 = tail call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
; CHECK-NEXT:   %i23 = tail call noundef i32 @llvm.nvvm.read.ptx.sreg.tid.x()
; CHECK-NEXT:   %i18 = tail call noundef i32 @llvm.nvvm.read.ptx.sreg.tid.x()
; CHECK-NEXT:   %i4 = tail call i32 @llvm.nvvm.read.ptx.sreg.nctaid.x()
; CHECK-NEXT:   %i = tail call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
; CHECK-NEXT:   %i5 = shl nsw i32 %i, 10
; CHECK-NEXT:   %i6 = or disjoint i32 %i5, 1023
; CHECK-NEXT:   %i7 = shl nsw i32 %i4, 10
; CHECK-NEXT:   %i8 = tail call i32 @llvm.smin.i32(i32 %i6, i32 1023)
; CHECK-NEXT:   %i9 = icmp slt i32 %i, 1
; CHECK-NEXT:   br i1 %i9, label %bb, label %bb46
;
; CHECK: bb:                                               ; preds = %entry
; CHECK-NEXT:   %i10 = inttoptr i64 %arg2 to ptr
; CHECK-NEXT:   br label %bb11
;
; CHECK: bb11:                                             ; preds = %bb41, %bb
; CHECK-NEXT:   %i12 = phi i32 [ %i8, %bb ], [ %i44, %bb41 ]
; CHECK-NEXT:   %i13 = phi i32 [ %i5, %bb ], [ %i42, %bb41 ]
; CHECK-NEXT:   %i14 = zext i32 %i13 to i64
; CHECK-NEXT:   %i15 = zext i32 %i12 to i64
; CHECK-NEXT:   %i16 = inttoptr i64 %i14 to ptr
; CHECK-NEXT:   %i17 = inttoptr i64 %i15 to ptr
; CHECK-NEXT:   %i19 = icmp eq i32 %i18, 0
; CHECK-NEXT:   %i20 = ptrtoint ptr %i16 to i64
; CHECK-NEXT:   %i21 = ptrtoint ptr %i17 to i64
; CHECK-NEXT:   %i22 = trunc i64 %i20 to i32
; CHECK-NEXT:   %i24 = add nsw i32 %i23, %i22
; CHECK-NEXT:   %i26 = sext i32 %i24 to i64
; CHECK-NEXT:   %i27 = icmp ugt i64 %i26, %i21
; CHECK-NEXT:   br i1 %i27, label %bb41, label %bb28
;
; CHECK: bb28:                                             ; preds = %bb11
; CHECK-NEXT:   %i29 = bitcast i64 %arg2 to double
; CHECK-NEXT:   %0 = getelementptr inbounds %struct.KernelLaunchEnvironmentTy.0, ptr %arg, i32 0, i32 3
; CHECK-NEXT:   %1 = load ptr, ptr %0
; CHECK-NEXT:   %contcount.ptr = getelementptr inbounds i32, ptr %1, i32 0
; CHECK-NEXT:   %cacheidx = atomicrmw add ptr %contcount.ptr, i32 1 acquire
; CHECK-NEXT:   %2 = getelementptr inbounds %struct.KernelLaunchEnvironmentTy.0, ptr %arg, i32 0, i32 4
; CHECK-NEXT:   %3 = load ptr, ptr %2
; CHECK-NEXT:   %4 = getelementptr inbounds ptr, ptr %3, i32 0
; CHECK-NEXT:   %cache.out.ptr = load ptr, ptr %4
; CHECK-NEXT:   %i18.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-NEXT:   %5 = getelementptr inbounds %cache_cell, ptr %i18.cacheidx, i32 0, i32 0
; CHECK-NEXT:   store i32 %i18, ptr %5
; CHECK-NEXT:   %i.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-NEXT:   %6 = getelementptr inbounds %cache_cell, ptr %i.cacheidx, i32 0, i32 1
; CHECK-NEXT:   store i32 %i, ptr %6
; CHECK-NEXT:   %i23.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-NEXT:   %7 = getelementptr inbounds %cache_cell, ptr %i23.cacheidx, i32 0, i32 2
; CHECK-NEXT:   store i32 %i23, ptr %7
; CHECK-NEXT:   %i4.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-NEXT:   %8 = getelementptr inbounds %cache_cell, ptr %i4.cacheidx, i32 0, i32 3
; CHECK-NEXT:   store i32 %i4, ptr %8
; CHECK-NEXT:   %i13.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-NEXT:   %9 = getelementptr inbounds %cache_cell, ptr %i13.cacheidx, i32 0, i32 4
; CHECK-NEXT:   store i32 %i13, ptr %9
; CHECK-NEXT:   %i12.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-NEXT:   %10 = getelementptr inbounds %cache_cell, ptr %i12.cacheidx, i32 0, i32 5
; CHECK-NEXT:   store i32 %i12, ptr %10
; CHECK-NEXT:   %i32.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-NEXT:   %11 = getelementptr inbounds %cache_cell, ptr %i32.cacheidx, i32 0, i32 6
; CHECK-NEXT:   store i32 %i24, ptr %11
; CHECK-NEXT:   %i25.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-NEXT:   %12 = getelementptr inbounds %cache_cell, ptr %i25.cacheidx, i32 0, i32 7
; CHECK-NEXT:   store i32 %i25, ptr %12
; CHECK-NEXT:   %i31.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-NEXT:   %13 = getelementptr inbounds %cache_cell, ptr %i31.cacheidx, i32 0, i32 8
; CHECK-NEXT:   store i64 %i26, ptr %13
; CHECK-NEXT:   call void asm sideeffect "exit;", ""()
; CHECK-NEXT:   unreachable
;
; CHECK: bb41:                                             ; preds = %bb11
; CHECK-NEXT:   tail call void @llvm.nvvm.barrier0()
; CHECK-NEXT:   %i42 = add nsw i32 %i13, %i7
; CHECK-NEXT:   %i43 = add nsw i32 %i12, %i7
; CHECK-NEXT:   %i44 = tail call i32 @llvm.smin.i32(i32 %i43, i32 1023)
; CHECK-NEXT:   %i45 = icmp slt i32 %i42, 1024
; CHECK-NEXT:   br i1 %i45, label %bb11, label %bb46
;
; CHECK: bb46:                                             ; preds = %bb41, %entry
; CHECK-NEXT:   ret void
; CHECK-NEXT: }
;
; CHECK: define weak_odr protected void @__omp_offloading_daxpy_contd_0(ptr noalias noundef %arg, ptr noundef %arg1, i64 noundef %arg2, ptr noundef %arg3)
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
; CHECK: bb11:                                             ; preds = %bb41
; CHECK-NEXT:   %i14 = zext i32 %i42 to i64
; CHECK-NEXT:   %i15 = zext i32 %i44 to i64
; CHECK-NEXT:   %i16 = inttoptr i64 %i14 to ptr
; CHECK-NEXT:   %i17 = inttoptr i64 %i15 to ptr
; CHECK-NEXT:   %i19 = icmp eq i32 %25, 0
; CHECK-NEXT:   %i20 = ptrtoint ptr %i16 to i64
; CHECK-NEXT:   %i21 = ptrtoint ptr %i17 to i64
; CHECK-NEXT:   %i22 = trunc i64 %i20 to i32
; CHECK-NEXT:   %i24 = add nsw i32 %29, %i22
; CHECK-NEXT:   %i26 = sext i32 %i24 to i64
; CHECK-NEXT:   %i27 = icmp ugt i64 %i26, %i21
; CHECK-NEXT:   br i1 %i27, label %bb41, label %bb28
;
; CHECK: bb28:                                             ; preds = %bb11
; CHECK-NEXT:   %i29 = bitcast i64 %arg2 to double
; CHECK-NEXT:   br label %CacheStore
;
; CHECK: bb41:                                             ; preds = %CacheRemat, %bb11
; CHECK-NEXT:   %i29.2321 = phi i1 [ %55, %CacheRemat ], [ true, %bb11 ]
; CHECK-NEXT:   %i29.2320 = phi i64 [ %54, %CacheRemat ], [ %i21, %bb11 ]
; CHECK-NEXT:   %i29.2319 = phi ptr [ %53, %CacheRemat ], [ %i17, %bb11 ]
; CHECK-NEXT:   %i29.2318 = phi i64 [ %52, %CacheRemat ], [ %i15, %bb11 ]
; CHECK-NEXT:   %i29.2317 = phi i64 [ %51, %CacheRemat ], [ %i26, %bb11 ]
; CHECK-NEXT:   %i29.2316 = phi i32 [ %50, %CacheRemat ], [ %i24, %bb11 ]
; CHECK-NEXT:   %i29.2315 = phi i32 [ %49, %CacheRemat ], [ %i22, %bb11 ]
; CHECK-NEXT:   %i29.2314 = phi i64 [ %48, %CacheRemat ], [ %i20, %bb11 ]
; CHECK-NEXT:   %i29.2313 = phi ptr [ %47, %CacheRemat ], [ %i16, %bb11 ]
; CHECK-NEXT:   %i29.23 = phi i64 [ %46, %CacheRemat ], [ %i14, %bb11 ]
; CHECK-NEXT:   %i31.811 = phi i32 [ %35, %CacheRemat ], [ %i44, %bb11 ]
; CHECK-NEXT:   %i31.8 = phi i32 [ %33, %CacheRemat ], [ %i42, %bb11 ]
; CHECK-NEXT:   tail call void @llvm.nvvm.barrier0()
; CHECK-NEXT:   %i42 = add nsw i32 %i31.8, %45
; CHECK-NEXT:   %i43 = add nsw i32 %i31.811, %45
; CHECK-NEXT:   %i44 = tail call i32 @llvm.smin.i32(i32 %i43, i32 1023)
; CHECK-NEXT:   %i45 = icmp slt i32 %i42, 1024
; CHECK-NEXT:   br i1 %i45, label %bb11, label %bb46
;
; CHECK: bb46:                                             ; preds = %bb41
; CHECK-NEXT:   ret void
;
; CHECK: CacheStore:                                       ; preds = %bb28, %CacheRemat
; CHECK-NEXT:   %i31.812 = phi i32 [ %35, %CacheRemat ], [ %i44, %bb28 ]
; CHECK-NEXT:   %i31.810 = phi i32 [ %33, %CacheRemat ], [ %i42, %bb28 ]
; CHECK-NEXT:   %i31 = phi i64 [ %i26, %bb28 ], [ %i39, %CacheRemat ]
; CHECK-NEXT:   %i32 = phi i32 [ %i24, %bb28 ], [ %i38, %CacheRemat ]
; CHECK-NEXT:   %7 = getelementptr inbounds %struct.KernelLaunchEnvironmentTy.0, ptr %arg, i32 0, i32 3
; CHECK-NEXT:   %8 = load ptr, ptr %7
; CHECK-NEXT:   %contcount.ptr = getelementptr inbounds i32, ptr %8, i32 0
; CHECK-NEXT:   %cacheidx = atomicrmw add ptr %contcount.ptr, i32 1 acquire
; CHECK-NEXT:   %9 = getelementptr inbounds %struct.KernelLaunchEnvironmentTy.0, ptr %arg, i32 0, i32 4
; CHECK-NEXT:   %10 = load ptr, ptr %9
; CHECK-NEXT:   %11 = getelementptr inbounds ptr, ptr %10, i32 0
; CHECK-NEXT:   %cache.out.ptr = load ptr, ptr %11
; CHECK-NEXT:   %i18.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-NEXT:   %12 = getelementptr inbounds %cache_cell, ptr %i18.cacheidx, i32 0, i32 0
; CHECK-NEXT:   store i32 %25, ptr %12
; CHECK-NEXT:   %i.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-NEXT:   %13 = getelementptr inbounds %cache_cell, ptr %i.cacheidx, i32 0, i32 1
; CHECK-NEXT:   store i32 %27, ptr %13
; CHECK-NEXT:   %i23.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-NEXT:   %14 = getelementptr inbounds %cache_cell, ptr %i23.cacheidx, i32 0, i32 2
; CHECK-NEXT:   store i32 %29, ptr %14
; CHECK-NEXT:   %i4.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-NEXT:   %15 = getelementptr inbounds %cache_cell, ptr %i4.cacheidx, i32 0, i32 3
; CHECK-NEXT:   store i32 %31, ptr %15
; CHECK-NEXT:   %i13.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-NEXT:   %16 = getelementptr inbounds %cache_cell, ptr %i13.cacheidx, i32 0, i32 4
; CHECK-NEXT:   store i32 %i31.810, ptr %16
; CHECK-NEXT:   %i12.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-NEXT:   %17 = getelementptr inbounds %cache_cell, ptr %i12.cacheidx, i32 0, i32 5
; CHECK-NEXT:   store i32 %i31.812, ptr %17
; CHECK-NEXT:   %i32.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-NEXT:   %18 = getelementptr inbounds %cache_cell, ptr %i32.cacheidx, i32 0, i32 6
; CHECK-NEXT:   store i32 %i32, ptr %18
; CHECK-NEXT:   %i25.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-NEXT:   %19 = getelementptr inbounds %cache_cell, ptr %i25.cacheidx, i32 0, i32 7
; CHECK-NEXT:   store i32 %39, ptr %19
; CHECK-NEXT:   %i31.cacheidx = getelementptr inbounds %cache_cell, ptr %cache.out.ptr, i32 %cacheidx
; CHECK-NEXT:   %20 = getelementptr inbounds %cache_cell, ptr %i31.cacheidx, i32 0, i32 8
; CHECK-NEXT:   store i64 %i31, ptr %20
; CHECK-NEXT:   br label %ThreadExit
;
; CHECK: ThreadExit:                                       ; preds = %entry, %CacheStore
; CHECK-NEXT:   call void asm sideeffect "exit;", ""()
; CHECK-NEXT:   unreachable
;
; CHECK: CacheRemat:                                       ; preds = %entry
; CHECK-NEXT:   %21 = getelementptr inbounds %struct.KernelLaunchEnvironmentTy.0, ptr %arg, i32 0, i32 4
; CHECK-NEXT:   %22 = load ptr, ptr %21
; CHECK-NEXT:   %23 = getelementptr inbounds ptr, ptr %22, i32 1
; CHECK-NEXT:   %cache.in.ptr = load ptr, ptr %23
; CHECK-NEXT:   %i18.cacheidx1 = getelementptr inbounds %cache_cell, ptr %cache.in.ptr, i32 %gtid
; CHECK-NEXT:   %24 = getelementptr inbounds %cache_cell, ptr %i18.cacheidx1, i32 0, i32 0
; CHECK-NEXT:   %25 = load i32, ptr %24
; CHECK-NEXT:   %i.cacheidx2 = getelementptr inbounds %cache_cell, ptr %cache.in.ptr, i32 %gtid
; CHECK-NEXT:   %26 = getelementptr inbounds %cache_cell, ptr %i.cacheidx2, i32 0, i32 1
; CHECK-NEXT:   %27 = load i32, ptr %26
; CHECK-NEXT:   %i23.cacheidx3 = getelementptr inbounds %cache_cell, ptr %cache.in.ptr, i32 %gtid
; CHECK-NEXT:   %28 = getelementptr inbounds %cache_cell, ptr %i23.cacheidx3, i32 0, i32 2
; CHECK-NEXT:   %29 = load i32, ptr %28
; CHECK-NEXT:   %i4.cacheidx4 = getelementptr inbounds %cache_cell, ptr %cache.in.ptr, i32 %gtid
; CHECK-NEXT:   %30 = getelementptr inbounds %cache_cell, ptr %i4.cacheidx4, i32 0, i32 3
; CHECK-NEXT:   %31 = load i32, ptr %30
; CHECK-NEXT:   %i13.cacheidx5 = getelementptr inbounds %cache_cell, ptr %cache.in.ptr, i32 %gtid
; CHECK-NEXT:   %32 = getelementptr inbounds %cache_cell, ptr %i13.cacheidx5, i32 0, i32 4
; CHECK-NEXT:   %33 = load i32, ptr %32
; CHECK-NEXT:   %i12.cacheidx6 = getelementptr inbounds %cache_cell, ptr %cache.in.ptr, i32 %gtid
; CHECK-NEXT:   %34 = getelementptr inbounds %cache_cell, ptr %i12.cacheidx6, i32 0, i32 5
; CHECK-NEXT:   %35 = load i32, ptr %34
; CHECK-NEXT:   %i32.cacheidx7 = getelementptr inbounds %cache_cell, ptr %cache.in.ptr, i32 %gtid
; CHECK-NEXT:   %36 = getelementptr inbounds %cache_cell, ptr %i32.cacheidx7, i32 0, i32 6
; CHECK-NEXT:   %37 = load i32, ptr %36
; CHECK-NEXT:   %i25.cacheidx8 = getelementptr inbounds %cache_cell, ptr %cache.in.ptr, i32 %gtid
; CHECK-NEXT:   %38 = getelementptr inbounds %cache_cell, ptr %i25.cacheidx8, i32 0, i32 7
; CHECK-NEXT:   %39 = load i32, ptr %38
; CHECK-NEXT:   %i31.cacheidx9 = getelementptr inbounds %cache_cell, ptr %cache.in.ptr, i32 %gtid
; CHECK-NEXT:   %40 = getelementptr inbounds %cache_cell, ptr %i31.cacheidx9, i32 0, i32 8
; CHECK-NEXT:   %41 = load i64, ptr %40
; CHECK-NEXT:   %42 = shl nsw i32 %27, 10
; CHECK-NEXT:   %43 = or disjoint i32 %42, 1023
; CHECK-NEXT:   %44 = tail call i32 @llvm.smin.i32(i32 %43, i32 1023)
; CHECK-NEXT:   %45 = shl nsw i32 %31, 10
; CHECK-NEXT:   %46 = zext i32 %33 to i64
; CHECK-NEXT:   %47 = inttoptr i64 %46 to ptr
; CHECK-NEXT:   %48 = ptrtoint ptr %47 to i64
; CHECK-NEXT:   %49 = trunc i64 %48 to i32
; CHECK-NEXT:   %50 = add nsw i32 %29, %49
; CHECK-NEXT:   %51 = sext i32 %50 to i64
; CHECK-NEXT:   %52 = zext i32 %35 to i64
; CHECK-NEXT:   %53 = inttoptr i64 %52 to ptr
; CHECK-NEXT:   %54 = ptrtoint ptr %53 to i64
; CHECK-NEXT:   %55 = icmp ugt i64 %51, %54
; CHECK-NEXT:   %56 = bitcast i64 %arg2 to double
; CHECK-NEXT:   %i33 = getelementptr inbounds double, ptr %arg3, i64 %41
; CHECK-NEXT:   %i34 = load double, ptr %i33
; CHECK-NEXT:   %i35 = getelementptr inbounds double, ptr %arg1, i64 %41
; CHECK-NEXT:   %i36 = load double, ptr %i35
; CHECK-NEXT:   %i37 = tail call double @llvm.fmuladd.f64(double %56, double %i34, double %i36)
; CHECK-NEXT:   store double %i37, ptr %i35
; CHECK-NEXT:   %i38 = add nsw i32 %39, %37
; CHECK-NEXT:   %i39 = sext i32 %i38 to i64
; CHECK-NEXT:   %i40 = icmp ugt i64 %i39, %54
; CHECK-NEXT:   br i1 %i40, label %bb41, label %CacheStore
; CHECK-NEXT: }
