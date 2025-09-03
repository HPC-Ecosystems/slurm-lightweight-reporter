# Lightweight cluster reporting tool
# Uses native Slurm filebased logs (no accounting)
# 
# Does the lifting with BASH and then appends to the REPORT file
# Default is a weekly report
#
# Tested and developed on the OpenHPC2.x virtual lab 
# @ https://hpc-ecosystems.gitlab.io/training/openhpc-2.x-guide/
################################################################

#!/bin/bash

## CONFIG ##
# Specify folders and frequency of report
LOGFILE="/var/log/slurm/job_completions.log"
REPORT="/vagrant/slurm_weekly_summary.txt"

# Extract job records that have completed within the last $DAYS days using EndTime= field
# Note: This assumes EndTime is present and correctly formatted in the log
DAYS=7
CUTOFF=$(date --date="${DAYS} days ago" +"%Y-%m-%dT%H:%M:%S")

echo "Slurm Weekly Summary - $(date)" > "$REPORT"
echo "Reporting Window: Since $CUTOFF" >> "$REPORT"
echo "-----------------------------------" >> "$REPORT"

# Filter jobs
JOBS=$(awk -v cutoff="$CUTOFF" '
  /JobId=/ {
    if (match($0, /EndTime=([0-9\-T:]*)/, arr)) {
      if (arr[1] >= cutoff) print
    }
  }
' "$LOGFILE")

## SUMMARY COUNTS ##
# JOBS INFORMATION
# Count job states within the reporting window
echo "Job Counts:" >> "$REPORT"
echo "  Completed : $(echo "$JOBS" | grep -c "JobState=COMPLETED")" >> "$REPORT"
echo "  Cancelled : $(echo "$JOBS" | grep -c "JobState=CANCELLED")" >> "$REPORT"
echo "  Failed    : $(echo "$JOBS" | grep -c "JobState=FAILED")" >> "$REPORT"
echo "" >> "$REPORT"

# USER ACTIVITY
# Build per-user job statistics and tally Completed, Cancelled, Failed states
# Assumes 'UserId=' follows Slurm format (may require adaptation if customized)
echo "Jobs by User:" >> "$REPORT"

# Initialize counters
declare -A total completed failed cancelled

while IFS= read -r line; do
    user=$(echo "$line" | grep -oP 'UserId=\K[^()]+' | cut -d'(' -f1)
    [ -z "$user" ] && continue
    state=$(echo "$line" | grep -oP 'JobState=\K\S+')
    ((total["$user"]++))
    case "$state" in
        COMPLETED) ((completed["$user"]++)) ;;
        FAILED)    ((failed["$user"]++)) ;;
        CANCELLED) ((cancelled["$user"]++)) ;;
    esac
done <<< "$JOBS"

for user in "${!total[@]}"; do
    c=${completed[$user]:-0}
    f=${failed[$user]:-0}
    a=${cancelled[$user]:-0}
    printf "  %-10s %-3s  (Completed: %-2s  Cancelled: %-2s  Failed: %-2s)\n" "$user" "${total[$user]}" "$c" "$a" "$f"
done | sort -k2 -nr >> "$REPORT"

echo "" >> "$REPORT"


# NODE USAGE
# List unique NodeList entries used by jobs
# Warning: NodeList parsing may break if nodes are listed as ranges (e.g., node[001-004])
echo "Nodes Used:" >> "$REPORT"
echo "$JOBS" | awk '
  match($0, /NodeList=([a-zA-Z0-9_]+)/, arr) {
    if (arr[1] != "(null)") print arr[1]
  }
' | sort | uniq -c >> "$REPORT"
echo "" >> "$REPORT"

# Aggregate resource usage for TRES metrics (e.g., cpu, mem)
# Note: If 'Tres=' is missing from job log lines, these totals may be incomplete
# TRES mapped to slurm.conf
# @ → AccountingStorageTRES   = cpu,mem,energy,node,billing,fs/disk,vmem,pages

# AGGREGATE RESOURCES
echo "Resource Totals (TRES):" >> "$REPORT"
echo "$JOBS" | awk '
  match($0, /Tres=([^ ]+)/, t) {
    split(t[1], fields, ",")
    for (i in fields) {
      split(fields[i], kv, "=")
      key = kv[1]; val = kv[2]
      usage[key] += val
    }
  }
  END {
    for (k in usage) {
      print "  " k ": " usage[k]
    }
  }
' >> "$REPORT"

# Top 10 Users by CPU and Memory Usage
# Estimate CPU-hours and memory GB-hours per user by multiplying allocation by runtime
# Runtime sourced from Elapsed=HH:MM:SS, parsed into seconds
# TRES memory assumed to be in MB; converted to GB-hours via division by 1024
# Consider validating units if mixing node types with different accounting plugins

declare -A cpu_sec mem_sec

