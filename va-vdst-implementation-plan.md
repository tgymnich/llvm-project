# MI450 pipe-aware VA_VDST wait insertion

## Objective

Improve `SIInsertWaitcnts` for gfx1250 expert scheduling mode (`SCHED_MODE = 2`)
by using completion ordering within VALU execution domains. Generate the least
restrictive wait justified by the tracked dependencies and hardware guarantees,
including across basic blocks and loop backedges.

All work is based on Austin Kerbow's ordered-XDL branch, upstream PR #218326
(`users/kerbowa/amdgpu-vavdst-ordered-xdl-fence` on `origin`). That PR already
delivers the stronger XDL guarantee; this plan stacks on top of it.

Implement in four reviewable stages:

0. Completion-domain classification audit and fixes, with no wait-algebra
   changes.
1. Per-domain wait tracking, extending the data structures #218326 introduces.
2. The stronger completion guarantee for qualifying XDL instructions. This is
   #218326 itself; only gaps it leaves are in scope here.
3. Measured scheduling and register-allocation heuristic improvements.

Stage 1 includes partial-wait handling and control-flow support. A
straight-line prototype alone is not sufficient for enabling the optimization.

## Investigation baseline

- Ticket revision: `3c956bd6bc50b8dc0569df6839546bfca21c0790`.
- Inspected checkout: `f4c0e84b0e7ade0f6979f6b1f85b64cea058800d`.
- Completion-domain classification is unchanged between these revisions. Two
  relevant commits landed in between: #233708 (score wraparound check when
  VA_VDST increments by two) and #233712 (precommitted ordered-XDL tests in
  `llvm/test/CodeGen/AMDGPU/waitcnt-vavdst-ordered-xdl.mir`).
- The named `fp8_fa.ll` and `example_valu_dsload_wmma_mixed_valu_pessimistic_wait.mir`
  attachments were not found in the checkout.
- No local tests or MI450 runtime measurements were performed during planning.
  `/dev/kfd` was unavailable.

Create a new branch in the existing checkout, based on the head of #218326
rather than `main`:

```sh
git fetch origin users/kerbowa/amdgpu-vavdst-ordered-xdl-fence
git switch -c <branch> FETCH_HEAD
```

The PR head was `e81d8b92176692fbba3ec736fa896de39905ac1d` at planning time.
#218326 is still in review, so rebase onto its latest head whenever it is
updated, and onto `main` once it merges. Do not copy or reimplement its changes
in this branch. Upstream submissions from this work are stacked PRs on top of
#218326.

Do not use git worktrees. Preserve unrelated files and changes. Implementation
and validation are local; committing, pushing, and posting reviews are separate
actions.

## Related upstream work

#218326 is the base of this work. Coordinate with Austin Kerbow before starting
implementation, so the stacked changes match the direction of his PR.

| PR | State | Relevance |
| --- | --- | --- |
| #218326 Model ordered XDL writes in expert scheduling | Open | Implements Stage 2: XDL with >= 8 destination VGPRs acts as a VA_VDST fence |
| #233712 Precommit tests for ordered XDL VA_VDST waits | Merged | 18 MIR tests covering most Stage 2 validation cases |
| #233708 Detect score wraparound when VA_VDST increments by two | Merged | Scaled WMMA increment handling |
| #233717 Add a WAR stall for DS loads in the coexec scheduler | Open | Overlaps Stage 3 |
| #233707 Bias gfx1250 scheduling by co-execution slot flavor preferences | Open | Overlaps Stage 3 |

Review feedback on #218326 sets design expectations for this pass:

- Use monotonically increasing counts, like existing VGPR/SGPR scores. Do not
  iterate over all tracked VGPR state per instruction.
- Do not model an ordering property as a new `HWEvents` entry; events describe
  hardware paths. There are already more than 32 events.
- Avoid widening the per-register score struct; justify any added field.

In review, the #218326 author confirmed that a qualifying XDL instruction is
ordered after all earlier VALU instructions of any type, not only other XDL.

## Hardware contract

The supplied MI400 shader programming reference, section 4.3.7.1, explicitly
defines four completion domains. Section 4.3.7.2 clarifies Trans64 ordering.

| Domain | Completion ordering |
| --- | --- |
| Core / Side MACC | Ordered together |
| Trans16 / Trans32 | Ordered together |
| DP MACC, including Trans64 | Ordered together |
| XDL | Ordered within the domain |

Completion can be out of order between these domains. Completion-domain
classification must follow the counter contract, rather than scheduler resource
classes, instruction names, or estimated latency.

An additional guarantee applies to an XDL instruction writing at least eight
sequential VGPRs: its `VA_VDST` decrement follows the decrements of every earlier
instruction. This is a one-way ordering relation; it does not impose global
issue-order completion on subsequent VALU instructions.

