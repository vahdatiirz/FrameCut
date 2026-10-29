# Verification — 0.9.0 build 14

- 72 core Swift tests passed, zero failures, including exact transition endpoints, moving/textured atmosphere effects, avoiding global double exposure beneath particles, fractional-overlap instruction coverage and real exported-video decode checks.
- Physical-device Debug build, installation, installed version query and normal launch succeeded on an iPad Pro 11-inch M4, iPadOS 26.5.2. Nine synthetic device checks passed; [sanitized device results](iPad-0.9-result.json).
- All 32 local renderers produced valid endpoint/intermediate frames on the device. Smoke Drift, Confetti and Gold Confetti each exported a 4.6-second 720p30 film with a 1.4-second overlap; all 138 frames of each film decoded on the iPad and again on the host. Offline caption recognition, speech synthesis, Looks/FX, a composed movie and a short 4K60 export passed.
- Three existing project JSON files were unchanged across installation/testing.
- Simulator UI checks reached Effects, selected/applied Smoke Drift, persisted it across relaunch and exported a 5.5-second 720p30 sample; all 165 frames decoded. The two particle styles were exported through the core integration test, not individually through manual simulator UI in that run.
- The user accepted the current prototype appearance for this update and deferred smoke-realism improvements. This is not a claim of VN-equivalent visual quality.

Not fully verified: every manual menu operation, broad photographic/face inputs for the new styles, live performance and memory on all devices, old OS versions, Intel simulators, hour-long films, high-motion 4K sources, HDR and full accessibility. Earlier long-film tests used synthetic media and are not a broad reliability guarantee. No guarantee of zero bugs or full VN parity.

The optional Mac generator remains experimental: it produced decodable video in limited tests but failed the requested smoke appearance. Newer video models, true 3D camera control and complete premium-effect equivalence are unverified. External weights/runtime are not bundled or represented as covered by the app's MIT license.
