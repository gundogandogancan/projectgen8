# P002 — Apple-Native Intelligence Capability Report

**Doc status:** `PARTIAL — VERIFIED(compile) + RCOV(device/docs)` · **Phase:** 2 · **Date:** 2026-10-18 · PROMPT 002 §4.
Prefer current official Apple frameworks before third-party deps. "VERIFIED" here means **compiles & runs headless on this machine (macOS, Swift 6.3)**; device behavior/accuracy + current-doc specifics remain **RCOV** (Prompt 000 §54). No invented framework features.

| Capability | Framework | Status | Min OS (RCOV) | Offline | Privacy | Notes |
|---|---|---|---|---|---|---|
| Content hashing (exact identity) | **CryptoKit** `SHA256` | **VERIFIED (used in ContentIdentityResolverV1)** | iOS 13+/macOS 10.15+ | yes | on-device | real, deterministic |
| Language identification | **NaturalLanguage** `NLLanguageRecognizer` | VERIFIED (compiles headless) | iOS 12+ | yes | on-device | planned real semantic path |
| Text embeddings / classification | NaturalLanguage `NLEmbedding`/`NLModel` | RCOV | iOS 14+ | yes | on-device | embeddings availability per language |
| Text recognition (OCR) | **Vision** `VNRecognizeTextRequest` | RCOV | long-available; revised APIs iOS 18+ | yes | on-device (ephemeral frame) | needs a real image; integrate next increment |
| Image feature print / similarity | Vision `VNGenerateImageFeaturePrintRequest` | RCOV | iOS 13+ | yes | on-device | for perceptual identity Tier B upgrade |
| Speech transcription | Speech `SFSpeechRecognizer` | RCOV | iOS 13+ | varies (on-device subset) | permissioned | ASR port; permission-gated |
| Sound classification | SoundAnalysis | RCOV | iOS 15+ | yes | on-device | optional |
| Model runtime | Core ML | RCOV | iOS 11+ | yes | on-device | for exported specialist heads |
| Accelerated compute | Accelerate / Metal | RCOV | — | yes | on-device | only if justified by a measured bottleneck |
| Thermal / low-power | Foundation `ProcessInfo` | **VERIFIED** | long-available | yes | on-device | drives ResourceGovernor |

## Classification correction (002A §1)
Apple NaturalLanguage **language identification is a `REAL_LANGUAGE_SIGNAL`** — and nothing more. It is **NOT** evidence of semantic understanding, topic understanding, content-safety intelligence, multimodal understanding, or production content cognition. It is **not** "the content brain." Content-cognition/safety heads (benefit, violence, disease, manipulation, child-safety, sensitive-content) have **no validated provider yet** → they return `UNAVAILABLE`/`UNKNOWN` (002A §3), never a fabricated classification.

## Decisions
- **Apple-native first.** CryptoKit + NaturalLanguage are used/planned as REAL, non-fixture providers this phase. Vision OCR + feature-print integrate in the next increment with a generated/synthetic test image (no copyrighted media).
- Everything marked RCOV must be confirmed against current official docs + device before any claim moves to production-VERIFIED; accuracy is dataset-specific (no "X% accurate" without a benchmark).
- No third-party ML dependency added this phase (local-first, §5/§25).
