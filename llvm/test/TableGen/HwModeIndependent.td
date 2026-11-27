// RUN: llvm-tblgen -gen-register-info -register-info-debug -I %p/../../include %s -o %t 2>&1 | FileCheck %s --check-prefix=REG
// RUN: llvm-tblgen -gen-subtarget -I %p/../../include %s | FileCheck %s --check-prefix=SUBTARGET
// RUN: not llvm-tblgen -gen-register-info -I %p/../../include %s -DERROR -o %t 2>&1 | FileCheck %s --check-prefix=ERROR

include "llvm/Target/Target.td"

def TestTargetInstrInfo : InstrInfo;

def TestTarget : Target {
  let InstructionSet = TestTargetInstrInfo;
}

def FeatA : SubtargetFeature<"a", "HasA", "true", "">;
def FeatB : SubtargetFeature<"b", "HasB", "true", "">;
def FeatT : SubtargetFeature<"t", "HasT", "true", "">;
def FeatU : SubtargetFeature<"u", "HasU", "true", "">;

def HasA : Predicate<"Subtarget->hasA()">, AssemblerPredicate<(all_of FeatA)>;
def HasB : Predicate<"Subtarget->hasB()">, AssemblerPredicate<(all_of FeatB)>;
def HasT : Predicate<"Subtarget->hasT()">, AssemblerPredicate<(all_of FeatT)>;
def NotHasT : Predicate<"!Subtarget->hasT()">,
              AssemblerPredicate<(all_of (not FeatT))>;
def HasU : Predicate<"Subtarget->hasU()">, AssemblerPredicate<(all_of FeatU)>;

def ModeA : HwMode<[HasA]>;
// ModeB contradicts ModeT, so they are never combined.
def ModeB : HwMode<[HasB, NotHasT]>;
let Independent = true in {
def ModeT : HwMode<[HasT]>;
def ModeU : HwMode<[HasU]>;
}

class MyReg<string n> : Register<n> {
  let Namespace = "Test";
}

def X0 : MyReg<"x0">;
def X1 : MyReg<"x1">;

def XVT : ValueTypeByHwMode<[DefaultMode, ModeT], [i32, i16]>;

#ifdef ERROR
// ERROR: error: 'BadVT' is ambiguous in HwMode 'ModeA_ModeT': 'ModeA' selects 'i64' but 'ModeT' selects 'i16'
def BadVT : ValueTypeByHwMode<[DefaultMode, ModeA, ModeT], [i32, i64, i16]>;
#endif

let RegInfos = RegInfoByHwMode<[DefaultMode, ModeA, ModeB],
                               [RegInfo<32,32,32>, RegInfo<64,64,64>,
                                RegInfo<128,128,128>]> in
def XRegs : RegisterClass<"Test", [XVT], 32, (add X0, X1)>;

let RegInfos = RegInfoByHwMode<[DefaultMode, ModeU],
                               [RegInfo<32,32,32>, RegInfo<16,16,16>]> in
def YRegs : RegisterClass<"Test", [i32], 32, (add X0, X1)>;

// REG-LABEL: RegisterClass XRegs:
// REG: SpillSize: { DefaultMode:32 ModeA:64 ModeB:128 ModeT:32 ModeU:32 ModeT_ModeU:32 ModeA_ModeT:64 ModeA_ModeU:64 ModeA_ModeT_ModeU:64 ModeB_ModeU:128 }
// REG-LABEL: RegisterClass YRegs:
// REG: SpillSize: { DefaultMode:32 ModeA:32 ModeB:32 ModeT:32 ModeU:16 ModeT_ModeU:16 ModeA_ModeT:32 ModeA_ModeU:16 ModeA_ModeT_ModeU:16 ModeB_ModeU:16 }

// SUBTARGET-LABEL: unsigned TestTargetGenSubtargetInfo::getHwModeSet() const {
// SUBTARGET:         unsigned Modes = 0;
// SUBTARGET-NEXT:    if ((Subtarget->hasA())) Modes |= (1 << 0);
// SUBTARGET-NEXT:    if ((Subtarget->hasB()) && (!Subtarget->hasT())) Modes |= (1 << 1);
// SUBTARGET-NEXT:    if ((Subtarget->hasT())) Modes |= (1 << 2);
// SUBTARGET-NEXT:    if ((Subtarget->hasU())) Modes |= (1 << 3);
// SUBTARGET-NEXT:    return Modes;
// SUBTARGET-NEXT:  }
// SUBTARGET-LABEL: unsigned TestTargetGenSubtargetInfo::getHwMode(enum HwModeType type) const {
// SUBTARGET-NEXT:    unsigned Modes = getHwModeSet();
// SUBTARGET-EMPTY:
// SUBTARGET-NEXT:    if (!Modes)
// SUBTARGET-NEXT:      return Modes;
// SUBTARGET-EMPTY:
// SUBTARGET-NEXT:    switch (type) {
// SUBTARGET-NEXT:    case HwMode_Default:
// SUBTARGET-NEXT:      break;
// SUBTARGET-NEXT:    case HwMode_ValueType:
// SUBTARGET-NEXT:      Modes &= 4;
// SUBTARGET-NEXT:      if (!Modes)
// SUBTARGET-NEXT:        return Modes;
// SUBTARGET-NEXT:      break;
// SUBTARGET-NEXT:    case HwMode_RegInfo:
// SUBTARGET-NEXT:      Modes &= 11;
// SUBTARGET-NEXT:      if (!Modes)
// SUBTARGET-NEXT:        return Modes;
// SUBTARGET-NEXT:      break;
// SUBTARGET-NEXT:    case HwMode_EncodingInfo:
// SUBTARGET-NEXT:      // No HwMode for EncodingInfo.
// SUBTARGET-NEXT:      return 0;
// SUBTARGET-NEXT:    }
// SUBTARGET-EMPTY:
// SUBTARGET-NEXT:    switch (Modes) {
// SUBTARGET-NEXT:    case 12: return 5; // ModeT_ModeU
// SUBTARGET-NEXT:    case 5: return 6; // ModeA_ModeT
// SUBTARGET-NEXT:    case 9: return 7; // ModeA_ModeU
// SUBTARGET-NEXT:    case 13: return 8; // ModeA_ModeT_ModeU
// SUBTARGET-NEXT:    case 10: return 9; // ModeB_ModeU
// SUBTARGET-NEXT:    }
// SUBTARGET-NEXT:    if (type != HwMode_Default && !llvm::has_single_bit<unsigned>(Modes))
// SUBTARGET-NEXT:      llvm_unreachable("Two or more HwModes were found!");
// SUBTARGET-NEXT:    return llvm::countr_zero(Modes) + 1;
// SUBTARGET-NEXT:  }
