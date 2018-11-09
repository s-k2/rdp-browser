#!/bin/bash

function die() {
	>&2 echo 
	>&2 echo "--------------------------------------------------------------------------------"
	>&2 echo "An unrecoverable and unexpected error occured!"
	>&2 echo "    What failed? $1"
	>&2 echo "Exiting now!"
	>&2 echo "--------------------------------------------------------------------------------"
	exit 1
}

function askYesNo() {
	while true; do
		read -p "$1 (y|n): " -n 1 -r REPLY
		echo # move to a new line

		if [[ $REPLY =~ ^[Yy]$ ]]
		then
			return 0
		elif [[ $REPLY =~ ^[Nn]$ ]]
		then
			return 1
		fi
	done
}

echo 
echo "What is the IP address of the internal network-interface?"
echo "---------------------------------------------------------"
echo 
echo "  By default the RDP service is accessible from all network-interfaces."
echo "  This would include the one connected to the internet!"
echo "  Limit it to the internal network by entering the internal IP of this computer!"
echo 
read -p "Enter the internal IP (leave blank = all interfaces): " -r LISTEN_ADDRESS
if [ -z "$LISTEN_ADDRESS" ]; then
	LISTEN_ADDRESS=0.0.0.0
fi

echo 
echo 
echo "Where to put the downloaded files?"
echo "----------------------------------"
echo 
echo "  EITHER: Download to a temporary-folder"
echo "     -> No one can really access them and they are gone if the session ends"
echo 
echo "  OR: Put them to a premanent directory, e. g. a mounted network-drive"
echo "     -> You need to make the directory readable for the user 'browser'!"
echo "        BTW: Make sure that this directory won't become a home for viruses and trojans"
echo 
read -p "Enter download-directory (leave blank for temporary): " -r DOWNLOAD_DIR

echo 
echo 
echo "Block installation of xterm/xedit/xutils?"
echo "-----------------------------------------"
echo 
echo "  By default some basic X11 programs (e. g. terminal, editor, ...) are dependencies of X11."
echo "  This script can prevent the installation of those tools if you want!"
echo 
echo "  EITHER yes: Create fake-packages that prevent the installation"
echo "     -> The only usable X11 program is the browser"
echo "        BUT: You can't install those programs on this computer anymore!"
echo 
echo "  OR: Let your users play with these programs (started through some downloads)"
echo "     -> A terminal is an interesting tool for a user who doesn't behave well!"
echo 
askYesNo "Block the installation of xterm?" && BLOCK_XTOOLS=y

echo 
echo 
echo "Install updates every hour?"
echo "---------------------------"
echo 
echo "  If you enter yes, this will put a simple script to /etc/cron.hourly"
echo "  It will run 'apt-get update' and 'apt-get dist-upgrade' every hour."
echo 
echo "  This should work just fine, but you will never get reports about its work."
echo "  Furthermore if a failed update might break your system!"
echo "  If you know how to setup it, maybe you should use the package 'unattended-upgrades'"
echo 
askYesNo "Install updates every hour?" && HOURLY_UPDATE=y


echo
echo

###################################################################################################

