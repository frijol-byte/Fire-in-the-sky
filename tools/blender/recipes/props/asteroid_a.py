"""asteroid_a: rock variant a for the asteroid fields (MultiMesh) and the physical rocks.

Brief: role = background and collision rock in a rusty belt. Silhouette keywords = lumpy,
faceted, round and chunky. Size = radius about 5 m at scale 1 (the arena scales instances 0.4x to 8x).
Rust-brown role material `ROCK`; the `-colonly` hull is the rock's convex hull.
"""

from kit import common, rocks

ID = "asteroid_a"
CATEGORY = "props"
TRIANGLE_BUDGET = (300, 2000)  # art bible 3.3: asteroid
SEED = 11


def build() -> None:
    bm = common.new_bm()
    rocks.add_rock(bm, 5.0, SEED, stretch=(1.0, 0.9, 0.85), lumpiness=0.34, craters=3)
    shape = rocks.rock("rock", bm)
    common.add_collision_hull("rock", [shape])
