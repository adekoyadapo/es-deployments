import json
from pathlib import Path

from init_main_cluster import setup_main_cluster
from init_monitoring_cluster import setup_monitoring_cluster

# Use of Path to get the parent directory of the current file
# This will allow us to run the script from anywhere
base_path = Path(__file__).parent


def load_config():
    with open(f"{base_path}/clusters_config.json") as f:
        return json.load(f)


def main():
    config = load_config()

    # Setup main cluster and monitoring cluster
    setup_main_cluster(config)
    setup_monitoring_cluster(config)


if __name__ == "__main__":
    main()
