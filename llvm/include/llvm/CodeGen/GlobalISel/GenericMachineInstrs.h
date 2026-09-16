//===- llvm/CodeGen/GlobalISel/GenericMachineInstrs.h -----------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
/// \file
/// Declares convenience wrapper classes for interpreting MachineInstr instances
/// as specific generic operations.
///
//===----------------------------------------------------------------------===//

#ifndef LLVM_CODEGEN_GLOBALISEL_GENERICMACHINEINSTRS_H
#define LLVM_CODEGEN_GLOBALISEL_GENERICMACHINEINSTRS_H

#include "llvm/ADT/APInt.h"
#include "llvm/CodeGen/MachineInstr.h"
#include "llvm/CodeGen/MachineMemOperand.h"
#include "llvm/CodeGen/TargetOpcodes.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/Instructions.h"
#include "llvm/Support/Casting.h"

namespace llvm {

/// A base class for all GenericMachineInstrs.
class GenericMachineInstr : public MachineInstr {
  constexpr static unsigned PoisonFlags =
      NoUWrap | NoSWrap | NoUSWrap | IsExact | Disjoint | NonNeg | FmNoNans |
      FmNoInfs | SameSign | InBounds;

public:
  GenericMachineInstr() = delete;

  /// Access the Idx'th operand as a register and return it.
  /// This assumes that the Idx'th operand is a Register type.
  Register getReg(unsigned Idx) const { return getOperand(Idx).getReg(); }

  static bool classof(const MachineInstr *MI) {
    return isPreISelGenericOpcode(MI->getOpcode());
  }

  bool hasPoisonGeneratingFlags() const { return getFlags() & PoisonFlags; }

  void dropPoisonGeneratingFlags() {
    clearFlags(PoisonFlags);
    assert(!hasPoisonGeneratingFlags());
  }
};

/// Provides common memory operand functionality.
class GMemOperation : public GenericMachineInstr {
public:
  /// Get the MachineMemOperand on this instruction.
  MachineMemOperand &getMMO() const { return **memoperands_begin(); }

  /// Returns true if the attached MachineMemOperand  has the atomic flag set.
  bool isAtomic() const { return getMMO().isAtomic(); }
  /// Returns true if the attached MachineMemOpeand as the volatile flag set.
  bool isVolatile() const { return getMMO().isVolatile(); }
  /// Returns true if the memory operation is neither atomic or volatile.
  bool isSimple() const { return !isAtomic() && !isVolatile(); }
  /// Returns true if this memory operation doesn't have any ordering
  /// constraints other than normal aliasing. Volatile and (ordered) atomic
  /// memory operations can't be reordered.
  bool isUnordered() const { return getMMO().isUnordered(); }

  /// Return the minimum known alignment in bytes of the actual memory
  /// reference.
  Align getAlign() const { return getMMO().getAlign(); }
  /// Returns the size in bytes of the memory access.
  LocationSize getMemSize() const { return getMMO().getSize(); }
  /// Returns the size in bits of the memory access.
  LocationSize getMemSizeInBits() const { return getMMO().getSizeInBits(); }

  static bool classof(const MachineInstr *MI) {
    return GenericMachineInstr::classof(MI) && MI->hasOneMemOperand();
  }
};

/// Atomically updates memory and returns the value read before the update.
class GAtomicRMW : public GMemOperation {
public:
  Register getOldValueReg() const { return getReg(0); }
  Register getPointerReg() const { return getReg(1); }
  Register getValueReg() const { return getReg(2); }

  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() >= TargetOpcode::GENERIC_ATOMICRMW_OP_START &&
           MI->getOpcode() <= TargetOpcode::GENERIC_ATOMICRMW_OP_END;
  }
};

/// Atomically replaces a matching value, optionally returning whether the
/// comparison succeeded.
class GAtomicCmpXchg : public GMemOperation {
public:
  Register getOldValueReg() const { return getReg(0); }

  bool hasSuccessResult() const {
    return getOpcode() == TargetOpcode::G_ATOMIC_CMPXCHG_WITH_SUCCESS;
  }

  Register getSuccessReg() const {
    assert(hasSuccessResult() && "expected a success result");
    return getReg(1);
  }

  Register getPointerReg() const { return getReg(getNumExplicitDefs()); }
  Register getCompareReg() const { return getReg(getNumExplicitDefs() + 1); }
  Register getNewValueReg() const { return getReg(getNumExplicitDefs() + 2); }

  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_ATOMIC_CMPXCHG ||
           MI->getOpcode() == TargetOpcode::G_ATOMIC_CMPXCHG_WITH_SUCCESS;
  }
};

/// Represents any type of generic load or store.
/// G_LOAD, G_STORE, G_ZEXTLOAD, G_SEXTLOAD, G_FPEXTLOAD, G_FPTRUNCSTORE.
class GLoadStore : public GMemOperation {
public:
  /// Get the source register of the pointer value.
  Register getPointerReg() const { return getOperand(1).getReg(); }

  static bool classof(const MachineInstr *MI) {
    switch (MI->getOpcode()) {
    case TargetOpcode::G_LOAD:
    case TargetOpcode::G_STORE:
    case TargetOpcode::G_ZEXTLOAD:
    case TargetOpcode::G_SEXTLOAD:
    case TargetOpcode::G_FPEXTLOAD:
    case TargetOpcode::G_FPTRUNCSTORE:
      return true;
    default:
      return false;
    }
  }
};

/// Represents indexed loads. These are different enough from regular loads
/// that they get their own class. Including them in GAnyLoad would probably
/// make a footgun for someone.
class GIndexedLoad : public GMemOperation {
public:
  /// Get the definition register of the loaded value.
  Register getDstReg() const { return getOperand(0).getReg(); }
  /// Get the def register of the writeback value.
  Register getWritebackReg() const { return getOperand(1).getReg(); }
  /// Get the base register of the pointer value.
  Register getBaseReg() const { return getOperand(2).getReg(); }
  /// Get the offset register of the pointer value.
  Register getOffsetReg() const { return getOperand(3).getReg(); }

  bool isPre() const { return getOperand(4).getImm() == 1; }
  bool isPost() const { return !isPre(); }

  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_INDEXED_LOAD;
  }
};

/// Represents a G_INDEX_ZEXTLOAD/G_INDEXED_SEXTLOAD.
class GIndexedExtLoad : public GIndexedLoad {
public:
  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_INDEXED_SEXTLOAD ||
           MI->getOpcode() == TargetOpcode::G_INDEXED_ZEXTLOAD;
  }
};

