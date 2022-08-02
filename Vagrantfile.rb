# -*- mode: ruby -*-
# vi: set ft=ruby :

################################################
### OPENHPC 2.x Virtual Lab 
###
### A Contribution by the Advanced Computer Engineering (ACE) Lab 
### on behalf of the CHPC's HPC Ecosystems Project
###
### Developed by:
### Lara Timm, HPC Engineer (ACE Lab)
### Bryan Johnston, Senior Technologist (ACE Lab)
###
################################################

Vagrant.configure("2") do |config|
  # https://docs.vagrantup.com.
  # https://vagrantcloud.com/search.

	config.vm.define "compute00" do |compute00|
		compute00.vm.box = "compute00"
	end

  config.ssh.insert_key = false
	
	# https://app.vagrantup.com/bento/boxes/rockylinux-8.5
  #config.vm.box = "bento/rockylinux-8.5"

  
	# https://app.vagrantup.com/bento/boxes/rockylinux-8
  config.vm.box = "bento/rockylinux-8"
	# this is RockyLinux 8.6 "Green Obsidian"
  config.vm.box_version = "202206.14.0"
	
	config.vm.hostname = "sms-host"
  
  #config.vm.post_up_message = "HPC Ecosystems \r\n user:vagrant password:vagrant"
  
  #### MESSAGE_BEGIN ############################
  config.vm.post_up_message = <<-MESSAGE
   ============================================
	======== OpenHPC Virtual Lab Notice ========
	============================================
	
	Vagrant VM configuration complete!
	
      You now have the SMS node of a 3-node Virtual Cluster running within vagrant.

    The final Virtual Cluster includes the following VMs:
      1. smshost: the SMS Host for OpenHPC 
		--> This is the DEFAULT VM <--
	
			2. client00: a compute node
      3. client01: a compute node
		==> THESE ARE MANUALLY IMPORTED VIA GIT <==

    ++++++++++++++++++++++++++++++++++++++++++++
	 To access the SMS Host VM:
	  - vagrant ssh
	  - vagrant ssh default
	  - vagrant ssh <id>
	  - any SSH client to 127.0.0.1:2229 (vagrant::vagrant)

	============================================
	======== END OF MESSAGE ====================
	============================================

  MESSAGE
  #### MESSAGE_END ##############################
	
  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine and only allow access
  # via 127.0.0.1 to disable public access
  # forward port mapping guest port 22 via localhost port 2229
  # (i.e. access localhost:2229 is mapped to guest:22)
  config.vm.network "forwarded_port", guest: 22, host: 2299, host_ip: "127.0.0.1", id: "ssh"

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  config.vm.network "private_network", ip: "10.10.10.10",
		virtualbox__intnet: "hpcnet"
  
  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  # config.vm.network "public_network"

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  # config.vm.synced_folder "../data", "/vagrant_data"
  # config.vm.synced_folder "
	#config.vm.synced_folder ".", "/home/vagrant"

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  config.vm.provider "virtualbox" do |vb|
    # Display the VirtualBox GUI when booting the machine
    vb.gui = false
    # Customize the amount of memory on the VM:
    vb.memory = "1024"
	# set the VM host to dual core
	vb.cpus = 2
		
	# rename from default (containing folder+timestamp)
	vb.name = "smshost_for_openhpc2x_virtual-lab"
	
	# set host CPU cap to 50% of host machine
	vb.customize ["modifyvm", :id, "--cpuexecutioncap", "50"]
	
	# set host Gfx to vboxsvga to stop crashes
	vb.customize ["modifyvm", :id, "--graphicscontroller", "vboxsvga"]
  end

  # Enable provisioning with a shell script. Additional provisioners such as
  # Puppet, Chef, Ansible, Salt, and Docker are also available. Please see the
  # documentation for more information about their specific syntax and use.

  # more tips: https://www.vagrantup.com/docs/provisioning/shell.html "heredoc"
 config.vm.provision "shell" do |s|
	s.inline = "sudo yum install vim git tmux -y"
  end


end
