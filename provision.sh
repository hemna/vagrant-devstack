#!/usr/bin/env bash
set -x

#
# This script is executed within the running VM as the root user.  It
# is actually copied to /tmp/vagrant-shell and executed there.  Other
# files here (in this source dir) are copied into /vagrant in the VM,
# and so must be referenced by full pathname.
#

# Avoid problems reading devstack log files with read only for root/adm
usermod -aG adm vagrant
VAGRANT_FILES="/home/vagrant/files"
VAGRANT_FILES_BIN="$VAGRANT_FILES/bin"
CONFIG_YAML="$VAGRANT_FILES/config.yaml"
SHYAML="$VAGRANT_FILES_BIN/shyaml"

# Avoid port conflicts between swift and sshd
sed -i '/X11DisplayOffset/ {s/10$/100/}' /etc/ssh/sshd_config
service ssh restart

export DEBIAN_FRONTEND=noninteractive

PACKAGES="wget ansible git tig git-review cifs-utils pandoc python-yaml python-pip"
APT_OPTIONS="-o DPkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold"

apt-get $APT_OPTIONS update -y -qq >/dev/null
apt-get $APT_OPTIONS install -y -q $PACKAGES

PACKAGES+=" $($SHYAML get-value extra_packages < $CONFIG_YAML)"
apt-get $APT_OPTIONS install -y -q $PACKAGES

# make sure pip is latest
pip install -U pip

# install any extra python packages
PYTHON_PACKAGES=$($SHYAML get-value python_packages < $CONFIG_YAML)
if [[ -n $PYTHON_PACKAGES ]] ; then
	pip install $PYTHON_PACKAGES
fi

# install any ruby gems
RUBY_GEMS=$($SHYAML get-value ruby_gems < $CONFIG_YAML)
if [[ -n $RUBY_GEMS ]] ; then
    gem install $RUBY_GEMS
fi

cp /vagrant/files/motd /etc/motd
chmod 644 /etc/motd

# Copy over other configuration files, dereferencing symlinks as necessary
if [ -d /vagrant/files/home ] ; then
    # --cvs-exclude omits things like .git dirs, editor save files, etc.
    sudo -u vagrant rsync --copy-unsafe-links --cvs-exclude -av  /vagrant/files/home/ ~vagrant
fi

# append id_rsa.pub to authorized keys if it has not already been done
authkeys=$(wc -l ~vagrant/.ssh/authorized_keys | awk '{print $1}')
if [[ $authkeys < 2 ]] ; then
    if [[ -f ~vagrant/.ssh/id_rsa.pub ]] ; then
        # Append the key from id_rsa.pub in .ssh dir, if any
        cat ~vagrant/.ssh/id_rsa.pub >> ~vagrant/.ssh/authorized_keys
    elif [[ -f /tmp/id_rsa.pub ]] ; then
        # Append the key from /tmp/id_rsa.pub, if any
        cat /tmp/id_rsa.pub >> ~vagrant/.ssh/authorized_keys
    fi
fi

INSTALL_DOTFILES=$($SHYAML get-value install_dotfiles True < $CONFIG_YAML)
if [[ $INSTALL_DOTFILES == 'True' ]]; then
	sudo -iu vagrant $VAGRANT_FILES_BIN/dotfiles-install.sh
fi

DEVSTACK_REPO=http://github.com/opensack-dev/devstack
if [ ! -d ~vagrant/devstack ] ; then
    # Clone devstack
    sudo -iu vagrant git clone ${DEVSTACK_REPO}
fi

# If a specific branch is requested, check it out
DEVSTACK_BRANCH=$($SHYAML get-value devstack_branch < $CONFIG_YAML)
if [[ -n $DEVSTACK_BRANCH ]] ; then
    sudo -iu vagrant bash -c "cd devstack; git checkout ${DEVSTACK_BRANCH}"
fi

# Copy local devstack customizations, if any
if [ -f /vagrant/files/local.conf ] ; then
    sudo -u vagrant cp $VAGRANT_FILES/local.conf ~vagrant/devstack
fi
if [ -f /vagrant/files/local.sh ] ; then
    sudo -u vagrant cp $VAGRANT_FILES/local.sh ~vagrant/devstack
fi

# If the hostname is to be changed, we have to first bring down rabbitmq
# and its friends, or stack.sh will not start properly
HOSTNAME=$($SHYAML get-value hostname xenial-devstack< $CONFIG_YAML)
OLDHOSTNAME=$(hostname)
if [[ $OLDHOSTNAME != $HOSTNAME ]] ; then

	# bring rabbit back up
	HAS_RABBIT=""
	pgrep rabbitmq-server >& /dev/null
    if [ $? -eq 0 ] ; then
	   HAS_RABBIT="true"
	fi

    if [[ $HAS_RABBIT ]] ; then
		# stop rabbitmq and friends
		service rabbitmq-server stop
		pkill epmd
	fi

	# change the hostname
	hostname $HOSTNAME

	# Update /etc/hosts (hostname does not seem to do this reliably)
	sed -i -e s/$OLDHOSTNAME/$HOSTNAME/ /etc/hosts

	if [[ $HAS_RABBIT ]] ; then
		# bring rabbit back up
		service rabbitmq-server start
		if [ $? -ne 0 ] ; then
			echo "Failed to start rabbitmq" >&2
			exit 1
		fi
	fi
fi

if [ -f /vagrant/pre_stack.sh ] ; then
    bash /vagrant/pre_stack.sh
fi

# Manila
USE_MANILA=$($SHYAML get-value use_manila False < $CONFIG_YAML)
if [[ $USE_MANILA = 'True' ]] ; then
	sudo rm -rf /opt/stack/horizon
fi

# Maybe we don't want to run devstack just yet.
BYPASS_DEVSTACK=$($SHYAML get-value bypass_devstack False < $CONFIG_YAML)
if [[ $BYPASS_DEVSTACK != 'False' ]] ; then
    echo "Bypassing stack.sh as requested by config.yaml"
else
    # stack it!
    sudo -iu vagrant ~vagrant/devstack/stack.sh
fi

if [ -f /vagrant/post_stack.sh ] ; then
    bash /vagrant/post_stack.sh
fi

# Avoid expanding tabs so that the here docs with ^I's work correctly
# vi: set noexpandtab :
