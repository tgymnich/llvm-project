// RUN: llvm-tblgen -gen-global-isel -I %p/../../../include -optimize-match-table=false %s | FileCheck %s

include "llvm/Target/Target.td"

def MyTargetISA : InstrInfo;
def MyTarget : Target { let InstructionSet = MyTargetISA; }

def Has64 : Predicate<"Subtarget->has64()">;
def HasT : Predicate<"Subtarget->hasT()">;

def Mode64 : HwMode<[Has64]>;
let Independent = true in
def ModeT : HwMode<[HasT]>;

def ModeVT : ValueTypeByHwMode<[DefaultMode, Mode64], [i32, i64]>;

def R0 : Register<"r0"> { let Namespace = "MyTarget"; }
def GPR : RegisterClass<"MyTarget", [ModeVT], 32, (add R0)> {
  let RegInfos = RegInfoByHwMode<[DefaultMode, Mode64],
                                 [RegInfo<32,32,32>, RegInfo<64,64,64>]>;
}

def CLZ : Instruction {
  let Namespace = "MyTarget";
  let OutOperandList = (outs GPR:$dst);
  let InOperandList = (ins GPR:$src);
}

// The pattern is valid in Mode64 and in Mode64_ModeT, but not in ModeT alone.
def : Pat<(i64 (ctlz GPR:$src)), (CLZ GPR:$src)>;

// CHECK-LABEL: computeAvailableModuleFeatures(const MyTargetSubtarget *Subtarget) const {
// CHECK-NEXT:    PredicateBitset Features{};
// CHECK-NEXT:    if (((Subtarget->has64()) && !((Subtarget->hasT()))) || ((Subtarget->has64()) && (Subtarget->hasT())))
// CHECK-NEXT:      Features.set(Feature_HwMode0Bit);

// CHECK-LABEL: LLT MyTargetInstructionSelector::getLLTForHwMode(unsigned Index) const {
// CHECK:         case 0:
// CHECK-NEXT:      switch (HwMode) {
// CHECK-NEXT:      default:
// CHECK-NEXT:        return LLT();
// CHECK-NEXT:      case 1:
// CHECK-NEXT:        return LLT::scalar(64);
// CHECK-NEXT:      case 3:
// CHECK-NEXT:        return LLT::scalar(64);
// CHECK-NEXT:      }
