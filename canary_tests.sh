#!/bin/bash
set -ex # -e: exit immediately if there are errors. -x: print out every line that runs

echo '' # Give some visual separation to any humans looking at the logs
date '+%Y-%m-%d' # This is to help the logs analysis find today's logs.

if [[ "$(whoami)" != "root" ]] ; then
	echo "We must run as root, but currently we're $(whoami) instead."
	exit 1
fi

# See https://stackoverflow.com/a/1482133 for an explanation of this next line. It gets the
# directory in which this script resides.
this_dir="$(dirname -- "$( readlink -f -- "$0"; )")";
pushd "$this_dir" > /dev/null

# This script is adapted from
# https://viam.atlassian.net/wiki/spaces/ENG/pages/155451406/Data+ML+Canary+Testing+Bot

systemctl stop viam-canary

# Install the latest rdk. Installing instead of upgrading to ensure we get the latest version and don't get stuck on stable.
curl "https://storage.googleapis.com/packages.viam.com/apps/viam-server/viam-server-latest-$(uname -m).AppImage" -o viam-server
chmod 755 viam-server
./viam-server --aix-install

systemctl start viam-canary
sleep 60 # The server takes some time to set up its connections; don't talk to it too soon.

git pull --ff-only origin main # Update the test script if necessary

pip install -r requirements.txt # Install any new dependencies

echo "running tests..."
# The cron job that runs our script writes stdout to file. If something goes wrong in the tests, it
# will be written to stderr. Redirect that to stdout so it gets written to file, too.
./test_gpios.py 2>&1
echo "done running tests!"

popd > /dev/null # pushd "$this_dir"
exit 0
