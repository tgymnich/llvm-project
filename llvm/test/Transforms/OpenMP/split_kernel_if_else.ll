; RUN: opt < %s -S -passes="openmp-opt-postlink,simplifycfg" | FileCheck %s

target triple = "nvptx64"

declare void @__ompx_split()

define void @test(ptr noundef %tid_addr, ptr noundef %ptr) "kernel" {
  entry:
    %tid = load i64, ptr %tid_addr
    %arrayidx = getelementptr inbounds double, ptr %ptr, i64 %tid
    %cmp = icmp ult i64 0, %tid
    br i1 %cmp, label %if, label %else
  if:
    call void @__ompx_split()
    %val1 = load double, ptr %arrayidx
    %add = fadd double %val1, 2.0
    store double %add, ptr %arrayidx
    br label %end
  else:
    %val2 = load double, ptr %arrayidx
    %mul = fmul double %val2, %val2
    store double %mul, ptr %arrayidx
    br label %end
  end:
    ret void
}

!llvm.module.flags = !{!3, !4}

!3 = !{i32 7, !"openmp", i32 51}
!4 = !{i32 7, !"openmp-device", i32 51}


; CHECK: define void @test(ptr noundef %tid_addr, ptr noundef %ptr)
; CHECK-NEXT: entry:
; CHECK-NEXT:   %tid = load i64, ptr %tid_addr
; CHECK-NEXT:   %arrayidx = getelementptr inbounds double, ptr %ptr, i64 %tid
; CHECK-NEXT:   store ptr %arrayidx, ptr @test_continuation_cache
; CHECK-NEXT:   %cmp = icmp ult i64 0, %tid
; CHECK-NEXT:   br i1 %cmp, label %if, label %else
;
; CHECK: if:                                               ; preds = %entry
; CHECK-NEXT:   call void asm sideeffect "exit;", ""()
; CHECK-NEXT:   unreachable
;
; CHECK: else:                                             ; preds = %entry
; CHECK-NEXT:   %val2 = load double, ptr %arrayidx
; CHECK-NEXT:   %mul = fmul double %val2, %val2
; CHECK-NEXT:   store double %mul, ptr %arrayidx
; CHECK-NEXT:   ret void
; CHECK-NEXT: }
; 
; CHECK: define void @test_contd(ptr noundef %tid_addr, ptr noundef %ptr)
; CHECK-NEXT: entry:
; CHECK-NEXT:   %tid = load i64, ptr %tid_addr
; CHECK-NEXT:   %0 = load ptr, ptr @test_continuation_cache
; CHECK-NEXT:   %cmp = icmp ult i64 0, %tid
; CHECK-NEXT:   call void @llvm.assume(i1 %cmp)
; CHECK-NEXT:   %val1 = load double, ptr %0
; CHECK-NEXT:   %add = fadd double %val1, 2.000000e+00
; CHECK-NEXT:   store double %add, ptr %0
; CHECK-NEXT:   ret void
; CHECK-NEXT: }
