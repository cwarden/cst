#!/bin/bash

cd $(dirname $0) 
mkdir -p tmp/opt/pentaho/biserver-ce/pentaho-solutions
rsync -aC --delete solution/ tmp/opt/pentaho/biserver-ce/pentaho-solutions

user=$(git config --get user.name)
email=$(git config --get user.email)

# install fpm ruby gem if it's not installed
if [ -z "$(which fpm)" ]; then
	echo "Install fpm: gem install fpm"
	exit 1
fi

fpm --maintainer "$user <$email>" \
  --description 'Community Startup Tabs (CST) for Pentaho BI Server' \
  --url http://cst.webdetails.org/ \
  --depends pentaho-bi-server \
  --name pentaho-cst \
  --version $(date +%Y%m%d) \
  --architecture all \
  -s dir -t deb \
  -C tmp    ./opt/pentaho/biserver-ce

rm -rf tmp
