"""Generates scenes/cafe/cafe.tscn (the counter-service cafe layout) from code.

Run from the repo root:  python tools/gen_cafe_layout.py
It OVERWRITES the scene, so edits made in the Godot editor since the last run
are lost. Either make layout changes here, or retire this script once the
scene is being edited by hand.
"""
import math
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "scenes", "cafe", "cafe.tscn")
FURN = "res://assets/kenney/furniture/"
FOOD = "res://assets/kenney/food/"
ST = "res://scripts/cafe/"

ROOM_W, ROOM_D = 7, 6
BOX, CYL = 1, 2
NAV = ["nav_source"]

ext = []        # (type, path, id)
subs = []       # raw sub_resource text blocks
nodes = []      # raw node text blocks


def res(kind, path):
    for t, p, i in ext:
        if p == path:
            return f'ExtResource("{i}")'
    i = f"{len(ext) + 1}_{path.rsplit('/', 1)[-1].split('.')[0]}"
    ext.append((kind, path, i))
    return f'ExtResource("{i}")'


def scene(path):
    return res("PackedScene", path)


def script(path):
    return res("Script", path)


def fmt(v):
    v = round(v, 4)
    return str(int(v)) if v == int(v) else str(v)


def xform(pos=(0, 0, 0), yaw=0.0, pitch=0.0):
    """Godot Basis.from_euler (YXZ order) + origin, in .tscn text form."""
    cy, sy = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    cp, sp = math.cos(math.radians(pitch)), math.sin(math.radians(pitch))
    m = [
        [cy, sy * sp, sy * cp],
        [0, cp, -sp],
        [-sy, cy * sp, cy * cp],
    ]
    # Godot's text format lists the basis row by row.
    rows = [m[r][c] for r in range(3) for c in range(3)]
    return "Transform3D(" + ", ".join(fmt(x) for x in rows + list(pos)) + ")"


def node(name, typ, parent=".", props=(), instance=None, groups=None):
    g = (" groups=[" + ", ".join(f'"{x}"' for x in groups) + "]") if groups else ""
    if typ:
        head = f'[node name="{name}" type="{typ}" parent="{parent}"{g}]'
    else:
        head = f'[node name="{name}" parent="{parent}" instance={instance}{g}]'
    nodes.append("\n".join([head, *props]))


def prop(name, parent, model, pos, yaw=0.0, scale=1.0, center=True, collision=0):
    props = [f"transform = {xform(pos, yaw)}", f"script = {script(ST + 'prop_3d.gd')}",
             f"model = {scene(model)}"]
    if scale != 1.0:
        props.append(f"model_scale = {fmt(scale)}")
    if not center:
        props.append("center = false")
    if collision:
        props.append(f"collision = {collision}")
    node(name, "Node3D", parent, props)


def sign(parent, text, pos):
    node("Sign", "Label3D", parent, [
        f"transform = {xform(pos)}", "billboard = 1", "pixel_size = 0.004", "font_size = 40",
        "outline_size = 12", "modulate = Color(1, 0.92, 0.75, 1)", f'text = "{text}"'])


# --- Root, environment, camera, light -------------------------------------
subs.append("""[sub_resource type="Environment" id="Environment_cafe"]
background_mode = 1
background_color = Color(0.11, 0.08, 0.07, 1)
ambient_light_source = 2
ambient_light_color = Color(0.95, 0.82, 0.68, 1)
ambient_light_energy = 0.35
tonemap_mode = 2
tonemap_white = 1.6""")
nodes.append(f"""[node name="Cafe" type="Node3D"]
script = {script(ST + "cafe.gd")}""")
node("WorldEnvironment", "WorldEnvironment", props=['environment = SubResource("Environment_cafe")'])
node("Sun", "DirectionalLight3D", props=[
    f"transform = {xform((0, 5, 0), yaw=-60, pitch=-45)}",
    "light_color = Color(1, 0.92, 0.8, 1)", "light_energy = 0.6", "shadow_enabled = true",
    "directional_shadow_max_distance = 80.0", "shadow_blur = 1.5"])
node("Camera", "Camera3D", props=[
    "fov = 30.0", f"script = {script(ST + 'cafe_camera.gd')}"])

# --- Navigation: baked at runtime from every StaticBody under "nav_source" groups.
subs.append("""[sub_resource type="NavigationMesh" id="NavigationMesh_cafe"]
geometry_parsed_geometry_type = 1
geometry_source_geometry_mode = 1
geometry_source_group_name = &"nav_source"
cell_size = 0.1
cell_height = 0.1
agent_height = 1.0
agent_radius = 0.2
agent_max_climb = 0.1""")
node("Navigation", "NavigationRegion3D", props=['navigation_mesh = SubResource("NavigationMesh_cafe")'])

