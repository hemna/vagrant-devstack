require 'yaml'
CONFIG = YAML.load(File.open(File.join(File.dirname(__FILE__), "config.yaml"), File::RDONLY).read)

VAGRANTFILE_API_VERSION = "2" if not defined? VAGRANTFILE_API_VERSION

# The libvirt plugin needs a recent version of Vagrant
Vagrant.require_version ">=1.6.5"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

    # solves issue 1673 (https://github.com/mitchellh/vagrant/issues/1673)
    config.ssh.shell = "bash -c 'BASH_ENV=/etc/profile exec bash'"

    config.vm.define "devstack" do |devstack|

        if CONFIG['box'] == "<<BOX NAME>>"
           abort "You must configure the box name in config.yaml"
        end
        devstack.vm.box = CONFIG['box']
        devstack.vm.hostname = CONFIG['hostname']

        # Create port forward to horizon on indicated host port
        if CONFIG['horizon_port']
            devstack.vm.network "forwarded_port", guest: 80, host: CONFIG['horizon_port'], host_ip: "0.0.0.0"
        end

        enable_bridge = CONFIG.fetch('enable_bridge_networking', false)
        if enable_bridge
            bridge_interface = CONFIG.fetch('bridge_interface', 'eth0')
            bridge_ip = CONFIG.fetch('bridge_ip', 'dhcp')
            if bridge_ip == 'dhcp'
                devstack.vm.network :public_network, :dev => bridge_interface, :mode => 'bridge'
            else
                devstack.vm.network :public_network, :dev => bridge_interface, :mode => 'bridge', ip: bridge_ip
            end
        end


        use_ssh_agent = CONFIG.fetch('use_ssh_agent', false)
        if use_ssh_agent
            config.ssh.forward_agent = true
        else
            if File.exists?(ENV["HOME"] + "/.ssh/id_rsa")
                devstack.vm.provision "file", source: "~/.ssh/id_rsa", destination: ".ssh/id_rsa"
            end
        end

        if File.exists?(ENV["HOME"] + "/.ssh/id_rsa.pub")
            devstack.vm.provision "file", source: "~/.ssh/id_rsa.pub", destination: "/tmp/id_rsa.pub"
        end

        devstack.vm.synced_folder ENV["PWD"]+"/files", "/home/vagrant/files", type: "rsync"
        #devstack.vm.provision "file", source: ENV["PWD"]+"/files", destination: "/home/vagrant/files"
        devstack.vm.provision "file", source: ENV["PWD"]+"/shyaml", destination: "/home/vagrant/files/bin/shyaml"
        devstack.vm.provision "file", source: ENV["PWD"]+"/config.yaml", destination: "/home/vagrant/files/config.yaml"

        config.ssh.forward_x11 = CONFIG.fetch('forward_x11', false)

        # fetch values from config file, using reasonable defaults
        memory = CONFIG.fetch('memory', 8192)
        cpus = CONFIG.fetch('cpus', 2)
        # Size smaller than VM image size is ignored, so we default to 1G
        hdsize = CONFIG.fetch('hdsize', 1)

        devstack.vm.provider "virtualbox" do |vb|
            vb.customize ["modifyvm", :id, "--memory", memory ]
            vb.customize ["modifyvm", :id, "--cpus", cpus ]
        end

        devstack.vm.provider :libvirt do |lv|
            lv.memory = memory
            lv.cpus = cpus
            lv.nested = true
            lv.machine_virtual_size = hdsize
        end

        nfs = CONFIG['nfs']
        if nfs
            nfs.each do |host, guest|
                config.vm.synced_folder "#{host}", "#{guest}", type: "nfs"
            end
        end

        # provision the VM with provision.sh
        devstack.vm.provision "shell" do |s|
            s.path = "provision.sh"
        end
    end

end
