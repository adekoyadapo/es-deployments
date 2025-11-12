import json
from pathlib import Path
from elasticsearch import Elasticsearch, NotFoundError, BadRequestError
from jinja2 import Template

# Use of Path to get the parent directory of the current file
# This will allow us to run the script from anywhere
base_path = Path(__file__).parent

def check_remote_cluster_exists(es, remote_cluster_name):
    """
    Check if a remote cluster exists by its name.
    Returns True if the cluster exists, False otherwise.
    """
    try:
        # Check if the remote cluster exists
        remote_info = es.cluster.remote_info()
        if remote_cluster_name in remote_info:
            print(f"Remote cluster '{remote_cluster_name}' exists.")
            return True
        else:
            print(f"Remote cluster '{remote_cluster_name}' does not exist.")
            return False
    except NotFoundError:
        print(f"Remote cluster '{remote_cluster_name}' was not found.")
        return False
    except Exception as e:
        print(f"Error checking remote cluster: {e}")
        return False


def setup_remote_settings_with_jinja(es, config, remote_settings_path):
    # Instantiate Elasticsearch client based on configuration
    if "cloud_id" in config["monitoring_cluster"]:
        es = Elasticsearch(
            cloud_id=config["monitoring_cluster"]["cloud_id"],
            api_key=config["monitoring_cluster"]["api_key"],
        )
    elif "host" in config["monitoring_cluster"]:
        host = config["monitoring_cluster"]["host"]
        port = config["monitoring_cluster"]["port"]
        scheme = config["monitoring_cluster"]["scheme"]
        username = config["monitoring_cluster"]["username"]
        password = config["monitoring_cluster"]["password"]
        es = Elasticsearch(
            hosts=[{"host": host, "port": int(port), "scheme": scheme}],
            basic_auth=(username, password), verify_certs=False, ssl_show_warn=False
        )

    with open(remote_settings_path, "r") as file:
        template_content = file.read()

    template = Template(template_content)
    remote_settings_config_str = template.render(
        proxy_address=config["remote_cluster"]["proxy_address"],
        server_name=config["remote_cluster"]["server_name"],
    )

    remote_settings_config = json.loads(remote_settings_config_str)
    es.cluster.put_settings(body=remote_settings_config)
    print("Cross Cluster Set-up")


def setup_monitoring_cluster(config):
    if "cloud_id" in config["monitoring_cluster"]:
        es = Elasticsearch(
            cloud_id=config["monitoring_cluster"]["cloud_id"],
            api_key=config["monitoring_cluster"]["api_key"],
        )
    elif "host" in config["monitoring_cluster"]:
        host = config["monitoring_cluster"]["host"]
        port = config["monitoring_cluster"]["port"]
        scheme = config["monitoring_cluster"]["scheme"]
        username = config["monitoring_cluster"]["username"]
        password = config["monitoring_cluster"]["password"]
        es = Elasticsearch(
            hosts=[{"host": host, "port": int(port), "scheme": scheme}],
            basic_auth=(username, password), verify_certs=False, ssl_show_warn=False
        )

    # Check if the remote cluster exists before setting up
    remote_cluster_name = config["remote_cluster"]["server_name"]
    if check_remote_cluster_exists(es, remote_cluster_name):
        print("Proceeding with cross-cluster replication setup.")
        # Set-up cross-cluster replication
        setup_remote_settings_with_jinja(
            es, config, f"{base_path}/_meta/monitoring_cluster/cluster-settings.json"
        )
    else:
        print(f"Remote cluster '{remote_cluster_name}' does not exist. Skipping setup.")

    return es


def load_config():
    with open(f"{base_path}/clusters_config.json") as f:
        return json.load(f)


def main():
    config = load_config()
    setup_monitoring_cluster(config)


if __name__ == "__main__":
    main()