/// Represents either G_INDEXED_LOAD, G_INDEXED_ZEXTLOAD or G_INDEXED_SEXTLOAD.
class GIndexedAnyExtLoad : public GIndexedLoad {
public:
  static bool classof(const MachineInstr *MI) {
    switch (MI->getOpcode()) {
    case TargetOpcode::G_INDEXED_LOAD:
    case TargetOpcode::G_INDEXED_ZEXTLOAD:
    case TargetOpcode::G_INDEXED_SEXTLOAD:
      return true;
    default:
      return false;
    }
  }
};

/// Represents a G_ZEXTLOAD.
class GIndexedZExtLoad : GIndexedExtLoad {
public:
  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_INDEXED_ZEXTLOAD;
  }
};

/// Represents a G_SEXTLOAD.
class GIndexedSExtLoad : GIndexedExtLoad {
public:
  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_INDEXED_SEXTLOAD;
  }
};

/// Represents indexed stores.
class GIndexedStore : public GMemOperation {
public:
  /// Get the def register of the writeback value.
  Register getWritebackReg() const { return getOperand(0).getReg(); }
  /// Get the stored value register.
  Register getValueReg() const { return getOperand(1).getReg(); }
  /// Get the base register of the pointer value.
  Register getBaseReg() const { return getOperand(2).getReg(); }
  /// Get the offset register of the pointer value.
  Register getOffsetReg() const { return getOperand(3).getReg(); }

  bool isPre() const { return getOperand(4).getImm() == 1; }
  bool isPost() const { return !isPre(); }

  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_INDEXED_STORE;
  }
};

/// Represents any generic load, including sign/zero extending variants.
class GAnyLoad : public GLoadStore {
public:
  /// Get the definition register of the loaded value.
  Register getDstReg() const { return getOperand(0).getReg(); }

  /// Returns the Ranges that describes the dereference.
  const MDNode *getRanges() const {
    return getMMO().getRanges();
  }

  /// Returns the cache hint metadata for this load.
  const MDNode *getMemCacheHint() const { return getMMO().getMemCacheHint(); }

  static bool classof(const MachineInstr *MI) {
    switch (MI->getOpcode()) {
    case TargetOpcode::G_LOAD:
    case TargetOpcode::G_ZEXTLOAD:
    case TargetOpcode::G_SEXTLOAD:
    case TargetOpcode::G_FPEXTLOAD:
      return true;
    default:
      return false;
    }
  }
};

/// Represents a G_LOAD.
class GLoad : public GAnyLoad {
public:
  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_LOAD;
  }
};

/// Represents either a G_SEXTLOAD, G_ZEXTLOAD, or G_FPEXTLOAD.
class GExtLoad : public GAnyLoad {
public:
  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_SEXTLOAD ||
           MI->getOpcode() == TargetOpcode::G_ZEXTLOAD ||
           MI->getOpcode() == TargetOpcode::G_FPEXTLOAD;
  }
};

/// Represents a G_SEXTLOAD.
class GSExtLoad : public GExtLoad {
public:
  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_SEXTLOAD;
  }
};

/// Represents a G_ZEXTLOAD.
class GZExtLoad : public GExtLoad {
public:
  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_ZEXTLOAD;
  }
};

/// Represents a G_FPEXTLOAD.
class GFPExtLoad : public GAnyLoad {
public:
  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_FPEXTLOAD;
  }
};

/// Represents any generic store, including truncating variants.
class GAnyStore : public GLoadStore {
public:
  /// Get the stored value register.
  Register getValueReg() const { return getOperand(0).getReg(); }

  static bool classof(const MachineInstr *MI) {
    switch (MI->getOpcode()) {
    case TargetOpcode::G_STORE:
    case TargetOpcode::G_FPTRUNCSTORE:
      return true;
    default:
      return false;
    }
  }
};

/// Represents a G_STORE.
class GStore : public GAnyStore {
public:
  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_STORE;
  }
};

/// Represents a G_FPTRUNCSTORE.
class GFPTruncStore : public GAnyStore {
public:
  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_FPTRUNCSTORE;
  }
};

/// Represents a G_UNMERGE_VALUES.
class GUnmerge : public GenericMachineInstr {
public:
  /// Returns the number of def registers.
  unsigned getNumDefs() const { return getNumOperands() - 1; }
  /// Get the unmerge source register.
  Register getSourceReg() const { return getOperand(getNumDefs()).getReg(); }

  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_UNMERGE_VALUES;
  }
};

/// Extracts a result-sized bit range at a constant offset from a source.
class GExtract : public GenericMachineInstr {
public:
  Register getSrcReg() const { return getReg(1); }
  uint64_t getOffsetInBits() const { return getOperand(2).getImm(); }

  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_EXTRACT;
  }
};

/// Replaces a bit range in a base value at a constant offset.
class GInsert : public GenericMachineInstr {
public:
  Register getBaseReg() const { return getReg(1); }
  Register getInsertedReg() const { return getReg(2); }
  uint64_t getOffsetInBits() const { return getOperand(3).getImm(); }

  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_INSERT;
  }
};

/// Represents G_BUILD_VECTOR, G_CONCAT_VECTORS or G_MERGE_VALUES.
/// All these have the common property of generating a single value from
/// multiple sources.
class GMergeLikeInstr : public GenericMachineInstr {
public:
  /// Returns the number of source registers.
  unsigned getNumSources() const { return getNumOperands() - 1; }
  /// Returns the I'th source register.
  Register getSourceReg(unsigned I) const { return getReg(I + 1); }

  static bool classof(const MachineInstr *MI) {
    switch (MI->getOpcode()) {
    case TargetOpcode::G_MERGE_VALUES:
    case TargetOpcode::G_CONCAT_VECTORS:
    case TargetOpcode::G_BUILD_VECTOR:
      return true;
    default:
      return false;
    }
  }
};

/// Represents a G_MERGE_VALUES.
class GMerge : public GMergeLikeInstr {
public:
  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_MERGE_VALUES;
  }
};

/// Represents a G_CONCAT_VECTORS.
class GConcatVectors : public GMergeLikeInstr {
public:
  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_CONCAT_VECTORS;
  }
};

/// Represents a G_BUILD_VECTOR.
class GBuildVector : public GMergeLikeInstr {
public:
  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_BUILD_VECTOR;
  }
};

/// Represents a G_BUILD_VECTOR_TRUNC.
class GBuildVectorTrunc : public GMergeLikeInstr {
public:
  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_BUILD_VECTOR_TRUNC;
  }
};

