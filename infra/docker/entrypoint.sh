#!/bin/bash
# Sim node container entrypoint
# Installs the SSH public key and starts sshd

set -e

# Install the authorized key from the bind-mounted public key file
if [ -f /tmp/sim-authorized-key ]; then
  mkdir -p /root/.ssh
  chmod 700 /root/.ssh
  cp /tmp/sim-authorized-key /root/.ssh/authorized_keys
  chmod 600 /root/.ssh/authorized_keys
fi

# Print node identity on startup
echo "=== dc-sim node starting ==="
echo "Hostname:  $(hostname)"
echo "Platform:  ${SIM_PLATFORM:-unknown}"

# Start SSH daemon in foreground
exec /usr/sbin/sshd -D -e
