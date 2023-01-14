#!/usr/bin/env bash

# Reads all ssh public keys from the user's ~/.ssh directory and returns all
# the names that are found at the end of each public key
# Usage: get_ssh_key_names return_variable
get_ssh_key_names() {
  # Declare a variable to store the name of the variable that the return value
  # should be assigned to
  local return_value=$1
  # Declare an array to store the names of the ssh keys
  local ssh_key_names=()
  
  # Get the path to the user's ssh directory
  local ssh_dir=~/.ssh

  # Check if the ssh directory exists
  if [ ! -d "$ssh_dir" ]; then
    echo "Error: ssh directory not found"
    return 1
  fi

  # Loop through all files in the ssh directory
  for file in "$ssh_dir"/*.pub; do
    # Check if the private key file exists
    if [ ! -f "${file%.pub}" ]; then
      continue
    fi

    # Get the name of the ssh key using the ssh-keygen command
    local ssh_output
    ssh_output="$(ssh-keygen -lf $file 2>/dev/null)"

    # Check the exit code of the ssh-keygen command
    if [ $? -eq 0 ]; then
      # Get the ssh key name and append it to a new line
      local ssh_key_name
      ssh_key_name=$(echo "$ssh_output" | awk '{ for (i = 3; i <= NF; i++) {printf $i " "}; printf "\n"}')
      ssh_key_name=$(echo "$ssh_key_name" | sed 's/([^)]*)//g' | xargs)
      if [[ $ssh_key_name == "no comment" ]]; then
        ssh_key_name="${file%.*}"
        ssh_key_name="${ssh_key_name##*/}"
      fi

      printf "$ssh_key_name\n"
    fi
  done
}



# Get the array of ssh key names
# ssh_key_names=()

# get_ssh_key_names ssh_key_names
ssh_key_names_string=$(get_ssh_key_names)
IFS=$'\n' read -rd '' -a ssh_key_names <<<"$ssh_key_names_string"

# Print out a list of ssh key names
printf "List of ssh key names:\n"
for name in "${ssh_key_names[@]}"; do
  printf " - %s\n" "$name"
done