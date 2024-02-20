#ifndef LLVM_ADT_DINICMAXFLOW_H
#define LLVM_ADT_DINICMAXFLOW_H

#include "llvm/ADT/GraphTraits.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/SetVector.h"
#include "llvm/ADT/SmallBitVector.h"
#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/ADT/SmallVector.h"

#include "llvm/ADT/iterator_range.h"
#include "llvm/Support/Debug.h"
#include "llvm/Support/raw_ostream.h"
#include <algorithm>
#include <deque>
#include <iterator>
#include <limits>
#include <string>

namespace llvm {

template <typename GraphT, typename WeightTy,
          typename GT = GraphTraits<GraphT *>>
class DinicMaxFlow {
  using NodeRef = typename GT::NodeRef;
  using EdgeRef = typename GT::EdgeRef;
  using NodeIndex = size_t;

private:
  GraphT &Graph;

  NodeRef Source;
  NodeRef Sink;

  NodeIndex SourceIdx;
  NodeIndex SinkIdx;

  SmallVector<SmallVector<WeightTy>> Flow;
  SmallVector<SmallVector<WeightTy>> Capacity;

public:
  DinicMaxFlow(GraphT &Graph, NodeRef Source, NodeRef Sink)
      : Graph(Graph), Source(Source), Sink(Sink),
        Flow(GT::size(&Graph), SmallVector<int64_t>(GT::size(&Graph), 0)),
        Capacity(GT::size(&Graph), SmallVector<int64_t>(GT::size(&Graph))) {

    auto Nodes = make_range(GT::nodes_begin(&Graph), GT::nodes_end(&Graph));
    for (auto &&[Idx, Node] : enumerate(Nodes)) {
      if (Node == Source)
        SourceIdx = Idx;

      if (Node == Sink)
        SinkIdx = Idx;

      auto Edges =
          make_range(GT::child_edge_begin(Node), GT::child_edge_end(Node));
      for (EdgeRef Edge : Edges) {
        NodeRef Dst = &Edge->getTargetNode();
        NodeIndex DstIdx =
            std::distance(GT::nodes_begin(&Graph), find(Nodes, Dst));
        Capacity[Idx][DstIdx] = Edge->getCapacity();
      }
    }
  };

  void getSourceSideMinCut(SmallPtrSetImpl<NodeRef> &Result) {
    auto Nodes = make_range(GT::nodes_begin(&Graph), GT::nodes_end(&Graph));
    SetVector<NodeIndex> Q;
    Q.insert(SourceIdx);
    Result.insert(Source);

    while (!Q.empty()) {
      NodeIndex SrcIdx = Q.pop_back_val();

      for (auto &&[DstIdx, Dst] : enumerate(Nodes)) {
        if (Capacity[SrcIdx][DstIdx] - Flow[SrcIdx][DstIdx] > 0 &&
            !Result.contains(Dst) && !Q.contains(DstIdx)) {
          Q.insert(DstIdx);
          Result.insert(Dst);
        }
      }
    }
  }

  void getSinkSideMinCut(SmallPtrSetImpl<NodeRef> &Result) {
    SmallPtrSet<NodeRef, 32> SourceSide;
    getSourceSideMinCut(SourceSide);

    auto Nodes = make_range(GT::nodes_begin(&Graph), GT::nodes_end(&Graph));
    for (auto &Node : Nodes) {
      if (!SourceSide.contains(Node))
        Result.insert(Node);
    }
  }

  void getMinCut(SmallPtrSetImpl<NodeRef> &SourceSide,
                 SmallPtrSetImpl<NodeRef> &SinkSide) {
    getSourceSideMinCut(SourceSide);

    auto Nodes = make_range(GT::nodes_begin(&Graph), GT::nodes_end(&Graph));
    for (auto &Node : Nodes) {
      if (!SourceSide.contains(Node))
        SinkSide.insert(Node);
    }
  }

  const SmallVector<SmallVector<WeightTy>> &getFlowMatrix() const {
    return Flow;
  }

  WeightTy computeMaxFlow() {
    auto Size = GT::size(&Graph);

    SmallVector<int64_t> P(Size, 0);

    WeightTy F = 0;

    while (true) {
        WeightTy NewFlow = blockingFlow(P);

        if (NewFlow == 0)
            break;
        F += NewFlow; 
    }
  }

private:
  WeightTy blockingFlow(SmallVectorImpl<int64_t> &P) {
    auto Size = GT::size(&Graph);

    std::fill(P.begin(), P.end(), -1);
    P[SourceIdx] = -2;

    std::deque<int64_t> Q;

    while (!Q.empty()) {
      NodeIndex Src = Q.back();
      Q.pop_back();

      for (int64_t Dst = 0; Dst < Size; ++Dst) {
        if (P[Dst] == -1 && Capacity[Src][Dst] > Flow[Src][Dst]) {
          P[Dst] = Src;
          Q.push_front(Dst);
        }
      }
    }

    if (P[SinkIdx] == -1)
      return 0;

    WeightTy TotalFlow = 0;

    for (int64_t Idx = 0; Idx < Size; ++Idx) {
      WeightTy F = std::numeric_limits<WeightTy>::max();
      int64_t Dst = SinkIdx;
      int64_t Src = Idx;

      while (Dst != SourceIdx) {
        if (Dst == -1) {
          F = 0;
          break;
        } else {
          F = std::min(F, Capacity[Src][Dst] - Flow[Src][Dst]);
          Dst = Src;
          Src = P[Src];
        }
      }

      if (F == 0)
        continue;

      Dst = SinkIdx;
      Src = Idx;
      
      while (Dst != SourceIdx) {
        Flow[Src][Dst] += F;
        Flow[Dst][Src] -= F;
        Dst = Src;
        Src = P[Src];
      }

      TotalFlow += F;
    }
    return TotalFlow;
  }

public:
  LLVM_DUMP_METHOD void dump() {
    dbgs() << "Flow:"
           << "\n";
    for (auto &Row : Flow) {
      for (int64_t Element : Row) {
        dbgs() << std::to_string(Element) << "\t";
      }
      dbgs() << "\n";
    }
    dbgs() << "\n";

    dbgs() << "Capacity:"
           << "\n";
    for (auto Row : Capacity) {
      for (WeightTy Element : Row) {
        dbgs() << std::to_string(Element) << "\t";
      }
      dbgs() << "\n";
    }
    dbgs() << "\n";
  }
};

} // namespace llvm

#endif // LLVM_ADT_DINICMAXFLOW_H
