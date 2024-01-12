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
  ddev config --project-name=${PROJNAME} --database=mariadb:10.4
  ddev start -y >/dev/null
}

health_checks() {
  # Do something useful here that verifies the add-on
  # ddev exec "curl -s elasticsearch:9200" | grep "${PROJNAME}-elasticsearch"
  state=$(ddev mysql -u root -proot -e "show variables like 'general_log';" | grep general_log | cut -f 2)
  echo "# Captured state is $state"
  case "$state" in
    OFF)
      echo "# Turning dblog on..."
      ddev dblog on
      on=$(ddev mysql -u root -proot -e "show variables like 'general_log';" | grep general_log | cut -f 2)
      if [ "$on" != "ON"]; then
        echo "Failed to enable db query log"
        failed_dblog_command
      fi
      ;;
    ON)
      echo "# Turning dblog off..."
      ddev dblog off
      off=$(ddev mysql -u root -proot -e "show variables like 'general_log';" | grep general_log | cut -f 2)
      if [ "$off" != "OFF"]; then
        echo "Failed to disable db query log"
        failed_dblog_command
      fi
      ;;
    *)
      echo "# Could not determine log state"
      failed_db_log_test
      ;;
  esac
}

teardown() {
  set -eu -o pipefail
  cd ${TESTDIR} || ( printf "unable to cd to ${TESTDIR}\n" && exit 1 )
  ddev delete -Oy ${PROJNAME} >/dev/null 2>&1
  [ "${TESTDIR}" != "" ] && rm -rf ${TESTDIR}
}

@test "install from directory" {
  set -eu -o pipefail
  cd ${TESTDIR}
  echo "# ddev get ${DIR} with project ${PROJNAME} in ${TESTDIR} ($(pwd))" >&3
  ddev get ${DIR}
  ddev restart
  echo "# Running health checks..."
  health_checks
}

@test "install from release" {
  set -eu -o pipefail
  cd ${TESTDIR} || ( printf "unable to cd to ${TESTDIR}\n" && exit 1 )
  echo "# ddev get chromatichq/ddev-dblog with project ${PROJNAME} in ${TESTDIR} ($(pwd))" >&3
  ddev get chromatichq/ddev-dblog
  ddev restart #>/dev/null
  echo "# Running health checks..."
  health_checks
}

