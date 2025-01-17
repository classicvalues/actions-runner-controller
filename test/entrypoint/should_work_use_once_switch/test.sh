#!/usr/bin/env bash

# UNITTEST: should work legacy once switch set
# Will simulate a scenario where RUNNER_FEATURE_FLAG_EPHEMERAL=false. expects:
# - the configuration step to be run exactly once
# - the entrypoint script to exit with no error
# - the run.sh script to run with the --once flag

source ../assets/logging.sh

entrypoint_log() {
  while read I; do
    printf "\tentrypoint.sh: $I\n"
  done
}

log "Setting up test area"
export RUNNER_HOME=testarea
mkdir -p ${RUNNER_HOME}

log "Setting up the test"
export UNITTEST=true
export RUNNER_NAME="example_runner_name"
export RUNNER_REPO="myorg/myrepo"
export RUNNER_TOKEN="xxxxxxxxxxxxx"
export RUNNER_FEATURE_FLAG_EPHEMERAL="false"
export RUNNER_EPHEMERAL="true"

# run.sh and config.sh get used by the runner's real entrypoint.sh and are part of actions/runner.
# We change symlink dummy versions so the entrypoint.sh can run allowing us to test the real entrypoint.sh
log "Symlink dummy config.sh and run.sh"
ln -s ../../assets/config.sh ${RUNNER_HOME}/config.sh
ln -s ../../assets/run.sh ${RUNNER_HOME}/run.sh

cleanup() {
  rm -rf ${RUNNER_HOME}
  unset UNITTEST
  unset RUNNERHOME
  unset RUNNER_NAME
  unset RUNNER_REPO
  unset RUNNER_TOKEN
  unset RUNNER_EPHEMERAL
  unset RUNNER_FEATURE_FLAG_EPHEMERAL
}

# Always run cleanup when test ends regardless of how it ends
trap cleanup SIGINT SIGTERM SIGQUIT EXIT

log "Running the entrypoint"
log ""

# run.sh and config.sh get used by the runner's real entrypoint.sh and are part of actions/runner.
# We change symlink dummy versions so the entrypoint.sh can run allowing us to test the real entrypoint.sh
../../../runner/entrypoint.sh 2> >(entrypoint_log)

if [ "$?" != "0" ]; then
  error "==========================================="
  error "FAIL | Entrypoint script did not exit successfully"
  exit 1
fi

log "Testing if we went through the configuration step only once"
count=`cat ${RUNNER_HOME}/counter || echo "not_found"`
if [ ${count} != "1" ]; then
  error "==============================================="
  error "FAIL | The configuration step was not run exactly once"
  exit 1
fi

success "PASS | The configuration ran ${count} time(s)"

log "Testing if the configuration included the --once flag"
if ! grep -q -- '--once' ${RUNNER_HOME}/runner_args; then
  error "==============================================="
  error "FAIL | The configuration did not include the --once flag, config printed below:"
  exit 1
fi

success "PASS | The --once argument was passed in"

log "Testing if run.sh ran"
if [ ! -f "${RUNNER_HOME}/run_sh_ran" ]; then
  error "=============================="
  error "FAIL | The runner service has not run"
  exit 1
fi
success "PASS | run.sh ran"
success ""
success "==========================="
success "Test completed successfully"