function createFakePackage() {
	local FAKE_NAME=$1

	mkdir -p usr/share/doc/$FAKE_NAME
	echo $FAKE_NAME' fake package' >usr/share/doc/$FAKE_NAME/README.Debian
	echo 'Nobody wants to claim copyright for the fake '$FAKE_NAME >usr/share/doc/$FAKE_NAME/copyright
	echo 'Nobody has ever worked on that fake '$FAKE_NAME >usr/share/doc/$FAKE_NAME/changelog
	gzip usr/share/doc/$FAKE_NAME/changelog

	tar czf data.tar.gz usr

	local INSTALLED_SIZE="$(du -ks usr|cut -f 1)"

	echo 'Package: '$FAKE_NAME >control
	echo 'Version: 1:999' >>control
	echo 'Architecture: all' >>control
	echo 'Maintainer: Some Dummy <dummy@dummy.com>' >>control
	echo 'Installed-Size: '$INSTALLED_SIZE >>control
	echo 'Section: misc' >>control
	echo 'Priority: optional' >>control
	echo 'Multi-Arch: foreign' >>control
	echo 'Description: Dummy package to fulfill package dependencies' >>control
	echo " This is a dummy package that makes Debian's package management" >>control
	echo ' system believe that equivalents to packages on which other' >>control
	echo ' packages depend on are actually installed.  Deinstallation of' >>control
	echo ' this package is only possible when all pending dependency issues' >>control
	echo ' are properly resolved in some other way.' >>control
	echo ' .' >>control
	echo ' Please note that this is a crude hack and if thoughtlessly used' >>control
	echo ' might possibly do damage to your packaging system.  And please' >>control
	echo ' note as well that using it is not the recommended way of dealing' >>control
	echo ' with broken dependencies.  It is better to file a bug report.' >>control

	md5sum usr/share/doc/$FAKE_NAME/README.Debian >md5sums
	md5sum usr/share/doc/$FAKE_NAME/copyright >>md5sums
	md5sum usr/share/doc/$FAKE_NAME/changelog.gz >>md5sums

	tar czf control.tar.gz control md5sums

	echo "2.0" >debian-binary

	PKG_NAME=$FAKE_NAME'_999_all.deb'

	ar r $PKG_NAME debian-binary control.tar.gz data.tar.gz 2>/dev/null
	rm -Rf usr data.tar.gz control md5sums control.tar.gz debian-binary 
}


if [ -n "$BLOCK_XTOOLS" ]; then
	echo "Creating fake packages to prevent x11-apps, x11-tools and xterm to get installed"

	dpkg -s binutils >/dev/null 2>/dev/null || INSTALL_AND_REMOVE_BINUTILS=1
	if [ -n "$INSTALL_AND_REMOVE_BINUTILS" ]; then
		apt-get install -qq -y binutils >/dev/null || die "Installation of binutils failed"
	fi

	mkdir FakeXTools || die "There is already an directory FakeXTools within this directory. Please cd to another!"
	cd FakeXTools
	createFakePackage x11-apps
	dpkg -i $PKG_NAME >/dev/null 2>/dev/null || die "Fake package $PKG_NAME could not be installed"
	createFakePackage x11-tools
	dpkg -i $PKG_NAME >/dev/null 2>/dev/null || die "Fake package $PKG_NAME could not be installed"
	createFakePackage xterm
	dpkg -i $PKG_NAME >/dev/null 2>/dev/null || die "Fake package $PKG_NAME could not be installed"
	cd ..
	rm -Rf FakeXTools

	if [ -n "$INSTALL_AND_REMOVE_BINUTILS" ]; then
		apt-get remove -qq -y binutils >/dev/null || die "Remove of binutils failed"
	fi
fi

echo "Installing software (this may take some time)..."
apt-get install -qq -y firefox-esr >/dev/null || die "Installation of firefox-esr failed"
apt-get install -qq -y uuid >/dev/null || die "Installation of firefox-esr failed"
apt-get install -qq -y xrdp xorgxrdp >/dev/null || die "Installation of xrdp failed"
apt-get install -qq -y i3-wm --no-install-recommends >/dev/null || die "Installation of i3-wm failed"
systemctl enable xrdp  || die "Could not enable xrdp, are you using systemd?"

echo "Enable access to anybody in Xwrapper.config"
echo "allowed_users=anybody" >/etc/X11/Xwrapper.config || die "Xwrapper.config could not be changed"

