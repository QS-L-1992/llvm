; REQUIRES: x86-registered-target

; Test that index-only devirtualization handles and ignores any
; type metadata that could not be summarized (because it was internal
; and could not be promoted due to the fact that the module has
; no external symbols and therefore could not be assigned a unique
; identifier). In this case we should simply not get the type
; metadata summary entries, and no promotion will occur.

; Generate unsplit module with summary for ThinLTO index-based WPD.
; RUN: opt -thinlto-bc -thinlto-split-lto-unit=false -o %t2.o %s

; Check that we don't have module flag when splitting not enabled for ThinLTO,
; and that we generate summary information needed for index-based WPD.
; RUN: llvm-dis -o - %t2.o | FileCheck %s --check-prefix=DIS
; DIS-NOT: typeIdInfo
; DIS-NOT: typeidMetadata

; Index based WPD
; RUN: llvm-lto2 run %t2.o -save-temps -opaque-pointers -pass-remarks=. \
; RUN:   -o %t3 \
; RUN:   -r=%t2.o,test,plx \
; RUN:   -r=%t2.o,_ZN1D1mEi,
; RUN: llvm-dis %t3.1.4.opt.bc -o - | FileCheck %s --check-prefix=CHECK-IR

target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-grtev4-linux-gnu"

@llvm.global_ctors = appending global [1 x { i32, ptr, ptr }] [{ i32, ptr, ptr } { i32 65535, ptr @g, ptr null }]

%struct.D = type { ptr }

@_ZTV1D = internal constant { [3 x ptr] } { [3 x ptr] [ptr null, ptr undef, ptr @_ZN1D1mEi] }, !type !3

; CHECK-IR-LABEL: define weak_odr dso_local i32 @test
define weak_odr i32 @test(ptr %obj2, i32 %a) {
entry:
  %vtable2 = load ptr, ptr %obj2
  %p2 = call i1 @llvm.type.test(ptr %vtable2, metadata !4)
  call void @llvm.assume(i1 %p2)

  %fptr33 = load ptr, ptr %vtable2, align 8

  ; Check that the call was not devirtualized.
  ; CHECK-IR: %call4 = tail call i32 %fptr33
  %call4 = tail call i32 %fptr33(ptr nonnull %obj2, i32 0)
  ret i32 %call4
}
; CHECK-IR-LABEL: ret i32
; CHECK-IR-LABEL: }

; Function Attrs: inlinehint nounwind uwtable
define internal void @_ZN1DC2Ev(ptr %this) unnamed_addr align 2 {
entry:
  %this.addr = alloca ptr, align 8
  store ptr %this, ptr %this.addr, align 8
  %this1 = load ptr, ptr %this.addr
  store ptr getelementptr inbounds ({ [3 x ptr] }, ptr @_ZTV1D, i64 0, inrange i32 0, i64 2), ptr %this1, align 8
  ret void
}

define internal void @g() section ".text.startup" {
  %d = alloca %struct.D, align 8
  call void @_ZN1DC2Ev(ptr %d)
  ret void
}

declare i1 @llvm.type.test(ptr, metadata)
declare void @llvm.assume(i1)

declare i32 @_ZN1D1mEi(ptr %this, i32 %a)

!3 = !{i64 16, !4}
!4 = distinct !{}
