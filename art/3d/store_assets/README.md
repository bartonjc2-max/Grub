# Store assets: alternate room items

Prepared assets only. Nothing here is wired into the game, Unity, or `room.blend`.

Each variant sits exactly where its canon item sits in `../room.blend`, so it can replace it.

| Category | Replaces (canon element) | Variants |
|---|---|---|
| rugs | `rug` (objects `Rug`, `Rug_Border`; part of the bare room plate, not a layer) | `rug_sage_round`, `rug_striped_rect`, `rug_checker`, `rug_scalloped` |
| pictures | `picL` (fits `picR` too, see below) | `pic_sunset_hills`, `pic_flower`, `pic_abstract`, `pic_moon` |
| plants | `plant` | `plant_snake`, `plant_bushy`, `plant_cactus`, `plant_trailing` |
| couches | `couch` | `couch_teal_two_seater`, `couch_mustard_loveseat`, `couch_low_bench` |

## What is in each variant folder

`<category>/<id>/`

- `render.png`: the room from the canon camera at the plate size (1284 x 2778), with only this variant swapped
  in for its canon item. All other canon items are present. Raw render, not painted.
- `mask.png`: RGBA, alpha = where the variant is visible (everything else held out on a transparent film, the
  same method `render_room_layers.py` uses for `mask_<element>_raw.png`).
- `<id>.blend`: only this variant's objects, with their meshes and materials (no scene, camera or lights).
- `meta.json`: name, description, object names, world bounding box, render times.

Top level (batch 1 and batch 2 together): `catalog.json` (every variant, its files, and its bounding box in plate pixels, top-left origin,
measured from the mask), and `contact_sheet.png` (a labelled crop of every variant).

## Rebuild

```
cd GrubIOS/art/3d/store_assets
/Applications/Blender.app/Contents/MacOS/Blender -b --python build_store_assets.py
python3 make_catalog.py
```

- `build_store_assets.py` opens `../room.blend`, builds and renders in memory, and never saves it.
- Build a subset with `ONLY=rug_checker,pic_moon` or `CATEGORY=plants` in front of the Blender command.
- Quick preview: `PLATE_W=428 PLATE_H=926` (then rerun at full size before using anything).
- To add a variant: write a builder function and add a line to `VARIANTS` in `build_store_assets.py`.
- `make_catalog.py` needs python3 with PIL and numpy.

## Naming

Variant objects use the canon name prefixes on purpose: `Rug*`, `PicL_*`, `Sofa_*`, and `Pot*` / `Leaf*` /
`Stem` / `Soil`. `render_room_layers.py` groups objects into elements by those names, so a variant dropped in
place of the canon objects is picked up as the same element with no script change. Materials are named
`Store_<id>_<part>` so they do not collide with the canon materials.

## Turning a variant into a game layer (later, not done here)

The game does not use these raw renders directly. It uses a painted plate rebuilt from a bare room plus one
painted layer per element. To put a variant in the game, the same pipeline has to be run with the variant in
the room:

1. **Work on a copy of the room.** Copy `room.blend` to e.g. `room_<id>.blend`. Do not edit `room.blend`.
2. **Swap the objects.** In the copy, delete the canon objects of the element being replaced (for the couch,
   every `Sofa_*` object; for the plant, `Pot`, `Pot_Rim`, `Soil`, `Stem`, `Leaf*`; for a picture, `PicL_*`;
   for the rug, `Rug` and `Rug_Border`). Then File > Append > `<id>.blend` > Object, select all, and they land
   in the right place with the right names. Save the copy.
   - For the right-hand picture slot: append, move the objects by x +1.15 and z -0.05 (PicL centre is
     x -4.0, z 2.05; PicR centre is x -2.85, z 2.00), and rename the `PicL_` prefix to `PicR_`. The PicR frame
     is slightly smaller (0.60 x 0.76 against 0.68 x 0.84), so scale by about 0.9 if it must match exactly.
