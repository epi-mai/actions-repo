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

#
# dependencies
#
# Remove rwky-redis.list to prevent 404, probably unuseable for trusty.
# SBL 27/06/2017: mis en commentaire car fait planter le build. Probablement
# depuis le passage sur les VM Trusty de Travis.
# rm /etc/apt/sources.list.d/rwky-redis.list
curl -u travisci:${APT_PASSWORD} https://apt.epiconcept.fr/prep/key.gpg | sudo apt-key add -
echo 'deb [arch=amd64,all] https://apt.epiconcept.fr/prep/ jessie main' | sudo tee /etc/apt/sources.list.d/epiconcept.list > /dev/null
echo -e "machine apt.epiconcept.fr\nlogin travisci\npassword ${APT_PASSWORD}" | sudo tee /etc/apt/auth.conf


#
# install dependencies
#
rm -rf /space
# Build the file tree
cp -R ${0%/*}/../deb-build/packages/system/epiconcept-arborescence/space /space/

mkdir /space/www/configuration/voozanoo4/ini
chown www-data: /space/www/configuration/voozanoo4/ini
mkdir /space/applisdata
chown www-data: /space/applisdata
mkdir /space/applistmp
chown www-data: /space/applistmp
mkdir /space/www/configuration/voozanoo4/env/
chown www-data: /space/www/configuration/voozanoo4/env/
dest=/space/www/configuration/voozanoo4/configuration
src=/space/www/configuration/voozanoo4/ini
if [ ! -e "$dest" ]; then
        ln -s $src $dest
fi

# XXX travis pre-installs MySQL 5.6
sudo apt-get remove --purge "^mysql.*"
sudo apt-get autoremove
sudo apt-get autoclean
sudo rm -rf /var/lib/mysql
sudo rm -rf /var/log/mysql

apt-get update
apt-get install -y curl git
apt-get install -y jq
# Using the source code from Travis's git clone to get the dependances, because the mkpack
# was not called yet
_VOO4DEPS=$(
  jq -r '.PACKAGING.INF_DEPENDS[]' \
  $2/configs/APPINFOS
)

apt-get install -y apache2
sudo a2enmod ssl

apt-get install -y ${_VOO4DEPS}
apt-get install -y mysql-server
mysql -e "CREATE USER 'travis'@'localhost' IDENTIFIED BY 'travis';"
apt-get install -y epi-frontal

sudo add-apt-repository -y ppa:ondrej/php
sudo apt-get update

apt-get install -y php7.4-cli php7.4 php7.4-curl php7.4-mysql php7.4-xsl php7.4-mbstring libapache2-mod-php7.4

#
# Install Voozanoo4
#
mkdir -p /tmp/deb-build/i386/deb
echo "Building Voozanoo4 core"
${0%/*}/../cirecipes/deb-build/bin/mkpack.voo4core.sh --voo4-version=${_VOO4V}

echo "Installing Voozanoo4 core"
if [ -f "/var/lib/dpkg/lock" ]; then
  sleep 3 && sudo rm /var/lib/dpkg/lock
fi

packageName="voozanoo4_${_VOO4V}_${TRAVIS_BUILD_NUMBER}_$(date +"%Y%m%d%H%M%S").deb"
mv "/tmp/deb-build/i386/deb/voozanoo4_${_VOO4V}.deb" "/tmp/deb-build/i386/deb/${packageName}"
dpkg -i "/tmp/deb-build/i386/deb/${packageName}"
