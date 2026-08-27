#!/bin/bash
# User Management Script
# Create, modify, and delete users

set -euo pipefail

case "${1:-help}" in
    create)
        USERNAME="${2:?Usage: $0 create <username>}"
        useradd -m -s /bin/bash "$USERNAME"
        echo "User $USERNAME created"
        passwd "$USERNAME"
        ;;
    delete)
        USERNAME="${2:?Usage: $0 delete <username>}"
        userdel -r "$USERNAME"
        echo "User $USERNAME deleted"
        ;;
    sudo)
        USERNAME="${2:?Usage: $0 sudo <username>}"
        usermod -aG sudo "$USERNAME"
        echo "Added $USERNAME to sudo group"
        ;;
    ssh-key)
        USERNAME="${2:?Usage: $0 ssh-key <username>}"
        KEY="${3:?Usage: $0 ssh-key <username> <key>}"
        USER_HOME=$(eval echo ~"$USERNAME")
        mkdir -p "$USER_HOME/.ssh"
        echo "$KEY" >> "$USER_HOME/.ssh/authorized_keys"
        chmod 600 "$USER_HOME/.ssh/authorized_keys"
        chown -R "$USERNAME:$USERNAME" "$USER_HOME/.ssh"
        echo "SSH key added for $USERNAME"
        ;;
    list)
        echo "=== System Users ==="
        awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd
        ;;
    *)
        echo "Usage: $0 {create|delete|sudo|ssh-key|list}"
        ;;
esac