/// Represents a G_SHUFFLE_VECTOR.
class GShuffleVector : public GenericMachineInstr {
public:
  Register getSrc1Reg() const { return getOperand(1).getReg(); }
  Register getSrc2Reg() const { return getOperand(2).getReg(); }
  ArrayRef<int> getMask() const { return getOperand(3).getShuffleMask(); }

  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_SHUFFLE_VECTOR;
  }
};

/// Represents a G_PTR_ADD.
class GPtrAdd : public GenericMachineInstr {
public:
  Register getBaseReg() const { return getReg(1); }
  Register getOffsetReg() const { return getReg(2); }

  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_PTR_ADD;
  }
};

/// Materializes the address of a machine frame object.
class GFrameIndex : public GenericMachineInstr {
public:
  int getFrameIndex() const { return getOperand(1).getIndex(); }

  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_FRAME_INDEX;
  }
};

/// Materializes a global address with an offset and target-specific flags.
class GGlobalValue : public GenericMachineInstr {
public:
  MachineOperand &getGlobalValueOperand() { return getOperand(1); }
  const MachineOperand &getGlobalValueOperand() const { return getOperand(1); }
  int64_t getOffset() const { return getGlobalValueOperand().getOffset(); }
  unsigned getTargetFlags() const {
    return getGlobalValueOperand().getTargetFlags();
  }

  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_GLOBAL_VALUE;
  }
};

/// Materializes a constant-pool address with an offset and target-specific
/// flags.
class GConstantPool : public GenericMachineInstr {
public:
  MachineOperand &getConstantPoolOperand() { return getOperand(1); }
  const MachineOperand &getConstantPoolOperand() const { return getOperand(1); }
  int getConstantPoolIndex() const {
    return getConstantPoolOperand().getIndex();
  }
  int64_t getOffset() const { return getConstantPoolOperand().getOffset(); }
  unsigned getTargetFlags() const {
    return getConstantPoolOperand().getTargetFlags();
  }

  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_CONSTANT_POOL;
  }
};

/// Represents a G_IMPLICIT_DEF.
class GImplicitDef : public GenericMachineInstr {
public:
  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_IMPLICIT_DEF;
  }
};

/// Represents a G_SELECT.
class GSelect : public GenericMachineInstr {
public:
  Register getCondReg() const { return getReg(1); }
  Register getTrueReg() const { return getReg(2); }
  Register getFalseReg() const { return getReg(3); }

  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_SELECT;
  }
};

/// Represents an unconditional branch to a basic block.
class GBr : public GenericMachineInstr {
public:
  MachineBasicBlock *getTargetMBB() const { return getOperand(0).getMBB(); }

  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_BR;
  }
};

/// Branches to a target block when its condition is nonzero.
class GBrCond : public GenericMachineInstr {
public:
  Register getConditionReg() const { return getReg(0); }
  MachineBasicBlock *getTargetMBB() const { return getOperand(1).getMBB(); }

  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_BRCOND;
  }
};

/// Represents an indirect branch to an address held in a register.
class GBrIndirect : public GenericMachineInstr {
public:
  Register getTargetReg() const { return getReg(0); }

  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_BRINDIRECT;
  }
};

/// Represents an indirect branch through a jump table.
class GBrJT : public GenericMachineInstr {
public:
  Register getJumpTableReg() const { return getReg(0); }
  unsigned getJumpTableIndex() const { return getOperand(1).getIndex(); }
  Register getIndexReg() const { return getReg(2); }

  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_BRJT;
  }
};

/// Represent a G_ICMP or G_FCMP.
class GAnyCmp : public GenericMachineInstr {
public:
  CmpInst::Predicate getCond() const {
    return static_cast<CmpInst::Predicate>(getOperand(1).getPredicate());
  }
  Register getLHSReg() const { return getReg(2); }
  Register getRHSReg() const { return getReg(3); }

  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_ICMP ||
           MI->getOpcode() == TargetOpcode::G_FCMP;
  }
};

/// Represent a G_ICMP.
class GICmp : public GAnyCmp {
public:
  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_ICMP;
  }
};

/// Represent a G_FCMP.
class GFCmp : public GAnyCmp {
public:
  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_FCMP;
  }
};

/// Represents overflowing binary operations.
/// Only carry-out:
/// G_UADDO, G_SADDO, G_USUBO, G_SSUBO, G_UMULO, G_SMULO
/// Carry-in and carry-out:
/// G_UADDE, G_SADDE, G_USUBE, G_SSUBE
class GBinOpCarryOut : public GenericMachineInstr {
public:
  Register getDstReg() const { return getReg(0); }
  Register getCarryOutReg() const { return getReg(1); }
  MachineOperand &getLHS() { return getOperand(2); }
  MachineOperand &getRHS() { return getOperand(3); }
  Register getLHSReg() const { return getOperand(2).getReg(); }
  Register getRHSReg() const { return getOperand(3).getReg(); }

  static bool classof(const MachineInstr *MI) {
    switch (MI->getOpcode()) {
    case TargetOpcode::G_UADDO:
    case TargetOpcode::G_SADDO:
    case TargetOpcode::G_USUBO:
    case TargetOpcode::G_SSUBO:
    case TargetOpcode::G_UADDE:
    case TargetOpcode::G_SADDE:
    case TargetOpcode::G_USUBE:
    case TargetOpcode::G_SSUBE:
    case TargetOpcode::G_UMULO:
    case TargetOpcode::G_SMULO:
      return true;
    default:
      return false;
    }
  }
};

/// Represents overflowing add/sub operations.
/// Only carry-out:
/// G_UADDO, G_SADDO, G_USUBO, G_SSUBO
/// Carry-in and carry-out:
/// G_UADDE, G_SADDE, G_USUBE, G_SSUBE
class GAddSubCarryOut : public GBinOpCarryOut {
public:
  bool isAdd() const {
    switch (getOpcode()) {
    case TargetOpcode::G_UADDO:
    case TargetOpcode::G_SADDO:
    case TargetOpcode::G_UADDE:
    case TargetOpcode::G_SADDE:
      return true;
    default:
      return false;
    }
  }
  bool isSub() const { return !isAdd(); }

  bool isSigned() const {
    switch (getOpcode()) {
    case TargetOpcode::G_SADDO:
    case TargetOpcode::G_SSUBO:
    case TargetOpcode::G_SADDE:
    case TargetOpcode::G_SSUBE:
      return true;
    default:
      return false;
    }
  }
  bool isUnsigned() const { return !isSigned(); }

