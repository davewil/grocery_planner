# AI-003 Receipt Scanning - Future Goals

This document records deferred features that MUST be revisited in future phases.
These were explicitly scoped out of the MVP (Phases 1-4) but are critical for the full vision.

## Phase 5: Advanced OCR with LayoutLM

**Priority:** High
**Deferred from:** Phase 2 (Basic OCR)

The MVP uses Tesseract + regex for OCR extraction. LayoutLM (or LayoutLMv3) should replace this for significantly better accuracy:

- **LayoutLM** (microsoft/layoutlm-base-uncased) understands document layout and spatial relationships
- Can identify receipt structure (header, line items, totals, tax) with high accuracy
- Handles diverse receipt formats much better than regex-based parsing
- Expected improvement: 85% -> 95%+ accuracy on item extraction

### Implementation Notes
- Add `transformers>=4.30.0` and `torch>=2.0.0` to Python service
- Fine-tune on receipt-specific dataset
- Can run alongside Tesseract as an enhanced post-processing step
- Consider LayoutLMv3 for multimodal (image + text) understanding

## Phase 6: Cloud Storage (S3/GCS)

**Priority:** Medium
**Deferred from:** Phase 1 (File Upload Infrastructure)

The MVP uses local disk storage (`priv/uploads/receipts/`). Cloud storage is needed for production:

- **Amazon S3** or **Google Cloud Storage** for receipt image storage
- Benefits: scalability, redundancy, CDN, lifecycle policies
- Consider `ex_aws_s3` or `waffle` with S3 adapter for Elixir integration
- Implement signed URLs for secure access
- Add image lifecycle policies (auto-delete after retention period)
- Consider image compression/optimization before storage

### Implementation Notes
- Abstract storage behind a behaviour (`ReceiptStorage`) so local and cloud are swappable
- Environment-based configuration (local for dev, S3 for prod)
- Migrate existing local files to cloud when switching

## Phase 6: Mobile Camera Optimization

**Priority:** Medium
**Deferred from:** Phase 1 (Upload UI)

The MVP supports file upload only. Mobile camera capture needs optimization:

- Native camera capture button (prominent on mobile)
- Real-time receipt edge detection and auto-crop
- Guidance overlay ("align receipt within frame")
- Auto-capture when receipt is properly aligned
- HEIC format support and conversion
- Image quality assessment before upload ("image too blurry")
- Compression for mobile uploads to reduce bandwidth

### Implementation Notes
- Consider using a JavaScript camera library (e.g., camera-controls)
- Server-side HEIC conversion via `image_magic` or Sharp
- Client-side image quality scoring before upload
- Progressive enhancement: basic file input for desktop, camera UI for mobile

---

*This document was created as part of AI-003 MVP implementation to ensure these goals are not lost. Review and prioritize when Phases 1-4 are stable.*
