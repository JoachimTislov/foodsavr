"""Release channel topology shared by promotion, setup, and status."""

UPSTREAM_REPO = "JoachimTislov/foodsavr"
TOPOLOGY_CHANNELS: dict[str, dict[str, str]] = {
    "single": {},
    "two-stage": {"stable": "develop"},
    "full-channels": {
        "daily": "develop",
        "weekly": "daily",
        "stable": "weekly",
    },
}

TOPOLOGIES = tuple(TOPOLOGY_CHANNELS)
