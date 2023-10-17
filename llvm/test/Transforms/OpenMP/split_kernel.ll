; REQUIRES: x86-registered-target
; RUN: llvm-as %s -o %t.bc
; RUN: llvm-lto2 run %t.bc -o %t.o -r=%t.bc,test,px -opt-pipeline="openmp-opt-cgscc" --select-save-temps="opt"
; RUN: llvm-dis %t.o.4.opt.bc -o - | FileCheck %s

target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

define void @test(ptr noundef %tid_addr, ptr noundef %ptr) "kernel" {
; CHECK-LABEL: define {{[^@]+}}@__omp_offloading_2b_10393b5_spmd_l12
; CHECK-SAME: () #[[ATTR0:[0-9]+]] {
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[TMP0:%.*]] = call i32 @__kmpc_target_init(ptr @[[GLOB1]], i8 2, i1 false)
; CHECK-NEXT:    [[EXEC_USER_CODE:%.*]] = icmp eq i32 [[TMP0]], -1
; CHECK-NEXT:    br i1 [[EXEC_USER_CODE]], label [[USER_CODE_ENTRY:%.*]], label [[WORKER_EXIT:%.*]]
; CHECK:       user_code.entry:
; CHECK-NEXT:    call void @spmd_helper() #[[ATTR7:[0-9]+]]
; CHECK-NEXT:    call void @__kmpc_target_deinit(ptr @[[GLOB1]], i8 2)
; CHECK-NEXT:    ret void
; CHECK:       worker.exit:
; CHECK-NEXT:    ret void
;
  entry:
    %tid = load i64, ptr %tid_addr
    %arrayidx = getelementptr inbounds double, ptr %ptr, i64 %tid
    %cmp = icmp ult i64 0, %tid
    br i1 %cmp, label %if, label %end
  if:
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



///

; ModuleID = '/home/tgymnich/foo.o.o.0.4.opt.bc'
source_filename = "ld-temp.o"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

define void @test(ptr noundef %tid_addr, ptr noundef %ptr) #0 {
entry:
  %tid = load i64, ptr %tid_addr, align 8
  %arrayidx = getelementptr inbounds double, ptr %ptr, i64 %tid
  %cmp = icmp ult i64 0, %tid
  br i1 %cmp, label %if, label %end

if:                                               ; preds = %entry
  %val1 = load double, ptr %arrayidx, align 8
  %add = fadd double %val1, 2.000000e+00
  store double %add, ptr %arrayidx, align 8
  br label %end

end:                                              ; preds = %if, %entry
  %val2 = load double, ptr %arrayidx, align 8
  %mul = fmul double %val2, %val2
  store double %mul, ptr %arrayidx, align 8
  ret void
}

attributes #0 = { "kernel" }

!llvm.module.flags = !{!0, !1}

!0 = !{i32 7, !"openmp", i32 51}
!1 = !{i32 7, !"openmp-device", i32 51}