echo "Create systemd-unit to create a temporary directory for Xauth on each boot"
echo '[Unit]' >/etc/systemd/system/prepare-xrdp-tmp.service || die "prepare-xrdp-tmp.service could not be created"
echo 'Description=Prepare temporary directory for XRDP' >>/etc/systemd/system/prepare-xrdp-tmp.service
echo '[Service]' >>/etc/systemd/system/prepare-xrdp-tmp.service
echo 'ExecStart=/bin/mkdir -p /tmp/xrdp-session' >>/etc/systemd/system/prepare-xrdp-tmp.service
echo 'ExecStartPost=/bin/chown browser /tmp/xrdp-session' >>/etc/systemd/system/prepare-xrdp-tmp.service
echo 'ExecStartPost=/bin/chgrp browser /tmp/xrdp-session' >>/etc/systemd/system/prepare-xrdp-tmp.service
echo '[Install]' >>/etc/systemd/system/prepare-xrdp-tmp.service
echo 'WantedBy=multi-user.target' >>/etc/systemd/system/prepare-xrdp-tmp.service
systemctl start prepare-xrdp-tmp
systemctl enable prepare-xrdp-tmp
# Sometimes this doesn't work when starting and enabling the unit for the first time, so do it extra:
/bin/mkdir -p /tmp/xrdp-session
/bin/chown browser /tmp/xrdp-session
/bin/chgrp browser /tmp/xrdp-session

echo "User 'browser' will loose all permissions to his home-directory"
chgrp root /home/browser/ || die "Cannot change group of browser's home"
chown root /home/browser/ || die "Cannot change owner of browser's home"

