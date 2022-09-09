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

  config.vm.define "smshost" do |smshost|

    smshost.vm.box = "bento/rockylinux-8"
    smshost.vm.box_version = "202206.14.0"
    smshost.vm.hostname = "smshost"

    smshost.vm.network "forwarded_port", guest: 22, host: 2299, host_ip: "127.0.0.1", id: "ssh"
    smshost.vm.network "private_network", ip: "10.10.10.10",virtualbox__intnet: "hpcnet"

    smshost.vm.provider "virtualbox" do |vb|
    
      vb.name = "smshost"
      vb.cpus = 2
      vb.memory = "1024"
      vb.gui = false

    end

    smshost.vm.provision "shell" do |s|
      s.inline = "sudo yum install vim git tmux -y"
      end

  end

  config.vm.define "compute00", autostart: false do |compute00|

    compute00.vm.box = "file://./package.box"
    compute00.vm.hostname = "compute00"
    compute00.vm.boot_timeout = 5
    compute00.vm.network "private_network", :adapter=>1, ip: "10.10.10.100", mac: "080027F9F3B1", virtualbox__intnet: "hpcnet"

    compute00.vm.provider "virtualbox" do |vb|
    
      vb.name = "compute00"
      vb.cpus = 2
      vb.memory = "3072"
      vb.gui = false

    end

  end

  config.vm.define "compute01", autostart: false do |compute01|

    compute01.vm.box = "file://./package.box"
    compute01.vm.hostname = "compute01"
    compute01.vm.boot_timeout = 5
    compute01.vm.network "private_network", :adapter=>1, ip: "10.10.10.101", mac: "080027F59A31", virtualbox__intnet: "hpcnet"

    compute01.vm.provider "virtualbox" do |vb|
    
      vb.name = "compute01"
      vb.cpus = 2
      vb.memory = "3072"
      vb.gui = false

    end

  end

end