  static bool classof(const MachineInstr *MI) {
    switch (MI->getOpcode()) {
    case TargetOpcode::G_UADDO:
    case TargetOpcode::G_SADDO:
    case TargetOpcode::G_USUBO:
    case TargetOpcode::G_SSUBO:
    case TargetOpcode::G_UADDE:
    case TargetOpcode::G_SADDE:
    case TargetOpcode::G_USUBE:
    case TargetOpcode::G_SSUBE:
      return true;
    default:
      return false;
    }
  }
};

/// Represents overflowing add operations.
/// G_UADDO, G_SADDO
class GAddCarryOut : public GBinOpCarryOut {
public:
  bool isSigned() const { return getOpcode() == TargetOpcode::G_SADDO; }

  static bool classof(const MachineInstr *MI) {
    switch (MI->getOpcode()) {
    case TargetOpcode::G_UADDO:
    case TargetOpcode::G_SADDO:
      return true;
    default:
      return false;
    }
  }
};

/// Represents overflowing sub operations.
/// G_USUBO, G_SSUBO
class GSubCarryOut : public GBinOpCarryOut {
public:
  bool isSigned() const { return getOpcode() == TargetOpcode::G_SSUBO; }

  static bool classof(const MachineInstr *MI) {
    switch (MI->getOpcode()) {
    case TargetOpcode::G_USUBO:
    case TargetOpcode::G_SSUBO:
      return true;
    default:
      return false;
    }
  }
};

/// Represents overflowing add/sub operations that also consume a carry-in.
/// G_UADDE, G_SADDE, G_USUBE, G_SSUBE
class GAddSubCarryInOut : public GAddSubCarryOut {
public:
  Register getCarryInReg() const { return getReg(4); }

  static bool classof(const MachineInstr *MI) {
    switch (MI->getOpcode()) {
    case TargetOpcode::G_UADDE:
    case TargetOpcode::G_SADDE:
    case TargetOpcode::G_USUBE:
    case TargetOpcode::G_SSUBE:
      return true;
    default:
      return false;
    }
  }
};

/// Multiplies two integers and returns the product and overflow indicator.
class GMulOverflow : public GBinOpCarryOut {
public:
  Register getOverflowReg() const { return getReg(1); }
  bool isSigned() const { return getOpcode() == TargetOpcode::G_SMULO; }

  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_UMULO ||
           MI->getOpcode() == TargetOpcode::G_SMULO;
  }
};

/// Divides two integers and returns both the quotient and remainder.
class GDivRem : public GenericMachineInstr {
public:
  Register getQuotientReg() const { return getReg(0); }
  Register getRemainderReg() const { return getReg(1); }
  Register getLHSReg() const { return getReg(2); }
  Register getRHSReg() const { return getReg(3); }

  bool isSigned() const { return getOpcode() == TargetOpcode::G_SDIVREM; }

  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_SDIVREM ||
           MI->getOpcode() == TargetOpcode::G_UDIVREM;
  }
};

/// Represents a call to an intrinsic.
class GIntrinsic final : public GenericMachineInstr {
public:
  Intrinsic::ID getIntrinsicID() const {
    return getOperand(getNumExplicitDefs()).getIntrinsicID();
  }

  bool is(Intrinsic::ID ID) const { return getIntrinsicID() == ID; }

  bool hasSideEffects() const {
    switch (getOpcode()) {
    case TargetOpcode::G_INTRINSIC_W_SIDE_EFFECTS:
    case TargetOpcode::G_INTRINSIC_CONVERGENT_W_SIDE_EFFECTS:
      return true;
    default:
      return false;
    }
  }

  bool isConvergent() const {
    switch (getOpcode()) {
    case TargetOpcode::G_INTRINSIC_CONVERGENT:
    case TargetOpcode::G_INTRINSIC_CONVERGENT_W_SIDE_EFFECTS:
      return true;
    default:
      return false;
    }
  }

  static bool classof(const MachineInstr *MI) {
    switch (MI->getOpcode()) {
    case TargetOpcode::G_INTRINSIC:
    case TargetOpcode::G_INTRINSIC_W_SIDE_EFFECTS:
    case TargetOpcode::G_INTRINSIC_CONVERGENT:
    case TargetOpcode::G_INTRINSIC_CONVERGENT_W_SIDE_EFFECTS:
      return true;
    default:
      return false;
    }
  }
};

// Represents a (non-sequential) vector reduction operation.
class GVecReduce : public GenericMachineInstr {
public:
  Register getVectorReg() const { return getReg(1); }

  static bool classof(const MachineInstr *MI) {
    switch (MI->getOpcode()) {
    case TargetOpcode::G_VECREDUCE_FADD:
    case TargetOpcode::G_VECREDUCE_FMUL:
    case TargetOpcode::G_VECREDUCE_FMAX:
    case TargetOpcode::G_VECREDUCE_FMIN:
    case TargetOpcode::G_VECREDUCE_FMAXIMUM:
    case TargetOpcode::G_VECREDUCE_FMINIMUM:
    case TargetOpcode::G_VECREDUCE_FMAXIMUMNUM:
    case TargetOpcode::G_VECREDUCE_FMINIMUMNUM:
    case TargetOpcode::G_VECREDUCE_ADD:
    case TargetOpcode::G_VECREDUCE_MUL:
    case TargetOpcode::G_VECREDUCE_AND:
    case TargetOpcode::G_VECREDUCE_OR:
    case TargetOpcode::G_VECREDUCE_XOR:
    case TargetOpcode::G_VECREDUCE_SMAX:
    case TargetOpcode::G_VECREDUCE_SMIN:
    case TargetOpcode::G_VECREDUCE_UMAX:
    case TargetOpcode::G_VECREDUCE_UMIN:
      return true;
    default:
      return false;
    }
  }

