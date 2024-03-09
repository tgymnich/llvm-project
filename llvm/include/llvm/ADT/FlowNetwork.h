#ifndef LLVM_ADT_FLOWNETWORK_H
#define LLVM_ADT_FLOWNETWORK_H

#include "llvm/ADT/DirectedGraph.h"
#include "llvm/ADT/GraphTraits.h"
#include "llvm/IR/Argument.h"
#include "llvm/IR/Instruction.h"
#include "llvm/IR/Instructions.h"
#include "llvm/Support/DOTGraphTraits.h"
#include "llvm/Support/GraphWriter.h"
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

class FlowNetworkBuilder;

class FlowNetworkNode : public FNNodeBase {
private:
  struct Source {};
  struct Sink {};

  using Union = std::variant<Source, Sink, Argument *, AllocaInst *,
                             std::pair<Instruction *, bool>>;

private:
  Union Val;

  friend FNNodeBase;
  friend FlowNetworkBuilder;

public:
  FlowNetworkNode() = delete;
  FlowNetworkNode(Union Val) : Val(Val){};
  FlowNetworkNode(Instruction *Inst, bool IsIncoming)
      : Val(std::make_pair(Inst, IsIncoming)){};
  FlowNetworkNode(Source Src) : Val(Src){};
  FlowNetworkNode(Sink Sink) : Val(Sink){};
  FlowNetworkNode(const FlowNetworkNode &N) = default;
  FlowNetworkNode(FlowNetworkNode &&N) : FNNodeBase(std::move(N)), Val(N.Val){};

public:
  inline bool isSource() const { return std::holds_alternative<Source>(Val); }
  inline bool isSink() const { return std::holds_alternative<Sink>(Val); }
  inline bool isInstruction() const {
    return std::holds_alternative<std::pair<Instruction *, bool>>(Val);
  }
  inline bool isArgument() const {
    return std::holds_alternative<Argument *>(Val);
  }
  inline bool isAlloca() const {
    return std::holds_alternative<AllocaInst *>(Val);
  }
  inline Instruction *getInstruction() const {
    return std::get<std::pair<Instruction *, bool>>(Val).first;
  }
  inline bool getIncoming() const {
    return std::get<std::pair<Instruction *, bool>>(Val).second;
  }
  inline Argument *getArgument() const { return std::get<Argument *>(Val); }
  inline AllocaInst *getAlloca() const { return std::get<AllocaInst *>(Val); }

public:
  void print(raw_ostream &OS, bool IsForDebug = false) const {
    if (isSource()) {
      OS << "<src>";
    } else if (isSink()) {
      OS << "<sink>";
    } else if (isInstruction()) {
      Instruction *Inst = getInstruction();
      OS << (getIncoming() ? "[In] " : "[Out] ") << *Inst;
    } else if (isArgument()) {
      OS << getArgument();
    } else if (isAlloca()) {
      OS << getAlloca();
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

    if (isArgument() && Rhs.isArgument()) {
      return getArgument() == Rhs.getArgument();
    }

    if (isAlloca() && Rhs.isAlloca()) {
      return getAlloca() == Rhs.getAlloca();
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
  using WeightType = int64_t;

  friend class FlowNetworkBuilder;

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

  void viewGraph() const {
#ifndef NDEBUG
    ViewGraph(this, "flow-network", true);
#else
    errs() << "FlowNetwork::viewGraph is only available in debug builds on "
           << "systems with Graphviz or gv!\n";
#endif // NDEBUG
  }
};

class FlowNetworkBuilder {
private:
  using NodeType = typename FlowNetwork::NodeType;
  using EdgeType = typename FlowNetwork::EdgeType;
  using WeightType = typename FlowNetwork::WeightType;

private:
  FlowNetwork &FN;

public:
  FlowNetworkBuilder(FlowNetwork &FN) : FN(FN) {}

public:
  NodeType &createSource() {
    NodeType *Node = new NodeType(NodeType::Source());
    FN.addNode(*Node);
    return *Node;
  }

  NodeType &createSink() {
    NodeType *Node = new NodeType(NodeType::Sink());
    FN.addNode(*Node);
    return *Node;
  }

  NodeType &createIncomingNode(Instruction *Inst) {
    NodeType *Node = new NodeType(Inst, true);
    FN.addNode(*Node);
    return *Node;
  }

  NodeType &createOutgoingNode(Instruction *Inst) {
    NodeType *Node = new NodeType(Inst, false);
    FN.addNode(*Node);
    return *Node;
  }

  NodeType &createArgumentNode(Argument *Arg) {
    NodeType *Node = new NodeType(Arg);
    FN.addNode(*Node);
    return *Node;
  }

  NodeType &createAllocaNode(AllocaInst *Alloca) {
    NodeType *Node = new NodeType(Alloca);
    FN.addNode(*Node);
    return *Node;
  }

public:
  bool addInstructionNode(Instruction *I, WeightType Capacity) {
    auto *It = find_if(FN.Nodes, [I](NodeType *N) {
      return N->isInstruction() && N->getInstruction() == I && N->getIncoming();
    });

    if (It != FN.Nodes.end())
      return false;

    NodeType *IncomingNode = new NodeType(I, true);
    NodeType *OutgoingNode = new NodeType(I, false);

    FN.Nodes.push_back(IncomingNode);
    FN.Nodes.push_back(OutgoingNode);

    EdgeType *Edge = new EdgeType(*OutgoingNode, Capacity);
    FN.connect(*IncomingNode, *OutgoingNode, *Edge);

    return true;
  }

  bool addSourceNode() {
    auto *It = find_if(FN.Nodes, [](NodeType *N) { return N->isSource(); });

    if (It != FN.Nodes.end())
      return false;

    NodeType *N = new NodeType(NodeType::Source());
    FN.Nodes.push_back(N);

    return true;
  }

  bool addSinkNode() {
    auto *It = find_if(FN.Nodes, [](NodeType *N) { return N->isSink(); });

    if (It != FN.Nodes.end())
      return false;

    NodeType *N = new NodeType(NodeType::Sink());
    FN.Nodes.push_back(N);

    return true;
  }

  bool addArgumentNode(Argument *Arg) {
    auto *It = find_if(FN.Nodes, [Arg](NodeType *N) {
      return N->isArgument() && N->getArgument() == Arg;
    });

    if (It != FN.Nodes.end())
      return false;

    NodeType *N = new NodeType(Arg);
    FN.Nodes.push_back(N);

    return true;
  }

  bool addAllocaNode(AllocaInst *Alloca) {
    auto *It = find_if(FN.Nodes, [Alloca](NodeType *N) {
      return N->isAlloca() && N->getAlloca() == Alloca;
    });

    if (It != FN.Nodes.end())
      return false;

    NodeType *N = new NodeType(Alloca);
    FN.Nodes.push_back(N);

    return true;
  }

  void addInstructionEdge(Instruction *Src, Instruction *Dst,
                          WeightType Capacity) {
    auto *SrcIt = find_if(FN.Nodes, [Src](NodeType *N) {
      return N->isInstruction() && N->getInstruction() == Src &&
             !N->getIncoming();
    });
    auto *DstIt = find_if(FN.Nodes, [Dst](NodeType *N) {
      return N->isInstruction() && N->getInstruction() == Dst &&
             N->getIncoming();
    });

    NodeType *SrcNode =
        SrcIt != FN.Nodes.end() ? *SrcIt : new NodeType(Src, false);
    NodeType *DstNode =
        DstIt != FN.Nodes.end() ? *DstIt : new NodeType(Dst, true);

    if (SrcIt == FN.Nodes.end())
      FN.Nodes.push_back(SrcNode);

    if (DstIt == FN.Nodes.end())
      FN.Nodes.push_back(DstNode);

    if (SrcNode->hasEdgeTo(*DstNode))
      return;

    EdgeType *Edge = new EdgeType(*DstNode, Capacity);
    FN.connect(*SrcNode, *DstNode, *Edge);
  }

  void addArgumentEdge(Argument *Src, Instruction *Dst, WeightType Capacity) {
    auto *SrcIt = find_if(FN.Nodes, [Src](NodeType *N) {
      return N->isArgument() && N->getArgument() == Src;
    });
    auto *DstIt = find_if(FN.Nodes, [Dst](NodeType *N) {
      return N->isInstruction() && N->getInstruction() == Dst &&
             N->getIncoming();
    });

    NodeType *SrcNode = SrcIt != FN.Nodes.end() ? *SrcIt : new NodeType(Src);
    NodeType *DstNode =
        DstIt != FN.Nodes.end() ? *DstIt : new NodeType(Dst, true);

    if (SrcIt == FN.Nodes.end())
      FN.Nodes.push_back(SrcNode);

    if (DstIt == FN.Nodes.end())
      FN.Nodes.push_back(DstNode);

    if (SrcNode->hasEdgeTo(*DstNode))
      return;

    EdgeType *Edge = new EdgeType(*DstNode, Capacity);
    FN.connect(*SrcNode, *DstNode, *Edge);
  }

  void addAllocaEdge(AllocaInst *Src, Instruction *Dst, WeightType Capacity) {
    auto *SrcIt = find_if(FN.Nodes, [Src](NodeType *N) {
      return N->isAlloca() && N->getAlloca() == Src;
    });
    auto *DstIt = find_if(FN.Nodes, [Dst](NodeType *N) {
      return N->isInstruction() && N->getInstruction() == Dst &&
             N->getIncoming();
    });

    NodeType *SrcNode = SrcIt != FN.Nodes.end() ? *SrcIt : new NodeType(Src);
    NodeType *DstNode =
        DstIt != FN.Nodes.end() ? *DstIt : new NodeType(Dst, true);

    if (SrcIt == FN.Nodes.end())
      FN.Nodes.push_back(SrcNode);

    if (DstIt == FN.Nodes.end())
      FN.Nodes.push_back(DstNode);

    if (SrcNode->hasEdgeTo(*DstNode))
      return;

    EdgeType *Edge = new EdgeType(*DstNode, Capacity);
    FN.connect(*SrcNode, *DstNode, *Edge);
  }

  void addSourceEdge(Instruction *Dst, WeightType Capacity) {
    auto *SrcIt = find_if(FN.Nodes, [](NodeType *N) { return N->isSource(); });
    auto *DstIt = find_if(FN.Nodes, [Dst](NodeType *N) {
      return N->isInstruction() && N->getInstruction() == Dst &&
             N->getIncoming();
    });

    NodeType *SrcNode =
        SrcIt != FN.Nodes.end() ? *SrcIt : new NodeType(NodeType::Source());
    NodeType *DstNode =
        DstIt != FN.Nodes.end() ? *DstIt : new NodeType(Dst, true);

    if (SrcIt == FN.Nodes.end())
      FN.Nodes.push_back(SrcNode);

    if (DstIt == FN.Nodes.end())
      FN.Nodes.push_back(DstNode);

    if (SrcNode->hasEdgeTo(*DstNode))
      return;

    EdgeType *Edge = new EdgeType(*DstNode, Capacity);
    FN.connect(*SrcNode, *DstNode, *Edge);
  }

  void addSourceEdge(Argument *Dst, WeightType Capacity) {
    auto *SrcIt = find_if(FN.Nodes, [](NodeType *N) { return N->isSource(); });
    auto *DstIt = find_if(FN.Nodes, [Dst](NodeType *N) {
      return N->isArgument() && N->getArgument() == Dst;
    });

    NodeType *SrcNode =
        SrcIt != FN.Nodes.end() ? *SrcIt : new NodeType(NodeType::Source());
    NodeType *DstNode = DstIt != FN.Nodes.end() ? *DstIt : new NodeType(Dst);

    if (SrcIt == FN.Nodes.end())
      FN.Nodes.push_back(SrcNode);

    if (DstIt == FN.Nodes.end())
      FN.Nodes.push_back(DstNode);

    if (SrcNode->hasEdgeTo(*DstNode))
      return;

    EdgeType *Edge = new EdgeType(*DstNode, Capacity);
    FN.connect(*SrcNode, *DstNode, *Edge);
  }

  void addSinkEdge(Instruction *Src, WeightType Capacity) {
    auto *SrcIt = find_if(FN.Nodes, [Src](NodeType *N) {
      return N->isInstruction() && N->getInstruction() == Src &&
             !N->getIncoming();
    });
    auto *DstIt = find_if(FN.Nodes, [](NodeType *N) { return N->isSink(); });

    NodeType *SrcNode =
        SrcIt != FN.Nodes.end() ? *SrcIt : new NodeType(Src, false);
    NodeType *DstNode =
        DstIt != FN.Nodes.end() ? *DstIt : new NodeType(NodeType::Sink());

    if (SrcIt == FN.Nodes.end())
      FN.Nodes.push_back(SrcNode);

    if (DstIt == FN.Nodes.end())
      FN.Nodes.push_back(DstNode);

    if (SrcNode->hasEdgeTo(*DstNode))
      return;

    EdgeType *Edge = new EdgeType(*DstNode, Capacity);
    FN.connect(*SrcNode, *DstNode, *Edge);
  }

  void addSinkEdge(Argument *Src, WeightType Capacity) {
    auto *SrcIt = find_if(FN.Nodes, [Src](NodeType *N) {
      return N->isArgument() && N->getArgument() == Src;
    });
    auto *DstIt = find_if(FN.Nodes, [](NodeType *N) { return N->isSink(); });

    NodeType *SrcNode = SrcIt != FN.Nodes.end() ? *SrcIt : new NodeType(Src);
    NodeType *DstNode = DstIt != FN.Nodes.end() ? *DstIt : new NodeType(NodeType::Sink());

    if (SrcIt == FN.Nodes.end())
      FN.Nodes.push_back(SrcNode);

    if (DstIt == FN.Nodes.end())
      FN.Nodes.push_back(DstNode);

    if (SrcNode->hasEdgeTo(*DstNode))
      return;

    EdgeType *Edge = new EdgeType(*DstNode, Capacity);
    FN.connect(*SrcNode, *DstNode, *Edge);
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
// GraphTraits specializations for the FlowNetwork
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
};

template <> struct GraphTraits<const FlowNetworkNode *> {
  using NodeRef = const FlowNetworkNode *;
  using EdgeRef = const FlowNetworkEdge *;

  static const FlowNetworkNode *
  FNGetTargetNode(DGEdge<FlowNetworkNode, FlowNetworkEdge> *P) {
    return &P->getTargetNode();
  }

  // Provide a mapped iterator so that the GraphTrait-based implementations can
  // find the target nodes without having to explicitly go through the edges.
  using ChildIteratorType = mapped_iterator<FlowNetworkNode::const_iterator,
                                            decltype(&FNGetTargetNode)>;
  using ChildEdgeIteratorType = FlowNetworkNode::EdgeListTy::const_iterator;

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
struct GraphTraits<const FlowNetwork *>
    : public GraphTraits<const FlowNetworkNode *> {
  using nodes_iterator = FlowNetwork::const_iterator;
  static NodeRef getEntryNode(const FlowNetwork *FN) { return *FN->begin(); }
  static nodes_iterator nodes_begin(const FlowNetwork *FN) {
    return FN->begin();
  }
  static nodes_iterator nodes_end(const FlowNetwork *FN) { return FN->end(); }
  static unsigned size(const FlowNetwork *FN) { return FN->size(); }
};

//===--------------------------------------------------------------------===//
// DOTGraphTraits specializations for the FlowNetwork
//===--------------------------------------------------------------------===//

template <>
struct DOTGraphTraits<const FlowNetwork *> : public DefaultDOTGraphTraits {
  DOTGraphTraits(bool isSimple = false) : DefaultDOTGraphTraits(isSimple) {}

  // std::string getNodeIdentifierLabel(const FlowNetworkNode *N, const FlowNetwork *FN) {
  //   std::string Output;
  //   llvm::raw_string_ostream OS(Output);
  //   OS << static_cast<const void *>(N);
  //   OS.flush();
  //   return "";
  // }

  std::string getNodeLabel(const FlowNetworkNode *N, const FlowNetwork *FN) {
    std::string Output;
    llvm::raw_string_ostream OS(Output);

    if (N->isSource()) {
      OS << "<src>";
    } else if (N->isSink()) {
      OS << "<sink>";
    } else if (N->isInstruction()) {
      if (isSimple())
        N->getInstruction()->printAsOperand(OS);
      else
        OS << *N->getInstruction();
    } else if (N->isArgument()) {
      N->getArgument()->printAsOperand(OS);
    } else if (N->isAlloca()) {
      if (isSimple())
        N->getAlloca()->printAsOperand(OS);
      else
        OS << *N->getAlloca();
    }

    OS.flush();
    return Output;
  }

  std::string
  getEdgeAttributes(const FlowNetworkNode *Node,
                    GraphTraits<const FlowNetwork *>::ChildIteratorType EI,
                    const FlowNetwork *FN) {
    std::string Output;
    raw_string_ostream OS(Output);

    SmallVector<FlowNetworkEdge *> EL;
    Node->findEdgesTo(**EI, EL);

    OS << format("label=\"%d\"", EL.front()->getCapacity());

    OS.flush();
    return Output;
  }

  // static void addCustomGraphFeatures(const FlowNetwork *FN, GraphWriter<const FlowNetwork *> &GW) {
  //   raw_ostream &OS = GW.getOStream();

  //   for (const FlowNetworkNode *N : *FN) {
  //     if (N->isInstruction() && N->getIncoming()) {
  //       Instruction *I = N->getInstruction();
  //       OS.indent(4) << "subgraph cluster" << static_cast<const void *>(I) << " {\n";
  //       auto It = GraphTraits<const FlowNetwork*>::child_begin(N);
  //       OS.indent(8) << "Node" << static_cast<const void *>(N) << ";\n";
  //       OS.indent(8) << "Node" << static_cast<const void *>(*It) << ";\n";
  //       OS << "}\n";
  //     }
  //   }
  // }
};

} // namespace llvm

#endif // LLVM_ADT_FLOWNETWORK_H