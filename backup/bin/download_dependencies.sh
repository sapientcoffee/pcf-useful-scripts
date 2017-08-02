#!/bin/bash

set -eu

pushd $(dirname $0) > /dev/null 2>&1

_curl() {
	curl -k -L $@
}

# Get UAAC tool
echo " === Downloading uaac"
gem install cf-uaac
echo " ==="

# Get `cfops`` tool
echo " === Downloading cfops"
_curl https://github.com/pivotalservices/cfops/releases/download/v3.0.8/cfops_linux64 -o /usr/local/bin/cfops
chmod +x /usr/local/bin/cfops
echo " ==="

# Get RabbitMQ plugin for `cfops`
echo " === RabbitMQ cfops plugin"
tmpdir=$(mktemp -d)
_curl https://github.com/pivotalservices/cfops-rabbitmq-plugin/releases/download/v0.0.5/cfops-rabbitmq-plugin_binaries.tgz -o $tmpdir/cfops.tgz
mkdir ./plugins
tar xzvf $tmpdir/cfops.tgz -C $tmpdir
find $tmpdir -iregex '.+linux64/cfops-rabbitmq-plugin' -exec mv {} ./plugins/ \;
echo " ==="

popd > /dev/null 2>&1
