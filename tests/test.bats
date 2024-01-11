setup() {
  set -eu -o pipefail
  export DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )/.."
  export TESTDIR=~/tmp/test-ddev-dblog
  mkdir -p $TESTDIR
  export PROJNAME=ddev-dblog
  export DDEV_NON_INTERACTIVE=true
  ddev delete -Oy ${PROJNAME} >/dev/null 2>&1 || true
  cd "${TESTDIR}"
  ddev config --project-name=${PROJNAME}
  ddev start -y >/dev/null
}

health_checks() {
  # Do something useful here that verifies the add-on
  # ddev exec "curl -s elasticsearch:9200" | grep "${PROJNAME}-elasticsearch"
  state=$(ddev mysql -u root -proot -e "show variables like 'general_log';" | grep general_log | cut -f 2)
  case "$state" in
    OFF)
      ddev dblog on
      on=$(ddev mysql -u root -proot -e "show variables like 'general_log';" | grep general_log | cut -f 2)
      if [ "$on" != "ON"]; then
        echo "Failed to enable db query log"
        failed_dblog_command
      fi
      ;;
    ON)
      ddev dblog off
      off=$(ddev mysql -u root -proot -e "show variables like 'general_log';" | grep general_log | cut -f 2)
      if [ "$off" != "OFF"]; then
        echo "Failed to disable db query log"
        failed_dblog_command
      fi
      ;;
    *)
      echo "Could not determine log state"
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
  health_checks
}

@test "install from release" {
  set -eu -o pipefail
  cd ${TESTDIR} || ( printf "unable to cd to ${TESTDIR}\n" && exit 1 )
  echo "# ddev get chromatichq/ddev-dblog with project ${PROJNAME} in ${TESTDIR} ($(pwd))" >&3
  ddev get chromatichq/ddev-dblog
  ddev restart >/dev/null
  health_checks
}