# --- Floor and walls (front and right walls are cut away for the camera) ----
node("Room", "Node3D", groups=NAV)
subs.append("""[sub_resource type="StandardMaterial3D" id="Material_floor"]
albedo_color = Color(0.36, 0.24, 0.18, 1)
roughness = 0.85""")
subs.append(f"""[sub_resource type="BoxMesh" id="BoxMesh_floor"]
material = SubResource("Material_floor")
size = Vector3({ROOM_W}, 0.05, {ROOM_D})""")
node("Floor", "MeshInstance3D", "Room", [
    f"transform = {xform((ROOM_W / 2, -0.025, ROOM_D / 2))}", 'mesh = SubResource("BoxMesh_floor")'])
# Walkable surface for the navigation bake only (layer 7: nothing collides with it).
subs.append(f"""[sub_resource type="BoxShape3D" id="BoxShape3D_navfloor"]
size = Vector3({ROOM_W}, 0.1, {ROOM_D})""")
node("NavFloor", "StaticBody3D", "Room", ["collision_layer = 64", "collision_mask = 0"])
node("Shape", "CollisionShape3D", "Room/NavFloor", [
    f"transform = {xform((ROOM_W / 2, -0.06, ROOM_D / 2))}", 'shape = SubResource("BoxShape3D_navfloor")'])

node("Walls", "Node3D", "Room")
for x in range(ROOM_W):
    model = "wallWindow.glb" if x in (2, 4) else "wall.glb"
    prop(f"Back{x}", "Room/Walls", FURN + model, (x, 0, 0), center=False)
for z in range(ROOM_D):
    model = "wallDoorway.glb" if z == 5 else ("wallWindow.glb" if z == 3 else "wall.glb")
    prop(f"Left{z}", "Room/Walls", FURN + model, (0, 0, z + 1), yaw=90, center=False)
for z in range(ROOM_D):
    model = "wallWindow.glb" if z in (2, 4) else "wall.glb"
    prop(f"Right{z}", "Room/Walls", FURN + model, (ROOM_W, 0, z), yaw=-90, center=False)

# Invisible bounds keep the barista inside (customers walk through the door).
node("Bounds", "StaticBody3D", "Room", ["collision_mask = 0"])
for i, (pos, size) in enumerate([
    ((3.5, 1, -0.1), (7.4, 2, 0.2)), ((-0.1, 1, 3), (0.2, 2, 6.4)),
    ((7.1, 1, 3), (0.2, 2, 6.4)), ((3.5, 1, 6.1), (7.4, 2, 0.2)),
]):
    sid = f"BoxShape3D_bound{i}"
    subs.append(f'[sub_resource type="BoxShape3D" id="{sid}"]\nsize = Vector3({", ".join(fmt(s) for s in size)})')
    node(f"Bound{i}", "CollisionShape3D", "Room/Bounds", [f"transform = {xform(pos)}", f'shape = SubResource("{sid}")'])

# --- Counters: a back counter against the wall and a front service counter,
# with a short work strip between them and a gate gap at the right end.
CAB = 0.43
node("Counter", "Node3D", groups=NAV)
for k in range(14):
    prop(f"Back{k}", "Counter", FURN + "kitchenCabinet.glb", (k * CAB, 0, 0.5), center=False, collision=BOX)
for k in range(13):
    prop(f"Front{k}", "Counter", FURN + "kitchenCabinet.glb", (k * CAB, 0, 1.7), center=False, collision=BOX)
prop("FrontEnd", "Counter", FURN + "kitchenCabinet.glb", (7 - CAB, 0, 1.7), center=False, collision=BOX)
prop("Plant", "Counter", FURN + "plantSmall2.glb", (6.78, 0.45, 1.47), scale=1.6)
prop("Honey", "Counter", FOOD + "honey.glb", (3.2, 0.45, 0.25), scale=0.35)
prop("Mugs", "Counter", FOOD + "mug.glb", (2.75, 0.45, 0.25), yaw=40, scale=0.35)

node("Stations", "Node3D", groups=NAV)
node("Register", "Area3D", "Stations", [
    f"transform = {xform((0.75, 0, 1.25))}", f"script = {script(ST + 'register.gd')}", "size = Vector3(0.9, 1, 0.6)"])
prop("Till", "Stations/Register", FURN + "computerScreen.glb", (0, 0.45, 0.2), yaw=180, scale=1.6)
sign("Stations/Register", "Order here", (0, 1.25, 0.3))

node("EspressoMachine", "Area3D", "Stations", [
    f"transform = {xform((2.0, 0, 0.6))}", f"script = {script(ST + 'espresso_machine.gd')}", "size = Vector3(0.9, 1, 0.5)"])
prop("Machine", "Stations/EspressoMachine", FURN + "kitchenCoffeeMachine.glb", (0, 0.45, -0.32), scale=1.6)
prop("Cup", "Stations/EspressoMachine", FOOD + "cup-saucer.glb", (0.3, 0.45, -0.25), scale=0.35)

