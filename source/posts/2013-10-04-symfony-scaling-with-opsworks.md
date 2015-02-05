---
date: 2013-10-04 15:23:00
title: Scaling Symfony 2 with AWS OpsWorks
priority: 0.9
changefreq: daily
categories:
- IT
- Symfony
tags:
- symfony
- aws
- cloud
- opsworks
- scaling
---

During the last complete rebuild of <a href="http://goalshouter.com/" target="_blank">Goalshouter</a> we needed to redesign our infrastructure to handle the big traffic we were expecting.

Our biggest difference between an everyday site is that 80% of the traffic is concentrated in some hours of sunday because most of the soccer matches are at that time.
We needed a solution that was being able to scale fast to a large number of servers.

According to <a href="http://newrelic.com" target="_blank">New Relic</a> on sunday afternoon the requests per second increases by 20x in a couple of minutes. Our match processing tool is a bit resource intensive and we need enough power to let teams track their matches and people follow them.

READMORE

> N.B. This is an example I've setup for our specific application, you could have different needs and may need a simplier or more complicated setup

I've decided to divide our application into three main components:

 - frontend webservers
 - MySql slaves
 - cluster of MySql masters

### MySql XtraDB Cluster

First of all I've installed <a href="http://www.percona.com/software/percona-xtradb-cluster" target="_blank">Percona XtraDB Cluster</a> on three dedicated servers which easily handle our writing needs while providing us an high available solution which never had a failure since we've started.

You can easily install it on your own following this simple <a href="http://www.percona.com/doc/percona-xtradb-cluster/howtos/ubuntu_howto.html" target="_blank">tutorial</a> and you'll end up with a working MySql cluster powered by the enhanced InnoDB version called <a href="http://www.percona.com/software/percona-xtradb" target="_blank">XtraDB</a>.

## AWS OpsWorks

The MySql cluster is the only part we've left off Amazon Web Services for performance and pricing reasons, we don't need to scale it so fast since the number of writes we're going to handle is predictable and the price of such performant machines is less than we would have paid for on AWS.

<a href="http://aws.amazon.com/opsworks/" target="_blank">OpsWorks</a> is a new deployment & management tool available on the AWS console which let you deploy orchestrate your application servers using chef recipes or built-in components.

### Stacks

The first thing you've to create on OpsWorks is a **stack**, each one is an _environment_ with its own configuration and servers, we've one for production and one for development.
Each stack has a json which replaces the attributes in your chef recipes and during each run brings the informations of the whole stack (other servers informations and custom configuration).

### Layers

Each stack has one or more layers which basically groups instances by behaviour like installed packages, recipes to be run, load balancers to be attached and so on.

We've created three layers on our stacks:

 - frontend webservers
 - MySql slaves
 - MySql masters proxy

I could have merged frontend and MySql slaves on a single layer by running a slave on each of the frontend instances but I would have had slower boot times and we don't really need that since each slave can handle all the requests of about 8/10 frontend webservers so I've preferred to keep things separated.

Let's see how I've configured these layers:

#### MySql masters proxy

Let's start by the simplier layer, the MySql masters proxy. Its role is to handle all writing requests from the frontend webserver and the replication connections from the MySql slaves and proxy those to a working (connected to the cluster) MySql dedicated server we've talked before.

To do that I've installed the ```haproxy``` package via layer settings and after installing <a href="https://github.com/olafz/percona-clustercheck" target="_blank">clustercheck</a> on our masters I've created a chef recipe that uses this template for setting up HAProxy:

