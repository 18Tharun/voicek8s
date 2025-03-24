#!/bin/bash

set -e

# Output with colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Ask for website URL
read -p "Enter your website URL to test (e.g., https://yourdomain.com): " WEBSITE_URL
if [ -z "$WEBSITE_URL" ]; then
    echo -e "${RED}No URL provided. Using local endpoints for testing.${NC}"
    WEBSITE_URL="http://localhost"
fi

echo -e "${YELLOW}Setting up stress test environment for gradual traffic simulation...${NC}"
echo -e "${YELLOW}Target: ${WEBSITE_URL}${NC}"

# Install Python and pip if not already installed
if ! command -v pip3 &> /dev/null; then
    echo -e "${YELLOW}Installing Python3 and pip...${NC}"
    sudo apt-get update
    sudo apt-get install -y python3 python3-pip
fi

# Install Python dependencies
echo -e "${YELLOW}Installing Python dependencies...${NC}"
pip3 install pandas matplotlib --user

# Install hey for load testing if not already installed
if ! command -v hey &> /dev/null; then
    echo -e "${YELLOW}Installing hey tool for load testing...${NC}"
    wget -q https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_amd64
    chmod +x hey_linux_amd64
    sudo mv hey_linux_amd64 /usr/local/bin/hey
fi

# Install MySQL client tools if not present
if ! command -v mysql &> /dev/null; then
    echo -e "${YELLOW}Installing MySQL client tools...${NC}"
    sudo apt-get install -y mysql-client || echo -e "${RED}Failed to install MySQL client tools. Some tests may not work.${NC}"
fi

# Create output directories
mkdir -p results analysis

echo -e "${GREEN}Environment setup complete! Starting stress test...${NC}"

# Start collecting Docker stats directly (without docker-stats-collector)
echo -e "${YELLOW}Starting Docker stats collection...${NC}"
docker stats --format "{{.Container}}\t{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" > results/docker-stats.log &
STATS_PID=$!

# Progressive load testing for website with gradually increasing traffic
echo -e "${YELLOW}Starting progressive load testing to simulate growth from minimal to 100 users...${NC}"

# Stage 1: Minimal traffic (current state)
echo -e "${GREEN}Stage 1: Testing with minimal traffic (5 concurrent users)${NC}"
hey -n 50 -c 5 "$WEBSITE_URL" > results/website_minimal_load.log 2>&1 || echo -e "${RED}Website minimal load test failed${NC}"
sleep 30

# Stage 2: Medium traffic (growth stage)
echo -e "${GREEN}Stage 2: Testing with medium traffic (25 concurrent users)${NC}"
hey -n 100 -c 25 "$WEBSITE_URL" > results/website_medium_load.log 2>&1 || echo -e "${RED}Website medium load test failed${NC}"
sleep 30

# Stage 3: Target traffic (100 users)
echo -e "${GREEN}Stage 3: Testing with target traffic (100 concurrent users)${NC}"
hey -n 200 -c 100 "$WEBSITE_URL" > results/website_target_load.log 2>&1 || echo -e "${RED}Website target load test failed${NC}"
sleep 30

echo -e "${YELLOW}Running container tests...${NC}"

# Test database (MySQL) if accessible
DB_CONTAINERS=$(docker ps --filter "ancestor=abhishekanbu01/real-estate-calls-db" --format "{{.ID}}" || docker ps --filter "name=db" --format "{{.ID}}")
if [ ! -z "$DB_CONTAINERS" ]; then
    echo "Found database container: $DB_CONTAINERS"
    DB_IP=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $DB_CONTAINERS)
    
    if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
        read -sp "Enter MySQL root password: " MYSQL_ROOT_PASSWORD
        echo
    fi
    
    echo "Testing database at $DB_IP..."
    if command -v mysqlslap &> /dev/null; then
        mysqlslap --host=$DB_IP --user=root --password="$MYSQL_ROOT_PASSWORD" \
          --concurrency=10,50 --iterations=3 --number-of-queries=100 \
          --create-schema=stress_test --query="SELECT 1" --delimiter=";" \
          > results/db_test.log 2>&1 || echo -e "${RED}MySQL test failed${NC}"
    fi
