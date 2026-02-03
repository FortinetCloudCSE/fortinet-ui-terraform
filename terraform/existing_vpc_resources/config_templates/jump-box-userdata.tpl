#! /bin/bash
sudo apt update
sudo apt -y upgrade
sudo apt -y install sysstat
sudo apt -y install net-tools
sudo apt -y install iperf3
sudo apt -y install apache2
sudo apt -y install lnav
sudo apt -y install awscli
sudo apt -y install unzip
sudo apt -y install jq
sudo apt -y sshpass
sudo ufw allow 'Apache'
sudo sed -i 's/It works!/Management Jump Box - ${region}${availability_zone}!/' /var/www/html/index.html
sudo systemctl start apache2
echo "Management Jump Box - ${region}${availability_zone}" > /var/www/html/demo.txt

PRIMARY_IF=$(ip route | grep default | awk '{print $5}')

# Enable IP forwarding to allow NAT for spoke VPC instances
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf

# Configure iptables NAT for spoke VPCs
# NAT traffic from spoke VPCs (East: 192.168.0.0/24, West: 192.168.1.0/24) to internet via jump box EIP
sudo iptables -t nat -A POSTROUTING -s 192.168.0.0/24 -o $PRIMARY_IF -j MASQUERADE
sudo iptables -t nat -A POSTROUTING -s 192.168.1.0/24 -o $PRIMARY_IF -j MASQUERADE

# Allow forwarding for spoke VPC traffic
sudo iptables -A FORWARD -s 192.168.0.0/24 -j ACCEPT
sudo iptables -A FORWARD -s 192.168.1.0/24 -j ACCEPT
sudo iptables -A FORWARD -d 192.168.0.0/24 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -d 192.168.1.0/24 -m state --state RELATED,ESTABLISHED -j ACCEPT

# Install and save iptables rules persistently
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent
sudo netfilter-persistent save

runuser -l ubuntu -c 'git clone https://github.com/tfutils/tfenv.git ~/.tfenv'
runuser -l ubuntu -c 'mkdir ~/bin'
runuser -l ubuntu -c 'ln -s ~/.tfenv/bin/* ~/bin'
runuser -l ubuntu -c 'tfenv install 1.7.5'
runuser -l ubuntu -c 'tfenv use 1.7.5'
runuser -l ubuntu -c 'echo "export PATH=/sbin:$PATH:~/bin" >> ~/.bashrc'

