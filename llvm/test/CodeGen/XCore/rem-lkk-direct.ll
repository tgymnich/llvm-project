; RUN: llc -mtriple=xcore < %s | FileCheck %s

define i16 @urem_i16(i16 %x) {
; CHECK-LABEL: urem_i16:
; CHECK:       # %bb.0:
; CHECK-NEXT:    zext r0, 16
; CHECK-NEXT:    ldw r1, cp[.LCPI0_0]
; CHECK-NEXT:    mul r0, r0, r1
; CHECK-NEXT:    ldc r1, 0
; CHECK-NEXT:    ldc r2, 95
; CHECK-NEXT:    lmul r0, r1, r0, r2, r1, r1
; CHECK-NEXT:    retsp 0
  %r = urem i16 %x, 95
  ret i16 %r
}

define i16 @srem_i16(i16 %x) {
; CHECK-LABEL: srem_i16:
; CHECK:       # %bb.0:
; CHECK-NEXT:    sext r0, 16
; CHECK-NEXT:    ldw r1, cp[.LCPI1_0]
; CHECK-NEXT:    mul r1, r0, r1
; CHECK-NEXT:    ldc r2, 0
; CHECK-NEXT:    ldc r3, 95
; CHECK-NEXT:    lmul r1, r2, r1, r3, r2, r2
; CHECK-NEXT:    mkmsk r2, 4
; CHECK-NEXT:    shr r0, r0, r2
; CHECK-NEXT:    ldc r2, 94
; CHECK-NEXT:    and r0, r0, r2
; CHECK-NEXT:    sub r0, r1, r0
; CHECK-NEXT:    retsp 0
  %r = srem i16 %x, -95
  ret i16 %r
}
define i8 @urem_i8(i8 %x) {
; CHECK-LABEL: urem_i8:
; CHECK:       # %bb.0:
; CHECK-NEXT:    zext r0, 8
; CHECK-NEXT:    ldc r1, 293
; CHECK-NEXT:    mul r0, r0, r1
; CHECK-NEXT:    ldc r1, 2047
; CHECK-NEXT:    and r0, r0, r1
; CHECK-NEXT:    mkmsk r1, 3
; CHECK-NEXT:    mul r0, r0, r1
; CHECK-NEXT:    ldc r1, 11
; CHECK-NEXT:    shr r0, r0, r1
; CHECK-NEXT:    retsp 0
  %r = urem i8 %x, 7
  ret i8 %r
}

define i8 @srem_i8(i8 %x) {
; CHECK-LABEL: srem_i8:
; CHECK:       # %bb.0:
; CHECK-NEXT:    sext r0, 8
; CHECK-NEXT:    shr r1, r0, 7
; CHECK-NEXT:    ldc r2, 6
; CHECK-NEXT:    and r1, r1, r2
; CHECK-NEXT:    ldc r2, 147
; CHECK-NEXT:    mul r0, r0, r2
; CHECK-NEXT:    ldc r2, 1023
; CHECK-NEXT:    and r0, r0, r2
; CHECK-NEXT:    mkmsk r2, 3
; CHECK-NEXT:    mul r0, r0, r2
; CHECK-NEXT:    ldc r2, 10
; CHECK-NEXT:    shr r0, r0, r2
; CHECK-NEXT:    sub r0, r0, r1
; CHECK-NEXT:    retsp 0
  %r = srem i8 %x, 7
  ret i8 %r
}
