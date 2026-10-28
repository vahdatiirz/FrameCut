# Feature coverage — 0.5.0 preview

These rows track development against observed/documented VN capabilities. Partial means partial; missing means not implemented. Acceptance notes describe the boundary, not a promise that every item works. This is not an official VN compatibility matrix.

| ID | Capability | Status | Acceptance / remaining boundary |
|---|---|---|---|
| VN-001 | Trim / split / merge | partial | Trim at 0.05-second or frame increments, split, concatenate and verify boundaries. |
| VN-002 | Duplicate / replace | partial | Duplicate with a new identifier; replace media while preserving valid edits. |
| VN-003 | Timeline zoom and thumbnails | partial | Source poster thumbnails, 1–30x zoom and ruler seeking implemented; zoom and thumbnails observed in simulator. Continuous filmstrip and all physical gestures not verified. |
| VN-004 | Drag reorder / edge trimming | partial | Drag reorder and edge-trim controls implemented. Core identity, undo and ramp-preserving trim tests pass; direct drag gestures were inconclusive in UI automation. |
| VN-005 | Quick / Pro mode and ripple | missing | Preserve absolute timestamps and gaps in Pro; connect clips in Quick. |
| VN-006 | Track layout / visibility / snapping | partial | Overlapping text, audio and overlay regions receive separate rows; vertical scrolling added and lane allocation tested. Track visibility, manual track order and snapping remain. |
| VN-007 | Undo / redo / drafts | partial | Persist edits; undo/redo all supported edits without media loss; recover corrupt drafts independently. |
| VN-008 | Multi-selection | missing | Move/copy/delete several sub-track items together. |
| VN-009 | Reverse | implemented-host-tested | Decode output to verify temporal frame order is reversed. |
| VN-010 | Freeze / extract still | implemented-host-tested | Hold a selected frame for specified duration and export a still image. |
| VN-011 | Crop / flip / rotate / framing | partial | Interactive crop plus arbitrary rotation, horizontal and vertical flip. |
| VN-012 | Speed constant 0.1–100x | partial | Verify decoded duration at the advertised range; current range is 0.25–4x. |
| VN-013 | Speed curves and presets | partial | Custom speed ramps with source/output mapping; six named behaviors. |
| VN-014 | Keyframes / easing | partial | Animate position/scale/rotation/opacity/adjustments with customizable curves. |
| VN-015 | 19 animation presets | partial | 19 independent editable motion recipes reuse MotionTrack. Endpoint, distinct trajectory, validation and split-domain tests pass; exact VN preset equivalence and visual review of all 19 are not claimed. |
| VN-016 | Overlay video / photo / sticker | implemented-host-tested | Place multiple independent video, still and sticker layers over the main track. |
| VN-017 | Masks / custom masks | partial | Shape and freeform masks on main and overlay tracks, with feather/invert. |
| VN-018 | Mosaic / region blur | partial | Render multiple selectable regional privacy effects. |
| VN-019 | Stabilization strengths | missing | Measure reduction of camera motion and compare crop/strength settings. |
| VN-020 | Motion FX / tracked body FX | missing | Timed motion effects and subject-attached effects verified on moving subjects. |
| VN-021 | Background cutout | missing | Locally isolate people and objects with transparent export and video temporal consistency. |
| VN-022 | Frame interpolation | missing | Generate motion-compensated intermediate frames; do not equate frame duplication with interpolation. |
| VN-023 | Transitions | partial | Real two-source transitions of adjustable length; current release only fades clips to black/white. |
| VN-024 | Filters and intensity | partial | Independent filters exist; match all observed VN filter groups and verify pixels. |
| VN-025 | LUT import / favorites | partial | Parse .cube LUT files, render them and preserve imported/favorite resources. |
| VN-026 | HSL / adjustments keyframes | missing | Per-color HSL and animated adjustments with numeric input. |
| VN-027 | Brightness / contrast / exposure / warmth | partial | Current controls render correctly; full parameter inventory is not matched. Color reset now preserves privacy masks, framing and cut effects; regression reproduced and fixed. |
| VN-028 | Stocks / asset catalogs | access-limited | Original or properly licensed assets, search, favorites and offline storage; VN proprietary catalog API/license unavailable. |
| VN-029 | Font import | partial | Project-local TTF/OTF import, face selection and persistent font references implemented; registration/idempotence and missing font behavior tested. Physical font file picker and portable packaging not verified. |
| VN-030 | ZIP batch import | missing | Safely import nested media/assets without path traversal or zip bombs. |
| VN-031 | Albums / favorites / extraction | missing | Organize local media and extract audio from video. |
| VN-032 | Multiple timed titles | implemented-host-tested | Independently time, style and layer text; verify start/end in decoded output. |
| VN-033 | Text styling / layout | partial | Outline/shadow/alignment/spacing plus multilingual multiline layout beyond current single title. |
| VN-034 | Text template library | missing | Reusable styled and animated text recipes. |
| VN-035 | SRT / subtitle editing and export | partial | Round-trip subtitle text/timing, edit cues and burn into video. |
| VN-036 | Auto captions local models | partial | Bundled independent Whisper Tiny recognized known English speech with word timestamps on physical iPad in builds 4 and 5 without a paid API. Broader language and long audio accuracy remain unverified. |
| VN-037 | Cloud captions / translation | free-local-research | Requires an independently configured backend or licensed VN API; no authorized credentials/provider yet. |
| VN-038 | Bilingual / animated captions | missing | Two languages and synchronized word animations. |
| VN-039 | Filler / silence removal | missing | Detect segments and ripple all affected tracks consistently. |
| VN-040 | Text to speech | partial | Local device voice synthesized narration and offline recognition recovered the words on physical iPad build 5. All voices/languages and UI paths not verified. |
| VN-041 | Music / effects / multitrack mixing | partial | Current single background track; needs timed independent tracks and source ranges. |
| VN-042 | Audio fade in/out | implemented-host-tested | Verify decoded RMS envelope and boundaries. |
| VN-043 | Voice recording | missing | Record, preview, trim and place microphone audio on timeline. |
| VN-044 | Beat markers / detection | missing | Manual/automatic beats, editable timing and visual markers. |
| VN-045 | BeatsClips / AutoCut | missing | Beat-aligned edits with reusable rhythm templates and output timing tests. |
| VN-046 | Denoise | missing | Local audio noise reduction with measured noise improvement and speech preservation. |
| VN-047 | Character voice switch | free-local-research | No licensed VN character-voice backend or equivalent configured model; do not fake this. |
| VN-048 | 12 editing recipes | partial | Twelve independent timing/color/title recipes exist; does not establish VN template parity. |
| VN-049 | Reusable custom templates | missing | Create/import/export user templates with editable placeholders. |
| VN-050 | VN codes / CawCut templates | free-local-research | VN/CawCut backend and proprietary format integration unavailable; own format is not compatibility. |
| VN-051 | Stories / sections | missing | Storyboard sections and descriptions round-trip into editable timeline. |
| VN-052 | Teleprompter / camera | missing | Script display during recording and reusable recorded media. |
| VN-053 | Photo editor / batch photos | missing | Independent still-image edits and exports, not a video-only substitute. |
| VN-054 | Collage layouts / cutout | missing | Multiple stills, custom layouts, cutout, backgrounds and export. |
| VN-055 | AI avatar | free-local-research | Requires generation service/model, voices and avatar rights; no backend configured. |
| VN-056 | AI image/video generation | free-local-research | Requires independent generation backend with credentials and cost controls. |
| VN-057 | AI enhancement / colorize | missing | Actual enhancement model results, not resize/sharpen relabelled as AI. |
| VN-058 | MP4 / resolution / FPS / bitrate | partial | Physical iPad build 5 exported 3840×2160 at 60fps with exactly 30 decoded frames in 0.5 seconds. 720p30 edited audio/text/layers/transition export also passed. 50fps and bitrate sweeps remain. |
| VN-059 | Dolby Vision / HDR | missing | Preserve HDR pixel/color metadata and verify decoded HDR export on supported hardware. |
| VN-060 | Project transfer / AirDrop / iCloud | missing | Transfer project and media, reopen without missing resources. |
| VN-061 | Password / expiration secure drafts | missing | Authenticated encryption and expiration behavior with explicit limitations. |
| VN-062 | Social sharing / no watermark | partial | System share sheet and unwatermarked MP4 exist; destination apps not tested. |
| VN-063 | Long film / device reliability | unverified | Physical iPad import, edit, recover, export and memory/performance soak; not covered by short host tests. |
