#!/bin/sh

# user@host for jumphost
JUMP_HOST=user@swdc-os-jump.westeurope.cloudapp.azure.com

# Make sure jump port is unique/available on ${JUMP_HOST} !! 
JUMP_PORT=20059

# private key for jumphost authentication
HOST_KEY="$HOME/.ssh/sshfw_key"

# If custom key comment is required e.g. (myRpi)
HOST_COMMENT=""

generate_key()
{
	local key="$1"
	local comment="$2"
	
	[ -z "$comment" ] && comment="$(hostname)-$(cat /sys/class/net/eth0/address | tr -d :)"
	ssh-keygen -t rsa -b 4096 -N '' -f $key -C "$comment"
}

generate_service()
{
	local output="$1"
	cat<< EOF > ${output}
[Unit]
Description=Starts SSH Port forwarding
After=multi-user.target
[Service]
Type=idle
User=$USER
ExecStart=/usr/bin/ssh -o ExitOnForwardFailure=yes -v -nNT -i $HOST_KEY -R ${JUMP_PORT}:localhost:22 ${JUMP_HOST}
Restart=on-failure
RestartSec=30
StartLimitBurst=100
SyslogIdentifier=ssh-forward
[Install]
WantedBy=multi-user.target
EOF
}

read -p "Enter unique forwarding port for $JUMP_HOST [$JUMP_PORT]: " choice
if [ -n "$choice" ]; then
	JUMP_PORT=$choice
fi

if [ ! -f $HOST_KEY ]; then
	echo "### Generating key: $HOST_KEY"
	generate_key $HOST_KEY $HOST_COMMENT
fi

echo "### Provisioning key: $HOST_KEY to $JUMP_HOST. Please enter password:"
ssh-copy-id -i $HOST_KEY $JUMP_HOST

# generate systemd service
generate_service "/tmp/ssh-forward.service"

# install systemd service
# NOTE: check for old services in /etc/systemd/system/ or /run/systemd/system/ as they are with higher priority
sudo cp -v "/tmp/ssh-forward.service" /lib/systemd/system/

sudo systemctl daemon-reload
sudo systemctl start ssh-forward
sudo systemctl enable ssh-forward
sudo systemctl status ssh-forward