``` erb
global
    log 127.0.0.1   local0
    log 127.0.0.1   local1 notice
    maxconn 4096
    user haproxy
    group haproxy
    daemon

defaults
    log     global
    mode    http
    option  tcplog
    option  dontlognull
    retries 3
    option redispatch
    maxconn 2000
    contimeout      10000
    clitimeout      300000
    srvtimeout      300000

listen webcluster *:80
    stats enable
    stats auth admin:<%= @statspwd %>

listen mysql-cluster 0.0.0.0:3306
    mode tcp
    balance leastconn
    option  httpchk

<% if @masters %>
    <% @masters.each_with_index do |master, i| %>
    server mysql<%= i + 1 %> <%= master %>:3306 check port 9200 inter 12000 rise 3 fall 3
    <% end %>
<% end %>
```

In this case ```@masters``` is an array of IP addresses or hostnames which HAProxy should check the availability and proxy traffic to them. The masters variable, along with the statspwd has been set via the stack's configuration json.

You should set the recipe to be run on instance's setup stage, you can read more about at lifecycle events <a href="http://aws.amazon.com/opsworks/faqs/#lifecycle" target="_blank">here</a>.

#### MySql slaves

The MySql slaves layer has the responsability to handle the read requests from the webservers and keep themselves in sync with the MySql masters. To do so when an instance boots it installs a MySql server and clones the database defined in stack configuration and starts replicating it.

To setup this layer I've told OpsWorks to install these packages: ```mysql-server, mysql-client, build-essential, libmysqlclient-dev, libmysql-ruby1.8```. These are needed to setup the server and let the chef recipes dump the remote database and install locally a copy (I'm not sure if libmysql-ruby1.8 is needed anymore since the build-essential already builds it and they've updated Chef to version 11).

The recipe we're actually running on setup stage is this:

