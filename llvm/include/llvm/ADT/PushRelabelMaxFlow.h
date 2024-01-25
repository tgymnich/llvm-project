#ifndef LLVM_ADT_PUSHRELABELMAXFLOW_H
#define LLVM_ADT_PUSHRELABELMAXFLOW_H

#include "llvm/ADT/GraphTraits.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/SmallSet.h"
#include "llvm/ADT/SmallVector.h"

#include "llvm/ADT/iterator_range.h"
#include "llvm/Support/Debug.h"
#include "llvm/Support/raw_ostream.h"
#include <algorithm>
#include <iterator>
#include <limits>
#include <optional>
#include <queue>
#include <string>

namespace llvm {

template <class GraphT, class GT = GraphTraits<GraphT *>>
class PushRelableMaxFlow {
  using NodeRef = typename GT::NodeRef;
  using EdgeRef = typename GT::EdgeRef;
  using NodeIndex = int64_t;

private:
  GraphT &Graph;
  const int64_t Size;

  NodeRef Source;
  NodeRef Sink;

  SmallVector<SmallVector<int64_t>> Flow;
  SmallVector<SmallVector<int64_t>> Capacity;

  SmallVector<int64_t> Height;
  SmallVector<int64_t> Excess;

public:
  PushRelableMaxFlow(GraphT &Graph, NodeRef Source, NodeRef Sink)
      : Graph(Graph), Size(GT::size(&Graph)), Source(Source), Sink(Sink),
        Height(Size, 0), Excess(Size, 0),
        Flow(Size, SmallVector<int64_t>(Size, 0)),
        Capacity(Size, SmallVector<int64_t>(Size, 0)) {
    auto Nodes = make_range(GT::nodes_begin(&Graph), GT::nodes_end(&Graph));
    for (auto &&[Idx, Node] : enumerate(Nodes)) {
      for (EdgeRef Edge : Node->getEdges()) {
        NodeRef Dst = &Edge->getTargetNode();
        NodeIndex DstIdx =
            std::distance(GT::nodes_begin(&Graph), find(Nodes, Dst));
        Capacity[Idx][DstIdx] = Edge->getCapacity();
      }
    }
  };

  void getSourceSideMinCut(SmallVectorImpl<NodeRef> &Result) {
    auto Nodes = make_range(GT::nodes_begin(&Graph), GT::nodes_end(&Graph));
    NodeIndex Source =
        std::distance(GT::nodes_begin(&Graph), find(Nodes, this->Source));
    SmallSet<NodeIndex, 32> Reachable;
    Reachable.insert(Source);
    std::queue<NodeIndex> Worklist;
    Worklist.push(Source);

    while (!Worklist.empty()) {
      NodeIndex Todo = Worklist.front();
      Worklist.pop();
      for (NodeIndex i = 0; i < Size; ++i) {
        if (residualCapacity(Todo, i) > 0) {
          if (std::get<1>(Reachable.insert(i))) {
            Worklist.push(i);
          }
        }
      }
    }

    Result.reserve(Reachable.size());

    for (auto &&[Idx, Node] : enumerate(Nodes)) {
      if (Reachable.contains(Idx))
        Result.push_back(Node);
    }
  }

  void getSinkSideMinCut(SmallVector<NodeRef> &Result) {
    auto Nodes = make_range(GT::nodes_begin(&Graph), GT::nodes_end(&Graph));
    NodeIndex SinkIdx =
        std::distance(GT::nodes_begin(&Graph), find(nodes(Graph), Sink));
    SmallSet<NodeIndex, 32> Reachable;
    Reachable.insert(SinkIdx);
    std::queue<NodeIndex> Worklist;
    Worklist.push(SinkIdx);

    while (!Worklist.empty()) {
      NodeIndex Todo = Worklist.front();
      Worklist.pop();
      for (NodeIndex Idx = 0; Idx < Size; ++Idx) {
        if (residualCapacity(Idx, Todo) > 0) {
          if (std::get<1>(Reachable.insert(Idx))) {
            Worklist.push(Idx);
          }
        }
      }
    }

    Result.reserve(Reachable.size());

    for (auto &&[Idx, Node] : enumerate(Nodes)) {
      if (Reachable.contains(Idx))
        Result.push_back(Node);
    }
  }