Before enabling each optimization, check the applicable silicon revision and
instruction forms. In particular, establish the ordering of both counter events
for scaled VOP3PX2 WMMA. The existing target feature counts these instructions as
two increments, but that alone does not prove that both events can be used as
ordered successors of every earlier dependency.

Nonzero thresholds rely on counting same-domain successors as guaranteed
outstanding. Overcounting hardware events is unsound; undercounting is safe.
Confirm with the hardware team:

- VOPD/VOPD3 (`hasVOPD3()` on gfx1250): whether a dual-issue instruction
  contributes one or two VA_VDST events, and its completion domain.
- Whether VALU instructions executed with `EXEC = 0` still increment and
  decrement VA_VDST, or may be skipped.
- That DOT instructions complete in the XDL domain (see below).
- The completion domain of non-XDL WMMA forms such as `v_wmma_f32_16x16x4_f32`.

VALU instructions invisible to the compiler, such as those inside inline asm,
only undercount successors and remain safe.

The hardware counter and wait encoding have different ranges. The wait field is
four bits; 15 means no wait, so 14 is the largest effective nonzero threshold.
Use existing target constants instead of introducing literal masks or limits.

## Current implementation

Relevant files and symbols:

- `llvm/lib/Target/AMDGPU/AMDGPUHWEvents.cpp`:
  `getExpertSchedulingEventType` already distinguishes four VALU event classes.
- `llvm/lib/Target/AMDGPU/SIInsertWaitcnts.cpp`:
  `WaitcntBrackets`, `updateByEvent`, `determineWaitForScore`, `applyWaitcnt`,
  `simplifyWaitcnt`, and `merge` implement counter and register tracking.
- `llvm/lib/Target/AMDGPU/SIInstrInfo.cpp`:
  `isXDL` and `isXDLWMMA` distinguish XDL instructions using target metadata.
- `llvm/lib/Target/AMDGPU/AMDGPUWaitcntUtils.{h,cpp}` and
  `llvm/lib/Target/AMDGPU/Utils/AMDGPUBaseInfo.{h,cpp}` define counter limits and
  encoding helpers.
- `llvm/lib/Target/AMDGPU/GCNPreRAAntiHints.cpp` contains the VA_VDST WAR
  register-allocation avoidance rule.

The current scoreboard combines progress from all VALU domains into a shared
score. When multiple event types are pending, `counterOutOfOrder` causes
`determineWaitForScore` to select zero. Merely changing that predicate would be
unsound: wait application, register tracking, simplification, and CFG merging
must understand per-domain progress as well.

Known classification gaps in the current classifier:

- F64 transcendental instructions have both `TRANS` and `IsDPMACCInstruction`.
  `isTRANS` is tested first, placing them with Trans32.
- On GFX12+, `isXDL` returns `isDOT(MI) || isXDLWMMA(MI)`, so `v_dot*`
  instructions are classified as XDL.
- Non-XDL WMMA forms, such as `v_wmma_f32_16x16x4_f32`, are neither XDL, TRANS,
  nor DP MACC and fall into Core / Side MACC.
- `IsDPMACCInstruction` metadata is incomplete. For example, `V_CVT_F64_I32`,
  `V_CVT_F64_F32`, and `V_CVT_F64_U32` lack the flag, while neighboring
  `WriteDoubleCvt` instructions have it. #229900 recently fixed 64-bit VOPC.

These gaps are harmless today because any mixed-domain state waits for zero.
With nonzero thresholds, a misclassification becomes a miscompile.

## Stage 0: Classification audit

Land classification fixes before changing the wait algebra, so their effect is
reviewable separately.

- Audit `IsDPMACCInstruction` against the documented DP MACC domain, including
  integer operations, F64 conversions, and 64-bit VOPC/VOP3 forms.
- Resolve F64 transcendental ordering per section 4.3.7.2.
- Confirm or correct DOT and non-XDL WMMA classification.
- Preserve counter contributions from instructions without VGPR destinations.
- Represent scaled WMMA counter contributions according to verified event
  ordering. Use conservative handling where that ordering remains unresolved.

Provide a single classification helper for the VA_VDST tracker using existing
opcode metadata. Gate new behavior to gfx1250 expert scheduling. Keep
classification changes for other generations outside this scope unless
independently validated.

## Stage 1: Per-domain tracking

Implement on top of #218326. Extend the scores, wait determination, and merge
logic it introduces rather than adding a parallel representation. Add a hidden
`cl::opt` to disable per-domain thresholds during bring-up.

### 1. Add per-domain VA_VDST state

Maintain issued and known-completed scores for each completion domain as
monotonically increasing counts. Track pending VGPR reads and writes by
physical register unit and domain.