echo "Creating /etc/xrdp/xrdp.ini"
echo '[Globals]' >/etc/xrdp/xrdp.ini || die "Cannot edit /etc/xrdp/xrdp.ini"
echo 'ini_version=1' >>/etc/xrdp/xrdp.ini
echo '' >>/etc/xrdp/xrdp.ini
echo 'fork=true' >>/etc/xrdp/xrdp.ini
echo 'port=3389' >>/etc/xrdp/xrdp.ini
echo 'address='$LISTEN_ADDRESS >>/etc/xrdp/xrdp.ini
echo 'tcp_nodelay=true' >>/etc/xrdp/xrdp.ini
echo 'tcp_keepalive=true' >>/etc/xrdp/xrdp.ini
echo '' >>/etc/xrdp/xrdp.ini
echo 'security_layer=negotiate' >>/etc/xrdp/xrdp.ini
echo 'crypt_level=high' >>/etc/xrdp/xrdp.ini
echo 'certificate=' >>/etc/xrdp/xrdp.ini
echo 'key_file=' >>/etc/xrdp/xrdp.ini
echo 'ssl_protocols=TLSv1 TLSv1.1, TLSv1.2' >>/etc/xrdp/xrdp.ini
echo 'allow_channels=true' >>/etc/xrdp/xrdp.ini
echo 'allow_multimon=true' >>/etc/xrdp/xrdp.ini
echo 'bitmap_cache=true' >>/etc/xrdp/xrdp.ini
echo 'bitmap_compression=true' >>/etc/xrdp/xrdp.ini
echo 'bulk_compression=true' >>/etc/xrdp/xrdp.ini
echo 'max_bpp=32' >>/etc/xrdp/xrdp.ini
echo 'new_cursors=true' >>/etc/xrdp/xrdp.ini
echo 'use_fastpath=both' >>/etc/xrdp/xrdp.ini
echo '' >>/etc/xrdp/xrdp.ini
echo 'blue=009cb5' >>/etc/xrdp/xrdp.ini
echo 'grey=dedede' >>/etc/xrdp/xrdp.ini
echo 'ls_title=Surf through the World Wide Web' >>/etc/xrdp/xrdp.ini
echo 'ls_top_window_bg_color=009cb5' >>/etc/xrdp/xrdp.ini
echo 'ls_width=350' >>/etc/xrdp/xrdp.ini
echo 'ls_height=430' >>/etc/xrdp/xrdp.ini
echo 'ls_bg_color=dedede' >>/etc/xrdp/xrdp.ini
echo 'ls_logo_filename=' >>/etc/xrdp/xrdp.ini
echo 'ls_logo_x_pos=55' >>/etc/xrdp/xrdp.ini
echo 'ls_logo_y_pos=50' >>/etc/xrdp/xrdp.ini
echo 'ls_label_x_pos=30' >>/etc/xrdp/xrdp.ini
echo 'ls_label_width=60' >>/etc/xrdp/xrdp.ini
echo 'ls_input_x_pos=110' >>/etc/xrdp/xrdp.ini
echo 'ls_input_width=210' >>/etc/xrdp/xrdp.ini
echo 'ls_input_y_pos=220' >>/etc/xrdp/xrdp.ini
echo 'ls_btn_ok_x_pos=142' >>/etc/xrdp/xrdp.ini
echo 'ls_btn_ok_y_pos=370' >>/etc/xrdp/xrdp.ini
echo 'ls_btn_ok_width=85' >>/etc/xrdp/xrdp.ini
echo 'ls_btn_ok_height=30' >>/etc/xrdp/xrdp.ini
echo 'ls_btn_cancel_x_pos=237' >>/etc/xrdp/xrdp.ini
echo 'ls_btn_cancel_y_pos=370' >>/etc/xrdp/xrdp.ini
echo 'ls_btn_cancel_width=85' >>/etc/xrdp/xrdp.ini
echo 'ls_btn_cancel_height=30' >>/etc/xrdp/xrdp.ini
echo '' >>/etc/xrdp/xrdp.ini
echo '[Logging]' >>/etc/xrdp/xrdp.ini
echo 'LogFile=xrdp.log' >>/etc/xrdp/xrdp.ini
echo 'LogLevel=ERROR' >>/etc/xrdp/xrdp.ini
echo 'EnableSyslog=true' >>/etc/xrdp/xrdp.ini
echo 'SyslogLevel=ERROR' >>/etc/xrdp/xrdp.ini
echo '' >>/etc/xrdp/xrdp.ini
echo '[Channels]' >>/etc/xrdp/xrdp.ini
echo 'rdpdr=true' >>/etc/xrdp/xrdp.ini
echo 'rdpsnd=true' >>/etc/xrdp/xrdp.ini
echo 'drdynvc=true' >>/etc/xrdp/xrdp.ini
echo 'cliprdr=true' >>/etc/xrdp/xrdp.ini
echo 'rail=true' >>/etc/xrdp/xrdp.ini
echo 'xrdpvr=true' >>/etc/xrdp/xrdp.ini
echo 'tcutils=true' >>/etc/xrdp/xrdp.ini
echo '' >>/etc/xrdp/xrdp.ini
echo '[Xorg]' >>/etc/xrdp/xrdp.ini
echo 'name=Xorg' >>/etc/xrdp/xrdp.ini
echo 'lib=libxup.so' >>/etc/xrdp/xrdp.ini
echo 'username=ask' >>/etc/xrdp/xrdp.ini
echo 'password=ask' >>/etc/xrdp/xrdp.ini
echo 'ip=127.0.0.1' >>/etc/xrdp/xrdp.ini
echo 'port=-1' >>/etc/xrdp/xrdp.ini
echo 'code=20' >>/etc/xrdp/xrdp.ini

