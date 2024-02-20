#ifndef LLVM_ADT_FLOWNETWORK_H
#define LLVM_ADT_FLOWNETWORK_H

#include "llvm/ADT/DirectedGraph.h"
#include "llvm/ADT/GraphTraits.h"
#include "llvm/IR/Instruction.h"
#include <string>
#include <utility>
#include <variant>

namespace llvm {

//===--------------------------------------------------------------------===//
// Derived nodes, edges and graph types based on DirectedGraph.
//===--------------------------------------------------------------------===//

class FlowNetworkNode;
class FlowNetworkEdge;
using FNNodeBase = DGNode<FlowNetworkNode, FlowNetworkEdge>;
using FNEdgeBase = DGEdge<FlowNetworkNode, FlowNetworkEdge>;
using FlowNetworkBase = DirectedGraph<FlowNetworkNode, FlowNetworkEdge>;

class FlowNetworkEdge : public FNEdgeBase {
private:
  int64_t Capacity;

public:
  explicit FlowNetworkEdge(FlowNetworkNode &N) = delete;
  FlowNetworkEdge(FlowNetworkNode &N, int64_t C) : FNEdgeBase(N), Capacity(C) {}
  FlowNetworkEdge(const FlowNetworkEdge &E)
      : FNEdgeBase(E), Capacity(E.getCapacity()) {}
  FlowNetworkEdge(FlowNetworkEdge &&E)
      : FNEdgeBase(std::move(E)), Capacity(E.Capacity) {}
  FlowNetworkEdge &operator=(const FlowNetworkEdge &E) = default;

  size_t getCapacity() const { return Capacity; }
};
inline raw_ostream &operator<<(raw_ostream &, const FlowNetworkNode &);

inline raw_ostream &operator<<(raw_ostream &OS, const FlowNetworkEdge &Edge) {
  OS << "[" << std::to_string(Edge.getCapacity()) << "] to "
     << Edge.getTargetNode() << "\n";
  return OS;
}

class FlowNetworkNode : public FNNodeBase {
private:
  struct Source {};
  struct Sink {};
  std::variant<Source, Sink, std::pair<Instruction *, bool>> Val;

  friend FNNodeBase;

public:
  FlowNetworkNode() = delete;
  FlowNetworkNode(
      std::variant<Source, Sink, std::pair<Instruction *, bool>> Val)
      : Val(Val){};
  FlowNetworkNode(Instruction *Inst, bool isIncoming)
      : Val(std::make_pair(Inst, isIncoming)){};
  FlowNetworkNode(Source Src) : Val(Src){};
  FlowNetworkNode(Sink Sink) : Val(Sink){};
  FlowNetworkNode(const FlowNetworkNode &N) = default;
  FlowNetworkNode(FlowNetworkNode &&N) : FNNodeBase(std::move(N)), Val(N.Val){};

public:
  static FlowNetworkNode &CreateSource() {
    FlowNetworkNode *Node = new FlowNetworkNode(Source());
    return *Node;
  }

  static FlowNetworkNode &CreateSink() {
    FlowNetworkNode *Node = new FlowNetworkNode(Sink());
    return *Node;
  }

  static FlowNetworkNode &CreateIncomingNode(Instruction *Inst) {
    FlowNetworkNode *Node = new FlowNetworkNode(Inst, true);
    return *Node;
  }

