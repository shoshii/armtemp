#!/bin/sh
USER=$1

timedatectl set-timezone Asia/Tokyo

apt-get update -y
apt-get upgrade -y
add-apt-repository ppa:webupd8team/java -y
apt-get install openjdk-8-jdk -y
apt-get install maven -y
apt-get install git -y

git clone https://github.com/Azure-Samples/azure-cosmos-java-getting-started.git /home/$USER/azure-cosmos-java-getting-started/
git clone https://github.com/Azure-Samples/azure-spring-boot-samples /home/$USER/azure-spring-boot-samples/
chown -R $USER:$USER /home/$USER/*