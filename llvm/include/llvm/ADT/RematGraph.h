

#ifndef LLVM_ADT_REMATGRAPH_H
#define LLVM_ADT_REMATGRAPH_H

#include "llvm/ADT/BitVector.h"
#include "llvm/ADT/GraphTraits.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/SmallVector.h"

#include "llvm/ADT/SparseMultiSet.h"
#include "llvm/ADT/UniqueVector.h"
#include <cassert>

namespace llvm {

template <typename NodeTy, typename WeightTy> class RematGraphTraits;

template<typename NodeRef>
struct NodeOrSourceOrSink {
  enum Type { NODE, SOURCE, SINK };
  
  Type Ty;
  NodeRef Node;

private:
  NodeOrSourceOrSink(Type Ty, NodeRef N) : Ty(Ty), Node(N) {};

public:
  static NodeOrSourceOrSink<NodeRef> CreateSource() {
    return NodeOrSourceOrSink<NodeRef>(SOURCE, nullptr);
  }

  static NodeOrSourceOrSink<NodeRef> CreateSink() {
    return NodeOrSourceOrSink<NodeRef>(SINK, nullptr);
  }

  static NodeOrSourceOrSink<NodeRef> CreateNode(NodeRef Node) {
    return NodeOrSourceOrSink<NodeRef>(NODE, Node);
  }
};

template <typename NodeTy, typename WeightTy> struct RematGraph {
public:
  using NodeType = NodeTy;
  using NodeRef = NodeTy *;
  using WeightType = WeightTy;
  using AdjacencyMatrixTy = SmallVector<SmallVector<WeightTy>>;
  using NodeListTy = UniqueVector<NodeRef>;

  using iterator = typename NodeListTy::iterator;
  using const_iterator = typename NodeListTy::const_iterator;

  using nodes_iterator = typename NodeListTy::iterator;
  using ChildIteratorType = filter_iterator<nodes_iterator, bool (*)(NodeRef)>;

  friend class RematGraphTraits<NodeTy, WeightTy>;

private:
  NodeRef Root;
  NodeListTy Nodes;
  AdjacencyMatrixTy AdjacencyMatrix;

public:
  RematGraph(){};

  struct AMNode {
    NodeRef Node;
    RematGraph<NodeTy, WeightTy> *Graph;
  };

  bool addNode(NodeRef Node) {
    if (!Nodes.idFor(Node))
      return false;

    // auto AMN = std::make_unique<AMNode>(Node, this);

    Nodes.insert(Node);

    for (auto &Row : AdjacencyMatrix)
      Row.push_back(0);

    AdjacencyMatrix.push_back(SmallVector<WeightTy>(this->size(), 0));

    return true;
  }

  bool removeNode(NodeRef Node) {
    // FIXME: this is slow!
    unsigned NodeId = Nodes.idFor(Node);

    assert(NodeId != 0);

    NodeListTy NewNodes;
    for (auto Node :
         make_filter_range(Nodes, [&](NodeRef N) { return Node != N; }))
      NewNodes.insert(Node);

    for (auto &&[From, Row] : enumerate(AdjacencyMatrix))
      for (auto &&[To, Weight] : enumerate(Row))
        if (From == NodeId - 1 || To == NodeId - 1)
          Weight = 0;

    AdjacencyMatrix.erase(AdjacencyMatrix.begin() + (NodeId - 1));
    Nodes = NewNodes;
  }

  void addEdge(NodeRef From, NodeRef To, WeightTy Weight) {
    unsigned FromId = Nodes.idFor(From);
    unsigned ToId = Nodes.idFor(To);

    assert(FromId != 0 && ToId != 0);

    AdjacencyMatrix[FromId - 1][ToId - 1] = Weight;
  }

  void removeEdge(NodeRef From, NodeRef To) {
    unsigned FromId = Nodes.idFor(From);
    unsigned ToId = Nodes.idFor(To);

    assert(FromId != 0 && ToId != 0);

    AdjacencyMatrix[FromId - 1][ToId - 1] = 0.0;
  }

  NodeRef getEntryNode() const { return Root; }

  size_t size() const { return Nodes.Size(); }

  const_iterator begin() const { return Nodes.begin(); }
  const_iterator end() const { return Nodes.end(); }
  iterator begin() { return Nodes.begin(); }
  iterator end() { return Nodes.end(); }

  const NodeType &front() const { return *Nodes.front(); }
  NodeType &front() { return *Nodes.front(); }
  const NodeType &back() const { return *Nodes.back(); }
  NodeType &back() { return *Nodes.back(); }

  ChildIteratorType child_begin(NodeRef Node) {
    auto Filter = [&](unsigned To) {
      unsigned From = Nodes.idFor(Node);
      return From < size() && To < size() &&
             AdjacencyMatrix[From - 1][To - 1] != 0;
    };
    return ChildIterType(Nodes.begin(), Filter);
  }

  ChildIteratorType child_end(NodeRef Node) {
    auto Filter = [&](unsigned To) {
      unsigned From = Nodes.idFor(Node);
      return From < size() && To < size() &&
             AdjacencyMatrix[From - 1][To - 1] != 0;
    };
    return ChildIterType(Nodes.end(), Filter);
  }
};

template <typename NodeTy, typename WeightTy> class RematGraphTraits {
  using GraphTy = RematGraph<NodeTy, WeightTy>;
  using NodeRef = std::pair<const GraphTy *, typename GraphTy::NodeRef>;

  class WrappedSuccIterator
      : public iterator_adaptor_base<
            WrappedSuccIterator, typename GraphTy::nodes_iterator,
            typename std::iterator_traits<
                typename GraphTy::nodes_iterator>::iterator_category,
            NodeRef, std::ptrdiff_t, NodeRef *, NodeRef> {

    using BaseT = iterator_adaptor_base<
        WrappedSuccIterator, typename GraphTy::nodes_iterator,
        typename std::iterator_traits<
            typename GraphTy::nodes_iterator>::iterator_category,
        NodeRef, std::ptrdiff_t, NodeRef *, NodeRef>;

    const GraphTy *Graph;

  public:
    WrappedSuccIterator(typename GraphTy::nodes_iterator Begin,
                        const GraphTy *G)
        : BaseT(Begin), Graph(G) {}

    NodeRef operator*() const { return {Graph, *this->I}; }
  };

  static NodeRef getEntryNode(const GraphTy &G) {
    return {&G, G.getEntryNode()};
  }

  using ChildIteratorType = WrappedSuccIterator;

  static ChildIteratorType child_begin(NodeRef Node) {
    return WrappedSuccIterator(Node.first.child_begin(Node.second), Node.first);
  }

  static ChildIteratorType child_end(NodeRef Node) {
    return WrappedSuccIterator(Node.first.child_end(Node.second), Node.first);
  }
};

template <typename NodeTy, typename WeightTy>
    struct GraphTraits <RematGraph<NodeTy, WeightTy>> : RematGraphTraits<NodeTy, WeightTy> {};

} // namespace llvm

#endif // LLVM_ADT_REMATGRAPH_H
