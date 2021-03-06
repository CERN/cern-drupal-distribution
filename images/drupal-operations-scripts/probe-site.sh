#!/bin/sh

usage() {
  echo "Usage: $0 --probe <probe_name>" 1>&2;
  exit 1;
}

# Options
ARGS=$(getopt -o 'p:' --long 'probe:' -- "$@") || exit 1
eval "set -- $ARGS"

while true; do
  case "$1" in
    (-p|--probe)
      export PROBE="$2"; shift 2;;
    (--) shift; break;;
    (*) usage;;
  esac
done
[[ -z "$PROBE" ]] && usage

# Whenever a probe fails, write a line to a file in emptydir
FILE=/var/run/${PROBE}_probe_failure

# We're doing a GET request to localhost:8080 and localhost:8080/user/login. The request will go first to nginx
# and then to php-fpm. The probes are on the php-fpm container.
# Doing the request directly to the unix socket in php-fpm didn't work.
# Related Issue: https://gitlab.cern.ch/webservices/webframeworks-planning/-/issues/616
HTTP_CODE_BASE=$(curl --max-time 200 --silent --fail --insecure -I localhost:8080 -w '%{http_code}\n' -o /dev/null)

# Expected responses:
# 200: normally working base URL
# 302: redirection (NOTE: not sure if there's a legitimate case to expect this)
# 403: fully private websites give this response
# 503: high load
if [[ "${HTTP_CODE_BASE}" -ne "200" && "${HTTP_CODE_BASE}" -ne "302" && "${HTTP_CODE_BASE}" -ne "403" && "${HTTP_CODE_BASE}" -ne "503" ]]; then
    echo "Probe failed" >> $FILE
    echo "Probe failed. Endpoint / responds with code: $HTTP_CODE_BASE"
    exit 1
fi

# NOTE: if the site is in maintenance mode or fully private, we expect the login button to still work.
HTTP_CODE_USER_LOGIN=$(curl --max-time 200 --silent --fail --insecure -I localhost:8080/user/login -w '%{http_code}\n' -o /dev/null)

# Expected responses:
# 302: redirection to the SSO page
if [[ "${HTTP_CODE_USER_LOGIN}" -ne "302" ]]; then
    echo "Probe failed" >> $FILE
    echo "Probe failed. Endpoint /user/login responds with code: $HTTP_CODE_USER_LOGIN"
    exit 1
fi

exit 0
