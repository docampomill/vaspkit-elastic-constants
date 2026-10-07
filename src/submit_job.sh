#!/bin/bash

RUN_DIR="${RUN_DIR:-$PWD}"
LOG_DIR="${RUN_DIR}/logs"

TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
STDOUT_FILE="${LOG_DIR}/vasp_${TIMESTAMP}.out"
STDERR_FILE="${LOG_DIR}/vasp_${TIMESTAMP}.err"
SUMMARY_FILE="${LOG_DIR}/vasp_${TIMESTAMP}.summary"

mkdir -p "$LOG_DIR"

START_TIME="$(date --iso-8601=seconds)"
START_SECONDS="$(date +%s)"
echo "Starting VASP"
echo "Host:      $(hostname)"
echo "Directory: $RUN_DIR"
echo "Stdout:    $STDOUT_FILE"
echo "Stderr:    $STDERR_FILE"
echo "Started:   $START_TIME"

# Launch the wrapper.
vasp-mpirun -np 96 vasp_std >"$STDOUT_FILE" 2>"$STDERR_FILE" &
WRAPPER_PID=$!

# Wait up to 10 seconds for the actual MPI launcher to appear.
rm -f vasp.pid
VASP_PID=""

for ((i = 0; i < 50; i++)); do
    VASP_PID=$(pgrep -P "$WRAPPER_PID" -x mpiexec.hydra)

    if [[ -n "$VASP_PID" ]]; then
        break
    fi

    kill -0 "$WRAPPER_PID" 2>/dev/null || break
    sleep 0.1
done

if [[ -n "$VASP_PID" ]]; then
    echo "$VASP_PID" > vasp.pid
    echo "MPI launcher PID: $VASP_PID"
else
    echo "WARNING: Could not identify the MPI launcher; vasp.pid was not created." >&2
fi

# Wait for the wrapper and capture the calculation's exit status.
wait "$WRAPPER_PID"
EXIT_CODE=$?

END_TIME="$(date --iso-8601=seconds)"
END_SECONDS="$(date +%s)"
DURATION_SECONDS=$((END_SECONDS - START_SECONDS))

if [[ $EXIT_CODE -eq 0 ]]; then
    RESULT="SUCCEEDED"
else
    RESULT="FAILED"
fi

{
    echo "VASP job $RESULT"
    echo
    echo "Host:          $(hostname)"
    echo "Directory:     $RUN_DIR"
    echo "Started:       $START_TIME"
    echo "Finished:      $END_TIME"
    echo "Duration:      ${DURATION_SECONDS} seconds"
    echo "Exit code:     $EXIT_CODE"
    echo "Stdout file:   $STDOUT_FILE"
    echo "Stderr file:   $STDERR_FILE"
    echo
    echo "Last 40 lines of stdout:"
    echo "----------------------------------------"
    tail -n 40 "$STDOUT_FILE"
    echo
    echo "Last 40 lines of stderr:"
    echo "----------------------------------------"
    tail -n 40 "$STDERR_FILE"
} >"$SUMMARY_FILE"

SUBJECT="[VASP] ${RESULT} on $(hostname), exit code ${EXIT_CODE}"

cat "$SUMMARY_FILE"

exit "$EXIT_CODE"