There is one completion timeline per domain. Read and write requirements refer
to that timeline; they do not count as separate hardware increments.

Preserve all outstanding cross-domain access requirements. A single latest
access per register is insufficient: two instructions in different domains can
both read a register, and a later memory load overwriting it must respect both
pending reads. Within one ordered domain, the latest relevant access subsumes
earlier accesses of the same kind.

Retain existing physical-register and subregister handling, and cover:

- RAW: VALU writes followed by memory reads of the register.
- WAW: VALU writes followed by memory writes to the register.
- WAR: VALU reads followed by memory writes to the register.

Use a small dedicated state object rather than multiplying the storage for all
unrelated memory counters. Use fixed-size arrays for the four domain frontiers
and an LLVM container appropriate for sparse per-register access requirements.
Never iterate over all tracked registers on each instruction.

### 2. Determine and apply waits

For a pending required access at score `S` in domain `P`, calculate:

```text
trailing = issued[P] - S
threshold = min(trailing, largest_effective_wait)
```

`trailing` counts completion events guaranteed to follow the required access.
If that access is unfinished, it and those successors are all outstanding, so
the shared count is at least `trailing + 1`. A wait for a count no greater than
`trailing` therefore proves completion of the access.

Take the minimum threshold over every pending requirement of the consumer.
Use zero when there are no proven successors. Emit no wait when all relevant
accesses are already known complete. Preserve the existing handling of
VALU-to-VALU dependencies protected by hardware in expert mode.

For an effective explicit or inserted `va_vdst(N)`, update every domain:

```text
completed[P] = max(completed[P], max(issued[P] - N, 0))
```

Use guarded unsigned subtraction. The shared total being at most `N` implies
that each individual domain has at most `N` outstanding events. Zero drains all
domains. The no-wait encoding must not advance completion state.

Keep wait simplification tied to a sound upper bound on the shared outstanding
total. A bound for one domain cannot justify removing a shared-counter wait.
If a separate total bound is retained to preserve precision after partial
waits, document the information it adds beyond the individual domain bounds.

Update determination, application, explicit-wait combination, and simplification
together. Do not interpret a partial wait as completion of a global issue-order
prefix, and do not clear all pending accesses after a nonzero wait.

### 3. Integrate control flow and state transitions

Merge domain scores independently, aligning relative frontiers and retaining
the most conservative outstanding access requirement at each register unit.
For a dependency that remains pending on multiple incoming paths, preserve the
minimum guaranteed trailing distance across those paths.

Never add successor instructions from mutually exclusive paths. Merge read
requirements from different domains even when they originate on different
predecessors. Paths with no pending requirement do not manufacture one, but
other incoming paths can still require a wait.

Clamp each requirement's trailing distance at `getLimit(VA_VDST) - 1` (14).
All distances of at least 14 behave identically: determination yields
`min(trailing, 14) = 14`, and any effective wait `N <= 14` satisfies
`trailing >= N` and completes the access. The clamp is therefore exact and
bounds loop state; only `EXP_CNT` saturates in `setScoreUB` today. Verify
convergence on loops, including loops without consumers in the body and
dependencies consumed after loop exit.

Handle function entry and return, calls, pre-existing explicit waits, and opaque
instructions using the pass's established conservative contracts. Extend state
verification and debug printing so incorrect frontiers and access requirements
can be diagnosed.

## Stage 2: Stronger XDL ordering

#218326, the base branch, implements this guarantee. Do not reimplement it.
Review it against the requirements below, and in Stage 1 combine its fence
evidence with per-domain thresholds. Raise gaps with Austin, either as feedback
on #218326 or as stacked follow-ups:

For each qualifying XDL completion event, its completion proves completion of
every earlier issued event in all domains. Conversely, while any such
predecessor is unfinished, the qualifying XDL event is guaranteed to remain
outstanding and can contribute to a safe threshold.

No per-register state is needed. Because XDL completes in order within its
domain, keep a bounded queue of recent qualifying XDL events as (XDL score,
per-domain issued frontiers). For a requirement `(P, S)`, find the earliest
entry whose frontier for `P` is at least `S`; it and every later XDL event are
guaranteed successors. Only the last 14 XDL events can affect a threshold, so
older entries can be dropped. Count each completion event once when combining
with same-domain successors of `P`, and define conservative joins for the queue
at CFG merges.

Do not assume that a second event of a scaled instruction obeys the same
relation without validating it.

Expected behavior for the ticket's eight-VGPR BF16 WMMA, subject to the verified
target contract and absence of additional register hazards:

| Sequence before dependent LDS load | Stage 1 | With qualifying XDL ordering |
| --- | --- | --- |
| Move, WMMA | `va_vdst(0)` | `va_vdst(1)` |
| Move, WMMA, two Core/Side adds | `va_vdst(2)` | `va_vdst(3)` |

Also test the reverse direction: an instruction issued after a qualifying XDL
must not automatically be treated as ordered after it.

## Validation

Add new cases to `llvm/test/CodeGen/AMDGPU/waitcnt-vavdst-ordered-xdl.mir`,
which already covers wide and narrow XDL destinations, f32 WMMA, matrix scale,
partial and explicit waits, CFG and loop merges, and the 14 clamp. Use
`expert_scheduling_gfx1250.mir` only for cases unrelated to that file. Fill the
remaining gaps:

| Area | Required cases |
| --- | --- |
| Basic ordering | Each domain alone; mixed domains with zero, one, and multiple same-domain successors |
| Hazards | RAW, WAR, WAW; multiple outstanding readers from different domains; overlapping subregisters |
| Classification | Trans32 versus Trans64; DP integer operations; F64 conversions; DOT; XDL and non-XDL WMMA; VOPD |
| Contributions | Scaled WMMA; VALU without VGPR destinations; verified multi-event forms |
| Wait encoding | Thresholds 0, 14, and no-wait 15; trailing counts beyond the effective encoding range |
| Partial waits | Existing waits; successive consumers; new issues after a partial wait; zero drains |
| Control flow | Diamonds with different domain histories; unequal path lengths; loops; calls and returns |
| Compatibility | Expert mode disabled; `cl::opt` disabled; existing expert-scheduling tests for other targets |

Other gfx1250 expert-mode tests will change and need regenerated checks:
`function-esm2-prologue-epilogue.ll`, `loop-prefetch-data.ll`,
`soft-waitcnt-deletion.mir`, `waitcnt-wcg-attributes.mir`, and
`anti-hints-*.gfx1250.mir`. `expert_scheduling_gfx12.mir` must stay unchanged.

Establish failing-before/passing-after code-generation expectations with a
baseline compiler before rebuilding the changed sources. Include a legal MIR
reproducer of the ticket sequence, with machine verification enabled.

Validate the reasoning independently with a small exhaustive completion-order
model. Enumerate legal interleavings of short domain queues and assert that
each generated threshold implies completion of every required access. Include
partial waits, weighted events where their semantics are established, and XDL
ordering edges. Keep the model out of the patch. It is algorithm evidence; MIR
tests exercise the production implementation, and neither substitutes for
hardware execution.

Build `llc` and required test helpers, run the focused LIT tests, then run the
relevant AMDGPU waitcnt and hazard coverage. Check formatting and
`git diff --check`. Broaden testing when failures or changed shared behavior
warrant it. Record exact test counts and the source revision used.

## Stage 3: Kernel measurement and heuristic tuning

Coordinate with #233717 and #233707, which already change gfx1250 co-execution
scheduling and DS load WAR stalls.

Obtain the missing Triton kernel attachment and reproduce the ticket command:

```sh
llc -march=amdgcn -mcpu=gfx1250 \
  -amdgpu-expert-scheduling-mode \
  -amdgpu-anti-hints-for-va-vdst \
  --amdgpu-vgpr-threshold-percent=90 \
  -o res.s fp8_fa.ll
```

Compare baseline and changed compilation using the same kernel and options.
Measure emitted threshold distribution, remaining zero waits, instruction and
register counts, compile-time cost, and MI450 runtime and numerical correctness.
Use representative attention and GEMM workloads in addition to the ticket
kernel. A higher threshold by itself is not evidence of a runtime improvement.

Inspect the remaining zero waits to identify the dependencies driving them.
Then tune instruction scheduling and the VA_VDST WAR anti-hint rule separately.
The anti-hint option controls register-allocation avoidance; changing its
lookback or lifetime is a distinct decision from changing instruction order.
Reuse the validated completion-domain classification where appropriate.

## Completion criteria

- Stage 0 classification matches the documented completion domains, with open
  hardware questions answered or handled conservatively.
- Stage 1 produces `va_vdst(2)` for the mixed-domain ticket sequence and retains
  zero waits where the tracked ordering provides no nonzero threshold.
- Partial waits and CFG merges preserve every pending RAW, WAR, and WAW
  requirement, with bounded, convergent loop state.
- Stage 2 (#218326) uses qualifying XDL ordering only for validated target forms
  and, combined with Stage 1, counts each guaranteed outstanding event once.
- Focused regression tests pass, with before/after evidence for changed waits.
- Independent model checks support the wait algebra; hardware claims and
  runtime results remain explicitly distinguished from compiler test results.
- Heuristic changes have measured benefits and verified numerical correctness
  on available MI450 workloads before being presented as performance fixes.