```ruby
#
# Cookbook Name:: acme
# Recipe:: mysql-slave
#
# Copyright 2013, Alessandro Tagliapietra
#
# All rights reserved - Do Not Redistribute
#

# Run apt-get update
include_recipe 'apt'

# Install MySql gem
package "libmysqlclient-dev" do
  action :nothing
end.run_action(:install)

chef_gem 'mysql' do
	version '2.9.1'
end

# Load gem into current load path
gem_path = Gem.path.first
$LOAD_PATH << "#{gem_path}/gems/mysql-2.9.1/lib"

require 'mysql'

# Create an unique local id
if node[:opsworks] and node[:opsworks][:instance]
	server_id = node[:opsworks][:instance][:aws_instance_id].scan(/\d+/)
else
	server_id = [*10000..20000].choice
end

# Define service into chef
service 'mysql' do
	supports :status => true, :start => true, :stop => true, :restart => true, :reload => true
	action :nothing
end

# Get master address
master_config = node[:acme][:database][:master]

# Create configuration
template node['acme']['database']['mysql']['config_path'] do
	source 'my.cnf.erb'
	mode '0655'
	variables(
		:server_id => server_id,
		:databases => master_config[:databases].split(',')
	)
end

# Restart MySql
service 'mysql' do
	action :restart
end

# If we're in configure lifecycle event just reload
if node[:opsworks] and node[:opsworks][:activity] == 'configure'
	service 'mysql' do
		action [:reload]
	end
else
	# Else configure from scratch
	new_root_pwd = node[:acme][:database][:slave][:password]

	ruby_block 'secure_install' do
		block do
			m = Mysql.new('localhost', 'root', '')
			m.query("UPDATE mysql.user SET Password=PASSWORD('#{new_root_pwd}') WHERE User='root';")
			m.query("DELETE FROM mysql.user WHERE User='';")
			m.query("DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');")
			m.query("DROP DATABASE test;")
			m.query("DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'")
			m.query("FLUSH PRIVILEGES;")
		end
		only_if do
			begin
				m = Mysql.new('localhost', 'root', '')
				true
			rescue Mysql::Error => e
				false
			end
		end
	end

	ruby_block 'setup_replication' do
		block do
			master_config = node[:acme][:database][:master]
			Chef::Log.info("Setting master to #{master_config[:hostname]}")

			m = Mysql.new('localhost', 'root', new_root_pwd)
			
			command = %Q{
				CHANGE MASTER TO
				MASTER_HOST="#{master_config[:hostname]}",
				MASTER_USER="#{master_config[:username]}",
				MASTER_PASSWORD="#{master_config[:password]}";
			}
			Chef::Log.info "Sending start replication command to mysql: "
			Chef::Log.info "#{command}"

			m.query('stop slave')
			m.query(command)
			m.close
		end
		only_if do
			begin
				m = Mysql.new('localhost', 'root', new_root_pwd)
			rescue Mysql::Error => e
				false
			end
		end
	end

	ruby_block 'drop_db' do
		block do
			master_config = node[:acme][:database][:master]
			Chef::Log.info("Dropping current db")

			m = Mysql.new('localhost', 'root', new_root_pwd)

			begin
				master_config[:databases].split(',').each { |db|
					m.query("DROP DATABASE #{db}")
				}
			rescue Mysql::Error => e
				true
			end
			m.close
		end
		only_if do
			begin
				m = Mysql.new('localhost', 'root', new_root_pwd)
			rescue Mysql::Error => e
				false
			end
		end
	end

	bash "import_db" do
		master_config = node[:acme][:database][:master]
		code <<-EOH
				mysqldump --master-data -h #{master_config[:hostname]} -u #{master_config[:username]} -p#{master_config[:password]} --database #{master_config[:databases].split(',').join(' ')} | mysql -u root -p#{new_root_pwd}
			EOH
		only_if do
			begin
				m = Mysql.new('localhost', 'root', new_root_pwd)
				true
			rescue Mysql::Error => e
				false
			end
		end
	end

	ruby_block 'start_replication' do
		block do
			master_config = node[:acme][:database][:master]
			Chef::Log.info("Starting mysql replication")

			m = Mysql.new('localhost', 'root', new_root_pwd)
			m.query('start slave')
			m.close
		end
		only_if do
			begin
				m = Mysql.new('localhost', 'root', new_root_pwd)
			rescue Mysql::Error => e
				false
			end
		end
	end

	ruby_block 'create_users' do
		block do
			master_config = node[:acme][:database][:master]
			Chef::Log.info("Creating slave users")

			m = Mysql.new('localhost', 'root', new_root_pwd, 'mysql')
			users = node[:acme][:database][:slave][:users]
			databases = master_config[:databases].split(',')
			users.each { |user|
				Chef::Log.info("Creating user #{user[:username]}")
				begin
					m.query("DROP USER '#{user[:username]}'@'%';")
				rescue Mysql::Error => e
				end
				m.query("FLUSH PRIVILEGES")
				m.query("CREATE USER '#{user[:username]}'@'%' IDENTIFIED BY '#{user[:password]}';")
				databases.each { |db|
					Chef::Log.info("Granting access to #{db}")
					m.query("GRANT ALL PRIVILEGES ON `#{db}`.* TO '#{user[:username]}'@'%';")
				}
				m.query("FLUSH PRIVILEGES")
			}
			m.close
		end
		only_if do
			begin
				m = Mysql.new('localhost', 'root', new_root_pwd)
			rescue Mysql::Error => e
				false
			end
		end
	end

	service 'mysql' do
		action [:restart]
	end
end
```

The template used for MySql configuration is this:

``` erb
[client]
port		= 3306
socket		= /var/run/mysqld/mysqld.sock

[mysqld_safe]
socket		= /var/run/mysqld/mysqld.sock
nice		= 0

[mysqld]
user		= mysql
pid-file	= /var/run/mysqld/mysqld.pid
socket		= /var/run/mysqld/mysqld.sock
port		= 3306
basedir		= /usr
datadir		= /var/lib/mysql
tmpdir		= /tmp
lc-messages-dir	= /usr/share/mysql
skip-external-locking

server-id		    = <%= @server_id %>
expire_logs_days	= 10
max_binlog_size     = 100M
binlog_format       = ROW
<% if @databases %>
<% @databases.each do |db| %>
replicate_do_db     = "<%= db %>"
<% end %>
<% end %>