else
    echo -e "${YELLOW}No database container found to test${NC}"
fi

# Test voice-agent container if accessible
VOICE_CONTAINERS=$(docker ps --filter "ancestor=abhishekanbu01/my-app-voice-agent" --format "{{.ID}}" || docker ps --filter "name=voice" --format "{{.ID}}")
if [ ! -z "$VOICE_CONTAINERS" ]; then
    echo "Found voice agent container: $VOICE_CONTAINERS"
    
    # Try to get mapped port for container
    VOICE_PORT=$(docker port $VOICE_CONTAINERS | grep -oP '(?<=:)\d+' | head -1)
    
    if [ ! -z "$VOICE_PORT" ]; then
        echo "Testing voice agent endpoints on port $VOICE_PORT..."
        for i in {1..3}; do
            echo "Round $i with ${i}0 concurrent connections..."
            hey -n 100 -c $((i*10)) http://localhost:$VOICE_PORT/ > results/voice_test_${i}.log 2>&1 || echo -e "${RED}Voice test $i failed${NC}"
            sleep 10
        done
    else
        echo -e "${RED}Could not determine voice container port mapping${NC}"
    fi
else
    echo -e "${YELLOW}No voice agent container found to test${NC}"
fi

# Let stats run for a total of 2 minutes
echo -e "${YELLOW}Continuing to collect stats for 60 more seconds...${NC}"
sleep 60

# Stop stats collection
kill $STATS_PID || true
echo -e "${GREEN}Stats collection stopped${NC}"

# Run analysis
echo -e "${YELLOW}Analyzing results...${NC}"
cat > analyze.py << 'EOL'
import pandas as pd
import matplotlib
matplotlib.use('Agg')  # Use non-interactive backend
import matplotlib.pyplot as plt
import sys
import os
import re

def parse_stats(log_file):
    data = []
    try:
        with open(log_file, 'r') as f:
            lines = f.readlines()
            
        for line in lines:
            if not line.strip():
                continue
                
            parts = line.strip().split('\t')
            if len(parts) >= 5:
                try:
                    container_id = parts[0]
                    name = parts[1]
                    cpu_percent = float(parts[2].replace('%', ''))
                    mem_percent = float(parts[4].replace('%', ''))
                    
                    data.append({
                        'container': name,
                        'cpu_percent': cpu_percent,
                        'mem_percent': mem_percent
                    })
                except (ValueError, IndexError) as e:
                    print(f"Error parsing line: {line.strip()} - {e}")
        
        if not data:
            print("No valid data found in log file")
            
        return pd.DataFrame(data)
    except Exception as e:
        print(f"Error processing log file: {e}")
        return pd.DataFrame()