  /// Get the opcode for the equivalent scalar operation for this reduction.
  /// E.g. for G_VECREDUCE_FADD, this returns G_FADD.
  unsigned getScalarOpcForReduction() {
    unsigned ScalarOpc;
    switch (getOpcode()) {
    case TargetOpcode::G_VECREDUCE_FADD:
      ScalarOpc = TargetOpcode::G_FADD;
      break;
    case TargetOpcode::G_VECREDUCE_FMUL:
      ScalarOpc = TargetOpcode::G_FMUL;
      break;
    case TargetOpcode::G_VECREDUCE_FMAX:
      ScalarOpc = TargetOpcode::G_FMAXNUM;
      break;
    case TargetOpcode::G_VECREDUCE_FMIN:
      ScalarOpc = TargetOpcode::G_FMINNUM;
      break;
    case TargetOpcode::G_VECREDUCE_FMAXIMUM:
      ScalarOpc = TargetOpcode::G_FMAXIMUM;
      break;
    case TargetOpcode::G_VECREDUCE_FMINIMUM:
      ScalarOpc = TargetOpcode::G_FMINIMUM;
      break;
    case TargetOpcode::G_VECREDUCE_FMAXIMUMNUM:
      ScalarOpc = TargetOpcode::G_FMAXIMUMNUM;
      break;
    case TargetOpcode::G_VECREDUCE_FMINIMUMNUM:
      ScalarOpc = TargetOpcode::G_FMINIMUMNUM;
      break;
    case TargetOpcode::G_VECREDUCE_ADD:
      ScalarOpc = TargetOpcode::G_ADD;
      break;
    case TargetOpcode::G_VECREDUCE_MUL:
      ScalarOpc = TargetOpcode::G_MUL;
      break;
    case TargetOpcode::G_VECREDUCE_AND:
      ScalarOpc = TargetOpcode::G_AND;
      break;
    case TargetOpcode::G_VECREDUCE_OR:
      ScalarOpc = TargetOpcode::G_OR;
      break;
    case TargetOpcode::G_VECREDUCE_XOR:
      ScalarOpc = TargetOpcode::G_XOR;
      break;
    case TargetOpcode::G_VECREDUCE_SMAX:
      ScalarOpc = TargetOpcode::G_SMAX;
      break;
    case TargetOpcode::G_VECREDUCE_SMIN:
      ScalarOpc = TargetOpcode::G_SMIN;
      break;
    case TargetOpcode::G_VECREDUCE_UMAX:
      ScalarOpc = TargetOpcode::G_UMAX;
      break;
    case TargetOpcode::G_VECREDUCE_UMIN:
      ScalarOpc = TargetOpcode::G_UMIN;
      break;
    default:
      llvm_unreachable("Unhandled reduction");
    }
    return ScalarOpc;
  }
};

/// Reduces a vector in order, starting from a scalar accumulator.
class GSeqVecReduce : public GenericMachineInstr {
public:
  Register getAccumulatorReg() const { return getReg(1); }
  Register getVectorReg() const { return getReg(2); }

  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_VECREDUCE_SEQ_FADD ||
           MI->getOpcode() == TargetOpcode::G_VECREDUCE_SEQ_FMUL;
  }
};

/// Represents a G_PHI.
class GPhi : public GenericMachineInstr {
public:
  /// Returns the number of incoming values.
  unsigned getNumIncomingValues() const { return (getNumOperands() - 1) / 2; }
  /// Returns the I'th incoming vreg.
  Register getIncomingValue(unsigned I) const {
    return getOperand(I * 2 + 1).getReg();
  }
  /// Returns the I'th incoming basic block.
  MachineBasicBlock *getIncomingBlock(unsigned I) const {
    return getOperand(I * 2 + 2).getMBB();
  }

  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_PHI;
  }
};

/// Provides the source operand of a single-input operation.
class GUnaryOp : public GenericMachineInstr {
protected:
  static bool isIntegerOpcode(unsigned Opcode) {
    switch (Opcode) {
    case TargetOpcode::G_ABS:
    case TargetOpcode::G_BITREVERSE:
    case TargetOpcode::G_BSWAP:
    case TargetOpcode::G_CTLS:
    case TargetOpcode::G_CTLZ:
    case TargetOpcode::G_CTLZ_ZERO_POISON:
    case TargetOpcode::G_CTPOP:
    case TargetOpcode::G_CTTZ:
    case TargetOpcode::G_CTTZ_ZERO_POISON:
      return true;
    default:
      return false;
    }
  }

  static bool isFloatingPointOpcode(unsigned Opcode) {
    switch (Opcode) {
    case TargetOpcode::G_FABS:
    case TargetOpcode::G_FACOS:
    case TargetOpcode::G_FASIN:
    case TargetOpcode::G_FATAN:
    case TargetOpcode::G_FCANONICALIZE:
    case TargetOpcode::G_FCEIL:
    case TargetOpcode::G_FCOS:
    case TargetOpcode::G_FCOSH:
    case TargetOpcode::G_FEXP:
    case TargetOpcode::G_FEXP2:
    case TargetOpcode::G_FEXP10:
    case TargetOpcode::G_FFLOOR:
    case TargetOpcode::G_FLOG:
    case TargetOpcode::G_FLOG2:
    case TargetOpcode::G_FLOG10:
    case TargetOpcode::G_FNEARBYINT:
    case TargetOpcode::G_FNEG:
    case TargetOpcode::G_FRINT:
    case TargetOpcode::G_FSIN:
    case TargetOpcode::G_FSINH:
    case TargetOpcode::G_FSQRT:
    case TargetOpcode::G_FTAN:
    case TargetOpcode::G_FTANH:
    case TargetOpcode::G_LROUND:
    case TargetOpcode::G_LLROUND:
      return true;
    default:
      return false;
    }
  }

public:
  Register getSrcReg() const { return getReg(1); }

  static bool classof(const MachineInstr *MI) {
    return isIntegerOpcode(MI->getOpcode()) ||
           isFloatingPointOpcode(MI->getOpcode());
  }
};

/// Provides the source operand of an integer unary operation.
class GIntUnaryOp : public GUnaryOp {
public:
  static bool classof(const MachineInstr *MI) {
    return isIntegerOpcode(MI->getOpcode());
  }
};

/// Provides the source operand of a floating-point unary operation.
class GFPUnaryOp : public GUnaryOp {
public:
  static bool classof(const MachineInstr *MI) {
    return isFloatingPointOpcode(MI->getOpcode());
  }
};

/// Represents a binary operation, i.e, x = y op z.
class GBinOp : public GenericMachineInstr {
public:
  Register getLHSReg() const { return getReg(1); }
  Register getRHSReg() const { return getReg(2); }