!includedir /etc/mysql/conf.d/
```

The important part is the loop over databases to tell MySql which one to replicate locally.

Now you can create as many MySql slaves as you want to scale your application read capacity.

#### Webservers

Now the core of our application, the webservers running the Symfony application.

First of all create a custom stack, tell OpsWorks to install these packages: ```nginx-full, php5-fpm, php5-cli, php5-curl, php5-gd, php-apc, php5-mysql, php5-intl, curl, git, php5-memcached```, additionally if you want to compress assets using Google closure install also ```openjdk-6-jre```.

Then if you plan to use more than one machine (otherwise why are you reading this?) you should create an Elastic Load Balancer from your EC2 console and attach it to the layer and also an ElastiCache cluster to store your Symfony sessions if you don't want users being logged out everytime they make another request (ELB doesn't stick users to instances until you tell him to do so in <a href="http://docs.aws.amazon.com/ElasticLoadBalancing/latest/DeveloperGuide/US_StickySessions.html" target="_blank">this way</a>).

Now that you have your server installed you need to create a chef recipe to do these things:

 - configure nginx's virtualhost
 - configure php5-fpm daemons
 - reconfigure your application for environment changes
 - deploy your application

Lets start one by one.

##### Nginx webserver

For the nginx virtualhost configuration I've created this recipe which wipes the virtualhost configuration folder, re-create it and reloads nginx:

```ruby
#
# Cookbook Name:: acme
# Recipe:: nginx-vhost
#
# Copyright 2013, Alessandro Tagliapietra
#
# All rights reserved - Do Not Redistribute
#

# Delete all nginx configuration files and create virtualhost configuration
dir_path = "#{node['acme']['nginx']['config_dir']}/sites-enabled"

ruby_block 'Clear nginx configuration' do
	block do
		Dir.foreach(dir_path) {|f| fn = File.join(dir_path, f); File.delete(fn) if f != '.' && f != '..'}
	end
end

# Be sure that the vhost folder exists and it's owned by www user
FileUtils.mkdir_p node['acme']['frontend']['deploy_dir']

directory node['acme']['frontend']['deploy_dir'] do
	owner node['acme']['frontend']['deploy_user']
	group node['acme']['frontend']['deploy_user']
end

template "#{dir_path}/acme" do
	source 'nginx-vhost.erb'
	mode '0700'
	variables(
		:vhost => node['acme']['frontend']['nginx']['vhost'],
		:root_path => node['acme']['frontend']['nginx']['root_path'],
		:error_log_path => node['acme']['frontend']['nginx']['error_log_path'],
		:access_log_path => node['acme']['frontend']['nginx']['access_log_path'],
		:socket_path => node['acme']['frontend']['php_fpm']['socket_path'],
		:lb_ip => node['acme']['frontend']['lb_ip']
	)
end

service 'nginx' do
	supports :status => true, :start => true, :stop => true, :restart => true, :reload => true
	action [:start, :reload]
