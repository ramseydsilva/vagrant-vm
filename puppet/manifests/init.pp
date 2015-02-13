$log_level = 'info'

host { 'demotest': ip => "127.0.0.1" }
host { 'gitsrv': ip => "107.21.109.134" }


file {'/etc/apt/sources.list.new':
    replace => "yes",
    source => "file:///vagrant/puppet/config/sources.list"
}

exec { 'update_sources_list':
    #command => "mv /etc/apt/sources.list /etc/apt/sources.list.old &&  
    #		mv /etc/apt/sources.list.new /etc/apt/sources.list &&
    command => "sudo apt-get update",
    require => File['/etc/apt/sources.list.new'],
    path => '/usr/bin:/bin'
}

package{ ['unattended-upgrades', 'python-pycurl', 'python-software-properties']:
    require => Exec['update_sources_list'],
    ensure =>  latest
}

exec { 'apt_update':
    command => "sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10 && 
                sudo echo 'deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen' | 
                sudo /usr/bin/tee /etc/apt/sources.list.d/mongodb.list &&
    		sudo add-apt-repository ppa:webupd8team/java && 
                sudo add-apt-repository ppa:chris-lea/node.js && 
                sudo apt-get update",
    require => [Package['python-software-properties']],
    path => '/usr/bin:/bin'
}

package{ ['expect', 'expect-dev', 'git', 'mongodb-org', 'putty-tools', 'python',
        'g++', 'make', 'nodejs'] :
    ensure => latest,
    require => Exec['apt_update']
}

exec { 'git receive-pack':
    command => 'git config --global remote.origin.receivepack "git receive-pack"',
    path => '/usr/bin:/bin',
    require => [Package['git']]
}

class java($version) {
 
  exec {
    'set-licence-selected':
      command => '/bin/echo debconf shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections';
 
    'set-licence-seen':
      command => '/bin/echo debconf shared/accepted-oracle-license-v1-1 seen true | /usr/bin/debconf-set-selections';
  }
 
  package { 'oracle-java8-installer':
    ensure => "${version}",
    require => [Package['python-software-properties'], Exec['apt_update'], Exec['set-licence-selected'], Exec['set-licence-seen']],
  }
}

class { 'java': version => '8u25+8u6arm-1~webupd8~1', }

package{ ['oracle-java8-set-default', 'maven']:
    ensure => installed,
    require => [Class['java'], Exec['apt_update']]
}

class { 'mysql::install': 
    require => [Exec['apt_update']]
}

file {'/home/vagrant/scripts':
    replace => "yes",
    ensure => "directory",
    recurse => "true",
    source => "file:///vagrant/puppet/scripts"
}

file {'/home/vagrant/.ssh/priv.ppk':
    replace => "no",
    ensure => "present",
    source => "file:///vagrant/puppet/config/priv.ppk"
}

exec { 'generate publickey':
    command => 'expect /home/vagrant/scripts/public.exp && expect /home/vagrant/scripts/private.exp',
    require => [Package['putty-tools'], File['/home/vagrant/scripts']],
    path => '/usr/bin:/bin',
    user => 'vagrant'
}

file {'/home/vagrant/config':
    replace => "yes",
    ensure => "directory",
    recurse => "true",
    source => "file:///vagrant/puppet/config"
}

exec {'enter passphrase':
    command => "find ./ -type f -exec sed -i 's/{{ passphrase }}/'$(cat /home/vagrant/config/passphrase)'/g' {} \; && rm -rf /home/vagrant/config",
    cwd => '/home/vagrant/scripts',
    path => '/usr/bin:/bin',
    require => [Exec['generate publickey'], File['/home/vagrant/config']]
}

    
class { 'nginx::setup':
    ensure     => 'present',
    enable     => 'true',
    service    => 'running',
    version    => 'installed',
    config     => '/vagrant/puppet/config/default-nginx.conf',
    require => [Exec['apt_update']]
}

