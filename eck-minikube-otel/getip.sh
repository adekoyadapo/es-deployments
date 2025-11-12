#!/bin/bash

# Function to retrieve the private IP address of the main interface
get_private_ip() {
    if [[ $(minikube status -p "$cluster_name") ]]; then
        ip=$(minikube -p "$cluster_name" ip)

    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # For macOS
        ip=$(ipconfig getifaddr en0)
    else
        # For Linux distributions
        ip=$(ip route get 1 | awk '{print $NF;exit}')
    fi

    echo "$ip"
}

# Function to convert IP address to sslip.io format
ip_to_sslip() {
    echo "$1" | tr '.' '-'
}

# Function to calculate network address based on /24 mask
get_network_address() {
    ip="$1"
    IFS='.' read -r -a octets <<< "$ip"
    echo "${octets[0]}.${octets[1]}.${octets[2]}.0/24"
}

# Main script
cluster_name="$1"
private_ip=$(get_private_ip)

if [[ -n "$private_ip" ]]; then
    sslip_io=$(ip_to_sslip "$private_ip").sslip.io
    private_network=$(get_network_address "$private_ip")
    echo "{\"sslip_io\": \"$sslip_io\", \"private_network\": \"$private_network\"}"
else
    echo "{\"error\": \"Failed to retrieve private IP address.\"}"
fi