  int64_t computeMaxFlow() {
    auto Nodes = make_range(GT::nodes_begin(&Graph), GT::nodes_end(&Graph));
    NodeIndex SourceIdx =
        std::distance(GT::nodes_begin(&Graph), find(Nodes, Source));
    NodeIndex SinkIdx = std::distance(GT::nodes_begin(&Graph), find(Nodes, Sink));

    // init height
    Height[SourceIdx] = Size;
    Excess[SourceIdx] = std::numeric_limits<int64_t>::max();

    // init preflow
    for (NodeIndex Idx = 0; Idx < Size; ++Idx) {
      if (Idx != SourceIdx)
        push(SourceIdx, Idx);
    }

    SmallVector<NodeIndex> Current;
    findMaxHeightVertices(SourceIdx, SinkIdx, Current);

    while (!Current.empty()) {
      for (NodeIndex i : Current) {
        bool Pushed = false;
        for (NodeIndex j = 0; j < Size && Excess[i]; j++) {
          if (residualCapacity(i, j) > 0 && isAdmissible(i, j)) {
            push(i, j);
            Pushed = true;
          }
        }
        if (!Pushed) {
          relabel(i);
          break;
        }
      }

      Current.clear();
      findMaxHeightVertices(SourceIdx, SinkIdx, Current);
    }

    return Excess[SinkIdx];
  }

  LLVM_DUMP_METHOD void dump() {
    dbgs() << "Flow:" << "\n";
    for (auto Row : Flow) {
      for (int64_t Element : Row) {
        dbgs() << std::to_string(Element) << "\t";
      }
      dbgs() << "\n";
    }
    dbgs() << "\n";

    dbgs() << "Capacity:" << "\n";
    for (auto Row : Capacity) {
      for (int64_t Element : Row) {
        dbgs() << std::to_string(Element) << "\t";
      }
      dbgs() << "\n";
    }
    dbgs() << "\n";

    dbgs() << "Height:" << "\n";
    for (int64_t Element : Height) {
      dbgs() << std::to_string(Element) << "\t";
    }
    dbgs() << "\n";

    dbgs() << "Excess:" << "\n";
    for (int64_t Element : Excess) {
      dbgs() << std::to_string(Element) << "\t";
    }
    dbgs() << "\n";
  }

private:
  inline int64_t residualCapacity(NodeIndex Src, NodeIndex Dest) {
    return Capacity[Src][Dest] - Flow[Src][Dest];
  }

  inline bool isAdmissible(NodeIndex Src, NodeIndex Dest) {
    return Height[Src] == Height[Dest] + 1;
  }

  void push(NodeIndex Src, NodeIndex Dest) {
    int64_t NewFlow = std::min(Excess[Src], residualCapacity(Src, Dest));
    Flow[Src][Dest] += NewFlow;
    Flow[Dest][Src] -= NewFlow;

    Excess[Src] -= NewFlow;
    Excess[Dest] += NewFlow;
  }

  void relabel(NodeIndex Src) {
    std::optional<int64_t> NewLabel;

    for (int64_t Dest = 0; Dest < Size; Dest++) {
      if (residualCapacity(Src, Dest) > 0)
        NewLabel = NewLabel.has_value()
                       ? std::min(NewLabel.value(), Height[Dest])
                       : Height[Dest];

      if (NewLabel.has_value())
        Height[Src] = NewLabel.value() + 1;
    }
  }

  void findMaxHeightVertices(NodeIndex Source, NodeIndex Drain,
                             SmallVectorImpl<NodeIndex> &MaxHeight) {
    for (NodeIndex i = 0; i < Size; i++) {
      if (i != Source && i != Drain && Excess[i] > 0) {
        if (!MaxHeight.empty() && Height[i] > Height[MaxHeight[0]])
          MaxHeight.clear();
        if (MaxHeight.empty() || Height[i] == Height[MaxHeight[0]])
          MaxHeight.push_back(i);
      }
    }
  }
};

} // namespace llvm

#endif // LLVM_ADT_PUSHRELABELMAXFLOW_H
