setup() {
  set -eu -o pipefail
  export DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )/.."
  export TESTDIR=~/tmp/test-ddev-dblog
  mkdir -p $TESTDIR
  export PROJNAME=ddev-dblog
  export DDEV_NON_INTERACTIVE=true
  ddev delete -Oy ${PROJNAME} >/dev/null 2>&1 || true
  cd "${TESTDIR}"
  # @todo Work to get multiple database server types to be installable here.
  # ddev doesn't natively support more than one database per environment, so
  # perhaps some hacking will be necessary so we can test support for other
  # server types down the road.
  ddev config --project-name=${PROJNAME} --database=mariadb:10.11
  ddev start -y >/dev/null
}

capture_state() {
  state=$(ddev mysql -u root -proot -e "show variables like 'general_log';" | grep general_log | cut -f 2)
  echo "# dblog state: $state" >&3
}

health_checks() {
  # Do something useful here that verifies the add-on
  echo "# Running health checks..." >&3
  ddev dblog ping | grep 'OK'
}

teardown() {
  set -eu -o pipefail
  cd ${TESTDIR} || ( printf "unable to cd to ${TESTDIR}\n" && exit 1 )
  ddev delete -Oy ${PROJNAME} >/dev/null 2>&1
  [ "${TESTDIR}" != "" ] && rm -rf ${TESTDIR}
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

@test "install from release" {
  set -eu -o pipefail
  cd ${TESTDIR} || ( printf "unable to cd to ${TESTDIR}\n" && exit 1 )
  echo "# ddev get chromatichq/ddev-dblog with project ${PROJNAME} in ${TESTDIR} ($(pwd))" >&3
  ddev get chromatichq/ddev-dblog
  ddev restart
  health_checks
}

@test "install from directory" {
  set -eu -o pipefail
  cd ${TESTDIR}
  echo "# ddev get ${DIR} with project ${PROJNAME} in ${TESTDIR} ($(pwd))" >&3
  ddev get ${DIR}
  ddev restart
  health_checks
}

@test "toggle dblog state" {
  toggle
  toggle
}
