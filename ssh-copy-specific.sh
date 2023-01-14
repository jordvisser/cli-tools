#!/usr/bin/env bash

###############################################################################
# Converts a string to lowercase, replaces special characters and whitespace
# characters with underscores.
#
# Args:
#   input_string: The string to be converted.
#
# Returns:
#   The modified string with only lowercase alphabetical characters, numbers,
#   and underscores.
###############################################################################
convert_string() {
  # Declare the input_string variable as local and assign the first argument
  # passed to the function to input_string
  local input_string
  input_string="$1"

  # Trim whitespace characters from both ends of the input string
  input_string="${input_string#"${input_string%%[![:space:]]*}"}"
  input_string="${input_string%"${input_string##*[![:space:]]}"}"

  # Convert to lowercase and replace special characters with their normal
  # alphabet character
  local lowercase_string
  lowercase_string=$(echo $input_string | tr '[:upper:]' '[:lower:]')
  local replaced_string
  replaced_string=$(echo $lowercase_string | iconv -f utf8 -t ascii//TRANSLIT)

  # Replace all non-alphanumeric characters and all types of whitespace
  # characters with underscores
  input_string=${replaced_string//[^a-z0-9]/_}
  input_string=${input_string//[[:space:]]/_}

  # Return the modified string
  echo "$input_string"
}

# Reads all ssh public keys from the user's ~/.ssh directory and returns all
# the names that are found at the end of each public key
# Usage: get_ssh_key_names return_variable
get_ssh_key_names() {
  # # Declare a variable to store the name of the variable that the return value
  # # should be assigned to
  # local return_value=$1
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


###############################################################################
# multiselect function is a modified version of the one originally created 
# by Paul Miu (username: mamiu) and sourced from 
# https://github.com/mamiu/dotfiles/blob/main/install/utils/multiselect.sh.
# Original source code is published under the MIT license, for more 
# information please refer to 
# https://github.com/mamiu/dotfiles/blob/main/LICENSE.md
#
# This function creates a selection menu in the terminal where the user can 
# navigate through options using the up and down arrow keys or the "j" and "k" 
# keys, toggle the selection of an option using the spacebar, and confirm 
# their selection using the enter key. It also has error handling for when the 
# user inputs an invalid key or selects too many options. The result of the 
# selection is stored in an array, which can be accessed and used after the 
# function is called.
#
# Usage:
#
#   multiselect "true" result options defaults
#
# Arguments:
#  - first argument is a boolean value to determine if help menu should be 
#    shown or not
#  - second argument is the return value, the array where the result of the 
#    selection will be stored
#  - third argument is an array of options
#  - fourth argument is an array of defaults, optional.
#
# Example:
#   options=( "Option 1" "Option 2" "Option 3" )
#   defaults=( "true" "true" "false" )
#   multiselect "true" result options defaults
###############################################################################
function multiselect {
  if [[ $1 = "true" ]]; then
    echo -e "j or ↓\t\t=> down"
    echo -e "k or ↑\t\t=> up"
    echo -e "⎵ (Space)\t=> toggle selection"
    echo -e "⏎ (Enter)\t=> confirm selection"
    echo
  fi

  # little helpers for terminal print control and key input
  ESC=$( printf "\033")
  cursor_blink_on()   { printf "$ESC[?25h"; }
  cursor_blink_off()  { printf "$ESC[?25l"; }
  cursor_to()         { printf "$ESC[$1;${2:-1}H"; }
  print_inactive()    { printf "$2   $1 "; }
  print_active()      { printf "$2  $ESC[7m $1 $ESC[27m"; }
  get_cursor_row()    { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${ROW#*[}; }

  local return_value=$2
  local -a options=("${!3}")
  local -a defaults=("${!4}")

  local selected=()
  local selected_count=0
  for ((i=0; i<${#options[@]}; i++)); do
    if [[ ${defaults[i]} = "true" ]]; then
      selected+=("true")
      ((selected_count++))
    else
      selected+=("false")
    fi
    printf "\n"
  done

  # determine current screen position for overwriting the options
  local lastrow=`get_cursor_row`
  local startrow=$(($lastrow - ${#options[@]}))

  # ensure cursor and input echoing back on upon a ctrl+c during read -s
  trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
  cursor_blink_off

  #######################################
  # Function to handle key input and return corresponding action (up, down, enter, or space)
  # Arguments:
  #   None
  #######################################
  key_input() {
    local key
    IFS= read -rsn1 key 2>/dev/null >&2
    if [[ $key = ""    ]]; then echo enter; fi;
    if [[ $key = $'\x20' ]]; then echo space; fi;
    if [[ $key = "k" ]]; then echo up; fi;
    if [[ $key = "j" ]]; then echo down; fi;
    if [[ $key = $'\x1b' ]]; then
      read -rsn2 key
      if [[ $key = [A || $key = k ]]; then echo up;  fi;
      if [[ $key = [B || $key = j ]]; then echo down;  fi;
    fi 
  }


  #######################################
  # Function to toggle the selection of an option and update the selected count
  # Arguments:
  #   option: the index of the option to toggle
  #######################################
  toggle_option() {
    local option=$1
    if [[ ${selected[option]} == true ]]; then
      selected[option]=false
      ((selected_count--))
    else
      selected[option]=true
      ((selected_count++))
    fi
  }

  #######################################
  # Function to print the options with selected ones marked and highlighted. 
  # The function takes one argument as input, which is an integer indicating
  # the index of the option to be highlighted
  # Arguments:
  #   option_index: the index of the option to be highlighted
  #######################################
  print_options() {
    # print options by overwriting the last lines
    local idx=0
    for option in "${options[@]}"; do
      local prefix="[ ]"
      if [[ ${selected[idx]} == true ]]; then
        prefix="[\e[38;5;46m✔\e[0m]"
      fi

      cursor_to $(($startrow + $idx))
      if [ $idx -eq $1 ]; then
        print_active "$option" "$prefix"
      else
        print_inactive "$option" "$prefix"
      fi
      ((idx++))
    done
    cursor_to $(($startrow + $idx))
    if [ $selected_count -gt 5 ]; then
      printf "\e[1;97;41m to many keys selected, please select up to 5 keys \e[0m"
    else 
      printf "                           "
    fi
  }

#######################################
# Function to confirm if the number of selected options is less than 4, print
# the options and exit the loop
# Arguments:
#   None
#######################################
  confirm_options() {
    if [ $selected_count -le 5 ]; then
      print_options -1; break
    fi
  }


  local active=0
  while true; do
    print_options $active

    # user key control
    case `key_input` in
      space)  toggle_option $active;;
      enter)  confirm_options;;
      up)   ((active--));
          if [ $active -lt 0 ]; then active=$((${#options[@]} - 1)); fi;;
      down)   ((active++));
          if [ $active -ge ${#options[@]} ]; then active=0; fi;;
    esac
  done

  # cursor position back to normal
  cursor_to $lastrow
  printf "\n"
  cursor_blink_on

  # echo "return_value is of type: $(declare -p return_value | cut -d ' ' -f 2)"
  # echo "return_value contains: ${return_value[@]}"
  # echo "selected is of type: $(declare -p selected | cut -d ' ' -f 2)"
  # echo "selected contains: ${selected[@]}"

  eval $return_value='("${selected[@]}")'
}


# get command line options
while getopts ":fnsi:p:o:" opt; do
  case $opt in
  f) force="-f ";;
  n) dry_run="-n ";;
  s) sftp="-s ";;
  i) identity_file="-i $OPTARG ";;
  p) port="-p $OPTARG ";;
  o) ssh_option="-o $OPTARG ";;
  \?)
    echo "Invalid option: -$OPTARG" >&2
    exit 1
    ;;
  esac
done
shift $((OPTIND-1))

# Get all public keys from ssh-add
keys=$(ssh-add -L)

# Split keys into an array
IFS=$'\n' read -rd '' -a key_array <<<"$keys"

# Get key names
key_names=()
for i in "${!key_array[@]}"; do
  key_name=$(echo ${key_array[i]}| awk '{$1=$2=""; print $0}')
  key_name=$(convert_string "$key_name")
  key_names+=("$key_name")
done

# Set initial selection
result=()
pre_selection=()
for key in "${key_array[@]}"; do
  pre_selection+=("false")
done

printf "\033[1mPlease select the ssh keys to be used:\033[0m\n"

multiselect "false" result key_names[@] pre_selection[@]

# Print the selected keys
idx=0
for key in "${key_array[@]}"; do
  if [[ ${result[idx]} = "true" ]]; then
    echo "$key"
    echo "ssh-copy-id $force$dry_run$sftp$identity_file$port$ssh_option$1"
  fi
  ((idx++))
done

# Get the array of ssh key names
ssh_key_names=()

ssh_key_names_string=$(get_ssh_key_names)
IFS=$'\n' read -rd '' -a ssh_key_names <<<"$ssh_key_names_string"

# Print out a list of ssh key names
printf "List of ssh key names:\n"
for name in "${ssh_key_names[@]}"; do
  printf " - %s\n" "$name"
done