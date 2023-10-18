; RUN: opt < %s -S -passes="openmp-opt-postlink,simplifycfg" | FileCheck %s

declare void @__ompx_split()

define void @test(ptr noundef %tid_addr, ptr noundef %ptr) "kernel" {
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


; CHECK: define void @test_mod(ptr noundef %tid_addr, ptr noundef %ptr)
; CHECK-NEXT: entry:
; CHECK-NEXT:   %tid = load i64, ptr %tid_addr
; CHECK-NEXT:   %arrayidx = getelementptr inbounds double, ptr %ptr, i64 %tid
; CHECK-NEXT:   store ptr %arrayidx, ptr @kernel_continuation_cache
; CHECK-NEXT:   %cmp = icmp ult i64 0, %tid
; CHECK-NEXT:   %0 = xor i1 %cmp, true
; CHECK-NEXT:   call void @llvm.assume(i1 %0)
; CHECK-NEXT:   %val2 = load double, ptr %arrayidx
; CHECK-NEXT:   %mul = fmul double %val2, %val2
; CHECK-NEXT:   store double %mul, ptr %arrayidx
; CHECK-NEXT:   ret void
; CHECK-NEXT: }
;
; CHECK: define void @test_contd(ptr noundef %tid_addr, ptr noundef %ptr)
; CHECK-NEXT: entry:
; CHECK-NEXT:   %tid = load i64, ptr %tid_addr
; CHECK-NEXT:   %0 = load ptr, ptr @kernel_continuation_cache
; CHECK-NEXT:   %cmp = icmp ult i64 0, %tid
; CHECK-NEXT:   br i1 %cmp, label %if, label %end
;
; CHECK: if:                                               ; preds = %entry
; CHECK-NEXT:   %val1 = load double, ptr %0
; CHECK-NEXT:   %add = fadd double %val1, 2.000000e+00
; CHECK-NEXT:   store double %add, ptr %0
; CHECK-NEXT:   br label %end
;
; CHECK: end:                                              ; preds = %if, %entry
; CHECK-NEXT:   %val2 = load double, ptr %0
; CHECK-NEXT:   %mul = fmul double %val2, %val2
; CHECK-NEXT:   store double %mul, ptr %0
; CHECK-NEXT:   ret void
; CHECK-NEXT: }