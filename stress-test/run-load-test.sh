#!/bin/bash

set -e

# Output with colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Application details - pre-configured for your specific containers with updated image names
APP_URL="http://143.198.108.197:3000"
DB_PORT="3306"
CONTAINER_FRONTEND="frontend2"       # Updated to match your docker run command
CONTAINER_DB="db5"                   # Updated to match your docker run command
CONTAINER_PARALLEL="parallel"         # Updated to match your docker run command
CONTAINER_VOICE="voice2-metrics"      # Updated to match your docker run command

echo -e "${YELLOW}Target URL for testing: ${APP_URL}${NC}"
echo -e "${YELLOW}Preparing to run stress test with 100 concurrent users...${NC}"

# Install hey for load testing if not already installed
if ! command -v hey &> /dev/null; then
    echo -e "${YELLOW}Installing hey tool for load testing...${NC}"
    wget -q https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_amd64
    chmod +x hey_linux_amd64
    sudo mv hey_linux_amd64 /usr/local/bin/hey
fi

# Create output directories
mkdir -p results

# Start docker stats collection for all your containers
echo -e "${YELLOW}Starting Docker stats collection for your containers...${NC}"
docker stats --format "{{.Container}}\t{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" \
  $CONTAINER_FRONTEND $CONTAINER_DB $CONTAINER_PARALLEL $CONTAINER_VOICE > results/docker-stats.log &
STATS_PID=$!

# Check voice2-metrics container health status (since it's marked unhealthy)
echo -e "${YELLOW}Checking voice2-metrics container health...${NC}"
HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' $CONTAINER_VOICE)
echo -e "Voice metrics container health status: ${RED}${HEALTH_STATUS}${NC}"
docker inspect --format='{{range .State.Health.Log}}{{.Output}}{{end}}' $CONTAINER_VOICE > results/voice_health.log
echo "Health check logs saved to results/voice_health.log"

# Run warmup test with 10 users on frontend
echo -e "${YELLOW}Running warmup test with 10 concurrent users on frontend...${NC}"
hey -n 100 -c 10 -t 30 "${APP_URL}" > results/warmup_test.log 2>&1

# Wait between tests
sleep 10

# Run main test with 100 concurrent users for 5 minutes
echo -e "${GREEN}Starting main stress test with 100 concurrent users for 5 minutes...${NC}"
echo -e "${YELLOW}This will help determine how your application performs under high load.${NC}"
hey -n 30000 -c 100 -t 300 "${APP_URL}" > results/stress_test_100users.log

# Generate CSV report from the stress test
hey -n 30000 -c 100 -t 300 -o csv "${APP_URL}" > results/stress_test_100users.csv

# Test MySQL database if needed
echo -e "${YELLOW}Testing database connection performance...${NC}"
if command -v mysqlslap &> /dev/null; then
    echo -e "${GREEN}Running database stress test...${NC}"
    # Using the provided MySQL root password
    DB_PASSWORD="my-secret-pw"
    
    mysqlslap --host=127.0.0.1 --port=$DB_PORT --user=root --password="$DB_PASSWORD" \
      --concurrency=25,50,100 --iterations=3 --number-of-queries=200 \
      --create-schema=stress_test --query="SELECT 1" --delimiter=";" \
      > results/db_stress_test.log 2>&1 || echo -e "${RED}Database test failed${NC}"
else
    echo -e "${RED}MySQL tools not available for database testing${NC}"
fi

# Create a detailed report
echo -e "${GREEN}Creating detailed report...${NC}"
cat > results/analyze-stress-test.py << 'EOL'
#!/usr/bin/env python3
import pandas as pd
import matplotlib
matplotlib.use('Agg')  # Use non-interactive backend
import matplotlib.pyplot as plt
import sys
import os

def analyze_stress_test(csv_file):
    # Read the CSV file
    try:
        df = pd.read_csv(csv_file)
        
        # Basic statistics
        total_requests = len(df)
        avg_response = df['response-time'].mean()
        max_response = df['response-time'].max()
        min_response = df['response-time'].min()
        percentile_90 = df['response-time'].quantile(0.9)
        percentile_99 = df['response-time'].quantile(0.99)
        
        # Group by status code
        status_counts = df['status-code'].value_counts()
        success_rate = status_counts.get(200, 0) / total_requests * 100 if total_requests > 0 else 0
        
        # Create report
        with open('stress_test_report.txt', 'w') as f:
            f.write("STRESS TEST REPORT - 100 CONCURRENT USERS\n")
            f.write("=======================================\n\n")
            f.write(f"Total Requests: {total_requests}\n")
            f.write(f"Success Rate: {success_rate:.2f}%\n\n")
            
            f.write("Response Time Statistics (seconds):\n")
            f.write(f"  Average: {avg_response:.4f}\n")
            f.write(f"  Minimum: {min_response:.4f}\n")
            f.write(f"  Maximum: {max_response:.4f}\n")
            f.write(f"  90th Percentile: {percentile_90:.4f}\n")
            f.write(f"  99th Percentile: {percentile_99:.4f}\n\n")
            
            f.write("Status Code Distribution:\n")
            for status, count in status_counts.items():
                f.write(f"  {status}: {count} ({count/total_requests*100:.2f}%)\n")
            
            f.write("\nKUBERNETES RESOURCE RECOMMENDATIONS\n")
            f.write("==================================\n")
            
            # Very simple recommendations based on response times
            if percentile_90 < 0.5:
                cpu_req = "0.5"
                mem_req = "512Mi"
                replicas = 2
            elif percentile_90 < 1.0:
                cpu_req = "1"
                mem_req = "1Gi"
                replicas = 2
            else:
                cpu_req = "2"
                mem_req = "2Gi"
                replicas = 3
            
            f.write(f"Based on the response times with 100 concurrent users:\n")
            f.write(f"  Recommended replicas: {replicas}\n")
            f.write(f"  CPU requests: {cpu_req}\n")
            f.write(f"  Memory requests: {mem_req}\n")
            
            if success_rate < 95:
                f.write(f"\n⚠️ WARNING: Success rate below 95% ({success_rate:.2f}%). Consider increasing resources.\n")
            if percentile_90 > 2.0:
                f.write(f"\n⚠️ WARNING: 90th percentile response time is high ({percentile_90:.2f}s). Consider increasing CPU allocation.\n")
        
        # Create response time histogram
        plt.figure(figsize=(10, 6))
        plt.hist(df['response-time'], bins=50, alpha=0.75)
        plt.title('Response Time Distribution')
        plt.xlabel('Response Time (seconds)')
        plt.ylabel('Frequency')
        plt.grid(True, alpha=0.3)
        plt.savefig('response_time_histogram.png')
            
        print("Analysis complete. Results saved to stress_test_report.txt")
        
    except Exception as e:
        print(f"Error analyzing stress test results: {e}")
        
