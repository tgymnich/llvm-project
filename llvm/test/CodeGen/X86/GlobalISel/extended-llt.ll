; RUN: llc -mtriple=x86_64 -global-isel -global-isel-abort=1 -verify-machineinstrs -stop-after=ir-translator %s -o - | FileCheck %s
; RUN: llc -mtriple=x86_64 -global-isel -global-isel-abort=1 -verify-machineinstrs %s -o /dev/null
; RUN: llc -mtriple=x86_64 -mattr=+avx2 -global-isel -global-isel-abort=1 -verify-machineinstrs %s -o /dev/null
; RUN: llc -mtriple=x86_64 -mattr=+avx512f -global-isel -global-isel-abort=1 -verify-machineinstrs %s -o /dev/null
; RUN: llc -mtriple=i686 -mattr=+sse2 -global-isel -global-isel-abort=1 -verify-machineinstrs %s -o /dev/null

define float @select_float(i1 %cond, float %a, float %b) {
  ; CHECK-LABEL: name: select_float
  ; CHECK: {{%.+}}:_(f32) = G_SELECT {{%.+}}(i1), {{%.+}}, {{%.+}}
  %value = select i1 %cond, float %a, float %b
  ret float %value
}

define double @select_double(i1 %cond, double %a, double %b) {
  ; CHECK-LABEL: name: select_double
  ; CHECK: {{%.+}}:_(f64) = G_SELECT {{%.+}}(i1), {{%.+}}, {{%.+}}
  %value = select i1 %cond, double %a, double %b
  ret double %value
}

define float @phi_float(i1 %cond, ptr %a, ptr %b) {
  ; CHECK-LABEL: name: phi_float
  ; CHECK: {{%.+}}:_(f32) = G_PHI
  br i1 %cond, label %left, label %right
left:
  %x = load float, ptr %a
  br label %join
right:
  %y = load float, ptr %b
  br label %join
join:
  %value = phi float [ %x, %left ], [ %y, %right ]
  ret float %value
}

define x86_fp80 @extend_x87(double %value) {
  ; CHECK-LABEL: name: extend_x87
  ; CHECK: {{%.+}}:_(f80) = G_FPEXT {{%.+}}(f64)
  %extended = fpext double %value to x86_fp80
  ret x86_fp80 %extended
}

define <4 x float> @constant_vector() {
  ; CHECK-LABEL: name: constant_vector
  ; CHECK: {{%.+}}:_(<4 x f32>) = G_BUILD_VECTOR
  ret <4 x float> <float 1.0, float undef, float 2.0, float 3.0>
}
