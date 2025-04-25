#!/bin/bash

# Script to properly set permissions for home directories

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
	echo "This script must be run as root" >&2
	exit 1
fi

# Process each directory in /home
for user_dir in /home/*; do
	# Skip if not a directory
	if [ ! -d "$user_dir" ]; then
		continue
	fi
	
	# Extract username from directory path
	username=$(basename "$user_dir")
	
	echo "Setting permissions for $username's home directory..."
	
	# Set ownership of home directory to root
	chown root:root "$user_dir"
	
	# Set 755 permissions on home directory
	chmod 755 "$user_dir"
	
	# Handle .ssh directory if it exists
	if [ -d "$user_dir/.ssh" ]; then
		echo "Setting SSH directory permissions for $username..."
		
		# Set 700 permissions for .ssh directory
		chmod 700 "$user_dir/.ssh"
		
		# Set ownership of .ssh directory to the user
		chown -R "$username:root" "$user_dir/.ssh"
		
		# If authorized_keys exists, set proper permissions
		if [ -f "$user_dir/.ssh/authorized_keys" ]; then
			echo "Setting authorized_keys permissions for $username..."
			chmod 600 "$user_dir/.ssh/authorized_keys"
		fi
	fi

	# Create and set permissions for a share directory if it doesn't exist
	if [ ! -d "$user_dir/share" ]; then
		echo "Creating share directory for $username..."
		mkdir -p "$user_dir/share"
		chown "$username:root" "$user_dir/share"
		chmod 755 "$user_dir/share"
		echo "Share directory created and permissions set."
	else
		echo "Share directory already exists for $username. Setting permissions..."
		chown -R "$username:root" "$user_dir/share"
	fi
	
	echo "Completed permissions setup for $username"
	echo "----------------------------------------"
done

echo "All home directories processed."