3. **Render the layers.** `render_room_layers.py` opens `room.blend` by name and writes into `renders/`
   (`room_plate_bare.png`, `elem_<element>.png`, `mask_<element>_raw.png`, `room_layers_depth.json`). It needs
   a small change first so it can open the copy and write somewhere else (for example a `ROOM_BLEND` and an
   `OUT_DIR` environment variable); as written it would overwrite the canon renders.
   - (Superseded for rugs: see "The rug is its own layer" below. A rug now needs only `make_rug_layer.py`.)
   - A rug is not an element in `render_room_layers.py`: it is baked into the bare plate. A new rug therefore
     means a new bare plate and a new `elem_*` render for every element (their shadows fall on the rug). The
     alternative is to add `"rug"` to `ELEMENTS` so it becomes its own layer, which also needs a matching
     change in `painted/build_room_layers.py` and in the Unity shader that reads the layer textures (the layer
     textures currently hold five elements: four in `room_layers_a.png`, one in `room_layers_b.png`).
4. **Paint and assemble.** `painted/build_room_layers.py` runs the paint pass (`painted/paint_plate_d2.py`,
   Kuwahara + grain, then `painted/warm_plate.py`, the warm grade) on the bare plate and on each `elem_*`
   render, builds the masks and seam fit, and writes the game textures into `GrubUnity/Assets/Grub/Room`
   (`room_plate_painted_k12w.png`, `..._bare.png`, `room_layers_a/b/s.png`, `room_layers.json`). It
   **overwrites the live game textures**, so for a store item it needs an output name or folder per variant
   before it is run. That change, and how the game picks a texture set at runtime, is the wiring work that has
   not been designed yet.
5. **Check the hand-tuned numbers in `painted/build_room_layers.py`.** `POT_TOP_PX = 1440`, `BEND` and
   `CONTACT` were tuned for the canon plant and couch. A plant with a different pot height (the cactus and the
   trailing vine on its stand) needs a new `POT_TOP_PX` and probably a different bend; use the variant's `bbox`
   in `catalog.json` as the starting point.
6. **Check gameplay that depends on the shapes.** The canon plant height was set so a jumping Grub can grab a
   leaf (`shorten_plant.py`), and the couch was moved so he can stand on its backrest (`move_couch.py`). The
   variants keep the same footprint and seat height (0.72 m) but have different tops: see
   `world_bbox_max` in `catalog.json` (third number is the height in metres).

## Batch 2 (added 2026-11-22, second roll)

Batch 1 (the 15 variants above) is untouched. Batch 2 adds 22 more, built by `build_store_assets_b2.py`:

| Category | Batch 2 variants |
|---|---|
| rugs | `rug_rainbow_arch`, `rug_daisy`, `rug_zigzag_runner`, `rug_cloud`, `rug_hex_patchwork` |
| pictures | `pic_rainbow`, `pic_house`, `pic_cactus`, `pic_mountain_sun` (landscape frame), `pic_fruit_bowl` (round frame) |
| plants | `plant_monstera`, `plant_bamboo` (both canon height), `plant_tulips`, `plant_bonsai`, `plant_succulent_bowl` |
| couches | `couch_lilac_blanket`, `couch_green_corduroy`, `couch_cream_cushions`, `couch_futon` |
| extras (new) | `extra_side_table`, `extra_toy_box`, `extra_floor_cushion` |

```
cd GrubIOS/art/3d/store_assets
/Applications/Blender.app/Contents/MacOS/Blender -b --python build_store_assets_b2.py    # batch 2 only (about 4.5 min)
python3 make_catalog.py                                                                  # catalog + both contact sheets
```

- `build_store_assets_b2.py` imports `build_store_assets.py` for its helpers and its `run()` loop. The batch 1
  command is unchanged and still builds only batch 1; the batch 2 command only writes batch 2 folders. `ONLY=`,
  `CATEGORY=`, `PLATE_W=` / `PLATE_H=` work for both.
- To add a batch 2 variant: write a builder in `build_store_assets_b2.py` and add a line to `VARIANTS_B2`. A
  seventh tuple item holds options: `{"picR": True}` and/or `{"extra": fn(objects) -> dict for meta.json}`.