end
```

the template ```nginx-vhost.erb``` used in the recipe is the following:

```erb
server {
    server_name <%= @vhost %>;
    root <%= @root_path %>;
    error_log <%= @error_log_path %>;
    log_format  main  '$remote_addr $host $remote_user [$time_local] "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent" $request_time';
    access_log <%= @access_log_path %> main;
    rewrite ^/app\.php/?(.*)$ /$1 permanent;

    <% if @lb_ip %>
    set_real_ip_from    <%= @lb_ip %>;
    real_ip_header      X-Forwarded-For;
    <% end %>

    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_buffers 16 8k;
    gzip_http_version 1.1;
    gzip_types text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript;

    location / {
        index app.php;
        try_files $uri @rewriteapp;
    }

    location @rewriteapp {
        rewrite ^(.*)$ /app.php/$1 last;
    }

    location ~* \.(js|css)$ {
        expires 1d;
    }

    location ~ ^/app\.php(/|$) {
        fastcgi_pass unix:<%= @socket_path %>;
        include fastcgi_params;
    }
}
```

This was enough to configure nginx with the settings provided by the stack and make it ready to handle connections.

> N.B. The lb_ip provided by the stack configuration is the VPC subnet so nginx sets the real client IP when requests are proxied through the ELB

##### PHP5-FPM daemon

The php5-fpm configuration recipe is similar to the one used in the nginx's part and I'm not going to paste it, instead, this is the template used for the fpm pool configuration:

```erb
[<%= @pool_name %>]
user = <%= @user %>
group = <%= @group %>
listen = <%= @socket_path %>
listen.owner = <%= @user %>
listen.group = <%= @group %>
listen.mode = 0660
pm = dynamic
pm.max_children = 8
pm.start_servers = 3
pm.min_spare_servers = 1
pm.max_spare_servers = 3
php_admin_value[error_log] = <%= @error_log_path %>
php_admin_flag[log_errors] = on
```

##### Application reconfiguration

All the previous recipes has to be run on the setup stage of the instance since we need to run them only when it boots. What I'm going to show now is the configuration recipe that has to be set in the configuration stage of the layer, this lifecycle event is run everytime another instance in the stack has finished launching or has started the shutdown, this is useful to add a MySql slave to the doctrine configuration everytime we launch a new one or remove it when its going to be shut down.

In our Symfony codebase I've first created an ```amazon.yml``` file that is included into each of the config_*.yml files. It gets populated by the configuration recipe to add/override configuration values dynamically during the stack lifecycle.

This is the reconfigure recipe:

```ruby
#
# Cookbook Name:: acme
# Recipe:: configure
#
# Copyright 2013, Alessandro Tagliapietra
#
# All rights reserved - Do Not Redistribute
#

config_file = "#{node['acme']['frontend']['deploy_dir']}/current/app/config/amazon.yml"
release_path = "#{node['acme']['frontend']['deploy_dir']}/current"

template config_file do
	source 'config.yml.erb'
	owner node['acme']['frontend']['deploy_user']
	group node['acme']['frontend']['deploy_user']
	mode '0644'
	variables(
			:deploy_time => node['opsworks']['sent_at'],
			:master_host => node['opsworks']['layers']['mysql-haproxy']['instances'].first[1]['private_ip'],
			:database => node['acme']['frontend']['database'],
			:slaves => node['opsworks']['layers']['db']['instances'],
			:slave_user => node['acme']['database']['slave']['users'].first['username'],
			:slave_password => node['acme']['database']['slave']['users'].first['password'],
			:memcached => node['acme']['frontend']['memcached'],
			:parameters => node['acme']['frontend']['parameters']
		)
	only_if do
		File.exists? config_file
	end
end

execute 'clear_cache_warmup' do
	command 'php app/console cache:clear --env=prod'
	cwd release_path
	user node['acme']['frontend']['deploy_user']
	group node['acme']['frontend']['deploy_user']
	only_if do
		File.exists? config_file
	end
end

# Restart php-fpm and nginx service
service 'php5-fpm' do
	supports :status => true, :restart => true, :reload => true
	action [ :reload ]
	only_if do
		File.exists? config_file
	end
end
```

And this is the configuration template used:

```erb
doctrine:
    dbal:
        <% if @master_host %>
        host: <%= @master_host %>
        <% end %>
        <% if @database %>
        dbname: "<%= @database %>"
        <% end %>
        <% if @slaves %>
        slaves:
            <% @slaves.each do |slave| %>
            <%= slave[1][:aws_instance_id] %>:
                <% if @database %>
                dbname: "<%= @database %>"
                <% else %>
                dbname: "%database_name%"
                <% end %>
                host: <%= slave[1][:private_ip] %>
                user: <%= @slave_user %>
                password: <%= @slave_password %>
                charset: UTF8
            <% end %>
        <% end %>
    <% if @memcached %>
    orm:
        result_cache_driver:
            type:   memcached
            host:   <%= @memcached[:host] %>
            port:   <%= @memcached[:port] %>
            instance_class: Memcached
    <% end %>

