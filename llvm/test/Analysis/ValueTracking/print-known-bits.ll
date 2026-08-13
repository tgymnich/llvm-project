; RUN: opt -disable-output -passes="print<known-bits>" < %s 2>&1 | FileCheck %s

; CHECK-LABEL: name: @masks
; CHECK-NEXT:   i8 %a KnownBits:???????? SignBits:1 IsKnownNeverZero:0
; CHECK-NEXT:   %and = and i8 %a, 3 KnownBits:000000?? SignBits:6 IsKnownNeverZero:0
; CHECK-NEXT:   %or = or i8 %and, 16 KnownBits:000100?? SignBits:3 IsKnownNeverZero:1
; CHECK-NEXT:   %shl = shl i8 %or, 2 KnownBits:0100??00 SignBits:1 IsKnownNeverZero:1
define i8 @masks(i8 %a) {
  %and = and i8 %a, 3
  %or = or i8 %and, 16
  %shl = shl i8 %or, 2
  ret i8 %shl
}

; The known bits of an instruction are computed with the instruction itself as
; the context, so assumes and dominating conditions apply.

; CHECK-LABEL: name: @from_assume
; CHECK-NEXT:   i32 %a KnownBits:???????????????????????????????? SignBits:1 IsKnownNeverZero:0
; CHECK-NEXT:   %cmp = icmp ult i32 %a, 16 KnownBits:? SignBits:1 IsKnownNeverZero:0
; CHECK-NEXT:   %add = add i32 %a, 0 KnownBits:0000000000000000000000000000???? SignBits:27 IsKnownNeverZero:0
define i32 @from_assume(i32 %a) {
  %cmp = icmp ult i32 %a, 16
  call void @llvm.assume(i1 %cmp)
  %add = add i32 %a, 0
  ret i32 %add
}

; CHECK-LABEL: name: @from_dominating_condition
; CHECK-NEXT:   i32 %a KnownBits:???????????????????????????????? SignBits:1 IsKnownNeverZero:0
; CHECK-NEXT:   %cmp = icmp ult i32 %a, 4 KnownBits:? SignBits:1 IsKnownNeverZero:0
; CHECK-NEXT:   %add = add i32 %a, 0 KnownBits:000000000000000000000000000000?? SignBits:29 IsKnownNeverZero:0
define i32 @from_dominating_condition(i32 %a) {
entry:
  %cmp = icmp ult i32 %a, 4
  br i1 %cmp, label %if, label %else

if:
  %add = add i32 %a, 0
  ret i32 %add

else:
  ret i32 0
}

; Vector elements are merged into a single per-element result.

; CHECK-LABEL: name: @vectors
; CHECK-NEXT:   <2 x i8> %a KnownBits:???????? SignBits:1 IsKnownNeverZero:0
; CHECK-NEXT:   %and = and <2 x i8> %a, splat (i8 12) KnownBits:0000??00 SignBits:4 IsKnownNeverZero:0
define <2 x i8> @vectors(<2 x i8> %a) {
  %and = and <2 x i8> %a, splat (i8 12)
  ret <2 x i8> %and
}

; CHECK-LABEL: name: @range_attribute
; CHECK-NEXT:   i8 %a KnownBits:000000?? SignBits:6 IsKnownNeverZero:0
; CHECK-NEXT:   %add = add i8 %a, 0 KnownBits:000000?? SignBits:5 IsKnownNeverZero:0
define i8 @range_attribute(i8 range(i8 0, 4) %a) {
  %add = add i8 %a, 0
  ret i8 %add
}
