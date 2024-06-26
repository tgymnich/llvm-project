; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py
; RUN: llc -verify-machineinstrs -mtriple=powerpc64le-unknown-linux-gnu \
; RUN:     -ppc-asm-full-reg-names -mcpu=pwr8 < %s | FileCheck %s

%struct.m.2.5.8.11 = type { %struct.l.0.3.6.9, [7 x i8], %struct.a.1.4.7.10 }
%struct.l.0.3.6.9 = type { i8 }
%struct.a.1.4.7.10 = type { [27 x i8], [0 x i32], [4 x i8] }

define void @_ZN1m1nEv(ptr %this) local_unnamed_addr nounwind align 2 {
; CHECK-LABEL: _ZN1m1nEv:
; CHECK:       # %bb.0: # %entry
; CHECK-NEXT:    mflr r0
; CHECK-NEXT:    std r30, -16(r1) # 8-byte Folded Spill
; CHECK-NEXT:    stdu r1, -48(r1)
; CHECK-NEXT:    mr r30, r3
; CHECK-NEXT:    std r0, 64(r1)
; CHECK-NEXT:    lwz r3, 8(r3)
; CHECK-NEXT:    lwz r4, 36(r30)
; CHECK-NEXT:    rlwinm r3, r3, 27, 0, 0
; CHECK-NEXT:    clrlwi r4, r4, 31
; CHECK-NEXT:    rlwimi r4, r3, 0, 0, 0
; CHECK-NEXT:    bl _ZN1llsE1d
; CHECK-NEXT:    nop
; CHECK-NEXT:    ld r3, 8(r30)
; CHECK-NEXT:    rlwinm r4, r3, 27, 0, 0
; CHECK-NEXT:    bl _ZN1llsE1d
; CHECK-NEXT:    nop
; CHECK-NEXT:    addi r1, r1, 48
; CHECK-NEXT:    ld r0, 16(r1)
; CHECK-NEXT:    ld r30, -16(r1) # 8-byte Folded Reload
; CHECK-NEXT:    mtlr r0
; CHECK-NEXT:    blr
entry:
  %bc = getelementptr inbounds %struct.m.2.5.8.11, ptr %this, i64 0, i32 2
  %bf.load = load i216, ptr %bc, align 8
  %bf.lshr = lshr i216 %bf.load, 4
  %shl.i23 = shl i216 %bf.lshr, 31
  %shl.i = trunc i216 %shl.i23 to i32
  %arrayidx = getelementptr inbounds %struct.m.2.5.8.11, ptr %this, i64 0, i32 2, i32 1, i64 0
  %0 = load i32, ptr %arrayidx, align 4
  %and.i = and i32 %0, 1
  %or.i = or i32 %and.i, %shl.i
  tail call void @_ZN1llsE1d(ptr undef, i32 %or.i) #1
  %bf.load10 = load i216, ptr %bc, align 8
  %bf.lshr11 = lshr i216 %bf.load10, 4
  %shl.i1524 = shl i216 %bf.lshr11, 31
  %shl.i15 = trunc i216 %shl.i1524 to i32
  tail call void @_ZN1llsE1d(ptr undef, i32 %shl.i15) #1
  ret void
}
declare void @_ZN1llsE1d(ptr, i32) local_unnamed_addr #0