<% if @memcached %>
framework:
    session:
        handler_id: session.handler.memcached
    <% if @deploy_time %>
    templating:
        assets_version: "<%= @deploy_time %>"
    <% end %>

services:
    session.memcached:
        class: Memcached
        calls:
          - [ addServer, [ <%= @memcached[:host] %>, <%= @memcached[:port] %> ]]

    session.handler.memcached:
        class: Symfony\Component\HttpFoundation\Session\Storage\Handler\MemcachedSessionHandler
        arguments: [ @session.memcached, { prefix: "sess_", expiretime: "3600" } ]
<% end %>

<% if @parameters.length %>
parameters:
    <% @parameters.each do | index, item | %>
    <%= index %>:   <%= item %>
    <% end %>
<% end %>
```

Here you can see different configuration pieces have been used:

 - master settings to set the master as the HAProxy private IP
 - slaves array got by OpsWorks stack json to populate doctrine slaves config
 - memcached to use as doctrine's result cache and sessions storage
 - 'parameters' variable used to override some application parameters without having to write also into parameters.yml file

##### Application deploy

Now it's time for maybe the most essential part, the deploy recipe. As the name advice it has to be set on the runlist of the deploy lifecycle event.
The recipe role is to deploy a new application version fetching the code from git (or whatever the chef <a href="http://docs.opscode.com/resource_deploy.html" target="_blank">deploy resource</a> is able to handle) and run the post fetch scripts like warming up cache, dumping assets and restarting php5-fpm to clear apc cache.

Here it is:

```ruby
#
# Cookbook Name:: acme
# Recipe:: deploy
#
# Copyright 2013, Alessandro Tagliapietra
#
# All rights reserved - Do Not Redistribute
#

# Run apt-get update
include_recipe 'apt'

# Get deploy key for git fetch
deploy_key = node['acme']['frontend']['deploy_key']

# Setup ssh key and wrapper to be able to fetch the code
ruby_block 'Create deploy dir' do
	block do
		FileUtils.mkdir_p node['acme']['frontend']['deploy_dir']
	end
end

# Chown /var/www folder to deploy user
directory node['acme']['frontend']['deploy_dir'] do
	owner node['acme']['frontend']['deploy_user']
	group node['acme']['frontend']['deploy_user']
end

if deploy_key
	ruby_block "write_key" do
		block do
			f = ::File.open("#{node['acme']['frontend']['deploy_key_path']}", "w")
			f.print(deploy_key)
			f.close
		end
		not_if do ::File.exists?("#{node['acme']['frontend']['deploy_key_path']}"); end
	end

	file "#{node['acme']['frontend']['deploy_key_path']}" do
		mode '0600'
		owner node['acme']['frontend']['deploy_user']
		group node['acme']['frontend']['deploy_user']
	end

	template "#{node['acme']['frontend']['deploy_dir']}/git-ssh-wrapper" do
		source 'git-ssh-wrapper.erb'
		mode '0755'
		variables(:deploy_key_path => node['acme']['frontend']['deploy_key_path'])
	end
end

# Deploy acme code

# Create and change owner of shared deploy folder to avoid chef errors
ruby_block 'Create deploy shared folder' do
	block do
		FileUtils.mkdir_p "#{node['acme']['frontend']['deploy_dir']}/shared"
	end
	not_if do ::File.exists?("#{node['acme']['frontend']['deploy_dir']}/shared"); end
end

directory "#{node['acme']['frontend']['deploy_dir']}/shared" do
	owner node['acme']['frontend']['deploy_user']
	group node['acme']['frontend']['deploy_user']
end

