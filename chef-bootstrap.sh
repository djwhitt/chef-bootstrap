#!/usr/bin/env bash

rubygems_version="1.3.6"

function usage {
    echo "usage: $0 <client|server> <server-fqdn>"
}

if [[ $# != 2 ]]; then
    usage 
    exit
fi

if [[ $1 != 'server' && $1 != 'client' ]]; then
    usage 
    exit
fi

bootstrap_type="$1"
server_fqdn="$2"

# Install packages needed for Ruby + Rubygems
aptitude install ruby ruby1.8-dev libopenssl-ruby1.8 rdoc ri irb build-essential wget ssl-cert

# Install Rubygems from source
cd /tmp
wget "http://production.cf.rubygems.org/rubygems/rubygems-${rubygems_version}.tgz"
tar xzf "rubygems-${rubygems_version}.tgz"
cd "rubygems-${rubygems_version}"
ruby setup.rb -q --no-format-executable

# Disable Rubygems Rdoc and RI generation 
cat > /etc/gemrc <<EOF
gem: --no-ri --no-rdoc
EOF

# Install Chef
gem install chef

# Create Chef Solo config
cat > /tmp/solo.rb <<EOF
file_cache_path "/tmp/chef-solo"
cookbook_path "/tmp/chef-solo/cookbooks"
recipe_url "http://s3.amazonaws.com/chef-solo/bootstrap-latest.tar.gz"
EOF

# Create Chef server bootstrap config
cat > /tmp/chef-server.json <<EOF
{
  "bootstrap": {
    "chef": {
      "server_fqdn": "$server_fqdn",
      "webui_enabled": true
    }
  },
  "run_list": [ "recipe[chef::bootstrap_server]" ]
}
EOF

# Create Chef client bootstrap config
cat > /tmp/chef-client.json <<EOF
{
  "bootstrap": {
    "chef": {
      "server_fqdn": "$server_fqdn"
    }
  },
  "run_list": [ "recipe[chef::bootstrap_client]" ]
}
EOF

if [[ $bootstrap_type = 'client' ]]; then
    chef-solo -c /tmp/solo.rb -j /tmp/chef-client.json
fi

if [[ $bootstrap_type = 'server' ]]; then
    chef-solo -c /tmp/solo.rb -j /tmp/chef-server.json
fi
