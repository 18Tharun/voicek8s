#!/bin/bash

# Install necessary tools if not already installed
which docker-stats-collector || curl -s https://raw.githubusercontent.com/bcicen/docker-stats-collector/master/install.sh | bash

echo "Starting stress test for Voice AI containers"
echo "Recording baseline stats..."

# Create output directory
mkdir -p results

# Start monitoring docker stats
docker-stats-collector > results/docker-stats.log &
COLLECTOR_PID=$!

# Run stress testing with varying load
echo "Starting load test..."

# Test MySQL database performance
echo "Testing database performance..."
if ! command -v mysqlslap &> /dev/null; then
  echo "Installing MySQL client tools..."
  apt-get update && apt-get install -y mysql-client || \
  yum install -y mysql || \
  echo "Cannot install MySQL client. Please install manually."
fi

# If mysqlslap is available, run DB stress test
if command -v mysqlslap &> /dev/null; then
  # Get container IP
  DB_CONTAINER_IP=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(docker ps -q --filter name=db))
  
  # Set MySQL root password
  DB_PASSWORD="my-secret-pw"
  
  echo "Running DB load tests on $DB_CONTAINER_IP"
  mysqlslap --host=$DB_CONTAINER_IP --user=root --password="$DB_PASSWORD" \
    --concurrency=50,100 --iterations=5 --number-of-queries=1000 \
    --create-schema=test --query="SELECT 1" --delimiter=";" \
    --verbose > results/db_load_test.log 2>&1
fi

# Test voice agent container
echo "Testing voice agent API endpoints..."
for i in {1..5}; do
  echo "Round $i: Simulating $((10*i)) concurrent users"
  
  # Use hey tool for load testing - adjust the endpoints based on your application
  # Install hey if needed: go get -u github.com/rakyll/hey
  hey -n 1000 -c $((10*i)) http://localhost:3002/api/health > results/voice_agent_load_${i}.log
  
  # Allow some time to collect metrics
  sleep 60
done

# Stop the collector
kill $COLLECTOR_PID

echo "Stress test complete. Results are saved in the results directory."
echo "Analyze results/docker-stats.log to determine resource requirements for each container."