  static FlowNetworkNode &CreateOutgoingNode(Instruction *Inst) {
    FlowNetworkNode *Node = new FlowNetworkNode(Inst, false);
    return *Node;
  }

public:
  inline bool isSource() const { return std::holds_alternative<Source>(Val); }
  inline bool isSink() const { return std::holds_alternative<Sink>(Val); }
  inline bool isInstruction() const {
    return std::holds_alternative<std::pair<Instruction *, bool>>(Val);
  }
  inline Instruction *getInstruction() const {
    return std::get<std::pair<Instruction *, bool>>(Val).first;
  }
  inline bool getIncoming() const {
    return std::get<std::pair<Instruction *, bool>>(Val).second;
  }

public:
  void print(raw_ostream &OS, bool IsForDebug = false) const {
    if (isSource()) {
      OS << "<src>";
    } else if (isSink()) {
      OS << "<sink>";
    } else if (isInstruction()) {
      Instruction *Inst = getInstruction();
      OS << (getIncoming() ? "[In] " : "[Out] ") << *Inst;
    }
  }

protected:
  bool isEqualTo(const FlowNetworkNode &Rhs) const {
    if (isSource()) {
      return Rhs.isSource();
    }

    if (isSink()) {
      return Rhs.isSink();
    }

    if (isInstruction() && Rhs.isInstruction()) {
      return getInstruction() == Rhs.getInstruction() &&
             getIncoming() == Rhs.getIncoming();
    }

    return false;
  }
};

inline raw_ostream &operator<<(raw_ostream &OS, const FlowNetworkNode &Node) {
  Node.print(OS, true);
  return OS;
}

class FlowNetwork : public FlowNetworkBase {
public:
  using NodeType = FlowNetworkNode;
  using EdgeType = FlowNetworkEdge;

public:
  FlowNetwork() = default;
  ~FlowNetwork() {
    for (auto *Node : Nodes) {
      for (auto *Edge : *Node) {
        delete Edge;
      }
      delete Node;
    }
  }

  bool addNode(NodeType &N) {
    if (findNode(N) != Nodes.end()) {
      delete &N;
      return false;
    }

    Nodes.push_back(&N);
    return true;
  }

  void addEdge(NodeType &Src, NodeType &Dst, int64_t Capacity) {
    auto &SrcIt = **findNode(Src);
    auto &DstIt = **findNode(Dst);

    if (SrcIt.hasEdgeTo(DstIt))
      return;

    EdgeType *Edge = new EdgeType(DstIt, Capacity);
    connect(SrcIt, DstIt, *Edge);
  }
};

inline raw_ostream &operator<<(raw_ostream &OS, const FlowNetwork &G) {
  for (FlowNetworkNode *Node : G) {
    OS << *Node << "\n";
    OS << (Node->getEdges().empty() ? " Edges:none!\n" : " Edges:\n");
    for (const auto &Edge : Node->getEdges())
      OS.indent(2) << *Edge;
    OS << "\n";
  }
  return OS;
}

//===--------------------------------------------------------------------===//
// GraphTraits specializations for the DGTest
//===--------------------------------------------------------------------===//

template <> struct GraphTraits<FlowNetworkNode *> {
  using NodeRef = FlowNetworkNode *;
  using EdgeRef = FlowNetworkEdge *;

  static FlowNetworkNode *
  FNGetTargetNode(DGEdge<FlowNetworkNode, FlowNetworkEdge> *P) {
    return &P->getTargetNode();
  }

  // Provide a mapped iterator so that the GraphTrait-based implementations can
  // find the target nodes without having to explicitly go through the edges.
  using ChildIteratorType =
      mapped_iterator<FlowNetworkNode::iterator, decltype(&FNGetTargetNode)>;
  using ChildEdgeIteratorType = FlowNetworkNode::EdgeListTy::iterator;

  static NodeRef getEntryNode(NodeRef N) { return N; }
  static ChildIteratorType child_begin(NodeRef N) {
    return ChildIteratorType(N->begin(), &FNGetTargetNode);
  }
  static ChildIteratorType child_end(NodeRef N) {
    return ChildIteratorType(N->end(), &FNGetTargetNode);
  }

  static ChildEdgeIteratorType child_edge_begin(NodeRef N) {
    return N->getEdges().begin();
  }
  static ChildEdgeIteratorType child_edge_end(NodeRef N) {
    return N->getEdges().end();
  }
};

template <>
struct GraphTraits<FlowNetwork *> : public GraphTraits<FlowNetworkNode *> {
  using nodes_iterator = FlowNetwork::iterator;
  static NodeRef getEntryNode(FlowNetwork *FN) { return *FN->begin(); }
  static nodes_iterator nodes_begin(FlowNetwork *FN) { return FN->begin(); }
  static nodes_iterator nodes_end(FlowNetwork *FN) { return FN->end(); }
  static unsigned size(FlowNetwork *FN) { return FN->size(); }
  static unsigned size(const FlowNetwork *FN) { return FN->size(); }
};

} // namespace llvm

#endif // LLVM_ADT_FLOWNETWORK_H