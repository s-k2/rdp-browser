# rdp-browser

Setup XRDP on Debian to enable remote browsing with Firefox via RDP

## What's the use-case?

I am working in a lab where the computers can't get direct internet-access. Some programs break after a system-update and we disabled it. Thus it is too dangerous to browse the web with those computers. But we can't go without it. Our solution is to connect to a server via RDP and use that server to browse the web.

## What about usability?

For our users it should be as convinient as possible to use the browser. It should feel like a local browser and no one should enter credentials. Thus everybody connects with the same username and password so we can setup some launcher that already contains those credentials. 

If a session is established, it directly loads Firefox and no desktop environment. The script sets some preferences of Firefox, e. g. to disable messages like 'First run/Welcome to Firefox/We care about privacy/...'.

## And security?

We tried hard to cut down the permissions of the browser-account. It can only write to ``/tmp``. When a user connects to the server, a new temporary directory (with a new browser-profile) is created there. It is deleted again, when the session ends. Thus it should not be possible for the user to make any persistent change on the server. Even if a user managed to write something into ``/tmp``, everything will be deleted if you restart Debian. But be aware that each user may change the temporary files of any other connected user.

## How to use it?

1. Install Debian (Stretch and Buster worked well). In tasksel don't select anything except "standard system utilities" and maybe SSH if you need it. Configure your network-interfaces and create a user named ``browser``
2. Get the script in this repository (e. g. via ``wget https://raw.githubusercontent.com/s-k2/rdp-browser/master/setup-xrdp.sh && chmod +x setup-xrdp.sh``).
3. Run ``./setup-xrdp.sh`` as root, you will be asked four questions.
4. What is the IP address of the internal network-interface? By default the RDP service is accessible from all network-interfaces. This would include the one connected to the internet! Limit it to the internal network by entering the internal IP of this computer!
5. Where to put the downloaded files?  
   EITHER: Download to a temporary-folder -> No one can really access them and they are gone if the session ends  
   OR: Put them to a premanent directory, e. g. a mounted network-drive -> You need to make the directory readable for the user ``browser``!  BTW: Make sure that this directory won't become a home for viruses and trojans
6. Block installation of xterm/xedit/xutils? By default some basic X11 programs (e. g. terminal, editor, ...) are dependencies of X11.  This script can prevent the installation of those tools if you want!  
  EITHER yes: Create fake-packages that prevent the installation -> The only usable X11 program is the browser BUT: You can't install those programs on this computer anymore!  
  OR: Let your users play with these programs (started through some downloads) -> A terminal is an interesting tool for a user who doesn't behave well!
7. Install updates every hour? If you enter yes, this will put a simple script to ``/etc/cron.hourly``. It will run ``apt-get update`` and ``apt-get dist-upgrade`` every hour. This should work just fine, but you will never get reports about its work. Furthermore a failed update might break your system! If you know how to setup it, maybe you should use the package ``unattended-upgrades``
7. When it's done, your users can login via network with an RDP-client as ``browser`` and use Firefox (and only that)
