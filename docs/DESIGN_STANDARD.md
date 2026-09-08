# Mandatory visual and interaction standard

Applies to every future world area, room, HUD state, Godot scene and Android/Web export. Preserve the native Android foundation; the preview must export the same project, never substitute HTML/JavaScript gameplay.

## World artwork

- Terrain, streets, floors and walls use authored textures through TileMapLayer/Sprite2D resources. No plain solid-color rectangle/polygon terrain or placeholder wall/floor fills.
- Provide material detail, believable scale, borders, wear and an intentional palette. Road paint/crosswalks must keep their aspect ratio and stay on land. Do not confuse collision/debug geometry with visible art.
- Roofs must read as roofs, using opaque roof textures and rooftop equipment/edge details. Roof furniture is separate exterior decoration, never a leaked interior prop.
- Furnish rooms for their purpose: floors, walls, counters/desks, seating, fixtures and small decor. Add corresponding collision; route NPCs away from furniture. Functional-looking items should have a meaningful interaction or a clearly decorative role.
- Ground buildings, trees, vehicles, characters and furniture with contact/drop shadows. Use native shadow occluders where physical point-light response is needed. Keep shadow geometry separate from roof-opacity animation.
- Keep assets bundled, licensed and export-safe. Add new textures through the authoring pipeline and generated `art_registry.gd`; do not depend on directory enumeration that breaks when resources are remapped into a PCK.

## Roof visibility contract — release blocker

1. Every building starts with roof opacity exactly 1.
2. Only an accessible building's specific doorway interaction/Area2D entry may start its interior transition.
3. Reveal only that selected room. Other roofs stay fully opaque; other room floors, actors and props stay hidden.
4. Fade the selected roof smoothly, maintaining world coordinates and furniture collision. Do not reveal all interiors based on broad player proximity.
5. Exit restores opacity exactly 1 and fully conceals the room again. Rooftop landing must never count as entering an interior.
6. Extend regression coverage when adding an enterable building; inspect closed, intermediate fade, inside and restored states. Do not rely only on a screenshot of the open room.

## Light and effects

- Retain real CanvasModulate and PointLight2D nodes for the day/night cycle, headlamps, street lamps, interiors and muzzle flash. Painted glow alone does not satisfy the lighting requirement.
- Keep exterior day/night grading consistent when entering rooms. Use room material tinting and light masks rather than changing the whole city to an unrelated indoor ambient color.
- Interior lights should not illuminate an opaque roof. Walls/furniture should occlude lights appropriately; shadow filtering should soften edges without excessive blur or bleeding.
- Support High/Lite budgets. Pool lights, bound particle/decal counts and avoid unbounded effects. Lite is a performance option, not permission to replace artwork with flat placeholders.
- Water shaders, skids, exhaust, splashes and impact particles must be spatially grounded. Camera shake should be brief and restrained; zoom transitions should remain readable.

## UI and interaction

- Custom textured panel skins, consistent bundled fonts, portraits, deliberate hierarchy and icon-based controls. No default engine buttons/progress bars or flat placeholder panels.
- Preserve circular player portrait, readable health/armor and ammo, damage feedback, dark bordered minimap, current-objective tracker and directional guidance.
- Nearby NPCs expose Talk prompts. Dialogue uses a bottom overlay with portrait, styled readable text and explicit choices; entering a room must not silently complete a conversation objective.
- Keep Talk, Vehicle, Fire, Sprint and Land actions distinct. Maintain independent movement/fire touch IDs; releasing one finger must not cancel the other.
- Check dialogue choice hit areas, long text, pause/settings, HUD contrast over bright water and dark streets, safe margins and landscape phone aspect ratios. Do not use screenshots alone to validate touch usability.

## Verification before delivery

- Run `python3 scripts/check_art_standard.py`; it scans gameplay scripts for known placeholder-drawing/default-control patterns and checks native TileMap/lighting construction. This is a limited static guard, not proof that every visual is polished.
- Pass native import and the gameplay regression suite. Add tests for new interactions and save schema changes.
- Render and inspect city, interior, dialogue, closed/restored roof, night, rooftop and Lite states. Include an intermediate roof-fade capture in artifacts.
- Export and exercise the actual WebAssembly game, check browser errors and input response, and verify the preview host/MIME configuration.
- Export APK/AAB and verify native libraries, Android 10+ and absence of internet permissions. Never label debug-signed AABs as Play-ready.
- Record the verified source commit and CI run. Keep visual captures identified as desktop/native-Web renders, not physical-device evidence.
- Physical Android testing remains a separate release gate. Do not promise zero bugs, photorealism or AAA simulation based on these checks.
