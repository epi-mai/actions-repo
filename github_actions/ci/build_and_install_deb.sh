#!/usr/bin/env bash
#
# e.g
# sudo ./script/build_and_install_deb.sh $TEST_PROJECT_NAME $APPLI_CODE

set -e

(($(id -u) != 0)) &&
  echo "[ERROR] ${0##*/}: needs root privileges" && exit 1

_APPNAME=$1
_APP_SOURCE_CODE=$2

_APPV=$(jq -r .PACKAGING.INF_VERSION $2/configs/APPINFOS)
_PKG_LOWER_NAME=$(jq -r .PACKAGING.INF_PACKAGE $2/configs/APPINFOS | tr '[:upper:]' '[:lower:]')


[[ -z ${_APPNAME} || -z ${_APPV} ]] &&
  echo "[ERROR] ${0##*/}: missing argument (voo4version appname appversion)" &&
  exit 1
  
  
  
echo "Start building .deb"

# Expected branch name: release-2.24 => 2.24
_VOO4V=$(echo $GITHUB_REF | sed 's/.*- *\([0-9]\{1,2\}.[0-9]\{1,3\}\).*/\1/')
# Add suffix "-alpha" to version number, used by staging branch, ex: 2.24-alpha
if [[ $GITHUB_REF =~ ^staging-.*$ ]]; then
    _VOO4V=$_VOO4V"-alpha"
fi

echo "Version: $_VOO4V"

# clean-up (only needed for local builds)
rm -f /etc/apt/sources.list.d/epiconcept.list
rm -rf /tmp/voozanoo4_* /tmp/deb-build

export DEBIAN_FRONTEND=noninteractive

touch /usr/local/bin/php_conf_deploy.sh
chmod 0755 /usr/local/bin/php_conf_deploy.sh
echo -n 'exit 0' > /usr/local/bin/php_conf_deploy.sh

