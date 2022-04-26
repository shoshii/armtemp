#!/bin/sh

timedatectl set-timezone Asia/Tokyo

apt-get update
apt-get upgrade
apt install openjdk-8-jre-headless
apt-get install maven
apt-get install git