- `catalog.json`: batch 1 entries are exactly as before. Batch 2 entries add `"batch": 2`, `plate_margin_px`
  (smallest gap from the mask bbox to a plate edge) and the extras below.
- `contact_sheet.png` shows all 37 (batch 2 outlined in orange with a NEW tag);
  `contact_sheet_batch2.png` shows only batch 2, larger, with a row of the pictures at the PicR slot.

New conventions in batch 2:

- **Rugs** stay inside x -4.6..-1.45, y -4.75..-1.85, so every mask is at least 160 px clear of the plate edges
  and nothing reaches under the couch. (Batch 1's checker, scalloped and striped rugs run to the plate edge.)
- **Pictures** are also rendered at the right-hand slot: `render_picR.png` / `mask_picR.png` (canon PicR hidden,
  canon PicL back in place), with `bbox_picR` in the catalog. The transform is the one worked out above: offset
  x +1.15, z -0.05, scaled 0.9 in x and z about the picture centre (`meta.json` > `picR`). The `.blend` holds the
  PicL-slot objects only. The landscape frame is 0.84 x 0.62 and the round frame 0.76 across, so their masks are
  not the same shape as the canon 0.68 x 0.84 frame.
- **Plants**: `height_m` (true top of the evaluated mesh), `grabbable_leaf`, and `grab_leaves` (leaf objects
  reaching 2.0 m or more, with their z range). Canon is 2.28 m with grab leaves between 1.78 and 2.28 m.
  Several stalks are named `Leaf_Stem<k>` (not `Stem`) so the canon name test still groups them.
- **Couches**: `seat_top_m` (0.72 for all), `back_top_m`, `top_m`, `width_m`. Canon back top is 1.34 m.
- **Extras** are a new category that replaces nothing (`"replaces": null`). Objects are named `Extra_*`, which
  `render_room_layers.py` does not know: an extra needs its own entry in `ELEMENTS` (and a layer slot in the
  game textures) before it can be a game layer. `position_xy`, `height_m`, `footprint_m` and `placement_note`
  are in `meta.json`. Two floor slots are used: the corner gap between the plant and the door frame
  (-0.22, -0.50: side table) and open floor right of the rug (-0.42, -2.55: toy box or floor cushions, one at a
  time). The second slot overlaps the right-hand edge of the widest rugs (canon oval, batch 1 striped) by a few
  centimetres. No lamps: lamps and ceiling lights are ruled out.

## Game data and the unbaked rug (added 2026-11-22, third pass)

Three scripts turn the library into things the game reads. None of them changes a variant's `render.png`,
`mask.png` or `.blend`.

```
cd GrubIOS/art/3d/store_assets
B=/Applications/Blender.app/Contents/MacOS/Blender
$B -b --factory-startup --python measure_items.py     # item facts for every variant + the canon room (about 10 s)
$B -b --python render_picr.py                         # PicR-slot renders for pictures that lack them (10 s each)
python3 make_rug_layer.py rug_daisy rug_checker       # a rug as a game layer (about 12 s each)
python3 make_catalog.py                               # catalog.json picks all of it up
```

### measure_items.py: the numbers the game reads

Measures each variant's `.blend` (modifiers applied) and writes a `"game"` block into its `meta.json` and into
`catalog.json`, in the `room_items.json` schema (Unity world coordinates, metres): a rug's footprint, a plant's
height / grab height / pot / whether it bends, a couch's seat and back heights, an extra's obstacle circle. The
same run measures the canon room from `../room.blend` (never saved) and writes
`GrubUnity/Assets/Grub/Room/room_items.json` (the one file under GrubUnity this folder writes) and a copy,
`canon_items.json`. How each number is derived is in the script's docstring; a variant can overrule one with
`"game_overrides"` in its `meta.json`. **Run it again after `build_store_assets*.py`**, which rewrite `meta.json`.

Things to know about the numbers:
- `leafY` is the lowest point of the top leaf cluster (canon 1.79, top 2.27 in `leafTop`), not its middle.
- `bendable` comes from the geometry: a slender `Stem` / `*Stem*` / `*Cane*` object with leaves above it. The
  trailing vine has no stem (a pot on a stand), so it is `false` with the cactus, snake plant, bonsai and
  succulent bowl.
- A rug's `shape` is `ellipse` or `rect` only: the cloud, scalloped, hexagon and half-round rugs are `ellipse`
  with their bounding half-extents, so the half-round `rug_rainbow_arch` is the loosest fit.
- `plant_trailing` and `plant_succulent_bowl` stand on legs: `potTop` / `potRadius` are the pot up on its stand.

### The rug is its own layer

The canon rug used to be baked into the bare room plate. `../renders/unbaked/` is a complete staging set of the
game textures built with the rug out of the bare room and out of every element's shadow, plus `room_rug.png`
(1284 x 2778 RGBA, straight alpha) and `"rug": {"bbox", "file"}` in `room_layers.json`. The shader draws
`lerp(bare, rug.rgb, rug.a) x element contact shadows`, then the elements. Rebuild it (about 8 minutes: 1.5 of renders, 6.5 of painting and assembly):

```
cd GrubIOS/art/3d && S=$PWD/renders/unbaked
RUG=layer OUT_DIR=$S/work /Applications/Blender.app/Contents/MacOS/Blender -b --python render_room_layers.py
UNBAKED_RUG=1 OUT_DIR=$S RENDERS_DIR=$S/work python3 painted/build_room_layers.py
```

Both scripts behave exactly as before without those variables (and `painted/build_room_layers.py` then still
overwrites the live game textures). Keep `renders/unbaked/work/`: `make_rug_layer.py` needs
`room_plate_bare.png`, `room_full_norug.png`, `room_plate_bare_rug.png`, `room_full.png`, `mask_rug_raw.png`
from it, and `bare_fit_gains.json` beside it.

### make_rug_layer.py: all a new rug needs

`python3 make_rug_layer.py <rug id>` writes `rugs/<id>/game/room_rug.png` and `rugs/<id>/game/item.json`
(`{"rug": {...footprint...}, "file", "bbox"}`) from the variant's `render.png` and `mask.png`: the elements'
shadows are divided off the rug, it is pasted into the raw no-rug bare room, painted like the bare plate, and
given the bare plate's colour-fit gains. **About 12 seconds a rug, and that is the whole job**: no bare plate, no
element layer and no shadow texture is rebuilt; the game swaps one texture and one footprint. It needs
`measure_items.py` to have run (for the footprint). `rug_terracotta` is the canon rug, rebuilt from the staging
renders as a check (it has no `meta.json`, so it is not in the catalog). Made so far: `rug_terracotta`,
`rug_daisy`, `rug_checker`.

Limits:
- The rest of the room is the room without a rug. The terracotta rug throws a lot of warm light at the walls and
  couch in the raw render; the walls are colour-fitted to the approved plate either way, and the elements keep
  their look from the canon-rug renders, so a blue rug does not cool the room.
- `mask.png` holds out the canon elements, so a part of a rug hidden behind the couch or pot is not in the layer.
  None of the three made so far touches an element's silhouette; a rug that does would show floor there if that
  element moves away.
- The alpha is the geometric silhouette, so the painted edge's outward wobble (up to about 2 px) is trimmed.

### render_picr.py

Batch 1 pictures now have `render_picR.png` / `mask_picR.png` too, made from the objects in their `.blend`
with the batch 2 transform (offset x +1.15, z -0.05, scale 0.9). Their PicR bbox is identical to batch 2's
portrait frames (405, 1173, 117 x 145).

## Rules these were made under

- Never save over `room.blend` or `grub_clean.blend`, never write into `GrubUnity` (one exception since the third
  pass: `measure_items.py` writes `GrubUnity/Assets/Grub/Room/room_items.json`).
- Do not run `painted/build_room_layers.py` casually: it overwrites game textures.
- Original designs in the room's style: soft rounded clay shapes, matte materials, warm pastel palette.
