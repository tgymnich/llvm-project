#ifndef LLVM_ADT_FLOWNETWORK_H
#define LLVM_ADT_FLOWNETWORK_H

#include "llvm/ADT/DirectedGraph.h"
#include "llvm/ADT/GraphTraits.h"
#include "llvm/ADT/SCCIterator.h"
#include "llvm/ADT/SmallPtrSet.h"

#include "llvm/ADT/iterator_range.h"
#include "llvm/IR/Instruction.h"

namespace llvm {

//===--------------------------------------------------------------------===//
// Derived nodes, edges and graph types based on DirectedGraph.
//===--------------------------------------------------------------------===//

class FlowNetworkNode;
class FlowNetworkEdge;
using FNNodeBase = DGNode<FlowNetworkNode, FlowNetworkEdge>;
using FNEdgeBase = DGEdge<FlowNetworkNode, FlowNetworkEdge>;
using FlowNetworkBase = DirectedGraph<FlowNetworkNode, FlowNetworkEdge>;

class FlowNetworkNode : public FNNodeBase {
private:
  const Instruction *Inst;

public:
  FlowNetworkNode() = delete;
  FlowNetworkNode(const Instruction *Inst) : Inst(Inst) {}
  FlowNetworkNode(const FlowNetworkNode &N) = default;
  FlowNetworkNode(FlowNetworkNode &&N)
      : FNNodeBase(std::move(N)), Inst(N.Inst) {}

  /// Getter for the kind of this node.
  const Instruction *getInstruction() const { return Inst; }
};

class FlowNetworkEdge : public FNEdgeBase {
  private:
    size_t Capacity;

  public:
    explicit FlowNetworkEdge(FlowNetworkNode &N) = delete;
    FlowNetworkEdge(FlowNetworkNode &N, size_t C)
        : FNEdgeBase(N), Capacity(C) {}
    FlowNetworkEdge(const FlowNetworkEdge &E)
        : FNEdgeBase(E), Capacity(E.getCapacity()) {}
    FlowNetworkEdge(FlowNetworkEdge &&E)
        : FNEdgeBase(std::move(E)), Capacity(E.Capacity) {}
    FlowNetworkEdge &operator=(const FlowNetworkEdge &E) = default;

    size_t getCapacity() const { return Capacity; }
};

class FlowNetwork : public FlowNetworkBase {
public:
  FlowNetwork() = default;
  ~FlowNetwork(){};
};

//===--------------------------------------------------------------------===//
// GraphTraits specializations for the DGTest
//===--------------------------------------------------------------------===//

template <> struct GraphTraits<FlowNetworkNode *> {
  using NodeRef = FlowNetworkNode *;
  using EdgeRef = FlowNetworkEdge *;

  static FlowNetworkNode *FNGetTargetNode(DGEdge<FlowNetworkNode, FlowNetworkEdge> *P) {
    return &P->getTargetNode();
  }

  // Provide a mapped iterator so that the GraphTrait-based implementations can
  // find the target nodes without having to explicitly go through the edges.
  using ChildIteratorType =
      mapped_iterator<FlowNetworkNode::iterator, decltype(&FNGetTargetNode)>;
  using ChildEdgeIteratorType = FlowNetworkNode::iterator;

  static NodeRef getEntryNode(NodeRef N) { return N; }
  static ChildIteratorType child_begin(NodeRef N) {
    return ChildIteratorType(N->begin(), &FNGetTargetNode);
  }
  static ChildIteratorType child_end(NodeRef N) {
    return ChildIteratorType(N->end(), &FNGetTargetNode);
  }

  static ChildEdgeIteratorType child_edge_begin(NodeRef N) {
    return N->begin();
  }
  static ChildEdgeIteratorType child_edge_end(NodeRef N) { return N->end(); }
};

template <>
struct GraphTraits<FlowNetwork *> : public GraphTraits<FlowNetworkNode *> {
  using nodes_iterator = FlowNetwork::iterator;
  static NodeRef getEntryNode(FlowNetwork *FN) { return *FN->begin(); }
  static nodes_iterator nodes_begin(FlowNetwork *FN) { return FN->begin(); }
  static nodes_iterator nodes_end(FlowNetwork *FN) { return FN->end(); }
  static unsigned size (FlowNetwork *FN) { return FN->size(); }
  static unsigned size(const FlowNetwork *FN) { return FN->size(); }
};

} // namespace llvm

#endif // LLVM_ADT_FLOWNETWORK_H