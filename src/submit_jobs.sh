#!/bin/bash
# Run a VASP job in every strain_* folder, one after another, reusing the
# WAVECAR of the previous (smaller |strain|) run to speed up convergence.
#
# Order:  0.000 -> +0.005 -> +0.010 -> ...   (each seeded by the previous one)
#         0.000 -> -0.005 -> -0.010 -> ...
#
# Usage: SUB=submit_job.sh ./submit_jobs.sh   (SUB defaults to submit_job.sh)

SUB="${SUB:-submit_job.sh}"
TOP="$(cd "$(dirname "$0")" && pwd)"

[[ -f "$TOP/$SUB" ]] || { echo "ERROR: $TOP/$SUB not found" >&2; exit 1; }

n_ok=0; n_fail=0; failed=()

# run_one <dir> [src_dir]
# Runs $SUB in <dir>, first copying src_dir/WAVECAR in if it exists.
# Returns 0 if VASP terminated normally, 1 otherwise.
run_one() {
    local dir="$1" src="$2" name rc
    name="$(basename "$dir")"
    echo "[$(date '+%F %T')] START  $name"
    cp "$TOP/$SUB" "$dir/"
    chmod +x "$dir/$SUB"

    if [[ -n "$src" && -s "$src/WAVECAR" ]]; then
        cp "$src/WAVECAR" "$dir/WAVECAR"
        echo "                      WAVECAR <- $(basename "$src")"
    else
        echo "                      no WAVECAR, starting from scratch"
    fi

    ( cd "$dir" && taskset -c 0-95 "./$SUB" > log 2>&1 < /dev/null )
    rc=$?

    # Success = exit code 0 AND OUTCAR has VASP's normal-termination timing block
    if [[ $rc -eq 0 ]] && grep -q "General timing and accounting" "$dir/OUTCAR" 2>/dev/null; then
        echo "[$(date '+%F %T')] OK     $name (exit $rc)"
        ((n_ok++))
        return 0
    else
        echo "[$(date '+%F %T')] FAILED $name (exit $rc) -> see $name/log"
        ((n_fail++))
        failed+=("$name")
        return 1
    fi
}

# Split strain values into zero, positives (ascending) and negatives (increasing |strain|)
zero=""; pos=(); neg=()
while read -r v; do
    if awk -v x="$v" 'BEGIN { exit !(x + 0 > 0) }'; then
        pos+=("$v")
    elif awk -v x="$v" 'BEGIN { exit !(x + 0 < 0) }'; then
        neg=("$v" "${neg[@]}")
    else
        zero="$v"
    fi
done < <(for d in "$TOP"/strain_*/; do d="${d%/}"; echo "${d##*/strain_}"; done | sort -g)

echo "Job script: $SUB"
echo "Top dir:    $TOP"
echo "Order:      ${zero:+$zero }${pos[*]} ${neg[*]}"

# Unstrained reference first; it seeds both chains
zero_src=""
if [[ -n "$zero" ]]; then
    run_one "$TOP/strain_$zero" "" && zero_src="$TOP/strain_$zero"
fi

# run_chain <strain values...>: run outward from 0.000; after a failure,
# keep seeding from the last successful run in the chain
run_chain() {
    local prev="$zero_src" v d
    for v in "$@"; do
        d="$TOP/strain_$v"
        run_one "$d" "$prev" && prev="$d"
    done
}

run_chain "${pos[@]}"
run_chain "${neg[@]}"

echo "Done: $n_ok succeeded, $n_fail failed ${failed[*]}"
