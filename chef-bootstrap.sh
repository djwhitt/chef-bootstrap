#!/usr/bin/env bash

rubygems_version="1.3.7"

function usage {
    echo "usage: $0 <client|server> <server-url>"
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
server_url="$2"

# Install required packages
apt-get install ruby ruby-dev libopenssl-ruby build-essential wget ssl-cert

# Install Rubygems from source
cd /tmp
wget "http://production.cf.rubygems.org/rubygems/rubygems-${rubygems_version}.tgz"
tar xzf "rubygems-${rubygems_version}.tgz"
cd "rubygems-${rubygems_version}"
ruby setup.rb -q --no-format-executable

# Disable Rubygems RDoc and RI generation
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
      "server_url": "$server_url",
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
      "server_url": "$server_url"
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
