#include "llvm/IR/Instructions.h"
#include "llvm/Support/Debug.h"
#include <deque>

using namespace llvm;

namespace {

// RematGraph is used to construct a DAG for rematerializable instructions
// When the constructor is invoked with a candidate instruction (which is
// materializable) it builds a DAG of materializable instructions from that
// point.
// Typically, for each instruction identified as re-materializable across a
// suspend point, a RematGraph will be created.
struct RematGraph {
  // Each RematNode in the graph contains the edges to instructions providing
  // operands in the current node.
  struct RematNode {
    Instruction *Node;
    SmallVector<RematNode *> Operands;
    RematNode() = default;
    RematNode(Instruction *V) : Node(V) {}
  };

  RematNode *EntryNode;
  using RematNodeMap =
      SmallMapVector<Instruction *, std::unique_ptr<RematNode>, 8>;
  RematNodeMap Remats;
  const std::function<bool(Instruction &)> &MaterializableCallback;
  const std::function<bool(Instruction &, User *)> &CrossingCallback;

  RematGraph(Instruction *I,
             const std::function<bool(Instruction &)> &MaterializableCallback,
             const std::function<bool(Instruction &, User *)> &CrossingCallback)
      : MaterializableCallback(MaterializableCallback),
        CrossingCallback(CrossingCallback) {
    std::unique_ptr<RematNode> FirstNode = std::make_unique<RematNode>(I);
    EntryNode = FirstNode.get();
    std::deque<std::unique_ptr<RematNode>> WorkList;
    addNode(std::move(FirstNode), WorkList, cast<User>(I));
    while (WorkList.size()) {
      std::unique_ptr<RematNode> N = std::move(WorkList.front());
      WorkList.pop_front();
      addNode(std::move(N), WorkList, cast<User>(I));
    }
  }

  void addNode(std::unique_ptr<RematNode> NUPtr,
               std::deque<std::unique_ptr<RematNode>> &WorkList,
               User *FirstUse) {
    RematNode *N = NUPtr.get();
    if (Remats.count(N->Node))
      return;

    // We haven't see this node yet - add to the list
    Remats[N->Node] = std::move(NUPtr);
    for (auto &Def : N->Node->operands()) {
      Instruction *D = dyn_cast<Instruction>(Def.get());
      if (!D || !MaterializableCallback(*D) || !CrossingCallback(*D, FirstUse))
        continue;

      if (Remats.count(D)) {
        // Already have this in the graph
        N->Operands.push_back(Remats[D].get());
        continue;
      }

      bool NoMatch = true;
      for (auto &I : WorkList) {
        if (I->Node == D) {
          NoMatch = false;
          N->Operands.push_back(I.get());
          break;
        }
      }
      if (NoMatch) {
        // Create a new node
        std::unique_ptr<RematNode> ChildNode = std::make_unique<RematNode>(D);
        N->Operands.push_back(ChildNode.get());
        WorkList.push_back(std::move(ChildNode));
      }
    }
  }

#if !defined(NDEBUG) || defined(LLVM_ENABLE_DUMP)
  void dump() const {
    dbgs() << "Entry (";
    if (EntryNode->Node->getParent()->hasName())
      dbgs() << EntryNode->Node->getParent()->getName();
    else
      EntryNode->Node->getParent()->printAsOperand(dbgs(), false);
    dbgs() << ") : " << *EntryNode->Node << "\n";
    for (auto &E : Remats) {
      dbgs() << *(E.first) << "\n";
      for (RematNode *U : E.second->Operands)
        dbgs() << "  " << *U->Node << "\n";
    }
  }
#endif
};
} // end anonymous namespace

namespace llvm {

template <> struct GraphTraits<RematGraph *> {
  using NodeRef = RematGraph::RematNode *;
  using ChildIteratorType = RematGraph::RematNode **;

  static NodeRef getEntryNode(RematGraph *G) { return G->EntryNode; }
  static ChildIteratorType child_begin(NodeRef N) {
    return N->Operands.begin();
  }
  static ChildIteratorType child_end(NodeRef N) { return N->Operands.end(); }
};

} // end namespace llvm