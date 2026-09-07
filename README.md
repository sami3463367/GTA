# Azure Harbor — native offline Android game

Original top-down 2D open-city **development build**, built with **Godot 4.5.1**. This replaces the abandoned browser/WebView experiment; there is no HTML, JavaScript, WebView, or web server in the game or Android package.

## Current playable scope

- A coastal city with 28 buildings, streets, crosswalks, palms, a park, fountain and marina.
- Resolution-independent 2D artwork: rooftop furniture, solar panels, pools, planters and a hotel helipad.
- Walking/running, touch joystick, keyboard controls, cars, a speedboat and a helicopter.
- Landing on the hotel roof or park pad; walking on the roof; elevator back to the street.
- Three accessible interiors (café, market and hotel), with furniture collision and a hotel rooftop elevator.
- Wandering pedestrians, basic gunfire, civilian reactions, wanted level, simple police pursuit and health recovery.
- Four introductory objectives, rewards and free roam afterward.
- Original generated sound effects, sound toggle, pause menu and local atomic JSON saves.
- Fully bundled assets. No accounts, servers, advertising, analytics, remote downloads or internet permission.

**This is not a finished GTA-scale game.** Current NPC AI/police logic and animation are basic; most cars are parked, only three buildings have interiors, and there is one short introductory chapter. There is no multiplayer, elaborate life simulation, inventory economy or full campaign. Real Android hardware performance and lifecycle testing remain necessary before release. No claim of zero bugs is made.

## Play / develop

1. Install Godot **4.5.1 stable** (standard edition; no Unity or .NET needed).
2. Import `game/project.godot` and press F6/F5 to play.
3. Choose **Enter Azure Harbor**. Follow the gold objective marker.

| Action | Android | Desktop |
|---|---|---|
| Move / steer | Left joystick | WASD / arrows |
| Enter / exit / interact | USE | E |
| Helicopter land / take off | LAND | L |
| Hotel lobby rooftop elevator | LAND | L |
| Fire forward | Hold FIRE | Space |
| Run | RUN toggle | Shift |
| Pause | II / Android Back | Escape |

The helicopter starts at Sunset Park, west of the marina. Only the park pad and Meridian Hotel helipad permit landing. From the rooftop, approach the small LIFT structure and USE to descend. Boats can only be exited beside the marina dock or safe land. Saves preserve mission progress, money, health and settings, and restore a safe on-foot location; vehicle positions are currently reset on launch.

## Tests

```sh
godot --headless --path game --editor --import
godot --headless --path game --script res://tests/test_game.gd
```

The workflow also renders native menu, city, interior and rooftop screenshots under Xvfb and includes them in the build artifacts.

Native tests cover world collision, entrances, all four objectives, vehicle boarding/exiting, unsafe exits/landings, rooftop elevation, elevator use, combat, health recovery, save/load and corrupt saves. They exercise systems directly, not physical touchscreen playthroughs.

## Android packages

The `Native Android game` GitHub Actions workflow runs on `arena/01a07de1-gta` and can also be manually dispatched. It installs Godot, Android export templates, JDK 17 and the Android SDK, tests the project, exports APK/AAB files, verifies the APK signature/minimum SDK/native engine and checks that internet permissions are absent.

- **Android 10+**: minimum SDK 29, target SDK 35 (check current Play requirements before submitting).
- **ARMv7, ARM64 and x86_64** native libraries; landscape orientation; Compatibility renderer.
- `azure-harbor-test.apk`: debug-signed, installable for testing, **not a production release**.
- `azure-harbor-test.aab`: debug-signed bundle for packaging validation, **not accepted as a Play production upload**.
- Test signing keys are generated per workflow run. Installing a later test build may require uninstalling the older build first, which clears local saves. Production updates require a stable release key.
- AAB files are not directly installable; use the APK for phone testing.
- Download successful artifacts from the repository's Actions page. A workflow definition alone does not mean an export has succeeded; consult the run and logs.

### Release signing

Configure these **GitHub Actions repository secrets**, not files committed to Git and not credentials pasted into chat:

- `ANDROID_KEYSTORE_BASE64`: base64-encoded upload keystore.
- `ANDROID_KEY_ALIAS`: upload-key alias.
- `ANDROID_KEYSTORE_PASSWORD`: store/key password (Godot expects the same password for both).

Run the workflow manually with `release = true` to export `azure-harbor-release.aab`. Keep a secure backup of the upload key. Missing secrets fail the release job; there is no silent fallback to a debug-signed release.

Release signing does **not** make this prototype ready for store publication. Before publishing: finish/polish the planned gameplay, test on real Android 10+ devices (including airplane mode, interruptions, various aspect ratios and 16 KB page-size devices), verify the latest Play target-API rules, choose a permanent package ID, prepare original store artwork, complete privacy/data-safety and violence/content-rating declarations, and complete required Play testing/review.

## Source organization

- `game/scripts/city_game.gd`: gameplay, mission progression, persistence and audio.
- `game/scripts/world_data.gd`: deterministic geometry and world rules.
- `game/scripts/city_renderer.gd`: original procedural 2D city art.
- `game/scripts/game_hud.gd`: native Godot UI and touch input.
- `game/tests/test_game.gd`: headless native regression tests.
- `game/assets/`: original icon and locally generated sound effects.
- `.github/workflows/android.yml`: native export and verification pipeline.

All names, map layouts, visuals and sound assets in this repository are original project material. No GTA branding, characters, maps, music or extracted game assets are used.