  static bool classof(const MachineInstr *MI) {
    switch (MI->getOpcode()) {
    // Integer.
    case TargetOpcode::G_ABDS:
    case TargetOpcode::G_ABDU:
    case TargetOpcode::G_ADD:
    case TargetOpcode::G_SUB:
    case TargetOpcode::G_MUL:
    case TargetOpcode::G_CLMUL:
    case TargetOpcode::G_CLMULH:
    case TargetOpcode::G_SDIV:
    case TargetOpcode::G_UDIV:
    case TargetOpcode::G_SREM:
    case TargetOpcode::G_UREM:
    case TargetOpcode::G_ROTL:
    case TargetOpcode::G_ROTR:
    case TargetOpcode::G_SMIN:
    case TargetOpcode::G_SMAX:
    case TargetOpcode::G_UMIN:
    case TargetOpcode::G_UMAX:
    case TargetOpcode::G_SADDSAT:
    case TargetOpcode::G_SSUBSAT:
    case TargetOpcode::G_UADDSAT:
    case TargetOpcode::G_USUBSAT:
    case TargetOpcode::G_SAVGCEIL:
    case TargetOpcode::G_SAVGFLOOR:
    case TargetOpcode::G_UAVGCEIL:
    case TargetOpcode::G_UAVGFLOOR:
    case TargetOpcode::G_SMULH:
    case TargetOpcode::G_UMULH:
    // Floating point.
    case TargetOpcode::G_FATAN2:
    case TargetOpcode::G_FCOPYSIGN:
    case TargetOpcode::G_FLDEXP:
    case TargetOpcode::G_FMINNUM:
    case TargetOpcode::G_FMAXNUM:
    case TargetOpcode::G_FMINNUM_IEEE:
    case TargetOpcode::G_FMAXNUM_IEEE:
    case TargetOpcode::G_FMINIMUM:
    case TargetOpcode::G_FMAXIMUM:
    case TargetOpcode::G_FMINIMUMNUM:
    case TargetOpcode::G_FMAXIMUMNUM:
    case TargetOpcode::G_FADD:
    case TargetOpcode::G_FSUB:
    case TargetOpcode::G_FMUL:
    case TargetOpcode::G_FDIV:
    case TargetOpcode::G_FPOWI:
    case TargetOpcode::G_FPOW:
    case TargetOpcode::G_FREM:
    // Logical.
    case TargetOpcode::G_AND:
    case TargetOpcode::G_OR:
    case TargetOpcode::G_XOR:
      return true;
    default:
      return false;
    }
  };
};

/// Represents an integer binary operation.
class GIntBinOp : public GBinOp {
public:
  static bool classof(const MachineInstr *MI) {
    switch (MI->getOpcode()) {
    case TargetOpcode::G_ABDS:
    case TargetOpcode::G_ABDU:
    case TargetOpcode::G_ADD:
    case TargetOpcode::G_SUB:
    case TargetOpcode::G_MUL:
    case TargetOpcode::G_CLMUL:
    case TargetOpcode::G_CLMULH:
    case TargetOpcode::G_SDIV:
    case TargetOpcode::G_UDIV:
    case TargetOpcode::G_SREM:
    case TargetOpcode::G_UREM:
    case TargetOpcode::G_ROTL:
    case TargetOpcode::G_ROTR:
    case TargetOpcode::G_SMIN:
    case TargetOpcode::G_SMAX:
    case TargetOpcode::G_UMIN:
    case TargetOpcode::G_UMAX:
    case TargetOpcode::G_SADDSAT:
    case TargetOpcode::G_SSUBSAT:
    case TargetOpcode::G_UADDSAT:
    case TargetOpcode::G_USUBSAT:
    case TargetOpcode::G_SAVGCEIL:
    case TargetOpcode::G_SAVGFLOOR:
    case TargetOpcode::G_UAVGCEIL:
    case TargetOpcode::G_UAVGFLOOR:
    case TargetOpcode::G_SMULH:
    case TargetOpcode::G_UMULH:
      return true;
    default:
      return false;
    }
  };
};

/// Represents a floating point binary operation.
class GFBinOp : public GBinOp {
public:
  static bool classof(const MachineInstr *MI) {
    switch (MI->getOpcode()) {
    case TargetOpcode::G_FATAN2:
    case TargetOpcode::G_FCOPYSIGN:
    case TargetOpcode::G_FLDEXP:
    case TargetOpcode::G_FMINNUM:
    case TargetOpcode::G_FMAXNUM:
    case TargetOpcode::G_FMINNUM_IEEE:
    case TargetOpcode::G_FMAXNUM_IEEE:
    case TargetOpcode::G_FMINIMUM:
    case TargetOpcode::G_FMAXIMUM:
    case TargetOpcode::G_FMINIMUMNUM:
    case TargetOpcode::G_FMAXIMUMNUM:
    case TargetOpcode::G_FADD:
    case TargetOpcode::G_FSUB:
    case TargetOpcode::G_FMUL:
    case TargetOpcode::G_FDIV:
    case TargetOpcode::G_FPOWI:
    case TargetOpcode::G_FPOW:
    case TargetOpcode::G_FREM:
      return true;
    default:
      return false;
    }
  };
};

/// Provides the three register inputs of a ternary operation.
class GTernaryOp : public GenericMachineInstr {
public:
  Register getSrc1Reg() const { return getReg(1); }
  Register getSrc2Reg() const { return getReg(2); }
  Register getSrc3Reg() const { return getReg(3); }

  static bool classof(const MachineInstr *MI) {
    switch (MI->getOpcode()) {
    case TargetOpcode::G_FMA:
    case TargetOpcode::G_FMAD:
    case TargetOpcode::G_FSHL:
    case TargetOpcode::G_FSHR:
    case TargetOpcode::G_SBFX:
    case TargetOpcode::G_UBFX:
    case TargetOpcode::G_VECTOR_COMPRESS:
      return true;
    default:
      return false;
    }
  }
};

/// Combines two values using a third operand as the funnel shift amount.
class GFunnelShift : public GTernaryOp {
public:
  Register getShiftReg() const { return getSrc3Reg(); }
  bool isLeft() const { return getOpcode() == TargetOpcode::G_FSHL; }

  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_FSHL ||
           MI->getOpcode() == TargetOpcode::G_FSHR;
  }
};

/// Extracts a signed or unsigned bit field using register operands.
class GBitfieldExtract : public GTernaryOp {
public:
  Register getSrcReg() const { return getSrc1Reg(); }
  Register getLSBReg() const { return getSrc2Reg(); }
  Register getWidthReg() const { return getSrc3Reg(); }
  bool isSigned() const { return getOpcode() == TargetOpcode::G_SBFX; }

  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_SBFX ||
           MI->getOpcode() == TargetOpcode::G_UBFX;
  }
};

/// Multiplies two floating-point values and adds a third.
class GFMulAdd : public GTernaryOp {
public:
  bool isFused() const { return getOpcode() == TargetOpcode::G_FMA; }

  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_FMA ||
           MI->getOpcode() == TargetOpcode::G_FMAD;
  }
};