if __name__ == "__main__":
    if len(sys.argv) > 1:
        csv_file = sys.argv[1]
    else:
        csv_file = 'stress_test_100users.csv'
    
    if not os.path.exists(csv_file):
        print(f"CSV file '{csv_file}' not found")
        sys.exit(1)
        
    analyze_stress_test(csv_file)
EOL

# Install Python and dependencies
if command -v pip3 &> /dev/null || command -v pip &> /dev/null; then
    echo -e "${YELLOW}Installing Python dependencies for analysis...${NC}"
    pip3 install pandas matplotlib --user 2>/dev/null || pip install pandas matplotlib --user
    
    cd results
    chmod +x analyze-stress-test.py
    python3 analyze-stress-test.py stress_test_100users.csv || python analyze-stress-test.py stress_test_100users.csv
    cd ..
else
    echo -e "${RED}Python not available. Skipping detailed analysis. Check the raw results in results/stress_test_100users.log${NC}"
fi

# Generate container-specific resource usage report
echo -e "${YELLOW}Generating container resource usage report...${NC}"
cat > report-containers.sh << 'EOL'
#!/bin/bash
echo "CONTAINER RESOURCE USAGE SUMMARY"
echo "==============================="
echo

containers=("frontend2" "db5" "parallel" "voice2-metrics")  # Updated container names

for container in "${containers[@]}"; do
  echo "Container: $container"
  echo "-----------------"
  docker stats --no-stream $container --format "CPU: {{.CPUPerc}}, Memory: {{.MemPerc}} ({{.MemUsage}})" || echo "Container not running"
  
  # Get estimated resource requirements for kubernetes
  CPU_PCT=$(docker stats --no-stream $container --format "{{.CPUPerc}}" | sed 's/%//')
  MEM_PCT=$(docker stats --no-stream $container --format "{{.MemPerc}}" | sed 's/%//')
  
  if [ ! -z "$CPU_PCT" ]; then
    CPU_REQ=$(echo "scale=2; $CPU_PCT/100 * 0.8" | bc)
    CPU_LIM=$(echo "scale=2; $CPU_PCT/100 * 1.5" | bc)
    MEM_REQ=$(echo "scale=0; $MEM_PCT * 20" | bc)  # Rough estimate to convert to MB
    MEM_LIM=$(echo "scale=0; $MEM_PCT * 30" | bc)  # Rough estimate to convert to MB
    
    echo "Kubernetes resource recommendations:"
    echo "  requests:"
    echo "    cpu: \"${CPU_REQ}\""
    echo "    memory: \"${MEM_REQ}Mi\""
    echo "  limits:"
    echo "    cpu: \"${CPU_LIM}\""
    echo "    memory: \"${MEM_LIM}Mi\""
  fi
  echo
done
EOL

chmod +x report-containers.sh
./report-containers.sh > results/container_resources.txt

# Stop stats collection
if [ ! -z "${STATS_PID+x}" ]; then
    kill $STATS_PID || true
    echo -e "${GREEN}Docker stats collection stopped${NC}"
fi

# Create summary report with timestamp
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
REPORT_FILE="stress_test_report_${TIMESTAMP}.txt"

echo -e "\n${GREEN}=== STRESS TEST COMPLETED ====${NC}"
echo -e "Raw results are available in: results/stress_test_100users.log"

if [ -f "results/stress_test_report.txt" ]; then
    echo -e "\n${YELLOW}=== TEST REPORT FOR ${APP_URL} ====${NC}"
    cat results/stress_test_report.txt
    
    # Create a timestamped copy of the report
    cp results/stress_test_report.txt results/$REPORT_FILE
    echo -e "\nReport saved to results/$REPORT_FILE"
fi

echo -e "\n${YELLOW}=== CONTAINER RESOURCE USAGE ====${NC}"
cat results/container_resources.txt

echo -e "\n${GREEN}Next steps:${NC}"
echo -e "1. Review the stress test report for performance metrics"
echo -e "2. Check the container resource usage to size your Kubernetes pods"
echo -e "3. Note that voice2-metrics container is unhealthy - investigate health issues"
echo -e "4. Use the recommended resource settings for your Kubernetes deployment"
