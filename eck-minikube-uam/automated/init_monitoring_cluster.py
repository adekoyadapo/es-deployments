import json
import time
from pathlib import Path

from elasticsearch import BadRequestError, Elasticsearch
from elasticsearch.exceptions import NotFoundError
from jinja2 import Template

# Use of Path to get the parent directory of the current file
# This will allow us to run the script from anywhere
base_path = Path(__file__).parent


def index_exists(es, index_name):
    try:
        # This returns True if the index exists, False otherwise
        return es.indices.exists(index=index_name)
    except Exception as e:
        print(f"An error occurred while checking if index {index_name} exists: {e}")
        return False  # Assuming non-existence if there's an error


def enrich_policy_exists(es, policy_name):
    try:
        response = es.enrich.get_policy(name=policy_name)
        policies = response.get(
            "policies", []
        )  # Get the list of policies in the response
        for policy in policies:
            if policy["name"] == policy_name:
                return True
        return False
    except NotFoundError:
        return False
    except Exception as e:
        print(
            f"An unexpected error occurred while checking for the enrich policy {policy_name}: {e}"
        )
        return False


def transform_exists(es, transform_id):
    try:
        es.transform.get_transform(transform_id=transform_id)
        return True
    except Exception:
        return False


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

    # Set-up cross-cluster replication
    setup_remote_settings_with_jinja(
        es, config, f"{base_path}/_meta/monitoring_cluster/cluster-settings.json"
    )

    # Set-up follower index
    index_name = "kibana_objects-01"
    if index_exists(es, index_name):
        print(f"Index {index_name} already exists")

    else:
        # Proceed with CCR setup if the index does not exist
        with open(f"{base_path}/_meta/monitoring_cluster/ccr.json") as f:
            ccr_body = json.load(f)
        es.ccr.follow(body=ccr_body, index=index_name)
        print("Follower index created")

    # Put enrich processor
    policy_name = "objectid-policy"
    try:
        if not enrich_policy_exists(es, policy_name):
            with open(f"{base_path}/_meta/monitoring_cluster/enrich.json") as f:
                enrich_body = json.load(f)
            es.enrich.put_policy(name=policy_name, body=enrich_body)
            print("Enrich policy created")
        else:
            print("Enrich policy already exists")
    except BadRequestError as e:
        print(f"Attempted to create an enrich policy that already exists: {e}")

    time.sleep(10)

    es.enrich.execute_policy(name="objectid-policy", wait_for_completion=True)
    print("Enrich policy executed")

    # Create ingest pipeline
    with open(f"{base_path}/_meta/monitoring_cluster/ingest-pipeline.json") as f:
        pipeline_body = json.load(f)
    es.ingest.put_pipeline(id="enrich-ids", body=pipeline_body)
    print("Ingest pipeline created in monitoring cluster.")

    # Create component template
    with open(f"{base_path}/_meta/monitoring_cluster/component-template.json") as f:
        template_body = json.load(f)
    es.cluster.put_component_template(name="transform-obj", body=template_body)
    print("Component template created in monitoring cluster.")

    # Create index template
    with open(f"{base_path}/_meta/monitoring_cluster/index-template.json") as f:
        template_body = json.load(f)
    es.indices.put_index_template(name="kibana-transform", body=template_body)
    print("Index template created in monitoring cluster.")

    # Set-up watcher in mon cluster
    setup_watcher_with_jinja(
        es, config, f"{base_path}/_meta/monitoring_cluster/watcher.json"
    )

    transform_id = "kibana-transform-02"
    if transform_exists(es, transform_id):
        print("Transform already exists in monitoring cluster.")
    else:
        with open(f"{base_path}/_meta/monitoring_cluster/transform.json") as f:
            transform_body = json.load(f)
        es.transform.put_transform(transform_id=transform_id, body=transform_body)
        print("Transform created in monitoring cluster.")
        es.transform.start_transform(transform_id="kibana-transform-02")
        print("Transform started")

    time.sleep(30)

    # Check if a certain field exists
    if not check_field_exists(
        es, config, index="kibana-transform-02", field_name="object_title"
    ):
        es.transform.stop_transform(
            transform_id="kibana-transform-02", wait_for_completion=True
        )
        print("Transform stopped because the required field does not exist.")

        es.transform.reset_transform(transform_id="kibana-transform-02")
        print("Transform reset.")

        es.transform.start_transform(transform_id="kibana-transform-02")
        print("Transform restarted after resetting.")

    return es


def setup_remote_settings_with_jinja(es, config, remote_settings_path):
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


def setup_watcher_with_jinja(es, config, watcher_template_path):
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

    with open(watcher_template_path, "r") as file:
        template_content = file.read()

    template = Template(template_content)
    watcher_config_str = template.render(
        host=config["watcher_monitoring"]["host"],
        api_key=config["watcher_monitoring"]["api_key"],
    )

    watcher_config = json.loads(watcher_config_str)
    es.watcher.put_watch(id="policy-execute", body=watcher_config)
    print("Watcher setup in monitoring cluster.")


def check_field_exists(es, config, index, field_name):
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
    body = {"query": {"exists": {"field": field_name}}, "size": 0}
    response = es.search(index=index, body=body)
    return response["hits"]["total"]["value"] > 0