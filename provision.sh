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

# Avoid port conflicts between swift and sshd
sed -i '/X11DisplayOffset/ {s/10$/100/}' /etc/ssh/sshd_config
service ssh restart

export DEBIAN_FRONTENT=noninteractive

PACKAGES="git tig git-review cifs-utils pandoc"
PACKAGES+=" $(/vagrant/shyaml get-value extra_packages < /vagrant/config.yaml)"

apt-get update -y -qq >/dev/null
apt-get install -y -q $PACKAGES

# make sure pip is latest
pip install -U pip

# install any extra python packages
PYTHON_PACAKGES=$(/vagrant/shyaml get-value python_packages < /vagrant/config.yaml)
if [[ -n $PYTHON_PACKAGES ]] ; then
	pip install $PYTHON_PACKAGES
fi

# install any ruby gems
RUBY_GEMS=$(/vagrant/shyaml get-value ruby_gems < /vagrant/config.yaml)
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

INSTALL_DOTFILES=$(/vagrant/shyaml get-value install_dotfiles True < /vagrant/config.yaml)
if [[ $INSTALL_DOTFILES == 'True' ]]; then
	sudo -iu vagrant /vagrant/files/bin/dotfiles-install.sh
fi

INSTALL_POWERLINE=$(/vagrant/shyaml get-value install_powerline False < /vagrant/config.yaml)
if [[ $INSTALL_POWERLINE == 'True' ]] ; then
    echo "Installing Powerline"
    sudo -iu vagrant /vagrant/files/bin/powerline-install.sh
fi

DEVSTACK_REPO=http://github.com/opensack-dev/devstack
if [ ! -d ~vagrant/devstack ] ; then
    # Clone devstack
    sudo -iu vagrant git clone ${DEVSTACK_REPO}
fi

# If a specific branch is requested, check it out
DEVSTACK_BRANCH=$(/vagrant/shyaml get-value devstack_branch < /vagrant/config.yaml)
if [[ -n $DEVSTACK_BRANCH ]] ; then
    sudo -iu vagrant bash -c "cd devstack; git checkout ${DEVSTACK_BRANCH}"
fi

# Copy local devstack customizations, if any
if [ -f /vagrant/files/local.conf ] ; then
    sudo -u vagrant cp /vagrant/files/local.conf ~vagrant/devstack
fi
if [ -f /vagrant/files/local.sh ] ; then
    sudo -u vagrant cp /vagrant/files/local.sh ~vagrant/devstack
fi

# If the hostname is to be changed, we have to first bring down rabbitmq
# and its friends, or stack.sh will not start properly
HOSTNAME=$(/vagrant/shyaml get-value hostname xenial-devstack< /vagrant/config.yaml)
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
USE_MANILA=$(/vagrant/shyaml get-value use_manila False < /vagrant/config.yaml)
if [[ $USE_MANILA = 'True' ]] ; then
	sudo rm -rf /opt/stack/horizon
fi

# Maybe we don't want to run devstack just yet.
BYPASS_DEVSTACK=$(/vagrant/shyaml get-value bypass_devstack False < /vagrant/config.yaml)
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
