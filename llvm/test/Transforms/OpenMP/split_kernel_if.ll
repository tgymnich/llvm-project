; RUN: opt < %s -S -passes="openmp-opt-postlink,simplifycfg" | FileCheck %s

target triple = "nvptx64"

declare void @__ompx_split()

define void @test(ptr noundef %tid_addr, ptr noundef %ptr) "kernel" "omp_target_thread_limit"="32" "omp_target_num_teams"="1" {
  entry:
    %tid = load i64, ptr %tid_addr
    %arrayidx = getelementptr inbounds double, ptr %ptr, i64 %tid
    %cmp = icmp ult i64 0, %tid
    br i1 %cmp, label %if, label %end
  if:
    call void @__ompx_split()
    %val1 = load double, ptr %arrayidx
    %add = fadd double %val1, 2.0
    store double %add, ptr %arrayidx
    br label %end
  end:
    %val2 = load double, ptr %arrayidx
    %mul = fmul double %val2, %val2
    store double %mul, ptr %arrayidx
    ret void
}

!llvm.module.flags = !{!3, !4}

!3 = !{i32 7, !"openmp", i32 51}
!4 = !{i32 7, !"openmp-device", i32 51}


; CHECK: define void @test(ptr noundef %tid_addr, ptr noundef %ptr)
; CHECK-NEXT: entry:
; CHECK-NEXT:   %tid = load i64, ptr %tid_addr
; CHECK-NEXT:   %arrayidx = getelementptr inbounds double, ptr %ptr, i64 %tid
; CHECK-NEXT:   %cmp = icmp ult i64 0, %tid
; CHECK-NEXT:   br i1 %cmp, label %if, label %end
;
; CHECK: if:                                               ; preds = %entry
; CHECK-NEXT:   %cacheidx = atomicrmw add ptr @test_cont_count, i64 1 acquire
; CHECK-NEXT:   %0 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
; CHECK-NEXT:   %tidmapidx = getelementptr i32, ptr @test_tid_map, i64 %cacheidx
; CHECK-NEXT:   store i32 %0, ptr %tidmapidx, align 4
; CHECK-NEXT:   %arrayidx.cacheidx = getelementptr [32 x %cache_cell], ptr @test_cont_cache, i64 %cacheidx, i64 0
; CHECK-NEXT:   store ptr %arrayidx, ptr %arrayidx.cacheidx
; CHECK-NEXT:   call void asm sideeffect "exit;", ""()
; CHECK-NEXT:   unreachable
;
; CHECK: end:                                              ; preds = %entry
; CHECK-NEXT:   %val2 = load double, ptr %arrayidx
; CHECK-NEXT:   %mul = fmul double %val2, %val2
; CHECK-NEXT:   store double %mul, ptr %arrayidx
; CHECK-NEXT:   ret void
; CHECK-NEXT: }
;
; CHECK: define void @test_contd(ptr noundef %tid_addr, ptr noundef %ptr)
; CHECK-NEXT: entry:
; CHECK-NEXT:   %0 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
; CHECK-NEXT:   %tidmapidx = getelementptr i32, ptr @test_tid_map, i32 %0
; CHECK-NEXT:   %.mapped = load i32, ptr %tidmapidx
; CHECK-NEXT:   %1 = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
; CHECK-NEXT:   %2 = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
; CHECK-NEXT:   %3 = mul i32 %1, %2
; CHECK-NEXT:   %gtid = add i32 %.mapped, %3
; CHECK-NEXT:   %tid = load i64, ptr %tid_addr
; CHECK-NEXT:   %arrayidx.cacheidx = getelementptr [32 x %cache_cell], ptr @test_cont_cache, i32 %gtid, i64 0
; CHECK-NEXT:   %4 = load ptr, ptr %arrayidx.cacheidx
; CHECK-NEXT:   %cmp = icmp ult i64 0, %tid
; CHECK-NEXT:   br i1 %cmp, label %if, label %end
;
; CHECK: if:                                               ; preds = %entry
; CHECK-NEXT:   %val1 = load double, ptr %4
; CHECK-NEXT:   %add = fadd double %val1, 2.000000e+00
; CHECK-NEXT:   store double %add, ptr %4
; CHECK-NEXT:   br label %end
;
; CHECK: end:                                              ; preds = %if, %entry
; CHECK-NEXT:   %val2 = load double, ptr %4
; CHECK-NEXT:   %mul = fmul double %val2, %val2
; CHECK-NEXT:   store double %mul, ptr %4
; CHECK-NEXT:   ret void
; CHECK-NEXT: }