#!/bin/sh

timedatectl set-timezone Asia/Tokyo

apt-get update -y
apt-get upgrade -y
add-apt-repository ppa:webupd8team/java -y
apt-get install openjdk-8-jdk -y
apt-get install maven -y
apt-get install git -y

git clone https://github.com/Azure-Samples/azure-cosmos-java-getting-started.git