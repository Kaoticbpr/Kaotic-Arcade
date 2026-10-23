"""Playfield layout: every part this table adds on top of the VPX starter table.

Coordinates are VPX table units: the playfield is 952 wide and 2162 tall,
x grows to the right and y grows toward the player (the flippers sit at y 1803).
Names matter: the script reacts to events by name (TopLane1_Hit, Bumper2_Hit, ...).

To move a shot, change its numbers here and run tools/build.py again.
"""
import copy
import json
import math
from pathlib import Path

DEFAULTS = Path(__file__).parent / "defaults"


def _default(kind):
    return json.loads((DEFAULTS / f"{kind}.json").read_text())


def dp(x, y, smooth=False, sling=False):
    return {"x": float(x), "y": float(y), "z": 0.0, "smooth": smooth, "is_slingshot": sling,
            "has_auto_texture": True, "tex_coord": 0.0, "is_locked": False,
            "editor_layer_visibility": True}


def circle(cx, cy, r, n=10):
    return [dp(cx + r * math.cos(2 * math.pi * i / n), cy + r * math.sin(2 * math.pi * i / n), smooth=True)
            for i in range(n)]


def thick_line(points, width):
    """Outline (as drag points) of a wall that follows `points` with the given width."""
    left, right = [], []
    for i, (x, y) in enumerate(points):
        a = points[max(i - 1, 0)]
        b = points[min(i + 1, len(points) - 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        length = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / length * width / 2, dx / length * width / 2
        left.append(dp(x + nx, y + ny))
        right.append(dp(x - nx, y - ny))
    return left + right[::-1]


# ---------------------------------------------------------------- part makers

def wall(name, points, height=50.0, visible=True, material="Plastic White", rubber=False):
    w = _default("Wall")
    w.update(name=name, drag_points=points, height_top=height, height_bottom=0.0,
             is_top_bottom_visible=visible, is_side_visible=visible, display_texture=False,
             top_material=material, side_material=material, hit_event=rubber,
             elasticity=0.8 if rubber else 0.3, friction=0.3, scatter=0.0,
             is_timer_enabled=False, timer_interval=100, threshold=2.0)
    return "Wall", w


def bumper(name, x, y, radius=45.0, force=12.0):
    b = _default("Bumper")
    b.update(name=name, center={"x": x, "y": y}, radius=radius, force=force, threshold=1.0,
             scatter=2.0, height_scale=90.0, ring_speed=0.5, ring_drop_offset=0.0,
             cap_material="Plastic White", base_material="Plastic Cobalt Blue",
             socket_material="Metal", ring_material="Metal", is_ring_visible=True,
             is_socket_visible=True, hit_event=True, is_collidable=True,
             is_reflection_enabled=True, timer_interval=100)
    return "Bumper", b


def trigger(name, x, y, radius=25.0, shape="wire_a", rotation=0.0, surface="", visible=True):
    t = _default("Trigger")
    half = radius
    t.update(name=name, center={"x": x, "y": y}, radius=radius, rotation=rotation,
             shape=shape, surface=surface, is_visible=visible, is_enabled=True,
             material="Metal", hit_height=50.0, anim_speed=1.0, timer_interval=100,
             wire_thickness=0.0, scale_x=1.0, scale_y=1.0, is_reflection_enabled=True,
             drag_points=[dp(x - half, y - half), dp(x + half, y - half),
                          dp(x + half, y + half), dp(x - half, y + half)])
    return "Trigger", t


def target(name, x, y, rot=0.0, drop=False):
    t = _default("HitTarget")
    t.update(name=name, position={"x": x, "y": y, "z": 0.0}, size={"x": 32.0, "y": 32.0, "z": 32.0},
             rot_z=rot, target_type="drop_target_simple" if drop else "hit_target_rectangle",
             material="Plastic White", elasticity=0.35, elasticity_falloff=0.5, friction=0.2,
             scatter=0.0, threshold=2.0, timer_interval=100, raise_delay=100,
             disable_lighting_top=0.0, disable_lighting_below=0.0)
    return "HitTarget", t


def spinner(name, x, y, rotation=0.0, length=70.0):
    s = _default("Spinner")
    s.update(name=name, center={"x": x, "y": y}, rotation=rotation, length=length, height=60.0,
             damping=0.9879, angle_max=0.0, angle_min=0.0, elasticity=0.3,
             material="Metal", timer_interval=100, is_reflection_enabled=True)
    return "Spinner", s


def kicker(name, x, y, kind="hole_simple", radius=25.0):
    k = _default("Kicker")
    k.update(name=name, center={"x": x, "y": y}, radius=radius, kicker_type=kind,
             material="Metal", hit_accuracy=0.7, hit_height=40.0, legacy_mode=True,
             timer_interval=100)
    return "Kicker", k


def ramp(name, points, h_bottom, h_top, w_bottom=75.0, w_top=70.0, kind="flat"):
    r = _default("Ramp")
    r.update(name=name, drag_points=[dp(x, y, smooth=True) for x, y in points],
             height_bottom=h_bottom, height_top=h_top, width_bottom=w_bottom, width_top=w_top,
             ramp_type=kind, material="Plastic with an image", image_alignment="world",
             left_wall_height=62.0, right_wall_height=62.0,
             left_wall_height_visible=30.0, right_wall_height_visible=30.0,
             hit_event=False, threshold=2.0, elasticity=0.3, friction=0.0, scatter=0.0,
             is_reflection_enabled=True, timer_interval=100)
    return "Ramp", r


def insert(name, x, y, color, radius=16.0):
    """A playfield insert light (no bulb mesh), off until the script lights it."""
    li = _default("Light")
    li.update(name=name, center={"x": x, "y": y}, color=color, color2="#ffffff",
              falloff_radius=radius * 3, falloff_power=2.0, intensity=10.0, height=0.0,
              state=0.0, state_u32=0, is_bulb_light=False, show_bulb_mesh=False,
              has_static_bulb_mesh=False, depth_bias=0.0, fade_speed_up=0.2, fade_speed_down=0.2,
              drag_points=circle(x, y, radius, 10), blink_interval=125, blink_pattern="10")
    return "Light", li


def timer(name, interval):
    t = _default("Timer")
    t.update(name=name, timer_interval=interval, is_timer_enabled=False,
             center={"x": 20.0, "y": 20.0})
    return "Timer", t


# ---------------------------------------------------------------- the layout

def parts():
    p = []

    # Top rollover lanes (skill shot + bonus multiplier), guide posts between them.
    for i, x in enumerate((380, 460, 540), start=1):
        p.append(trigger(f"TopLane{i}", x, 250, radius=22, shape="wire_a"))
        p.append(insert(f"TopLaneLight{i}", x, 310, "#ffd400", radius=12))
    for i, x in enumerate((340, 420, 500, 580), start=1):
        p.append(wall(f"LaneGuide{i}", thick_line([(x, 205), (x, 285)], 10), height=50, rubber=True))

    # Pop bumpers.
    p.append(bumper("Bumper1", 370, 420))
    p.append(bumper("Bumper2", 550, 420))
    p.append(bumper("Bumper3", 460, 545))

    # Left ramp: rises from the lower left to a drop-off at the top left.
    # Below ~55 units of height a ball could clip under it, so guide walls close
    # the entrance section at playfield level.
    ramp_path = [(300, 1020), (285, 860), (262, 680), (248, 500), (240, 340)]
    p.append(ramp("LeftRamp", ramp_path, 0.0, 80.0))
    p.append(wall("RampGuideL", thick_line([(255, 1030), (240, 860), (220, 640)], 8), height=60))
    p.append(wall("RampGuideR", thick_line([(345, 1030), (330, 860), (308, 640)], 8), height=60))
    p.append(trigger("RampEnter", 300, 990, radius=25, shape="none", visible=False))
    p.append(trigger("RampMade", 244, 410, radius=25, shape="none", surface="LeftRamp", visible=False))
    p.append(insert("RampArrow", 300, 1100, "#ff2020", radius=14))

    # Right ramp: the left ramp's twin, fed by the left flipper. It hugs the right orbit guide so no
    # ball-sized gap is left between them, and drops off above the right orbit, clear of Bumper2.
    right_ramp_path = [(700, 1020), (712, 860), (728, 690), (735, 560), (735, 450)]
    p.append(ramp("RightRamp", right_ramp_path, 0.0, 80.0))
    p.append(wall("RightRampGuideL", thick_line([(655, 1030), (668, 860), (686, 660)], 8), height=60))
    p.append(wall("RightRampGuideR", thick_line([(745, 1030), (756, 860), (768, 660)], 8), height=60))
    p.append(trigger("RightRampEnter", 700, 990, radius=25, shape="none", visible=False))
    p.append(trigger("RightRampMade", 735, 480, radius=25, shape="none", surface="RightRamp", visible=False))
    p.append(insert("RightRampArrow", 700, 1100, "#ff2020", radius=14))

    # Left orbit lane (along the left wall) and right orbit lane (beside the shooter lane).
    p.append(wall("LeftOrbitGuide", thick_line([(110, 1000), (110, 700), (115, 470)], 8), height=50))
    p.append(trigger("LeftOrbit", 64, 760, radius=25, shape="none", visible=False))
    p.append(insert("LeftOrbitArrow", 64, 1050, "#20a0ff", radius=14))
    p.append(wall("RightOrbitGuide",
                  thick_line([(772, 1110), (775, 800), (790, 593), (775, 400), (690, 262)], 8), height=50))
    p.append(spinner("Spinner", 812, 880, rotation=0.0, length=68.0))
    p.append(trigger("RightOrbit", 815, 700, radius=25, shape="none", visible=False))
    p.append(insert("RightOrbitArrow", 812, 1150, "#20a0ff", radius=14))

    # Center scoop (starts segments, locks balls, collects extra ball).
    p.append(kicker("Scoop", 470, 760))
    p.append(insert("ScoopLight", 470, 830, "#ffffff", radius=14))

    # Left 3-bank drop targets in the pocket between the left orbit guide and the left ramp, angled
    # square-on to the right flipper's shot (which passes left of the ramp entrance).
    for i, (x, y) in enumerate(((145, 985), (181, 967), (217, 949)), start=1):
        p.append(target(f"Drop{i}", x, y, rot=-26.6, drop=True))
    p.append(insert("LockLight", 181, 1045, "#00e040", radius=14))

    # Two standup targets right of the scoop, clear of the right ramp entrance.
    p.append(target("Standup1", 575, 650, rot=20.0))
    p.append(target("Standup2", 600, 700, rot=20.0))

    # Segment (mode) inserts in an arc below the scoop, extra ball, shoot again.
    for i, (x, y) in enumerate(((380, 935), (425, 910), (470, 900), (515, 910), (560, 935)), start=1):
        p.append(insert(f"ModeLight{i}", x, y, "#c040ff", radius=13))
    p.append(insert("ExtraBallLight", 470, 1060, "#ff8000", radius=14))
    p.append(insert("ShootAgainLight", 437, 1690, "#ff2020", radius=16))
    for i in range(4):
        p.append(insert(f"BonusXLight{i + 2}", 395 + i * 28, 1150, "#ffffff", radius=10))

    # Outlanes (the template already has inlane triggers).
    p.append(trigger("LeftOutlane", 52, 1600, radius=22, shape="wire_a"))
    p.append(trigger("RightOutlane", 821, 1600, radius=22, shape="wire_a"))

    # Auto launcher in the shooter lane (multiball and ball-save balls). The script creates
    # the ball inside it and kicks it straight up; it stays disabled so the player's ball rolls past.
    auto = kicker("AutoKick", 901, 1750, kind="invisible")
    auto[1]["is_enabled"] = False
    p.append(auto)

    # Script timers.
    for name, ms in (("GameTimer", 100), ("MessageTimer", 2000), ("AutoLaunchTimer", 600),
                     ("BallSaveTimer", 10000), ("DropResetTimer", 1500), ("ScoopTimer", 1200),
                     ("EndBallTimer", 2500), ("AttractTimer", 3000), ("TiltDecayTimer", 1500),
                     ("LaunchButtonTimer", 800), ("LightShowTimer", 100)):
        p.append(timer(name, ms))
    return p


def apply(expanded_dir):
    """Write every part into an extracted table folder and register it in gameitems.json."""
    root = Path(expanded_dir)
    index_path = root / "gameitems.json"
    index = json.loads(index_path.read_text())
    existing = {e["file_name"] for e in index}
    names = set()
    for kind, item in parts():
        if item["name"] in names:
            raise ValueError(f"duplicate part name {item['name']}")
        names.add(item["name"])
        file_name = f"{kind}.{item['name']}.json"
        if file_name in existing:
            raise ValueError(f"{file_name} already exists in the starter table")
        (root / "gameitems" / file_name).write_text(json.dumps({kind: copy.deepcopy(item)}, indent=2))
        index.append({"file_name": file_name, "is_locked": False, "editor_layer": 2,
                      "editor_layer_name": "Show", "editor_layer_visibility": True})
    index_path.write_text(json.dumps(index, indent=2))
    return names
