#ifndef LLVM_ADT_PUSHRELABELMAXFLOW_H
#define LLVM_ADT_PUSHRELABELMAXFLOW_H

#include "llvm/ADT/GraphTraits.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/SetVector.h"
#include "llvm/ADT/SmallBitVector.h"
#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/ADT/SmallVector.h"

#include "llvm/ADT/iterator_range.h"
#include "llvm/Support/Debug.h"
#include "llvm/Support/MathExtras.h"
#include "llvm/Support/raw_ostream.h"
#include <algorithm>
#include <cassert>
#include <cstdint>
#include <deque>
#include <iterator>
#include <limits>
#include <string>

namespace llvm {

template <typename GraphT, typename WeightTy,
          typename GT = GraphTraits<GraphT *>>
class PushRelableMaxFlow {
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
  PushRelableMaxFlow(GraphT &Graph, NodeRef Source, NodeRef Sink)
      : Graph(Graph), Source(Source), Sink(Sink),
        Flow(GT::size(&Graph), SmallVector<WeightTy>(GT::size(&Graph), 0)),
        Capacity(GT::size(&Graph), SmallVector<WeightTy>(GT::size(&Graph))) {

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

    SmallVector<uint64_t> Height(Size, 0);
    Height[SourceIdx] = Size;

    SmallVector<uint64_t> Count(2 * Size + 1, 0);
    Count[0] = Size - 1;
    Count[Size] = 1;

    SmallVector<WeightTy> Excess(Size, 0);
    Excess[SourceIdx] = std::numeric_limits<WeightTy>::max();

    SmallBitVector Active(Size, false);
    Active[SourceIdx] = true;
    Active[SinkIdx] = true;

    std::deque<NodeIndex> Q;

    // init preflow
    for (NodeIndex Dst = 0; Dst < Size; ++Dst) {
      if (Dst != SourceIdx)
        pushFlow(SourceIdx, Dst, Height, Excess, Active, Q);
    }

    while (!Q.empty()) {
      NodeIndex Idx = Q.back();
      Q.pop_back();
      Active[Idx] = false;
      discharge(Idx, Height, Excess, Active, Count, Q);
    }

    return Excess[SinkIdx];
  }

private:
  void pushFlow(NodeIndex Src, NodeIndex Dst, SmallVectorImpl<uint64_t> &Height,
                SmallVectorImpl<WeightTy> &Excess, SmallBitVector &Active,
                std::deque<NodeIndex> &Q) {
    WeightTy NewFlow =
        std::min(Excess[Src], Capacity[Src][Dst] - Flow[Src][Dst]);

    if (NewFlow == 0)
      return;

    if (Height[Src] <= Height[Dst])
      return;

    Flow[Src][Dst] += NewFlow;
    Flow[Dst][Src] -= NewFlow;

    Excess[Src] -= NewFlow;
    Excess[Dst] += NewFlow;

    if (!Active[Dst] && Excess[Dst] > 0) {
      Active[Dst] = true;
      Q.push_front(Dst);
    }
  }

  void discharge(NodeIndex Src, SmallVectorImpl<uint64_t> &Height,
                 SmallVectorImpl<WeightTy> &Excess, SmallBitVector &Active,
                 SmallVectorImpl<uint64_t> &Count, std::deque<NodeIndex> &Q) {
    for (NodeIndex Dst = 0; Dst < GT::size(&Graph) && Excess[Src] != 0; ++Dst) {
      pushFlow(Src, Dst, Height, Excess, Active, Q);
    }

    if (Excess[Src] > 0) {
      if (Count[Height[Src]] == 1) {
        gap(Height[Src], Height, Excess, Active, Count, Q);
      } else {
        relabel(Src, Height, Excess, Active, Count, Q);
      }
    }
  }

  void gap(uint64_t H, SmallVectorImpl<uint64_t> &Height,
           SmallVectorImpl<WeightTy> &Excess, SmallBitVector &Active,
           SmallVectorImpl<uint64_t> &Count, std::deque<NodeIndex> &Q) {
    auto Size = GT::size(&Graph);

    for (NodeIndex Idx = 0; Idx < Size; ++Idx) {
      if (Height[Idx] < H)
        continue;

      Count[Height[Idx]] -= 1;
      Height[Idx] = std::max(Height[Idx], (uint64_t(Size)) + 1);
      Count[Height[Idx]] += 1;

      if (!Active[Idx] && Excess[Idx] > 0) {
        Active[Idx] = true;
        Q.push_front(Idx);
      }
    }
  }

  void relabel(NodeIndex Src, SmallVectorImpl<uint64_t> &Height,
               SmallVectorImpl<WeightTy> &Excess, SmallBitVector &Active,
               SmallVectorImpl<uint64_t> &Count, std::deque<NodeIndex> &Q) {
    auto Size = GT::size(&Graph);

    Count[Height[Src]] -= 1;
    Height[Src] = 2 * Size;
    for (NodeIndex Dst = 0; Dst < Size; ++Dst) {
      if (Capacity[Src][Dst] > Flow[Src][Dst])
        Height[Src] = std::min(Height[Src], Height[Dst] + 1);
    }
    Count[Height[Src]] += 1;

    if (!Active[Src] && Excess[Src] > 0) {
      Active[Src] = true;
      Q.push_front(Src);
    }
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

#endif // LLVM_ADT_PUSHRELABELMAXFLOW_H