file {"/home/vagrant/projects":
    ensure => "directory",
    owner => "vagrant",
    require => File['/home/vagrant/scripts']
}

exec { 'get server repo':
    command => 'expect /home/vagrant/scripts/git-clone-server.exp',
    user => 'vagrant',
    path => '/usr/bin:/bin',
    cwd => '/home/vagrant/projects',
    require => [Exec['enter passphrase'], Package['git'], File["/home/vagrant/projects"], Exec['generate publickey']],
    timeout => 0,
    returns => [0, 1, 128],
    creates => '/home/vagrant/projects/mt-server/mt-parent/mt-service/yml/server-mysql.yml'
}

exec { 'get web repo':
    command => 'expect /home/vagrant/scripts/git-clone-web.exp && cd web && git checkout master',
    user => 'vagrant',
    path => '/usr/bin:/bin',
    cwd => '/home/vagrant/projects',
    require => [Exec['enter passphrase'], Package['git'], File["/home/vagrant/projects"]],
    timeout => 0,
    returns => [0, 1, 128],
    creates => '/home/vagrant/projects/web/index.html'
}

exec { 'create mysql user':
    command => "mysql -u root --password='vagrant' < /home/vagrant/scripts/mysql-create-user.sql",
    require => [Package['mysql-server'], Package['mysql-client'], Exec['Set MySQL server\'s root password']],
    path => '/usr/bin:/bin'
}

file {'/home/vagrant/projects/server':
    replace => "yes",
    ensure => "directory",
    recurse => "true",
    source => "file:///vagrant/puppet/server"
}

exec { 'copy server-mysql.yml':
    command => "cp /home/vagrant/projects/mt-server/mt-parent/mt-service/yml/server-mysql.yml /home/vagrant/projects/server/server-mysql.yml",
    path => "/usr/bin:/bin",
    require => [Exec["get server repo"], File['/home/vagrant/projects/server']]
}

exec { 'run backend server':
    command => 'java -jar -XX:+CMSClassUnloadingEnabled -XX:MaxPermSize=256m mt-build-0.253.jar server server-mysql.yml > server.log & sleep 20',
    cwd => '/home/vagrant/projects/server',
    path => '/usr/bin:/bin',
    timeout => 30,
    require => [Package['maven'], Class['java'], Exec['copy server-mysql.yml']]
}

exec { 'create db drivers':
    command => "mysql -u demo --password='1abcdefg' < /home/vagrant/projects/mt-server/mt-parent/mt-service/sql/admin-insert-db-drivers.sql",
    path => '/usr/bin:/bin',
    require => [Package['mysql-client'], Package['mysql-server'], Exec['get server repo'], Exec['create mysql user'], Exec['run backend server']]
}

exec { 'create db servers':
    command => "mysql -u demo --password='1abcdefg' < /home/vagrant/projects/mt-server/mt-parent/mt-service/sql/admin-insert-db_servers.sql",
    path => '/usr/bin:/bin',
    require => [Package['mysql-client'], Package['mysql-server'], Exec['get server repo'], Exec['create db drivers']]
}

exec { 'clone dotfiles repo':
    command => "git clone http://github.com/ramseydsilva/dotfiles",
    path => "/usr/bin:/bin",
    cwd => "/home/vagrant",
    user => "vagrant",
    creates => '/home/vagrant/dotfiles',
    require => [Package['git']]
}

exec { 'configure vim':
    command => "git submodule init && git submodule update && ln -s /home/vagrant/dotfiles/.vim /home/vagrant/.vim && ln -s /home/vagrant/dotfiles/.vimrc /home/vagrant/.vimrc",
    path => "/usr/bin:/bin",
    cwd => "/home/vagrant/dotfiles",
    creates => '/home/vagrant/.vim',
    require => Exec['clone dotfiles repo'],
    user => "vagrant"
}
