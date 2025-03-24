import pandas as pd
import matplotlib.pyplot as plt
import sys
import os

def analyze_docker_stats(log_file):
    # Read the docker stats log file
    data = []
    with open(log_file, 'r') as f:
        for line in f:
            if line.startswith('CONTAINER'):
                continue
            parts = line.strip().split()
            if len(parts) >= 7:
                container_id = parts[0]
                name = parts[1]
                cpu_percent = float(parts[2].strip('%'))
                mem_usage = parts[3]
                mem_percent = float(parts[5].strip('%'))
                data.append({
                    'container': name,
                    'cpu_percent': cpu_percent,
                    'mem_percent': mem_percent
                })
    
    # Convert to DataFrame
    df = pd.DataFrame(data)
    
    # Group by container and calculate statistics
    stats = df.groupby('container').agg({
        'cpu_percent': ['mean', 'max', 'min'],
        'mem_percent': ['mean', 'max', 'min']
    })
    
    # Create output directory
    os.makedirs('analysis', exist_ok=True)
    
    # Save results
    stats.to_csv('analysis/resource_usage_summary.csv')
    
    # Plot results
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(15, 6))
    
    for container in df['container'].unique():
        container_df = df[df['container'] == container]
        ax1.plot(container_df.index, container_df['cpu_percent'], label=container)
        ax2.plot(container_df.index, container_df['mem_percent'], label=container)
    
    ax1.set_title('CPU Usage (%)')
    ax2.set_title('Memory Usage (%)')
    ax1.legend()
    ax2.legend()
    
    plt.savefig('analysis/resource_usage.png')
    plt.show()
    
    print("Analysis complete. Results saved in 'analysis' directory.")
    print("\nRecommended instance types based on usage:")
    
    # Simple recommendation logic
    for container in stats.index:
        max_cpu = stats.loc[container, ('cpu_percent', 'max')]
        max_mem = stats.loc[container, ('mem_percent', 'max')]
        
        if max_cpu > 80 or max_mem > 80:
            print(f"{container}: High usage - Consider large instance type")
        elif max_cpu > 50 or max_mem > 50:
            print(f"{container}: Medium usage - Consider medium instance type")
        else:
            print(f"{container}: Low usage - Basic instance type should suffice")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python analyze-results.py <docker_stats_log_file>")
    else:
        analyze_docker_stats(sys.argv[1])
