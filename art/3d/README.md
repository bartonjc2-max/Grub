# Grub 3D: the living room scene

This is the 3D build of the canon living room screen (`../../docs/canon/2026-11-19-livingroom-screen.png`).
Everything here is built in Blender 5.1 from simple shapes, with no Tripo and no textures.

## Rebuild

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b --python build_grub.py   # Grub → grub_clean.blend / .fbx
/Applications/Blender.app/Contents/MacOS/Blender -b --python build_room.py   # room + Grub → room.blend, renders/room_render.png
```

`build_room.py` loads `grub_clean.blend` from this folder. Rebuilding gives the committed render
pixel for pixel.

## What's in it

- **`build_grub.py`**: Grub, sized from `grub_measure.json`.
  - Body: a rounded box.
  - Arms and legs: capsules.
  - Face: square eyes and a mouth.
  - Rig: 6 bones, every vertex weighted 100% to one bone, so only the limbs move.
  - Animation: a `Waddle` action.
- **`build_room.py`**: the living room, set in a corner.
  - **Props:** a puffy two-seat couch (the base and arms are one piece), two pictures, a door, a potted plant and a beach ball.
  - **No ceiling light.** Jesse dropped it.
  - **Grub's look in this scene:** matte pastel skin `#669B8D` (roughness 0.9, sheen 0.5), with cream eye glints.
  - **Grub's shadow:** a flat oval decal under his feet (tint `#B0AAA3`, about 78% of the canon's strength), attached to his rig.
- **Lighting:**
  - Grub's lights (front, top and two faint lights behind him) light only Grub.
  - The room's lights skip Grub: one soft overhead pool, plus faint ambient light.
  - A wall behind the camera closes the room.
  - The ceiling has a glow only the camera sees.
- **Measurement tools**, each comparing the canon with `renders/room_render.png`:
  - `sample_grub.py`: Grub's color in 12 regions.
  - `sample_floor.py`: 10 floor, wall and ceiling spots.
  - `shadow_profile.py`: the shadow under Grub's feet.

Most look settings can be overridden with environment variables (`SKIN`, `GK`, `TOP`, `ROOMTOP`,
`SHC`, …), so you can try a value without editing the script.