# Deploy the code
deploy node['acme']['frontend']['deploy_dir'] do
	scm_provider Chef::Provider::Git
	repo node['acme']['frontend']['deploy_repo']
	revision node['acme']['frontend']['deploy_branch']
	if deploy_key
		git_ssh_wrapper "#{node['acme']['frontend']['deploy_dir']}/git-ssh-wrapper"
	end
	user node['acme']['frontend']['php_fpm']['user']
	group node['acme']['frontend']['php_fpm']['group']
	symlink_before_migrate({})
	purge_before_symlink ['data']
	create_dirs_before_symlink []
	# Removed due opsworks chef version
	#rollback_on_error true
	before_symlink do
		# Copy vendors from latest release to avoid to fetch all dependencies with composer
		ruby_block 'Copy vendors' do
			block do
				current_release = "#{node['acme']['frontend']['deploy_dir']}/current"
				FileUtils.cp_r "#{current_release}/vendor", "#{release_path}/vendor" if File.directory? "#{current_release}/vendor"
				FileUtils.chown_R node['acme']['frontend']['deploy_user'], node['acme']['frontend']['deploy_user'], "#{release_path}/vendor" if File.directory? "#{current_release}/vendor"
				Chef::Log.info "Copying older vendors from #{current_release}/vendor to #{release_path}/vendor" if File.directory? "#{current_release}/vendor"
				Chef::Log.info 'Not copying vendor folders since it\'s not found in older release' unless File.directory? "#{current_release}/vendor"
			end
			action :create
		end

		execute 'download_composer' do
			command 'curl -sS https://getcomposer.org/installer | php'
			cwd release_path
			user node['acme']['frontend']['deploy_user']
			group node['acme']['frontend']['deploy_user']
		end

		execute 'install_composer_dependencies' do
			command 'php composer.phar install --no-scripts --no-dev --verbose --prefer-source --optimize-autoloader'
			cwd release_path
			user node['acme']['frontend']['deploy_user']
			group node['acme']['frontend']['deploy_user']
		end

		execute 'build_boostrap' do
			command 'php vendor/sensio/distribution-bundle/Sensio/Bundle/DistributionBundle/Resources/bin/build_bootstrap.php app'
			cwd release_path
			user node['acme']['frontend']['deploy_user']
			group node['acme']['frontend']['deploy_user']
		end

		execute 'clear_cache' do
			command 'php app/console cache:clear --env=prod'
			cwd release_path
			user node['acme']['frontend']['deploy_user']
			group node['acme']['frontend']['deploy_user']
		end

		execute 'assets_dump' do
			command 'php app/console assetic:dump --env=prod'
			cwd release_path
			user node['acme']['frontend']['deploy_user']
			group node['acme']['frontend']['deploy_user']
		end

		execute 'remove_dev' do
			command 'rm web/app_dev.php'
			cwd release_path
			user node['acme']['frontend']['deploy_user']
			group node['acme']['frontend']['deploy_user']
		end
	end
	symlinks({"data" => "data"})
	action :deploy
	# Removed due opsworks chef version
	#notifies :reload, "service[nginx]", :immediately
end

# Restart php-fpm and nginx service
service 'php5-fpm' do
	supports :status => true, :restart => true, :reload => true
	action [ :reload ]
end

service 'nginx' do
	supports :status => true, :restart => true, :reload => true
	action [ :reload ]
end
```

Now some things that I've already done but are out of the scope of this post:

 - create a recipe to set the same timezone on each server to avoid MySql dateTime differences
 - create a custom template to set php specific settings based on stack configuration
 - change the php-fpm number of php instances based on the instance type
 - let each instance talk only with its same availability zone to isolate each group of servers to decrease downtime in case of AWS issues and to save on cross-AZ bandwidth cost

Hope you enjoyed this post and sorry for my bad english. If you think someone can be improved or has to be explained more clearly feel free to drop a comment, they're very appreciated! ;)