/// Performs signed or unsigned fixed-point multiplication or division.
class GFixedPointOp : public GenericMachineInstr {
public:
  Register getLHSReg() const { return getReg(1); }
  Register getRHSReg() const { return getReg(2); }
  int64_t getScale() const { return getOperand(3).getImm(); }

  bool isSigned() const {
    switch (getOpcode()) {
    case TargetOpcode::G_SDIVFIX:
    case TargetOpcode::G_SDIVFIXSAT:
    case TargetOpcode::G_SMULFIX:
    case TargetOpcode::G_SMULFIXSAT:
      return true;
    default:
      return false;
    }
  }

  bool isSaturating() const {
    switch (getOpcode()) {
    case TargetOpcode::G_SDIVFIXSAT:
    case TargetOpcode::G_SMULFIXSAT:
    case TargetOpcode::G_UDIVFIXSAT:
    case TargetOpcode::G_UMULFIXSAT:
      return true;
    default:
      return false;
    }
  }

  bool isDivision() const {
    switch (getOpcode()) {
    case TargetOpcode::G_SDIVFIX:
    case TargetOpcode::G_SDIVFIXSAT:
    case TargetOpcode::G_UDIVFIX:
    case TargetOpcode::G_UDIVFIXSAT:
      return true;
    default:
      return false;
    }
  }

  static bool classof(const MachineInstr *MI) {
    switch (MI->getOpcode()) {
    case TargetOpcode::G_SDIVFIX:
    case TargetOpcode::G_SDIVFIXSAT:
    case TargetOpcode::G_SMULFIX:
    case TargetOpcode::G_SMULFIXSAT:
    case TargetOpcode::G_UDIVFIX:
    case TargetOpcode::G_UDIVFIXSAT:
    case TargetOpcode::G_UMULFIX:
    case TargetOpcode::G_UMULFIXSAT:
      return true;
    default:
      return false;
    }
  }
};

/// Provides both results and the source of a two-result floating-point
/// operation.
class GFPMultiResultOp : public GenericMachineInstr {
public:
  Register getFirstResultReg() const { return getReg(0); }
  Register getSecondResultReg() const { return getReg(1); }
  Register getSrcReg() const { return getReg(2); }

  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_FFREXP ||
           MI->getOpcode() == TargetOpcode::G_FMODF ||
           MI->getOpcode() == TargetOpcode::G_FSINCOS;
  }
};

/// Tests a floating-point value against an immediate class mask.
class GIsFPClass : public GenericMachineInstr {
public:
  Register getSrcReg() const { return getReg(1); }
  unsigned getTestMask() const {
    return static_cast<unsigned>(getOperand(2).getImm());
  }

  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_IS_FPCLASS;
  }
};

/// Represents a logical binary operation.
class GLogicalBinOp : public GBinOp {
public:
  static bool classof(const MachineInstr *MI) {
    switch (MI->getOpcode()) {
    case TargetOpcode::G_AND:
    case TargetOpcode::G_OR:
    case TargetOpcode::G_XOR:
      return true;
    default:
      return false;
    }
  };
};

/// Represents an integer addition.
class GAdd : public GIntBinOp {
public:
  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_ADD;
  };
};

/// Represents a logical and.
class GAnd : public GLogicalBinOp {
public:
  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_AND;
  };
};

/// Represents a logical or.
class GOr : public GLogicalBinOp {
public:
  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_OR;
  };
};

/// Computes the bitwise exclusive-or of two values.
class GXor : public GLogicalBinOp {
public:
  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_XOR;
  };
};

/// Represents an extract vector element.
class GExtractVectorElement : public GenericMachineInstr {
public:
  Register getVectorReg() const { return getOperand(1).getReg(); }
  Register getIndexReg() const { return getOperand(2).getReg(); }

  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_EXTRACT_VECTOR_ELT;
  }
};

/// Represents an insert vector element.
class GInsertVectorElement : public GenericMachineInstr {
public:
  Register getVectorReg() const { return getOperand(1).getReg(); }
  Register getElementReg() const { return getOperand(2).getReg(); }
  Register getIndexReg() const { return getOperand(3).getReg(); }

  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_INSERT_VECTOR_ELT;
  }
};

/// Represents an extract subvector.
class GExtractSubvector : public GenericMachineInstr {
public:
  Register getSrcVec() const { return getOperand(1).getReg(); }
  uint64_t getIndexImm() const { return getOperand(2).getImm(); }

  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_EXTRACT_SUBVECTOR;
  }
};

/// Represents a insert subvector.
class GInsertSubvector : public GenericMachineInstr {
public:
  Register getBigVec() const { return getOperand(1).getReg(); }
  Register getSubVec() const { return getOperand(2).getReg(); }
  uint64_t getIndexImm() const { return getOperand(3).getImm(); }

  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_INSERT_SUBVECTOR;
  }
};

/// Compresses selected vector elements and fills unused lanes from a passthru.
class GVectorCompress : public GTernaryOp {
public:
  Register getVectorReg() const { return getSrc1Reg(); }
  Register getMaskReg() const { return getSrc2Reg(); }
  Register getPassthruReg() const { return getSrc3Reg(); }

  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_VECTOR_COMPRESS;
  }
};

/// Represents a freeze.
class GFreeze : public GenericMachineInstr {
public:
  Register getSourceReg() const { return getOperand(1).getReg(); }

  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_FREEZE;
  }
};

/// Represents a cast operation.
/// It models the llvm::CastInst concept.
/// The exception is bitcast.
class GCastOp : public GenericMachineInstr {
public:
  Register getSrcReg() const { return getOperand(1).getReg(); }

  static bool classof(const MachineInstr *MI) {
    switch (MI->getOpcode()) {
    case TargetOpcode::G_ADDRSPACE_CAST:
    case TargetOpcode::G_FPEXT:
    case TargetOpcode::G_FPTOSI:
    case TargetOpcode::G_FPTOUI:
    case TargetOpcode::G_FPTOSI_SAT:
    case TargetOpcode::G_FPTOUI_SAT:
    case TargetOpcode::G_FPTRUNC:
    case TargetOpcode::G_INTTOPTR:
    case TargetOpcode::G_PTRTOINT:
    case TargetOpcode::G_SEXT:
    case TargetOpcode::G_SITOFP:
    case TargetOpcode::G_TRUNC:
    case TargetOpcode::G_TRUNC_SSAT_S:
    case TargetOpcode::G_TRUNC_SSAT_U:
    case TargetOpcode::G_TRUNC_USAT_U:
    case TargetOpcode::G_UITOFP:
    case TargetOpcode::G_ZEXT:
    case TargetOpcode::G_ANYEXT:
      return true;
    default:
      return false;
    }
  };
};

