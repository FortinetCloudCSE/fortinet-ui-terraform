#! /bin/bash
sudo apt update
sudo apt -y upgrade
sudo apt -y install sysstat
sudo apt -y install net-tools
sudo apt -y install iperf3
sudo apt -y install apache2
sudo apt -y install lnav
sudo apt -y install awscli
sudo apt -y install vsftpd
sudo ufw allow 'Apache'
sudo sed -i 's/It works!/It works for ${region}${availability_zone}!/' /var/www/html/index.html
sudo systemctl start apache2
sudo apt -y install unzip
echo "Welcome to ${region}${availability_zone} Fortigate CNF Workshop Demo" > /var/www/html/demo.txt
cd /var/www/html
sudo sed -i 's/^#module(load="immark")/module(load="immark")/' /etc/rsyslog.conf
sudo sed -i 's/^#module(load="imudp")/module(load="imudp")/' /etc/rsyslog.conf
sudo sed -i 's/^#input(type="imudp" port="514")/input(type="imudp" port="514")/' /etc/rsyslog.conf
sudo service rsyslog restart
echo 'Welcome to ${region}${availability_zone} Fortigate CNF Workshop Demo' > /var/www/html/demo.txt
echo 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*%' > /var/www/html/eicar.com.txt

sudo sed -i 's/^anonymous_enable=YES/anonymous_enable=NO/' /etc/vsftpd.conf
sudo sed -i 's/^local_enable=NO/local_enable=YES/' /etc/vsftpd.conf
sudo sed -i 's/#write_enable=YES/write_enable=YES/' /etc/vsftpd.conf
sudo sed -i 's/#chroot_local_user=YES/chroot_local_user=YES/' /etc/vsftpd.conf
echo "allow_writeable_chroot=YES" >> /etc/vsftpd.conf
echo "pasv_enable=Yes" >> /etc/vsftpd.conf
echo "pasv_min_port=10090" >> /etc/vsftpd.conf
echo "pasv_max_port=10100" >> /etc/vsftpd.conf
sudo systemctl restart vsftpd.service
systemctl enable vsftpd

runuser -l ubuntu -c 'git clone https://github.com/tfutils/tfenv.git ~/.tfenv'
runuser -l ubuntu -c 'mkdir ~/bin'
runuser -l ubuntu -c 'ln -s ~/.tfenv/bin/* ~/bin'
runuser -l ubuntu -c 'tfenv install 1.7.5'
runuser -l ubuntu -c 'tfenv use 1.7.5'
runuser -l ubuntu -c 'echo "export PATH=$PATH:~/bin" >> ~/.bashrc'
runuser -l ubuntu -c 'echo "export PATH=$PATH:~/bin" >> ~/.bashrc'
runuser -l ubuntu -c 'echo "export AWS_ACCESS_KEY_ID=\`aws --profile default configure get aws_access_key_id\`" >> ~/.bashrc'
runuser -l ubuntu -c 'echo "export AWS_SECRET_ACCESS_KEY=\`aws --profile default configure get aws_secret_access_key\`" >> ~/.bashrc'

cat >> /home/ubuntu/fgt_config.conf <<EOF
# This is an FortiGate configuration example with two Geneve tunnel: geneve-az1, geneve-az2. Please add or remove based on your own value.
# Geneve tunnel name will be with format 'geneve-az<NUMBER>'. Check 'az_name_map' of the output of template, which is map of Geneve tunnel name to the AZ name that supported in Security VPC.
#
# This is an FortiGate configuration example with two Geneve tunnel: geneve-az1, geneve-az2. Please add or remove based on your own value.
# Geneve tunnel name will be with format 'geneve-az<NUMBER>'. Check 'az_name_map' of the output of template, which is map of Geneve tunnel name to the AZ name that supported in Security VPC.
# Change port2 to port1 if fgt_intf_mode set to 1-arm.

config system interface
edit port1
        set defaultgw disable
    next
    edit port2
        set defaultgw enable
    next
end
config system zone
    edit "geneve-tunnels"
        set interface "geneve-az1" "geneve-az2"
    next
end

config router static
    edit 0
        set dst 192.168.0.0 255.255.0.0
        set distance 5
        set priority 100
        set device "geneve-az1"
    next
    edit 0
        set dst 192.168.0.0 255.255.0.0
        set distance 5
        set priority 100
        set device "geneve-az2"
    next
    edit 0
        set dst 10.0.0.11 255.255.255.255
        set device "geneve-az1"
    next
    edit 0
        set dst 10.0.0.11 255.255.255.255
        set device "geneve-az2"
    next
end

config router policy
    edit 1
        set input-device "geneve-az1"
        set output-device "geneve-az1"
    next
    edit 2
        set input-device "geneve-az2"
        set output-device "geneve-az2"
    next
end

config firewall address
    edit "10.0.0.0/8"
        set subnet 10.0.0.0 255.0.0.0
    next
    edit "172.16.0.0/20"
        set subnet 172.16.0.0 255.255.240.0
    next
    edit "192.168.0.0/16"
        set subnet 192.168.0.0 255.255.0.0
    next
    edit "UnitedStates"
        set type geography
        set country "US"
    next
    edit "UnitedStatesIslands"
        set type geography
        set country "UM"
    next
    edit "Canada"
        set type geography
        set country "CA"
    next
end

config firewall addrgrp
    edit "rfc-1918-subnets"
        set member "10.0.0.0/8" "172.16.0.0/20" "192.168.0.0/16"
    next
    edit "NorthAmerica"
        set member "Canada" "UnitedStates" "UnitedStatesIslands"
    next
end

EOF




