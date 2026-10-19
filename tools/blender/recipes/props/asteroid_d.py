"""asteroid_d: rock variant d for the asteroid fields (MultiMesh) and the physical rocks.

Brief: role = background and collision rock in a rusty belt. Silhouette keywords = lumpy,
faceted, tall and craggy. Size = radius about 5 m at scale 1 (the arena scales instances 0.4x to 8x).
Rust-brown role material `ROCK`; the `-colonly` hull is the rock's convex hull.
"""

from kit import common, rocks

ID = "asteroid_d"
CATEGORY = "props"
TRIANGLE_BUDGET = (300, 2000)  # art bible 3.3: asteroid
SEED = 41


def build() -> None:
    bm = common.new_bm()
    rocks.add_rock(bm, 5.0, SEED, stretch=(0.9, 1.2, 1.0), lumpiness=0.42, craters=2)
    shape = rocks.rock("rock", bm)
    common.add_collision_hull("rock", [shape])
