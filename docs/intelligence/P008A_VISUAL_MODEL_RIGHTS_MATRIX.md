# P008A — Visual Model Rights Matrix (§1,§2,§27) — weights/data provenance, NOT code license
Decision classes: COMMERCIAL_CANDIDATE / RESEARCH_ONLY / LICENSE_AMBIGUOUS / DATA_PROVENANCE_RISK /
TOO_HEAVY_FOR_EXTENSION / APP_DEEP_ONLY / DESKTOP_ONLY / REJECTED.

| Candidate | Code license | Weights license | Data provenance | Commercial weights? | Size/feasibility | Decision (this turn) |
|-----------|-------------|-----------------|-----------------|---------------------|------------------|----------------------|
| Apple built-in Vision (VNClassifyImageRequest, OCR, feature print, saliency, barcode) | N/A (OS) | OS-provided | Apple | yes (on-device OS API) | native, cheap | **COMMERCIAL_CANDIDATE — USED as baseline (§3)** |
| Google SigLIP family | Apache-2.0 (code) | weights vary; several checkpoints carry non-commercial / dataset-restricted terms; WebLI data provenance not fully disclosed | opaque | **NOT confirmed clear** | ~0.2–1B, Core ML heavy | DATA_PROVENANCE_RISK / APP_DEEP_ONLY → NOT integrated |
| Microsoft Phi-3.5-Vision | MIT (code) | MIT-stated weights, but training-data provenance/product-risk needs case review | partially disclosed | plausibly, pending review | multi-B params | TOO_HEAVY_FOR_EXTENSION / APP_DEEP_ONLY → NOT integrated this turn |
| HF SmolVLM family | Apache-2.0 | Apache-2.0 stated; trained on datasets whose per-item provenance/rights are not individually verifiable offline | mixed/opaque | plausibly, pending data review | ~0.25–2B | LICENSE_AMBIGUOUS at DATA level / APP_DEEP_ONLY → NOT integrated |

**Rule applied:** a permissive CODE license is NOT sufficient; we require weights license + training-data provenance to
be acceptable for a commercial product. None of the external candidates could be verified at the weights+data level in
this environment, so **none was downloaded or integrated** (fail-closed). A real integration requires reading the exact
model card + dataset terms at a pinned commit, SHA-256, and a commercial-use decision (§27). Status:
`EXTERNAL_VISUAL_SEMANTIC = UNAVAILABLE_PENDING_WEIGHTS_AND_DATA_AUDIT`. Apple Vision baseline is used instead.
