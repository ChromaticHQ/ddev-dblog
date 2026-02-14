#!/usr/bin/env bats

# Bats is a testing framework for Bash
# Documentation https://bats-core.readthedocs.io/en/stable/
# Bats libraries documentation https://github.com/ztombol/bats-docs

# For local tests, install bats-core, bats-assert, bats-file, bats-support
# And run this in the add-on root directory:
#   bats ./tests/test.bats
# To exclude release tests:
#   bats ./tests/test.bats --filter-tags '!release'
# For debugging:
#   bats ./tests/test.bats --show-output-of-passing-tests --verbose-run --print-output-on-failure

setup() {
  set -eu -o pipefail

  # Override this variable for your add-on:
  export GITHUB_REPO=ddev/ddev-dblog

  TEST_BREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
  export BATS_LIB_PATH="${BATS_LIB_PATH}:${TEST_BREW_PREFIX}/lib:/usr/lib/bats"
  bats_load_library bats-assert
  bats_load_library bats-file
  bats_load_library bats-support

  export DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." >/dev/null 2>&1 && pwd)"
  export PROJNAME="test-$(basename "${GITHUB_REPO}")"
  mkdir -p "${HOME}/tmp"
  export TESTDIR="$(mktemp -d "${HOME}/tmp/${PROJNAME}.XXXXXX")"
  export DDEV_NONINTERACTIVE=true
  export DDEV_NO_INSTRUMENTATION=true
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1 || true
  cd "${TESTDIR}"
  # @todo Work to get multiple database server types to be installable here.
  # ddev doesn't natively support more than one database per environment, so
  # perhaps some hacking will be necessary so we can test support for other
  # server types down the road.
  run ddev config --project-name="${PROJNAME}" --project-tld=ddev.site --database=mariadb:10.11
  assert_success
  run ddev start -y
  assert_success
}

capture_state() {
  state=$(ddev mysql -u root -proot -e "show variables like 'general_log';" | grep general_log | cut -f 2)
  echo "# dblog state: $state" >&3
}

health_checks() {
  # Do something useful here that verifies the add-on

  # You can check for specific information in headers:
  # run curl -sfI https://${PROJNAME}.ddev.site
  # assert_output --partial "HTTP/2 200"
  # assert_output --partial "test_header"

  # Or check if some command gives expected output:
  # DDEV_DEBUG=true run ddev launch
  # assert_success
  # assert_output --partial "FULLURL https://${PROJNAME}.ddev.site"

  echo "# Running health checks..." >&3
  ddev dblog ping | grep 'OK'
}

teardown() {
  set -eu -o pipefail
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1
  # Persist TESTDIR if running inside GitHub Actions. Useful for uploading test result artifacts
  # See example at https://github.com/ddev/github-action-add-on-test#preserving-artifacts
  if [ -n "${GITHUB_ENV:-}" ]; then
    [ -e "${GITHUB_ENV:-}" ] && echo "TESTDIR=${HOME}/tmp/${PROJNAME}" >> "${GITHUB_ENV}"
  else
    [ "${TESTDIR}" != "" ] && rm -rf "${TESTDIR}"
  fi
}

toggle() {
  echo "# Test toggle of dblog state..." >&3
  capture_state
  case "$state" in
    OFF)
      echo "# Turning dblog on..." >&3
      ddev dblog on
      capture_state
      echo "# dblog state is now $state" >&3
      if [ "$state" != "ON"]; then
        echo "Failed to enable db query log" >&3
        failed_dblog_command
      fi
      ;;
    ON)
      echo "# Turning dblog off..." >&3
      ddev dblog off
      capture_state
      echo "# dblog state is now $state" >&3
      if [ "$state" != "OFF"]; then
        echo "Failed to disable db query log" >&3
        failed_dblog_command
      fi
      ;;
    *)
      echo "# Unexpected log state: $state" >&3
      failed_db_log_test
      ;;
  esac
}

@test "install from directory" {
  set -eu -o pipefail
  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success
  health_checks
}

# bats test_tags=release
@test "install from release" {
  set -eu -o pipefail
  echo "# ddev add-on get ${GITHUB_REPO} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${GITHUB_REPO}"
  assert_success
  run ddev restart -y
  assert_success
  health_checks
}

@test "toggle dblog state" {
  toggle
  toggle
}