echo "Creating /etc/xrdp/sesman.ini"
echo '[Globals]' >/etc/xrdp/sesman.ini || die "Cannot edit /etc/xrdp/sesman.ini"
echo 'ListenAddress=127.0.0.1' >>/etc/xrdp/sesman.ini
echo 'ListenPort=3350' >>/etc/xrdp/sesman.ini
echo 'EnableUserWindowManager=false' >>/etc/xrdp/sesman.ini
echo 'UserWindowManager=' >>/etc/xrdp/sesman.ini
echo 'DefaultWindowManager=startwm.sh' >>/etc/xrdp/sesman.ini # this must not be an absolute path!
echo '' >>/etc/xrdp/sesman.ini
echo '[Security]' >>/etc/xrdp/sesman.ini
echo 'AllowRootLogin=false' >>/etc/xrdp/sesman.ini
echo 'MaxLoginRetry=4' >>/etc/xrdp/sesman.ini
echo '' >>/etc/xrdp/sesman.ini
echo '[Sessions]' >>/etc/xrdp/sesman.ini
echo 'X11DisplayOffset=10' >>/etc/xrdp/sesman.ini
echo 'MaxSessions=50' >>/etc/xrdp/sesman.ini
echo 'KillDisconnected=true' >>/etc/xrdp/sesman.ini
echo 'DisconnectedTimeLimit=180' >>/etc/xrdp/sesman.ini
echo 'Policy=UBI' >>/etc/xrdp/sesman.ini
echo '' >>/etc/xrdp/sesman.ini
echo '[Logging]' >>/etc/xrdp/sesman.ini
echo 'LogFile=xrdp-sesman.log' >>/etc/xrdp/sesman.ini
echo 'LogLevel=ERROR' >>/etc/xrdp/sesman.ini
echo 'EnableSyslog=1' >>/etc/xrdp/sesman.ini
echo 'SyslogLevel=ERROR' >>/etc/xrdp/sesman.ini
echo '' >>/etc/xrdp/sesman.ini
echo '[Xorg]' >>/etc/xrdp/sesman.ini
echo 'param=Xorg' >>/etc/xrdp/sesman.ini
echo 'param=-config' >>/etc/xrdp/sesman.ini
echo 'param=xrdp/xorg.conf' >>/etc/xrdp/sesman.ini
echo 'param=-noreset' >>/etc/xrdp/sesman.ini
echo 'param=-nolisten' >>/etc/xrdp/sesman.ini
echo 'param=tcp' >>/etc/xrdp/sesman.ini
echo 'param=-logfile' >>/etc/xrdp/sesman.ini
echo 'param=/dev/null' >>/etc/xrdp/sesman.ini
echo '' >>/etc/xrdp/sesman.ini
echo '[SessionVariables]' >>/etc/xrdp/sesman.ini
echo 'PULSE_SCRIPT=/etc/xrdp/pulse/default.pa' >>/etc/xrdp/sesman.ini
echo 'CHANSRV_LOG_PATH=/tmp/xrdp-session/' >>/etc/xrdp/sesman.ini
echo 'XAUTHORITY=/tmp/xrdp-session/.Xauthority' >>/etc/xrdp/sesman.ini


echo "Restarting xrdp"
systemctl restart xrdp || die "Restarting xrdp failed"

echo "Creating a startwm.sh which starts i3 and Firefox in a temporary directory"
echo '#!/bin/bash' >/etc/xrdp/startwm.sh || die "Cannot edit /etc/xrdp/startwm.sh"
echo '' >>/etc/xrdp/startwm.sh
echo 'trap "rm -Rf $NEWHOME; exit" SIGHUP SIGINT SIGTERM' >>/etc/xrdp/startwm.sh
echo '' >>/etc/xrdp/startwm.sh
echo 'NEWHOME=/tmp/browser-`uuid`' >>/etc/xrdp/startwm.sh
echo 'mkdir $NEWHOME' >>/etc/xrdp/startwm.sh
echo 'cd $NEWHOME' >>/etc/xrdp/startwm.sh
echo 'HOME=$NEWHOME' >>/etc/xrdp/startwm.sh
echo '' >>/etc/xrdp/startwm.sh
echo 'mv $XAUTHORITY $NEWHOME/.Xauthority' >>/etc/xrdp/startwm.sh
echo 'XAUTHORITY=$NEWHOME/.Xauthority' >>/etc/xrdp/startwm.sh
echo '' >>/etc/xrdp/startwm.sh
echo 'i3 -c /etc/i3/config &' >>/etc/xrdp/startwm.sh
echo 'I3_PID=$!' >>/etc/xrdp/startwm.sh
echo 'firefox -new-instance' >>/etc/xrdp/startwm.sh
echo '' >>/etc/xrdp/startwm.sh
echo 'kill $I3_PID' >>/etc/xrdp/startwm.sh # I encountered an i3-process consuming 100% CPU once, so make sure to kill it
echo 'rm -Rf $NEWHOME' >>/etc/xrdp/startwm.sh
chmod +x /etc/xrdp/startwm.sh || die "Cannot make /etc/xrdp/startwm.sh executable"

