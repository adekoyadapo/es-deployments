output "cloud_id" {
  value = {
    source      = ec_deployment.source.elasticsearch.cloud_id,
    destination = ec_deployment.ccs.elasticsearch.cloud_id
  }
}

output "endpoint" {
  value = {
    source      = ec_deployment.source.elasticsearch.http_endpoint,
    destination = ec_deployment.ccs.elasticsearch.http_endpoint,
  }
}

output "credentials" {
  value = {
    source      = ec_deployment.source.elasticsearch_password,
    destination = ec_deployment.ccs.elasticsearch_password,
  }
  sensitive = true
}

output "env" {
  value     = <<EOL
LEADER_ELASTIC_CLOUD_ID="${ec_deployment.source.elasticsearch.cloud_id}"
LEADER_ELASTIC_HOST=${replace(replace(ec_deployment.source.elasticsearch.http_endpoint, "http://", ""), ":9200", "")}
LEADER_ELASTIC_PORT=9200
LEADER_ELASTIC_USERNAME=elastic
LEADER_ELASTIC_PASSWORD=${ec_deployment.source.elasticsearch_password}
FOLLOWER_ELASTIC_CLOUD_ID="${ec_deployment.ccs.elasticsearch.cloud_id}"
FOLLOWER_ELASTIC_HOST=${replace(replace(ec_deployment.ccs.elasticsearch.http_endpoint, "http://", ""), ":9200", "")}
FOLLOWER_ELASTIC_PORT=9200
FOLLOWER_ELASTIC_USERNAME=elastic
FOLLOWER_ELASTIC_PASSWORD=${ec_deployment.ccs.elasticsearch_password}
INDEX_NAME=demo
EVENTS_PER_SECOND=100
COUNT_INDEX_NAME=demo_count
SCHEME="http"
EOL
  sensitive = true
}