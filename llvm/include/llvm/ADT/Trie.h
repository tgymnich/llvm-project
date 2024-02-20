//===--- Trie.h -------------------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
///
/// \file
/// This file defines the Trie class.
///
//===----------------------------------------------------------------------===//

#ifndef LLVM_ADT_PREFIXTREE_H
#define LLVM_ADT_PREFIXTREE_H

#include "llvm/ADT/DenseMap.h"
#include <memory>
#include <optional>
#include <utility>

namespace llvm {

    template<typename KeyTy, typename IndexTy, typename ValueTy> class TrieNode {
    public:
        std::optional<IndexTy> Index;
        std::optional<ValueTy> Value;
        TrieNode<KeyTy, IndexTy, ValueTy>* Parent;
        DenseMap<IndexTy, std::unique_ptr<TrieNode<KeyTy, IndexTy, ValueTy>>> Children;

    public:
        TrieNode() : Index(std::nullopt), Value(std::nullopt), Parent(nullptr) {} 
        TrieNode(IndexTy Index) : Index(Index), Value(std::nullopt), Parent(nullptr)  {}
        TrieNode(IndexTy Index, ValueTy Value) : Index(Index), Value(Value), Parent(nullptr)  {}
        TrieNode(IndexTy Index, ValueTy Value, TrieNode<KeyTy, IndexTy, ValueTy> Parent) : Value(Value), Parent(Parent) {} 

    public:
        void add(IndexTy Index) {
            Children[Index] = std::make_unique(TrieNode<KeyTy, IndexTy, ValueTy>(Index, this));
        }

        void add(IndexTy Index, ValueTy Value) {
            Children[Index] = std::make_unique(TrieNode<KeyTy, IndexTy, ValueTy>(Index, Value, this));
        }
        
        void isTerminating() const {
            return Value.has_value();
        }
    };

    template <typename KeyTy, typename ValueTy, typename IndexTy = typename ValueTy::value_type>
    class Trie {
        using NodeTy = TrieNode<ValueTy, IndexTy, ValueTy>;

    private:
        std::unique_ptr<NodeTy> Root;

    public:
        Trie() : Root(std::make_unique<NodeTy>()) {}

    public:
        void insert(KeyTy Key, ValueTy Val) {
            if (Key.empty())
                return;

            NodeTy* CurrentNode = Root;

            for (IndexTy &Idx : Key) {
                auto ChildIt = CurrentNode->Children.find(Idx);
                if (ChildIt != CurrentNode->Children.end()) {
                    CurrentNode = *ChildIt;
                } else {
                    if (Idx == Key.back()) {
                        CurrentNode->add(Key, Val);
                    } else {
                        CurrentNode->add(Key);
                    }
                    CurrentNode = CurrentNode->Children[Key];
                }                
            }
        }

        std::optional<ValueTy> get(KeyTy Key) {
            if (Key.empty())
                return std::nullopt;

            NodeTy *CurrentNode = Root;

            for (IndexTy &Idx : Key) {
                auto ChildIt = CurrentNode->Children.find(Idx);
                if (ChildIt != CurrentNode->Children.end()) {
                    CurrentNode = *ChildIt;
                } else {
                    return std::nullopt;
                }
            }
            return CurrentNode->Value;
        }

        bool contains(KeyTy Key) const {
            if (Key.empty())
                return false;

            NodeTy *CurrentNode = Root;

            for (IndexTy &Idx : Key) {
                auto ChildIt = CurrentNode->Children.find(Idx);
                if (ChildIt != CurrentNode->Children.end()) {
                    CurrentNode = *ChildIt;
                } else {
                    return false;
                }
            }
            return CurrentNode->isTerminating();
        }
    };

    template<typename KeyTy, typename IndexTy, typename ValueTy>
    class TrieIterator {
    private:
        using self = TrieIterator<KeyTy, IndexTy,ValueTy>;

    public:
        using iterator_category = std::bidirectional_iterator_tag;
        using difference_type = std::ptrdiff_t;
        using pointer = std::pair<KeyTy, ValueTy>*;
        using reference = std::pair<KeyTy, ValueTy&>;

    private:
        Trie<KeyTy, IndexTy, ValueTy> T;
        TrieNode<KeyTy, IndexTy, ValueTy> *CurrentNode;
        KeyTy CurrentKey;
      

   reference operator*() const {
     assert(CurrentNode != nullptr && "dereferencing end() iterator");
     return std::make_pair(CurrentKey, CurrentNode);
   }

   pointer operator->() const {
     assert(CurrentNode != nullptr && "dereferencing end() iterator");
     return std::make_pair(CurrentKey, *CurrentNode);
   }

    public:
        self &operator++() {
            if (!CurrentNode->Children.empty()) {
                for (auto&& [K, V] : CurrentNode->Children) {

                }
            } else {
                // Iterate
                auto It = CurrentNode->Parent->Children.find(CurrentNode);
                CurrentNode = ++It;
            }
        }

        self &operator--() {

        }
    }


} // end namespace llvm

#endif // LLVM_ADT_PREFIXTREE_H