echo "Creating an i3 configuration"
# Mod3 should never be mapped to a valid key
echo 'set $mod Mod3' >/etc/i3/config || die "Cannot edit /etc/i3/config"
echo 'font pango:monospace 8' >>/etc/i3/config 
echo 'new_window 1pixel' >>/etc/i3/config 
echo 'bindsym $mod+m bar mode toggle' >>/etc/i3/config 

echo "Creating a default configuration for new Firefox profiles"
echo 'pref("intl.locale.matchOS", true);' >/etc/firefox-esr/firefox-esr.js || die "Cannot edit /etc/firefox-esr/firefox-esr.js"
echo 'pref("extensions.update.enabled", true);' >>/etc/firefox-esr/firefox-esr.js
echo 'pref("media.gmp-gmpopenh264.enabled", false);' >>/etc/firefox-esr/firefox-esr.js
echo '' >>/etc/firefox-esr/firefox-esr.js
echo 'lockPref("browser.download.useDownloadDir", true);' >>/etc/firefox-esr/firefox-esr.js
echo 'lockPref("browser.download.folderList", 2);' >>/etc/firefox-esr/firefox-esr.js
if [ -n "$DOWNLOAD_DIR" ]; then
	echo 'lockPref("browser.download.lastDir", "'$DOWNLOAD_DIR'");'
fi
echo 'lockPref("browser.download.forbid_open_with", true);' >>/etc/firefox-esr/firefox-esr.js
echo '' >>/etc/firefox-esr/firefox-esr.js
echo 'pref("browser.shell.checkDefaultBrowser", false);' >>/etc/firefox-esr/firefox-esr.js
echo 'pref("browser.newtabpage.enhanced", false);' >>/etc/firefox-esr/firefox-esr.js
echo 'pref("browser.rights.3.shown", true);' >>/etc/firefox-esr/firefox-esr.js
echo 'pref("browser.startup.homepage_override.mstone","ignore");' >>/etc/firefox-esr/firefox-esr.js
echo 'lockPref("plugins.hide_infobar_for_outdated_plugin", true);' >>/etc/firefox-esr/firefox-esr.js
echo 'lockPref("browser.tabs.crashReporting.sendReport", false);' >>/etc/firefox-esr/firefox-esr.js
echo 'lockPref("browser.reader.detectedFirstArticle", true);' >>/etc/firefox-esr/firefox-esr.js
echo 'pref("extensions.pocket.enabled", false);' >>/etc/firefox-esr/firefox-esr.js
echo 'lockPref("datareporting.healthreport.service.firstRun", false); ' >>/etc/firefox-esr/firefox-esr.js
echo 'lockPref("toolkit.telemetry.reportingpolicy.firstRun", false);' >>/etc/firefox-esr/firefox-esr.js
echo 'pref("datareporting.policy.dataSubmissionPolicyAcceptedVersion", 999);' >>/etc/firefox-esr/firefox-esr.js
echo 'pref("datareporting.policy.dataSubmissionPolicyNotifiedTime", "1533619817422");' >>/etc/firefox-esr/firefox-esr.js

if [ -n "$HOURLY_UPDATE" ]; then
	echo "Enabling hourly updates"
	echo '#!/bin/bash' >/etc/cron.hourly/hourly-upgrade || die "Cannot edit /etc/cron.hourly/hourly-upgrade"
	echo 'apt-get -y update && apt-get -y dist-upgrade' >>/etc/cron.hourly/hourly-upgrade
	chmod +x /etc/cron.hourly/hourly-upgrade
fi

echo
echo "All work is done, you can log in to this computer via RDP! Use 'browser' as login"


