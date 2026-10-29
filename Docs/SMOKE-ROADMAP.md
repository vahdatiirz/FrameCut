# Smoke design review and follow-up

The current textured-mist prototype is retained for 0.9.0 at the user's request. This is a design review through four professional lenses, not a claim of consultation with a human team. No further smoke optimization was included in this release.

| Lens | Next-update work |
|---|---|
| Editing | Keep the same overlap and exact endpoints; tune the peak cover so the scene change is hidden without an abrupt white flash. Preserve captions, audio and undo. |
| Graphics | Compare a richer layered shader with an independently created transparent volumetric-smoke sequence. Measure texture size, alpha quality, cache memory and repeated preview behavior before selecting one. |
| Directing | Make the chosen smoke action visibly distinct and controllable; compare light/heavy variants without changing the underlying subject or baked text. |
| Cinematography | Improve billow, edge softness, directional light and density. A grey noise field is not accepted as proof of realistic volume or 3D scene generation. |

Acceptance for a future update: side-by-side reference comparisons, photographs/faces/text and landscape footage, correct start/end joins, no black/transparent frames, cancellation/save/reopen, long-preview memory measurements and on-device preview/export tests. Any quality or speed claim needs new measurements. Other premium targets and controlled generative models remain separate follow-up work.
