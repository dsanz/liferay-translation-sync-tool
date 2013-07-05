liferay-pootle-manager
======================

Scripts for automating integration between pootle and liferay, and many more!

Git installation on CentOS
- https://gist.github.com/eddarmitage/2001099

Bash 4 installation
- ftp://ftp.gnu.org/gnu/bash/bash-4.2.tar.gz
- gunzip and tar xvf into /opt/bash-4.2
- cd /opt/bash-4.2
- ./configure
- ./make
(you can use /opt/bash-4.2/bash as script interpreter)

Java 1.6

ant 1.7+

Github setup 
- https://help.github.com/articles/set-up-git
- https://help.github.com/articles/generating-ssh-keys
- Then clone this repo and liferay/liferay-portal

Portal - plugins setup
- clone liferay-portal and liferay-plugins
- optionally, clone any other liferay repo for backporting translations
- download a bundle
- setup the bundle as target for compilation/deployment of portal & plugins repos
- cd liferay-portal; ant compile
- now, ant build-lang can be run from liferay-portal/portal-impl/ and each translatable plugin source root




