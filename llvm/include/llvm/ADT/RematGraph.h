

#ifndef LLVM_ADT_REMATGRAPH_H
#define LLVM_ADT_REMATGRAPH_H

#include "llvm/ADT/GraphTraits.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/SmallVector.h"

#include "llvm/ADT/UniqueVector.h"
#include "llvm/IR/Value.h"
#include "llvm/Support/Debug.h"
#include "llvm/Support/raw_ostream.h"

#include <cassert>
#include <functional>
#include <variant>

namespace llvm {

template <typename NodeRef> struct FlowNode {
  struct Source {};
  struct Sink {};

  std::variant<Source, Sink, NodeRef> Val;

private:
  FlowNode(std::variant<Source, Sink, NodeRef> Val) : Val(Val){};

public:
  static FlowNode<NodeRef> CreateSource() {
    return FlowNode<NodeRef>(Source());
  }

  static FlowNode<NodeRef> CreateSink() { return FlowNode<NodeRef>(Sink()); }

  static FlowNode<NodeRef> CreateNode(NodeRef Node) {
    return FlowNode<NodeRef>(Node);
  }

  bool operator==(const FlowNode &Rhs) const {
    if (std::holds_alternative<Source>(Val)) {
      return std::holds_alternative<Source>(Rhs.Val);
    }

    if (std::holds_alternative<Sink>(Val)) {
      return std::holds_alternative<Sink>(Rhs.Val);
    }

    if (std::holds_alternative<NodeRef>(Val) &&
        std::holds_alternative<NodeRef>(Rhs.Val)) {
      return std::get<NodeRef>(Val) == std::get<NodeRef>(Rhs.Val);
    }

    return false;
   }

  bool operator<(const FlowNode &Rhs) const {
    if (std::holds_alternative<Source>(Val)) {
      return !std::holds_alternative<Source>(Rhs.Val);
    }

    if (std::holds_alternative<Sink>(Val)) {
      return !(std::holds_alternative<Source>(Rhs.Val) ||
               std::holds_alternative<Sink>(Rhs.Val));
    }

    if (std::holds_alternative<NodeRef>(Val) &&
        std::holds_alternative<NodeRef>(Rhs.Val)) {
      return std::get<NodeRef>(Val) < std::get<NodeRef>(Rhs.Val);
    }

    if (std::holds_alternative<NodeRef>(Val)) {
      return !(std::holds_alternative<Source>(Rhs.Val) ||
               std::holds_alternative<Sink>(Rhs.Val));
    }

    return false;
  }

  void print(raw_ostream &OS, bool IsForDebug = false) const {
    if (std::holds_alternative<Source>(Val)) {
      OS << "<src>";
    } else if (std::holds_alternative<Sink>(Val)) {
      OS << "<sink>";
    } else if (std::holds_alternative<NodeRef>(Val)) {
      NodeRef Node = std::get<NodeRef>(Val);
      OS << *Node;
    }
  }
};

template <typename NodeRef>
inline raw_ostream &operator<<(raw_ostream &OS, const FlowNode<NodeRef> &Node) {
  Node.print(OS, true);
  return OS;
}

template <typename NodeTy, typename WeightTy> struct RematGraph {
public:
  using NodeType = NodeTy;
  using NodeRef = NodeTy &;
  using WeightType = WeightTy;
  using AdjacencyMatrixTy = SmallVector<SmallVector<WeightTy>>;
  using NodeListTy = UniqueVector<NodeTy>;

  using iterator = typename NodeListTy::iterator;
  using const_iterator = typename NodeListTy::const_iterator;

  using nodes_iterator = typename NodeListTy::iterator;
  // using ChildIteratorType = filter_iterator<nodes_iterator,
  // function_ref<bool(NodeRef)>>;

private:
  NodeTy Root;
  NodeListTy Nodes;
  AdjacencyMatrixTy AdjacencyMatrix;

public:
  RematGraph(NodeTy Root) : Root(Root) { addNode(Root); };

  bool addNode(NodeTy Node) {
    if (Nodes.idFor(Node) != 0)
      return false;

    Nodes.insert(Node);

    for (auto &Row : AdjacencyMatrix)
      Row.push_back(0);

    AdjacencyMatrix.push_back(SmallVector<WeightTy>(size(), 0));

    return true;
  }

  bool removeNode(NodeTy Node) {
    // FIXME: this is slow!
    unsigned NodeId = Nodes.idFor(Node);

    assert(NodeId != 0);

    NodeListTy NewNodes;
    for (auto &Node :
         make_filter_range(Nodes, [&](NodeTy N) { return Node != N; }))
      NewNodes.insert(Node);

    for (auto &&[From, Row] : enumerate(AdjacencyMatrix))
      for (auto &&[To, Weight] : enumerate(Row))
        if (From == NodeId - 1 || To == NodeId - 1)
          Weight = 0;

    AdjacencyMatrix.erase(AdjacencyMatrix.begin() + (NodeId - 1));
    Nodes = NewNodes;
  }

  void addEdge(NodeTy From, NodeTy To, WeightTy Weight) {
    unsigned FromId = Nodes.idFor(From);
    unsigned ToId = Nodes.idFor(To);

    assert(FromId != 0 && ToId != 0);

    AdjacencyMatrix[FromId - 1][ToId - 1] = Weight;
  }

  void removeEdge(NodeTy From, NodeTy To) {
    unsigned FromId = Nodes.idFor(From);
    unsigned ToId = Nodes.idFor(To);

    assert(FromId != 0 && ToId != 0);

    AdjacencyMatrix[FromId - 1][ToId - 1] = 0.0;
  }

  NodeRef getEntryNode() { return Root; }

  size_t size() const { return Nodes.size(); }

  const AdjacencyMatrixTy &getWeights() const { return AdjacencyMatrix; }

  unsigned operator[](NodeTy Node) const { return Nodes.idFor(Node) - 1; }

  const NodeTy &operator[](unsigned Id) const { return Nodes[Id + 1]; }

  const_iterator begin() const { return Nodes.begin(); }
  const_iterator end() const { return Nodes.end(); }
  iterator begin() { return Nodes.begin(); }
  iterator end() { return Nodes.end(); }

  const NodeType &front() const { return *Nodes.front(); }
  NodeType &front() { return *Nodes.front(); }
  const NodeType &back() const { return *Nodes.back(); }
  NodeType &back() { return *Nodes.back(); }

  // using ChildIteratorType =
  //     filter_iterator<nodes_iterator, function_ref<bool(NodeRef)>>;

  auto children(NodeRef From) {
    auto Filter = [&](NodeRef To) {
      unsigned FromId = Nodes.idFor(From);
      unsigned ToId = Nodes.idFor(To);
      return FromId < size() && ToId < size() &&
             AdjacencyMatrix[FromId - 1][ToId - 1] != 0;
    };

    return make_filter_range(Nodes, Filter);
  }

  auto child_begin(NodeRef From) {
    auto Filter = [&](NodeRef To) {
      unsigned FromId = Nodes.idFor(From);
      unsigned ToId = Nodes.idFor(To);
      return FromId < size() && ToId < size() &&
             AdjacencyMatrix[FromId - 1][ToId - 1] != 0;
    };

    return make_filter_range(Nodes, Filter).begin();
  }

  auto child_end(NodeRef From) {
    auto Filter = [&](NodeRef To) {
      unsigned FromId = Nodes.idFor(From);
      unsigned ToId = Nodes.idFor(To);
      return FromId < size() && ToId < size() &&
             AdjacencyMatrix[FromId - 1][ToId - 1] != 0;
    };

    return make_filter_range(Nodes, Filter).end();
  }

  void print(raw_ostream &OS, bool IsForDebug = false) const {
    for (auto Idx = 0; Idx < size(); ++Idx) {
      dbgs() << "\t" << std::to_string(Idx);
    }
    dbgs() << "\n";
    for (auto &&[Idx, Row] : enumerate(AdjacencyMatrix)) {
      dbgs() << std::to_string(Idx) << "\t";
      for (auto &Weight : Row) {
        if (Weight != 0) {
          dbgs() << std::to_string(Weight);
        } else {
          dbgs() << ".";
        }
        dbgs() << "\t";
      }
      dbgs() << "\n";
    }
  }

  LLVM_DUMP_METHOD void dump() const { print(dbgs(), true); }
};

// template <typename NodeTy, typename WeightTy> struct RematGraphTraits {
//   using GraphTy = RematGraph<NodeTy, WeightTy>;
//   using NodeRef = std::pair<const GraphTy *, typename GraphTy::NodeRef>;

// private:
//   class WrappedSuccIterator
//       : public iterator_adaptor_base<
//             WrappedSuccIterator, typename GraphTy::nodes_iterator,
//             typename std::iterator_traits<
//                 typename GraphTy::nodes_iterator>::iterator_category,
//             NodeRef, std::ptrdiff_t, NodeRef *, NodeRef> {

//     using BaseT = iterator_adaptor_base<
//         WrappedSuccIterator, typename GraphTy::nodes_iterator,
//         typename std::iterator_traits<
//             typename GraphTy::nodes_iterator>::iterator_category,
//         NodeRef, std::ptrdiff_t, NodeRef *, NodeRef>;

//     const GraphTy *Graph;

//   public:
//     WrappedSuccIterator(typename GraphTy::nodes_iterator Begin, const GraphTy
//     *G)
//         : BaseT(Begin), Graph(G) {}

//     NodeRef operator*() { return {Graph, *this->I}; }
//   };

// public:
//   static NodeRef getEntryNode(const GraphTy &G) {
//     return {&G, G.getEntryNode()};
//   }

// public:
//   using ChildIteratorType = WrappedSuccIterator;

//   static ChildIteratorType child_begin(NodeRef Node) {
//     return WrappedSuccIterator(Node.first->child_begin(Node.second),
//     Node.first);
//   }

//   static ChildIteratorType child_end(NodeRef Node) {
//     return WrappedSuccIterator(Node.first->child_end(Node.second),
//     Node.first);
//   }
//   };

//   template <typename NodeTy, typename WeightTy>
//   struct GraphTraits<RematGraph<NodeTy, WeightTy>> : RematGraphTraits<NodeTy,
//   WeightTy> {};

} // namespace llvm

namespace std {
template <typename NodeRef> struct std::hash<llvm::FlowNode<NodeRef>> {
  std::size_t operator()(llvm::FlowNode<NodeRef> const &FN) const {

    if (std::holds_alternative<llvm::FlowNode<NodeRef>::Source>(FN.Val)) {
      return std::hash<uint8_t>{}(0);
    } else if (std::holds_alternative<llvm::FlowNode<NodeRef>::Sink>(FN.Val)) {
      return std::hash<uint8_t>{}(1);
    } else if (std::holds_alternative<NodeRef>(FN.Val)) {
      NodeRef Node = std::get<NodeRef>(FN.Val);
      return std::hash<NodeRef>{}(Node);
    }
  }
};
} // namespace std

#endif // LLVM_ADT_REMATGRAPH_H