node("PastryCase", "Area3D", "Stations", [
    f"transform = {xform((3.0, 0, 1.25))}", f"script = {script(ST + 'pastry_case.gd')}", "size = Vector3(1, 1, 0.6)"])
prop("Plate", "Stations/PastryCase", FOOD + "plate.glb", (-0.2, 0.45, 0.2), scale=0.45)
prop("Croissant", "Stations/PastryCase", FOOD + "croissant.glb", (-0.2, 0.49, 0.2), yaw=30, scale=0.4)
prop("Plate2", "Stations/PastryCase", FOOD + "plate.glb", (0.25, 0.45, 0.2), scale=0.45)
prop("Muffin", "Stations/PastryCase", FOOD + "muffin.glb", (0.25, 0.49, 0.2), scale=0.45)

node("Pass", "Area3D", "Stations", [
    f"transform = {xform((4.9, 0, 1.25))}", f"script = {script(ST + 'pass.gd')}", "size = Vector3(1, 1, 0.6)"])
sign("Stations/Pass", "Pickup", (0, 1.25, 0.3))

node("TrashBin", "Area3D", "Stations", [
    f"transform = {xform((6.5, 0, 0.45))}", f"script = {script(ST + 'trash_bin.gd')}", "size = Vector3(0.7, 1, 0.7)"])
prop("Can", "Stations/TrashBin", FURN + "trashcan.glb", (0, 0, 0), scale=1.3, collision=CYL)

# --- Front of house: tables, each with one seat facing it from the counter side.
node("Tables", "Node3D", groups=NAV)
for n, (tx, tz) in enumerate([(2.6, 3.5), (4.4, 3.5), (6.2, 3.3), (3.5, 5.0), (5.4, 5.0)], start=1):
    prop(f"Table{n}", "Tables", FURN + "tableRound.glb", (tx, 0, tz), scale=1.4, collision=CYL)
    node("MugSpot", "Marker3D", f"Tables/Table{n}", [f"transform = {xform((0, 0.52, 0.15))}"], groups=["mug_spots"])
    node(f"Seat{n}", "Marker3D", "Tables", [
        f"transform = {xform((tx, 0, tz - 0.62))}", f"script = {script(ST + 'seat.gd')}", f'label = "{n}"'])
    prop("Chair", f"Tables/Seat{n}", FURN + "chairCushion.glb", (0, 0, 0), scale=1.5)

node("Decor", "Node3D", groups=NAV)
prop("Rug", "Decor", FURN + "rugRectangle.glb", (4.3, 0.005, 4.3), scale=2.2)
prop("Doormat", "Decor", FURN + "rugDoormat.glb", (0.35, 0.005, 5.5), yaw=90, scale=1.4)
prop("Bookcase", "Decor", FURN + "bookcaseOpenLow.glb", (0.2, 0, 3.4), yaw=90, scale=1.4, collision=BOX)
prop("PlantShelf", "Decor", FURN + "plantSmall1.glb", (0.2, 0.56, 3.2), scale=1.6)
prop("Lamp", "Decor", FURN + "lampRoundFloor.glb", (6.7, 0, 4.3), collision=CYL)
prop("PlantRight", "Decor", FURN + "pottedPlant.glb", (6.6, 0, 5.6), scale=1.3, collision=CYL)

# --- Markers ------------------------------------------------------------------
node("Markers", "Node3D")
node("Door", "Marker3D", "Markers", [f"transform = {xform((-0.6, 0, 5.5))}"])
node("Queue", "Node3D", "Markers")
for i, z in enumerate([2.15, 2.75, 3.35, 3.95, 4.55]):
    node(f"Spot{i}", "Marker3D", "Markers/Queue", [f"transform = {xform((0.75, 0, z))}"])
node("Pickup", "Node3D", "Markers")
for i, (x, z) in enumerate([(4.9, 2.15), (5.45, 2.3), (4.35, 2.35), (5.6, 2.7)]):
    node(f"Spot{i}", "Marker3D", "Markers/Pickup", [f"transform = {xform((x, 0, z))}"])

# --- Actors -------------------------------------------------------------------
node("Actors", "Node3D")
# Cats are spawned at runtime from CafeData.CATS (scenes/cafe/cat.tscn).

node("Barista", None, ".", [f"transform = {xform((3.0, 0, 0.9))}"], instance=scene("res://scenes/cafe/barista.tscn"))

node("Overlay", "CanvasLayer", props=["layer = 1"])
node("HUD", "CanvasLayer", props=["layer = 2", f"script = {script(ST + 'ui/cafe_hud.gd')}"])

out = [f"[gd_scene load_steps={len(ext) + len(subs) + 1} format=3]", ""]
out += [f'[ext_resource type="{t}" path="{p}" id="{i}"]' for t, p, i in ext]
out += [""] + ["\n".join([s, ""]) for s in subs]
out += ["\n\n".join(nodes), ""]
open(OUT, "w", newline="\n").write("\n".join(out))
print("nodes:", len(nodes), "ext:", len(ext))
