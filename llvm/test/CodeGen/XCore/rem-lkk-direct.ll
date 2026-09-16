; RUN: llc -mtriple=xcore < %s | FileCheck %s

define i16 @urem_i16(i16 %x) {
; CHECK-LABEL: urem_i16:
; CHECK:       # %bb.0:
; CHECK-NEXT:    mov r1, r0
; CHECK-NEXT:    zext r1, 16
; CHECK-NEXT:    ldc r2, 44151
; CHECK-NEXT:    mul r1, r1, r2
; CHECK-NEXT:    ldc r2, 22
; CHECK-NEXT:    shr r1, r1, r2
; CHECK-NEXT:    ldc r2, 95
; CHECK-NEXT:    mul r1, r1, r2
; CHECK-NEXT:    sub r0, r0, r1
; CHECK-NEXT:    retsp 0
  %r = urem i16 %x, 95
  ret i16 %r
}

define i16 @srem_i16(i16 %x) {
; CHECK-LABEL: srem_i16:
; CHECK:       # %bb.0:
; CHECK-NEXT:    mov r1, r0
; CHECK-NEXT:    sext r1, 16
; CHECK-NEXT:    ldc r2, 21385
; CHECK-NEXT:    mul r1, r1, r2
; CHECK-NEXT:    shr r1, r1, 16
; CHECK-NEXT:    sub r1, r1, r0
; CHECK-NEXT:    ldc r2, 32768
; CHECK-NEXT:    and r2, r1, r2
; CHECK-NEXT:    mkmsk r3, 4
; CHECK-NEXT:    shr r2, r2, r3
; CHECK-NEXT:    sext r1, 16
; CHECK-NEXT:    ashr r1, r1, 6
; CHECK-NEXT:    add r1, r1, r2
; CHECK-NEXT:    ldw r2, cp[.LCPI1_0]
; CHECK-NEXT:    mul r1, r1, r2
; CHECK-NEXT:    sub r0, r0, r1
; CHECK-NEXT:    retsp 0
  %r = srem i16 %x, -95
  ret i16 %r
}
define i8 @urem_i8(i8 %x) {
; CHECK-LABEL: urem_i8:
; CHECK:       # %bb.0:
; CHECK-NEXT:    mov r1, r0
; CHECK-NEXT:    zext r1, 8
; CHECK-NEXT:    ldc r2, 37
; CHECK-NEXT:    mul r1, r1, r2
; CHECK-NEXT:    shr r1, r1, 8
; CHECK-NEXT:    sub r2, r0, r1
; CHECK-NEXT:    ldc r3, 254
; CHECK-NEXT:    and r2, r2, r3
; CHECK-NEXT:    shr r2, r2, 1
; CHECK-NEXT:    add r1, r2, r1
; CHECK-NEXT:    shr r1, r1, 2
; CHECK-NEXT:    mkmsk r2, 3
; CHECK-NEXT:    mul r1, r1, r2
; CHECK-NEXT:    sub r0, r0, r1
; CHECK-NEXT:    retsp 0
  %r = urem i8 %x, 7
  ret i8 %r
}

define i8 @srem_i8(i8 %x) {
; CHECK-LABEL: srem_i8:
; CHECK:       # %bb.0:
; CHECK-NEXT:    mov r1, r0
; CHECK-NEXT:    sext r1, 8
; CHECK-NEXT:    ldw r2, cp[.LCPI3_0]
; CHECK-NEXT:    mul r1, r1, r2
; CHECK-NEXT:    shr r1, r1, 8
; CHECK-NEXT:    add r1, r1, r0
; CHECK-NEXT:    ldc r2, 128
; CHECK-NEXT:    and r2, r1, r2
; CHECK-NEXT:    shr r2, r2, 7
; CHECK-NEXT:    sext r1, 8
; CHECK-NEXT:    ashr r1, r1, 2
; CHECK-NEXT:    add r1, r1, r2
; CHECK-NEXT:    mkmsk r2, 3
; CHECK-NEXT:    mul r1, r1, r2
; CHECK-NEXT:    sub r0, r0, r1
; CHECK-NEXT:    retsp 0
  %r = srem i8 %x, 7
  ret i8 %r
}
