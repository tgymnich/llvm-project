; RUN: opt -S < %s -passes=globalopt | FileCheck %s

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

@_ZL1x = internal global ptr null, align 8, !dbg !0

define i32 @main(i32 %argc, ptr %argv) norecurse !dbg !18 {
; CHECK: define i32 @main
; Make sure we localized the global.
; CHECK: alloca ptr
; Make sure the metadata is sane. Currently, we just drop the metadata,
; so it points to nothing.
; CHECK: #dbg_value(ptr poison,
; CHECK: !2 = !{}
entry:
  call void @llvm.dbg.value(metadata i32 %argc, metadata !22, metadata !23), !dbg !24
  call void @llvm.dbg.value(metadata ptr %argv, metadata !25, metadata !23), !dbg !26
  %0 = load ptr, ptr %argv, align 8, !dbg !27
  store ptr %0, ptr @_ZL1x, align 8, !dbg !29
  call void @llvm.dbg.value(metadata ptr @_ZL1x, metadata !30, metadata !23), !dbg !31
  %1 = load ptr, ptr @_ZL1x, align 8, !dbg !32
  %2 = load i8, ptr %1, align 1, !dbg !33
  %conv = sext i8 %2 to i32, !dbg !33
  ret i32 %conv, !dbg !34
}

declare void @llvm.dbg.value(metadata, metadata, metadata)

!llvm.dbg.cu = !{!2}
!llvm.module.flags = !{!15, !16}
!llvm.ident = !{!17}

!0 = !DIGlobalVariableExpression(var: !1, expr: !DIExpression())
!1 = distinct !DIGlobalVariable(name: "x", linkageName: "_ZL1x", scope: !2, file: !14, line: 1, type: !6, isLocal: true, isDefinition: true)
!2 = distinct !DICompileUnit(language: DW_LANG_C_plus_plus, file: !3, producer: "clang", isOptimized: false, runtimeVersion: 0, emissionKind: FullDebug, enums: !4, retainedTypes: !5, globals: !13)
!3 = !DIFile(filename: "-", directory: "/")
!4 = !{}
!5 = !{!6, !11}
!6 = !DIDerivedType(tag: DW_TAG_pointer_type, baseType: !7, size: 64)
!7 = !DICompositeType(tag: DW_TAG_array_type, baseType: !8, size: 1600, elements: !9)
!8 = !DIBasicType(name: "char", size: 8, encoding: DW_ATE_signed_char)
!9 = !{!10}
!10 = !DISubrange(count: 200)
!11 = !DIDerivedType(tag: DW_TAG_pointer_type, baseType: !12, size: 64)
!12 = !DIDerivedType(tag: DW_TAG_pointer_type, baseType: !8, size: 64)
!13 = !{!0}
!14 = !DIFile(filename: "<stdin>", directory: "/")
!15 = !{i32 2, !"Dwarf Version", i32 4}
!16 = !{i32 2, !"Debug Info Version", i32 3}
!17 = !{!"clang"}
!18 = distinct !DISubprogram(name: "main", scope: !14, file: !14, line: 2, type: !19, isLocal: false, isDefinition: true, scopeLine: 2, flags: DIFlagPrototyped, isOptimized: false, unit: !2, retainedNodes: !4)
!19 = !DISubroutineType(types: !20)
!20 = !{!21, !21, !11}
!21 = !DIBasicType(name: "int", size: 32, encoding: DW_ATE_signed)
!22 = !DILocalVariable(name: "argc", arg: 1, scope: !18, file: !14, line: 2, type: !21)
!23 = !DIExpression()
!24 = !DILocation(line: 2, column: 14, scope: !18)
!25 = !DILocalVariable(name: "argv", arg: 2, scope: !18, file: !14, line: 2, type: !11)
!26 = !DILocation(line: 2, column: 26, scope: !18)
!27 = !DILocation(line: 2, column: 52, scope: !18)
!28 = !DILocation(line: 2, column: 38, scope: !18)
!29 = !DILocation(line: 2, column: 36, scope: !18)
!30 = !DILocalVariable(name: "y", scope: !18, file: !14, line: 2, type: !11)
!31 = !DILocation(line: 2, column: 68, scope: !18)
!32 = !DILocation(line: 2, column: 92, scope: !18)
!33 = !DILocation(line: 2, column: 91, scope: !18)
!34 = !DILocation(line: 2, column: 84, scope: !18)
