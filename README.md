Automated front end dev setup
-----------------------------

### Requirements

1. [VirtualBox](https://www.virtualbox.org/)
2. [Vagrant](http://www.vagrantup.com/) (and [puppet](http://docs.vagrantup.com/v2/provisioning/puppet_apply.html) for provisioning which is included in vagrant)
3. [Git](http://git-scm.com/)

### Usage

1. Save your putty private key to `puppet/config/priv.ppk`
1. Save your passphrase to `puppet/config/passphrase`
1. Fire up a terminal and run:

```
vagrant box add https://cloud-images.ubuntu.com/vagrant/precise/current/precise-server-cloudimg-amd64-vagrant-disk1.box
git clone git@github.com:demosolutions/vagrant-demo.git demo
cd demo
mkdir projects // this folder is mapped to the ~/projects folder of your guest
vagrant up
```

The server logs are stored in `~/projects/server/server.log`. The front end app will be accessable at http://localhost:3000 (or http://localhost:80 if your host machine allows to forward port 80). The server end points are accessible at port 8080 and 8081.

To ssh into your vagrant box, simply run `vagrant ssh`.

The projects folder on your host machine should contain files mapped onto the projects folder of your guest machine. So you can use any code editor on your host machine if you wish to edit project files located on the guest.

This script has been tested on mac OSX Lion and Windows 7. See notes below for your operating system.

#### Windows

On windows 7, optionally provide the provider argument while running vagrant up or else it uses hyper-v by default which is only available in Windows 8.
```
vagrant up --provider=virtualbox
```
Also make sure that `C:/Program Files/Oracle/VirtualBox` is added to your PATH environment


#### Mac OS

If your host machine is Mac OS, you can add demotest to the hosts file by adding `127.0.0.1 demotest` to the `/etc/hosts` file. To port forward port 80 to 3000 on your host machine, open a terminal and run:
```
sudo ipfw add 100 fwd 127.0.0.1,3000 tcp from any to any 80 in
```
Now the web app should be accessible at http://demotest/

* * *
