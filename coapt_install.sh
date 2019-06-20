#!/bin/bash
#
# coapt_install.sh
#
# Tristan M. Chase 2017-02-01
#
# Installs coapt.sh and any related scripts and system software needed to run it.


# Variables

## Dependencies

### System
sys_deps="aptitude perl findutils wget" #locate updatedb xargs

### coapt-specific
script_deps="coapt apt-snapshot"

## Destination
dir=$HOME/bin

# Process

## Install missing $sys_deps
echo "Installing system software needed for coapt to run..."
echo ""
sleep 2
sudo apt-get install $sys_deps
sleep 2
echo "Done installing system software."
echo ""

## Download raw $script_deps from GitHub to $dir
echo "Downloading script files from GitHub..."
echo ""
sleep 2

# Create destination directory and change to it
mkdir -p $dir
cd $dir

for file in $script_deps; do
	wget https://raw.githubusercontent.com/tristanchase/$file/master/$file.sh 
	mv $file.sh $file # Rename the $file (drop the .sh) 
	chmod 755 $file   # Make the $file executable
done

sleep 2
echo "Installation complete. You may now use coapt by typing it on the command line."
echo ""

## Check to see if $dir is in $PATH

### If not, add it and modify .(bas|zs|oh-my-zs)hrc to include it.

