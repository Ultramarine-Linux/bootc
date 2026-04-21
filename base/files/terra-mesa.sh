# Enable terra-mesa repo stream for updates

sed -i '0,/enabled=0/s/enabled=0/enabled=1/' /etc/yum.repos.d/terra-mesa.repo