while IFS= read -r line; do
    user=$(echo "$line" | grep -oP 'UserId=\K[^()]+' | cut -d'(' -f1)
    [ -z "$user" ] && continue

    # Get CPU and memory allocation
    tres=$(echo "$line" | grep -oP 'Tres=\K[^ ]+')
    cpu=$(echo "$tres" | grep -oP 'cpu=\K[0-9]+' || echo 0)
    mem_raw=$(echo "$tres" | grep -oP 'mem=\K[0-9]+')
    mem=${mem_raw:-0}

    # Get runtime in HH:MM:SS
    elapsed=$(echo "$line" | grep -oP 'Elapsed=\K[0-9:]+')
    IFS=: read -r h m s <<< "${elapsed:-0:0:0}"
    runtime_sec=$(( 3600 * h + 60 * m + s ))

    # Tally usage
    ((cpu_sec["$user"] += cpu * runtime_sec))
    ((mem_sec["$user"] += mem * runtime_sec))
done <<< "$JOBS"

# CPU usage (in hours)
echo "Top 10 Users by CPU-Hours:" >> "$REPORT"
for user in "${!cpu_sec[@]}"; do
    ch=$(awk "BEGIN { printf \"%.2f\", ${cpu_sec[$user]}/3600 }")
    echo -e "$ch\t$user"
done | sort -rn | head -n 10 | awk '{printf "  %-10s %s CPU-hours\n", $2, $1}' >> "$REPORT"
echo "" >> "$REPORT"

# Mem usage (in GB-hours)
echo "Top 10 Users by Memory (GB-Hours):" >> "$REPORT"
for user in "${!mem_sec[@]}"; do
    gbh=$(awk "BEGIN { printf \"%.2f\", ${mem_sec[$user]}/3600/1024 }")
    echo -e "$gbh\t$user"
done | sort -rn | head -n 10 | awk '{printf "  %-10s %s GB-hours\n", $2, $1}' >> "$REPORT"
echo "" >> "$REPORT"

echo "Top 10 Users by CPU-Hours and Memory GB-Hours:" >> "$REPORT"

# Prepare combined records
for user in "${!cpu_sec[@]}"; do
    cpu_hr=$(awk "BEGIN { printf \"%.2f\", ${cpu_sec[$user]}/3600 }")
    mem_hr=$(awk "BEGIN { printf \"%.2f\", ${mem_sec[$user]}/3600/1024 }")
    echo -e "$cpu_hr\t$mem_hr\t$user"
done | sort -k1 -rn | head -n 10 | awk '{printf "  %-10s %10s CPU-hours   %10s GB-hours\n", $3, $1, $2}' >> "$REPORT"

echo "" >> "$REPORT"


# Per-User Resource Summary
# (combines CPU and memory usage for each user)
# (sorted by CPU usage by default -- can change for total resource or memory)
echo "Per-User Resource Summary:" >> "$REPORT"
for user in "${!cpu_sec[@]}"; do
    ch=$(awk "BEGIN { printf \"%.2f\", ${cpu_sec[$user]}/3600 }")
    gbh=$(awk "BEGIN { printf \"%.2f\", ${mem_sec[$user]}/3600/1024 }")
    printf "  %-10s %8s CPU-hours   %8s GB-hours\n" "$user" "$ch" "$gbh"
done | sort -k2 -nr >> "$REPORT"
echo "" >> "$REPORT"

# DISK USAGE TRACKING
# Reports disk space statistics for key mount points (e.g., /, /home, /scratch)
# Consider tailoring mount points based on cluster layout
echo "Disk Usage Stats:" >> "$REPORT"
df -h | awk 'NR==1 || /\/(home|scratch|vagrant|$)/ { printf "  %-20s %-8s %-8s %-8s %-8s\n", $6, $2, $3, $4, $5 }' >> "$REPORT"
echo "" >> "$REPORT"

# per-user breakdowns
echo "Per-User Disk Usage (in Home Directory):" >> "$REPORT"

# Assumes user directories are under /home; adjust path as needed
for dir in /home/*; do
    user=$(basename "$dir")
    usage=$(du -sh "$dir" 2>/dev/null | awk '{print $1}')
    [ -n "$usage" ] && printf "  %-10s %s\n" "$user" "$usage"
done | sort -k2 -hr >> "$REPORT"

echo "" >> "$REPORT"

# DISK USAGE THRESHOLD CHECK
# Users exceeding defined threshold will be flagged
THRESHOLD_MB=190
THRESHOLD_BYTES=$((THRESHOLD_MB * 1024 * 1024))

echo "Disk Usage Threshold Warnings (>${THRESHOLD_MB}MB):" >> "$REPORT"

for dir in /home/*; do
    user=$(basename "$dir")
    usage_bytes=$(du -sb "$dir" 2>/dev/null | awk '{print $1}')
    if [ -n "$usage_bytes" ] && [ "$usage_bytes" -gt "$THRESHOLD_BYTES" ]; then
        usage_human=$(du -sh "$dir" | awk '{print $1}')
        printf "  %-10s %s exceeds threshold\n" "$user" "$usage_human"
    fi
done >> "$REPORT"

echo "" >> "$REPORT"
# historical snapshots
# TODO: history snapshots


# Mail summary
# Send report to configured address
# Replace with appropriate contact or remove if mail service is unavailable
# TODO: set up SMTP server (and relay)
mail -s "Slurm Weekly Summary" bryan@internal.domain < "$REPORT"
