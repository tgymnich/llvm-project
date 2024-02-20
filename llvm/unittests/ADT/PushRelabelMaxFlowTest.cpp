//===- llvm/unittest/ADT/PushRelabelMaxFlowTest.cpp
//-----------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// PushRelabelMaxFlow unit tests.
//
//===----------------------------------------------------------------------===//

#include "llvm/ADT/PushRelabelMaxFlow.h"
#include "gtest/gtest.h"

#include "llvm/ADT/DirectedGraph.h"
#include "llvm/ADT/GraphTraits.h"
#include "llvm/ADT/SCCIterator.h"
#include "llvm/ADT/SmallPtrSet.h"
#include "gtest/gtest.h"

namespace llvm {

//===--------------------------------------------------------------------===//
// Derived nodes, edges and graph types based on DirectedGraph.
//===--------------------------------------------------------------------===//

class FNTestNode;
class FNTestEdge;
using FNTestNodeBase = DGNode<FNTestNode, FNTestEdge>;
using FNTestEdgeBase = DGEdge<FNTestNode, FNTestEdge>;
using FNTestBase = DirectedGraph<FNTestNode, FNTestEdge>;

class FNTestNode : public FNTestNodeBase {
public:
  FNTestNode() = default;
};

class FNTestEdge : public FNTestEdgeBase {
private:
  int64_t Capacity;

public:
  explicit FNTestEdge(FNTestNode &N) = delete;
  FNTestEdge(FNTestNode &N, int64_t C) : FNTestEdgeBase(N), Capacity(C) {}
  FNTestEdge(const FNTestEdge &E)
      : FNTestEdgeBase(E), Capacity(E.getCapacity()) {}
  FNTestEdge(FNTestEdge &&E)
      : FNTestEdgeBase(std::move(E)), Capacity(E.Capacity) {}
  FNTestEdge &operator=(const FNTestEdge &E) = default;

  size_t getCapacity() const { return Capacity; }
};

class FNTestGraph : public FNTestBase {
public:
  FNTestGraph() = default;
  ~FNTestGraph(){};
};

using EdgeListTy = SmallVector<FNTestEdge *, 2>;

//===--------------------------------------------------------------------===//
// GraphTraits specializations for the DGTest
//===--------------------------------------------------------------------===//

template <> struct GraphTraits<FNTestNode *> {
  using NodeRef = FNTestNode *;
  using EdgeRef = FNTestEdge *;

  static FNTestNode *DGTestGetTargetNode(DGEdge<FNTestNode, FNTestEdge> *P) {
    return &P->getTargetNode();
  }

  // Provide a mapped iterator so that the GraphTrait-based implementations can
  // find the target nodes without having to explicitly go through the edges.
  using ChildIteratorType =
      mapped_iterator<FNTestNode::iterator, decltype(&DGTestGetTargetNode)>;
  using ChildEdgeIteratorType = FNTestNode::EdgeListTy::iterator;

  static NodeRef getEntryNode(NodeRef N) { return N; }
  static ChildIteratorType child_begin(NodeRef N) {
    return ChildIteratorType(N->begin(), &DGTestGetTargetNode);
  }
  static ChildIteratorType child_end(NodeRef N) {
    return ChildIteratorType(N->end(), &DGTestGetTargetNode);
  }

  static ChildEdgeIteratorType child_edge_begin(NodeRef N) {
    return N->getEdges().begin();
  }
  static ChildEdgeIteratorType child_edge_end(NodeRef N) {
    return N->getEdges().end();
  }
};

template <>
struct GraphTraits<FNTestGraph *> : public GraphTraits<FNTestNode *> {
  using nodes_iterator = FNTestGraph::iterator;
  static NodeRef getEntryNode(FNTestGraph *DG) { return *DG->begin(); }
  static nodes_iterator nodes_begin(FNTestGraph *DG) { return DG->begin(); }
  static nodes_iterator nodes_end(FNTestGraph *DG) { return DG->end(); }
  static unsigned size(FNTestGraph *FN) { return FN->size(); }
  static unsigned size(const FNTestGraph *FN) { return FN->size(); }
};

//===--------------------------------------------------------------------===//
// Test various modification and query functions.
//===--------------------------------------------------------------------===//

TEST(PushRelabelMaxFlowTest, SinkSideMinCut) {
  FNTestGraph DG;
  FNTestNode Source, N2, N3, N4, Sink;
  FNTestEdge E1(N2, 2), E2(N3, 2), E3(N4, 3), E4(N2, 1), E5(Sink, 3);

  DG.addNode(Source);
  DG.addNode(N2);
  DG.addNode(N3);
  DG.addNode(N4);
  DG.addNode(Sink);

  DG.connect(Source, N2, E1);
  DG.connect(Source, N3, E2);
  DG.connect(N3, N4, E3);
  DG.connect(N3, N2, E4);
  DG.connect(N2, Sink, E5);

  PushRelableMaxFlow<FNTestGraph, int64_t> MaxFlow(DG, &Source, &Sink);

  int64_t Flow = MaxFlow.computeMaxFlow();

  EXPECT_EQ(Flow, 3);


  SmallVector<SmallVector<int64_t>> ExpectedFlowMatrix = {
      {0, 2, 1, 0, 0}, 
      {-2, 0, -1, 0, 3}, 
      {-1, 1, 0, 0, 0},
      {0, 0, 0, 0, 0}, 
      {0, -3, 0, 0, 0},
  };

    SmallVector<SmallVector<int64_t>> CapacityMatrix = {
      {0, 2, 2, 0, 0}, 
      {0, 0, 0, 0, 3}, 
      {0, 1, 0, 3, 0},
      {0, 0, 0, 0, 0}, 
      {0, 0, 0, 0, 0},
  };

  EXPECT_EQ(MaxFlow.getFlowMatrix(), ExpectedFlowMatrix);


  SmallPtrSet<FNTestNode *, 5> SourceSide;
  SmallPtrSet<FNTestNode *, 5> SourceSideExpected = {&Source, &N3, &N4};
  MaxFlow.getSourceSideMinCut(SourceSide);

  EXPECT_EQ(SourceSide, SourceSideExpected);


  SmallPtrSet<FNTestNode *, 5> SinkSide;
  SmallPtrSet<FNTestNode *, 5> SinkSideExpected = {&N2, &Sink};
  MaxFlow.getSinkSideMinCut(SinkSide);

  EXPECT_EQ(SinkSide, SinkSideExpected);
}

} // namespace llvm