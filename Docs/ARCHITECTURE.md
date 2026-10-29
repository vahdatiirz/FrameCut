# Architecture

FrameCut is an independent implementation. REA was used as an investigation aid for public/installed VN metadata and resource labels; it is not part of the shipped app. Full native recovery of VN did not complete, so algorithmic parity is not claimed. No original VN executable, assets or templates are part of this repository.

- `Sources/FrameCutCore`: dependency-free Swift package containing Codable projects, validation, source/output timing, history, composition/export, Core Image effects, text rendering and local audio tools.
- `App/EditorModel.swift`: main-actor editing session, import copies, persistence, preview and export state.
- `App/*View.swift`: adaptive SwiftUI editor and task-specific panels; the guide routes to the existing editing session.
- `App/OfflineSpeechEngine.swift`: app-only WhisperKit actor with bundled model and runtime downloading disabled.
- `MotionPreset`: original recipes expressed as ordinary MotionTrack keyframes, reusing split/trim mapping and the existing compositor.
- `Tests/FrameCutCoreTests`: real output/time/pixel/audio checks and value-model regression tests.

Preview and export share rendering behavior. Relative single-file media references and validated numeric ranges are used in projects. New project fields are optional to preserve older drafts. There is no configured backend or paid API. Media is stored locally in the app container; system file/share destinations remain user-controlled.

`App/DeviceSmokeCheck.swift` is a DEBUG-only, explicitly invoked development check that uses synthetic fixtures in a separate verification folder. It does not run during ordinary launch or in the Release simulator build. Do not mistake successful short fixtures for long-film testing.


## 0.9 transition paths

TransitionRenderer remains shared by previews and export. AtmosphereTransition adds independent deterministic smoke/particle visuals; particle reveals reuse the existing wave matte. MediaEngine preserves rational CMTime boundaries and derives instruction duration from the inserted track. GeneratedBridgeAsset is a separate optional externally rendered overlap; the companion and external model are not embedded iPad inference.
