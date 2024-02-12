#ifndef LLVM_ADT_PUSHRELABELMAXFLOW_H
#define LLVM_ADT_PUSHRELABELMAXFLOW_H

#include "llvm/ADT/RematGraph.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/SmallSet.h"
#include "llvm/ADT/SmallVector.h"

#include "llvm/IR/Value.h"
#include "llvm/Support/Debug.h"
#include "llvm/Support/raw_ostream.h"
#include <algorithm>
#include <cstdint>
#include <limits>
#include <optional>
#include <queue>
#include <string>

namespace llvm {

template <typename GraphTy> class PushRelableMaxFlow {
  using WeightTy = typename GraphTy::WeightType;
  using NodeTy = FlowNode<Value *>;
  using NodeIndex = typename GraphTy::AdjacencyMatrixTy::size_type;

private:
  const GraphTy &Graph;
  NodeTy Source;
  NodeTy Sink;

  SmallVector<SmallVector<WeightTy>> Flow;

  SmallVector<WeightTy> Height;
  SmallVector<WeightTy> Excess;

public:
  PushRelableMaxFlow(const GraphTy &Graph, NodeTy Source, NodeTy Sink)
      : Graph(Graph), Source(Source), Sink(Sink),
        Flow(Graph.size(), SmallVector<WeightTy>(Graph.size(), 0)),
        Height(Graph.size(), 0), Excess(Graph.size(), 0) {}

  void getSourceSideMinCut(SmallVectorImpl<NodeTy> &Result) {
    NodeIndex SourceIdx = Graph[Source];

    SmallSet<NodeIndex, 32> Reachable;
    Reachable.insert(SourceIdx);
    std::queue<NodeIndex> Worklist;
    Worklist.push(SourceIdx);

    while (!Worklist.empty()) {
      NodeIndex Todo = Worklist.front();
      Worklist.pop();
      for (NodeIndex Idx = 0; Idx < Graph.size(); ++Idx) {
        if (residualCapacity(Todo, Idx) > 0) {
          if (std::get<1>(Reachable.insert(Idx))) {
            Worklist.push(Idx);
          }
        }
      }
    }

    Result.reserve(Reachable.size());

    for (auto &&[Idx, Node] : enumerate(Graph)) {
      if (Reachable.contains(Idx))
        Result.push_back(Node);
    }
  }

  void getSinkSideMinCut(SmallVector<NodeTy> &Result) {
    NodeIndex SinkIdx = Graph[Sink];
    SmallSet<NodeIndex, 32> Reachable;
    Reachable.insert(SinkIdx);
    std::queue<NodeIndex> Worklist;
    Worklist.push(SinkIdx);

    while (!Worklist.empty()) {
      NodeIndex Todo = Worklist.front();
      Worklist.pop();
      for (NodeIndex Idx = 0; Idx < Graph.size(); ++Idx) {
        if (residualCapacity(Idx, Todo) > 0) {
          if (std::get<1>(Reachable.insert(Idx))) {
            Worklist.push(Idx);
          }
        }
      }
    }

    Result.reserve(Reachable.size());

    for (auto &&[Idx, Node] : enumerate(Graph)) {
      if (Reachable.contains(Idx))
        Result.push_back(Node);
    }
  }

  int64_t computeMaxFlow() {
    NodeIndex SourceIdx = Graph[Source];
    NodeIndex SinkIdx = Graph[Sink];

    // init height
    Height[SourceIdx] = Graph.size();
    Excess[SourceIdx] = std::numeric_limits<WeightTy>::max();

    // init preflow
    for (NodeIndex Idx = 0; Idx < Graph.size(); ++Idx) {
      if (Idx != SourceIdx)
        push(SourceIdx, Idx);
    }

    SmallVector<NodeIndex> Current;
    findMaxHeightVertices(SourceIdx, SinkIdx, Current);

    while (!Current.empty()) {
      for (NodeIndex i : Current) {
        bool Pushed = false;
        for (NodeIndex j = 0; j < Graph.size() && Excess[i]; j++) {
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
    for (auto &Row : Flow) {
      for (WeightTy Element : Row) {
        if (Element != 0) {
          dbgs() << std::to_string(Element);
        } else {
          dbgs() << ".";
        }
        dbgs().indent(2);
      }
      dbgs() << "\n";
    }
    dbgs() << "\n";

    dbgs() << "Capacity:" << "\n";
    
    Graph.print(dbgs(), true);
  
    dbgs() << "\n";

    dbgs() << "Height:" << "\n";
    for (WeightTy Element : Height) {
      dbgs() << std::to_string(Element);
      dbgs().indent(2);
    }
    dbgs() << "\n";

    dbgs() << "Excess:" << "\n";
    for (WeightTy Element : Excess) {
      dbgs() << std::to_string(Element);
      dbgs().indent(2);
    }
    dbgs() << "\n";
  }

private:
  inline WeightTy residualCapacity(NodeIndex Src, NodeIndex Dest) {
    return Graph.getWeights()[Src][Dest] - Flow[Src][Dest];
  }

  inline bool isAdmissible(NodeIndex Src, NodeIndex Dest) {
    return Height[Src] == Height[Dest] + 1;
  }

  void push(NodeIndex Src, NodeIndex Dest) {
    WeightTy NewFlow = std::min(Excess[Src], residualCapacity(Src, Dest));
    Flow[Src][Dest] += NewFlow;
    Flow[Dest][Src] -= NewFlow;

    Excess[Src] -= NewFlow;
    Excess[Dest] += NewFlow;
  }

  void relabel(NodeIndex Src) {
    std::optional<WeightTy> NewLabel;

    for (NodeIndex Dest = 0; Dest < Graph.size(); Dest++) {
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
    for (NodeIndex i = 0; i < Graph.size(); i++) {
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
