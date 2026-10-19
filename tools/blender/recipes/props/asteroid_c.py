"""asteroid_c: rock variant c for the asteroid fields (MultiMesh) and the physical rocks.

Brief: role = background and collision rock in a rusty belt. Silhouette keywords = lumpy,
faceted, flat, like a slab. Size = radius about 5 m at scale 1 (the arena scales instances 0.4x to 8x).
Rust-brown role material `ROCK`; the `-colonly` hull is the rock's convex hull.
"""

from kit import common, rocks

ID = "asteroid_c"
CATEGORY = "props"
TRIANGLE_BUDGET = (300, 2000)  # art bible 3.3: asteroid
SEED = 37


def build() -> None:
    bm = common.new_bm()
    rocks.add_rock(bm, 5.0, SEED, stretch=(1.0, 1.0, 0.6), lumpiness=0.38, craters=4)
    shape = rocks.rock("rock", bm)
    common.add_collision_hull("rock", [shape])
