#!/bin/bash

# GreenPlum Cluster Initialization Script
# This script initializes a GreenPlum cluster with 2 segments without mirrors

set -e

echo "Starting GreenPlum cluster initialization..."

# Wait for all containers to be ready
echo "Waiting for all containers to be ready..."
sleep 30

# Set environment variables
export MASTER_DATA_DIRECTORY=/data/master/gpseg-1
export PGPORT=5432
export PGUSER=gpadmin
export PGPASSWORD=gpadmin

# Create necessary directories
echo "Creating directories..."
mkdir -p /data/master/gpseg-1
mkdir -p /data/primary
mkdir -p /data/logs

# Initialize the cluster
echo "Initializing GreenPlum cluster..."
gpinitsystem -c /opt/greenplum/config/gpinitsystem_config -h /opt/greenplum/config/segment_hostfile

# Start the cluster
echo "Starting GreenPlum cluster..."
gpstart -a

# Create database if it doesn't exist
echo "Creating database..."
createdb gpadmin || echo "Database already exists"

echo "GreenPlum cluster initialization completed successfully!"