def analyze_results(stats_file):
    df = parse_stats(stats_file)
    
    if df.empty:
        print("No data to analyze")
        return
    
    # Group by container and calculate stats
    stats = df.groupby('container').agg({
        'cpu_percent': ['mean', 'max'],
        'mem_percent': ['mean', 'max']
    })
    
    # Save to CSV
    stats.to_csv('analysis/resource_summary.csv')
    
    # Generate text report
    with open('analysis/recommendations.txt', 'w') as f:
        f.write("RESOURCE USAGE SUMMARY\n")
        f.write("=====================\n\n")
        
        for container in stats.index:
            avg_cpu = stats.loc[container, ('cpu_percent', 'mean')]
            max_cpu = stats.loc[container, ('cpu_percent', 'max')]
            avg_mem = stats.loc[container, ('mem_percent', 'mean')]
            max_mem = stats.loc[container, ('mem_percent', 'max')]
            
            f.write(f"Container: {container}\n")
            f.write(f"CPU: {avg_cpu:.1f}% average, {max_cpu:.1f}% peak\n")
            f.write(f"Memory: {avg_mem:.1f}% average, {max_mem:.1f}% peak\n")
            
            # Calculate kubernetes resources
            cpu_req = max(0.1, avg_cpu / 100)
            cpu_lim = max(0.2, max_cpu / 100 * 1.5)
            mem_req = max(128, avg_mem * 2)  # MB
            mem_lim = max(256, max_mem * 3)  # MB
            
            f.write("\nKubernetes Resource Recommendation:\n")
            f.write("resources:\n")
            f.write("  requests:\n")
            f.write(f"    cpu: \"{cpu_req:.1f}\"\n")
            f.write(f"    memory: \"{int(mem_req)}Mi\"\n")
            f.write("  limits:\n")
            f.write(f"    cpu: \"{cpu_lim:.1f}\"\n")
            f.write(f"    memory: \"{int(mem_lim)}Mi\"\n\n")
        
        # Node sizing recommendation
        total_cpu = sum(stats[('cpu_percent', 'max')]) / 100 * 1.5
        total_mem = sum(stats[('mem_percent', 'max')]) / 100 * 1.5
        
        f.write("\nRECOMMENDED NODE SIZE\n")
        f.write("====================\n")
        if total_cpu <= 1:
            f.write("CPU: Small instance (1 vCPU)\n")
        elif total_cpu <= 2:
            f.write("CPU: Medium instance (2 vCPU)\n")
        else:
            f.write(f"CPU: Large instance ({int(total_cpu + 1)} vCPU)\n")
            
        if total_mem <= 1:
            f.write("Memory: 1GB RAM\n")
        elif total_mem <= 2:
            f.write("Memory: 2GB RAM\n")
        elif total_mem <= 4:
            f.write("Memory: 4GB RAM\n")
        else:
            f.write(f"Memory: {int(total_mem + 2)}GB RAM\n")
    
    # Generate plots if possible
    try:
        for metric in ['cpu_percent', 'mem_percent']:
            plt.figure(figsize=(10, 6))
            for container in df['container'].unique():
                container_df = df[df['container'] == container]
                plt.plot(range(len(container_df)), container_df[metric], label=container)
            
            plt.title(f"{'CPU' if metric == 'cpu_percent' else 'Memory'} Usage Over Time")
            plt.xlabel("Time")
            plt.ylabel("Percentage (%)")
            plt.legend()
            plt.tight_layout()
            plt.savefig(f"analysis/{metric}_usage.png")
            plt.close()
    except Exception as e:
        print(f"Error generating plots: {e}")
    
    print("Analysis complete. Results saved to analysis/ directory.")

# Run analysis
if __name__ == "__main__":
    if not os.path.exists('analysis'):
        os.makedirs('analysis')
        
    if len(sys.argv) > 1:
        stats_file = sys.argv[1]
    else:
        stats_file = 'results/docker-stats.log'
    
    if not os.path.exists(stats_file):
        print(f"Stats file '{stats_file}' not found")
        sys.exit(1)
        
    analyze_results(stats_file)
EOL

# Run analysis script
python3 analyze.py results/docker-stats.log

echo -e "${GREEN}Stress test and analysis completed successfully!${NC}"
echo -e "${GREEN}Check the 'analysis' directory for results and recommendations.${NC}"
echo -e "${GREEN}Key findings are in analysis/recommendations.txt${NC}"
echo -e "${GREEN}Website performance test results are in results/website_*_load.log files${NC}"

# Output key recommendations
if [ -f "analysis/recommendations.txt" ]; then
    echo -e "\n${YELLOW}=== KEY RECOMMENDATIONS ====${NC}"
    cat analysis/recommendations.txt
fi

# Add growth planning section
cat >> analysis/recommendations.txt << EOF

GROWTH PLAN RECOMMENDATIONS
==========================
Based on your current minimal traffic with plans to scale to 100 users:

1. Initial Deployment:
   - Start with smaller instance sizes (s-1vcpu-2gb)
   - Use minimum replicas (1 per service)
   
2. Monitoring:
   - Set up alerts for when CPU/Memory usage exceeds 70%
   - Monitor response times to ensure they stay below 500ms

3. Scaling Strategy:
   - Implement Horizontal Pod Autoscaling (HPA) at 75% CPU utilization
   - Scale pods up to handle traffic spikes
   - Consider using DigitalOcean Kubernetes cluster autoscaling

4. Database Scaling:
   - Start with the smallest viable database instance
   - Consider read replicas when query load increases
   - Implement connection pooling to efficiently manage connections

5. Cost Management:
   - Use DigitalOcean container registry to reduce image pull times
   - Consider scheduled scaling for predictable traffic patterns
EOF
