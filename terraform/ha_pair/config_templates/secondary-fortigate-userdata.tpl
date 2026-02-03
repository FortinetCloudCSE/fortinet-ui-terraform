Content-Type: multipart/mixed; boundary="==BOUNDARY=="
MIME-Version: 1.0

--==BOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"
MIME-Version: 1.0

config system global
set hostname ${fgt_id}
set admintimeout 60
end

config system admin
edit admin
set password ${fgt_admin_password}
next
end

config system interface
edit port1
set mode static
set ip ${port1_ip} ${port1_mask}
set allowaccess ping https ssh
set alias untrusted
next
edit port2
set mode static
set ip ${port2_ip} ${port2_mask}
set allowaccess ping
set alias trusted
next
edit port3
set mode static
set ip ${port3_ip} ${port3_mask}
set allowaccess ping https ssh
set alias ha-sync
next
%{ if enable_dedicated_mgmt }
edit port4
set mode static
set ip ${port4_ip} ${port4_mask}
set allowaccess ping https ssh
set alias management
next
%{ endif }
end

config router static
edit 1
set device port1
set gateway ${port1_gateway}
next
%{ if enable_dedicated_mgmt }
edit 2
set device port4
set gateway ${port4_gateway}
set priority 10
next
%{ endif }
end

config system vdom-exception
edit 1
set object system.interface
next
edit 2
set object router.static
next
end

config system ha
set group-name ${ha_group_name}
set mode a-p
set hbdev port3 50
set session-pickup enable
set ha-mgmt-status enable
config ha-mgmt-interface
edit 1
set interface ${ha_mgmt_if}
set gateway ${ha_mgmt_gateway}
next
end
set override disable
set priority ${ha_priority}
set unicast-hb enable
set unicast-hb-peerip ${ha_peer_ip}
set unicast-hb-netmask 255.255.255.255
end

config system dns
set primary 169.254.169.253
end

%{ if enable_fortimanager }
config system central-management
set type fortimanager
set fmg ${fortimanager_ip}
set serial-number auto
end
%{ endif }

%{ if enable_fortianalyzer }
config log fortianalyzer setting
set status enable
set server ${fortianalyzer_ip}
set serial auto
end
config log fortianalyzer override-setting
set status enable
end
%{ endif }

%{ if license_type == "fortiflex" }
exec vm-license ${fortiflex_token}
%{ endif }

--==BOUNDARY==
Content-Type: text/plain; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="license.lic"

%{ if license_type == "byol" }
${file(license_file)}
%{ endif }

--==BOUNDARY==--
