#!/bin/bash

if [ -z "$1" ]; then
	echo "Usage: $0 </path/to/bi-server>"
	exit 1
fi

MANTLEGLOB="$1/tomcat/webapps/pentaho/WEB-INF/lib/mantle-*.jar"
MANTLEJAR=$(ls $MANTLEGLOB)

if [ ! -f "$MANTLEJAR" ]; then
	echo "mantle jar not found in $MANTLEGLOB"
	exit 1
fi

cd $(dirname $0)
mkdir -p tmp/opt/pentaho/biserver-ce/pentaho-solutions
mkdir -p tmp/opt/pentaho/biserver-ce/tomcat/webapps/pentaho/WEB-INF/lib
rsync -aC --delete solution/ tmp/opt/pentaho/biserver-ce/pentaho-solutions

cp $MANTLEJAR tmp
pushd tmp
MANTLEJAR=$(basename $MANTLEJAR)
unzip $MANTLEJAR org/pentaho/mantle/server/MantleSettings.properties
awk '$0 !~ /^(num-startup-urls|startup-(url|name))/ { print $0 }' < org/pentaho/mantle/server/MantleSettings.properties > org/pentaho/mantle/server/MantleSettings.properties.new
mv org/pentaho/mantle/server/MantleSettings.properties.new org/pentaho/mantle/server/MantleSettings.properties
cat >> org/pentaho/mantle/server/MantleSettings.properties <<EOF
num-startup-urls=1
startup-url-1=/pentaho/content/pentaho-cdf/RenderXCDF?solution=CST&path=%2F&action=cst.xcdf&template=mantle
startup-name-1=CST
EOF
jar uvf $MANTLEJAR org/pentaho/mantle/server/MantleSettings.properties
mv $MANTLEJAR opt/pentaho/biserver-ce/tomcat/webapps/pentaho/WEB-INF/lib
rm -rf org
popd

user=$(git config --get user.name)
email=$(git config --get user.email)

# install fpm ruby gem if it's not installed
if [ -z "$(which fpm)" ]; then
	echo "Install fpm: gem install fpm"
	exit 1
fi

cat > tmp/preinst << EOF
#!/bin/bash
dpkg-divert --package pentaho-cst --add --rename \
	--divert /opt/pentaho/biserver-ce/tomcat/webapps/pentaho/WEB-INF/lib/$MANTLEJAR.orig \
	/opt/pentaho/biserver-ce/tomcat/webapps/pentaho/WEB-INF/lib/$MANTLEJAR

dpkg-divert --package pentaho-cst --add --rename \
	--divert /opt/pentaho/biserver-ce/pentaho-solutions/system/pentaho-cdf/template-dashboard-clean.html.orig \
	/opt/pentaho/biserver-ce/pentaho-solutions/system/pentaho-cdf/template-dashboard-clean.html
EOF

cat > tmp/postrm << EOF
#!/bin/bash
if [ remove = "$1" -o abort-install = "$1" -o disappear = "$1" ]; then
	dpkg-divert --package pentaho-cst --remove --rename \
	--divert /opt/pentaho/biserver-ce/pentaho-solutions/system/pentaho-cdf/template-dashboard-clean.html \
	/opt/pentaho/biserver-ce/pentaho-solutions/system/pentaho-cdf/template-dashboard-clean.html
fi
EOF
chmod +x tmp/preinst tmp/postrm

fpm --maintainer "$user <$email>" \
  --description 'Community Startup Tabs (CST) for Pentaho BI Server' \
  --url http://cst.webdetails.org/ \
  --depends pentaho-bi-server \
  --name pentaho-cst \
  --version $(date +%Y%m%d) \
  --architecture all \
  --pre-install tmp/preinst \
  --post-uninstall tmp/postrm \
  -s dir -t deb \
  -C tmp    ./opt/pentaho/biserver-ce

rm -rf tmp