/// Represents a sext.
class GSext : public GCastOp {
public:
  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_SEXT;
  };
};

/// Represents a zext.
class GZext : public GCastOp {
public:
  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_ZEXT;
  };
};

/// Represents an any ext.
class GAnyExt : public GCastOp {
public:
  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_ANYEXT;
  };
};

/// Represents a trunc.
class GTrunc : public GCastOp {
public:
  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_TRUNC;
  };
};

/// Sign-extends the low source-width bits within the existing value type.
class GSExtInReg : public GenericMachineInstr {
public:
  Register getSrcReg() const { return getReg(1); }
  unsigned getSourceSizeInBits() const {
    return static_cast<unsigned>(getOperand(2).getImm());
  }

  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_SEXT_INREG;
  }
};

/// Represents a vscale.
class GVScale : public GenericMachineInstr {
public:
  APInt getSrc() const { return getOperand(1).getCImm()->getValue(); }

  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_VSCALE;
  };
};

/// Represents a step vector.
class GStepVector : public GenericMachineInstr {
public:
  uint64_t getStep() const {
    return getOperand(1).getCImm()->getValue().getZExtValue();
  }

  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_STEP_VECTOR;
  };
};

/// Represents a G_CONSTANT.
class GConstant : public GenericMachineInstr {
public:
  const ConstantInt *getConstantInt() const { return getOperand(1).getCImm(); }
  const APInt &getValue() const { return getConstantInt()->getValue(); }

  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_CONSTANT;
  };
};

/// Defines a scalar floating-point constant.
class GFConstantInstr : public GenericMachineInstr {
public:
  const ConstantFP *getConstantFP() const { return getOperand(1).getFPImm(); }
  const APFloat &getValue() const { return getConstantFP()->getValueAPF(); }

  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_FCONSTANT;
  };
};

/// Represents an integer subtraction.
class GSub : public GIntBinOp {
public:
  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_SUB;
  };
};

/// Represents an integer multiplication.
class GMul : public GIntBinOp {
public:
  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_MUL;
  };
};

/// Models carry-less multiplication returning either half of the double-width
/// product.
class GCarrylessMul : public GIntBinOp {
public:
  bool returnsHighHalf() const {
    return getOpcode() == TargetOpcode::G_CLMULH;
  }

  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_CLMUL ||
           MI->getOpcode() == TargetOpcode::G_CLMULH;
  }
};

/// Returns the low half of a double-width carry-less product.
class GCLMul : public GCarrylessMul {
public:
  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_CLMUL;
  }
};

/// Returns the high half of a double-width carry-less product.
class GCLMulH : public GCarrylessMul {
public:
  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_CLMULH;
  }
};

/// Rotates a value by a register-specified amount.
class GRotate : public GIntBinOp {
public:
  Register getSrcReg() const { return getLHSReg(); }
  Register getAmountReg() const { return getRHSReg(); }
  bool isLeft() const { return getOpcode() == TargetOpcode::G_ROTL; }

  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_ROTL ||
           MI->getOpcode() == TargetOpcode::G_ROTR;
  }
};

/// Provides source, shift amount, direction, and saturation information.
class GShift : public GenericMachineInstr {
public:
  Register getSrcReg() const { return getOperand(1).getReg(); }
  Register getShiftReg() const { return getOperand(2).getReg(); }

  bool isLeftShift() const {
    return getOpcode() == TargetOpcode::G_SHL ||
           getOpcode() == TargetOpcode::G_USHLSAT ||
           getOpcode() == TargetOpcode::G_SSHLSAT;
  }
  bool isRightShift() const { return !isLeftShift(); }

  bool isSaturating() const {
    return getOpcode() == TargetOpcode::G_USHLSAT ||
           getOpcode() == TargetOpcode::G_SSHLSAT;
  }

  static bool classof(const MachineInstr *MI) {
    switch (MI->getOpcode()) {
    case TargetOpcode::G_SHL:
    case TargetOpcode::G_LSHR:
    case TargetOpcode::G_ASHR:
    case TargetOpcode::G_USHLSAT:
    case TargetOpcode::G_SSHLSAT:
      return true;
    default:
      return false;
    }
  };
};

/// Shifts a value left, filling low bits with zero.
class GShl : public GShift {
public:
  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_SHL;
  }
};

/// Shifts a value right, filling high bits with zero.
class GLShr : public GShift {
public:
  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_LSHR;
  }
};

/// Shifts a value right, replicating its sign bit.
class GAShr : public GShift {
public:
  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_ASHR;
  }
};

/// Represents a threeway compare.
class GSUCmp : public GenericMachineInstr {
public:
  Register getLHSReg() const { return getOperand(1).getReg(); }
  Register getRHSReg() const { return getOperand(2).getReg(); }

  bool isSigned() const { return getOpcode() == TargetOpcode::G_SCMP; }

  static bool classof(const MachineInstr *MI) {
    switch (MI->getOpcode()) {
    case TargetOpcode::G_SCMP:
    case TargetOpcode::G_UCMP:
      return true;
    default:
      return false;
    }
  };
};

/// Represents an integer-like extending operation.
class GExtOp : public GCastOp {
public:
  static bool classof(const MachineInstr *MI) {
    switch (MI->getOpcode()) {
    case TargetOpcode::G_SEXT:
    case TargetOpcode::G_ZEXT:
    case TargetOpcode::G_ANYEXT:
      return true;
    default:
      return false;
    }
  };
};

/// Represents an integer-like extending or truncating operation.
class GExtOrTruncOp : public GCastOp {
public:
  static bool classof(const MachineInstr *MI) {
    switch (MI->getOpcode()) {
    case TargetOpcode::G_SEXT:
    case TargetOpcode::G_ZEXT:
    case TargetOpcode::G_ANYEXT:
    case TargetOpcode::G_TRUNC:
      return true;
    default:
      return false;
    }
  };
};

/// Represents a splat vector.
class GSplatVector : public GenericMachineInstr {
public:
  Register getScalarReg() const { return getOperand(1).getReg(); }

  static bool classof(const MachineInstr *MI) {
    return MI->getOpcode() == TargetOpcode::G_SPLAT_VECTOR;
  };
};

} // namespace llvm

#endif // LLVM_CODEGEN_GLOBALISEL_GENERICMACHINEINSTRS_H
