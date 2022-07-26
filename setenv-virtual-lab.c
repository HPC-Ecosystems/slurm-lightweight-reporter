# sms host information
sms_name=sms-host 	# Hostname for SMS server
sms_ip=10.10.10.10 	# Internal IP address on SMS server
# chrony time server information
ntp_server=time.google.com
cluster_ip_range=10.10.10.0/24
sms_eth_internal=eth1 # Internal Ethernet interface on SMS
internal_netmask=255.255.255.0 # Subnet netmask for internal network
CHROOT=/opt/ohpc/admin/images/rocky8.5