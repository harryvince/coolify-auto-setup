#!/usr/bin/env bash

required_deps=("curl" "jq" "ifconfig" "awk" "grep")

for dep in "${required_deps[@]}"; do
	if ! [ -x "$(command -v "$dep")" ]; then
		echo "Error: $dep is not installed. Please install it to run this script."
		exit 1
	fi
done

check_request() {
	RESPONSE=$1
	ignore_messages=(
		"Server deleted."
		"Validation started."
	)

	error_message=$(echo "$RESPONSE" | jq -r 'try .message // empty')
	if [ -n "$error_message" ]; then
		# Check if the error message is in the ignore list
		if printf '%s\n' "${ignore_messages[@]}" | grep -qF "$error_message"; then
			echo "Ignored message code" >/dev/null
		else
			echo "Error: API returned bad response [$error_message]"
			exit 1
		fi
	fi
}

determine_serverinfo_location() {
	if $dev; then
		echo ".serverinfo" # Relative directory for development
	else
		mkdir -p /etc/coolify          # Create location if not exists
		echo "/etc/coolify/serverinfo" # Absolute path for production
	fi
}

get_master_private_key_uuid() {
	response=$(curl --request GET -s \
		--url "https://$URL/api/v1/security/keys" \
		--header "Authorization: Bearer $API_TOKEN")
	check_request "$response"

	echo $response | jq -r '.[] | select((.description | type == "string")
    and select(.description | ascii_downcase | 
    startswith("the private key for the coolify host machine"))) | .uuid'
}

create_server() {
	PRIVATE_KEY_UUID=$1
	HOSTNAME=$(hostname)
	LOCAL_IP=$(ifconfig | grep 'en0' -A 4 | grep 'inet ' | awk '{print $2}')

	if [ "$register_type" == "local" ]; then
		IP="$LOCAL_IP"
	elif [ "$register_type" == "public" ]; then
		IP="$(curl -s ifconfig.me)"
	fi

	response=$(curl --request POST -s --url "https://$URL/api/v1/servers" \
		--header "Authorization: Bearer $API_TOKEN" \
		--header 'Content-Type: application/json' \
		--data "{
          \"name\": \"$HOSTNAME\",
          \"description\": \"$LOCAL_IP - Setup by automated coolify management script\",
          \"ip\": \"$IP\",
          \"port\": 22,
          \"user\": \"root\",
          \"private_key_uuid\": \"$PRIVATE_KEY_UUID\",
          \"is_build_server\": false,
          \"instant_validate\": false
      }")
	check_request "$response"

	dest=$(determine_serverinfo_location)
	echo "$(echo $response | jq -r '.uuid')" >$dest
}

delete_server() {
	UUID=$1

	response=$(curl --request DELETE -s \
		--url "https://$URL/api/v1/servers/$UUID" \
		--header "Authorization: Bearer $API_TOKEN")
	check_request "$response"
}

validate_server() {
	UUID=$1

	response=$(curl --request GET -s \
		--url "https://$URL/api/v1/servers/$UUID/validate" \
		--header "Authorization: Bearer $API_TOKEN")
	check_request "$response"
}

# Initialize variables for options
register=false
register_type=""
deregister=false
other_option=""
validate=false
dev=false
uuid_file=""

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
	case $1 in
	--register)
		# Check if the next argument is provided and is either "local" or "public"
		if [[ -n "$2" && ("$2" == "local" || "$2" == "public") ]]; then
			register=true
			register_type="$2"
			shift
		else
			echo "Error: --register requires an argument 'local' or 'public'."
			exit 1
		fi
		;;
	--deregister)
		deregister=true
		;;
	--validate)
		validate=true
		;;
	--other-option)
		other_option="$2"
		shift
		;;
	--dev)
		dev=true
		;;
	--help | -h)
		echo "Usage: $0 [--register local|public] [--deregister] [--validate] [--other-option value] [--dev]"
		exit 0
		;;
	*)
		echo "Unknown option: $1"
		echo "Use --help or -h for usage information."
		exit 1
		;;
	esac
	shift
done

if $register && $deregister; then
	echo "Error: --register and --deregister cannot be specified at the same time."
	exit 1
fi

if $deregister && $validate; then
	echo "Error: --deregister and --validate cannot be specified at the same time."
	exit 1
fi

if $register; then
	echo "Registering machine..."
	echo "Getting master private key..."
	master_priv_key_uuid=$(get_master_private_key_uuid)
	echo "Got master private key."
	echo "Creating server in coolify..."
	create_server "$master_priv_key_uuid"
	echo "Created server in coolify."
fi

if $deregister; then
	echo "Deregistering server..."
	info=$(determine_serverinfo_location)
	delete_server "$(cat $info)"
	rm $info
	echo "Server deregistered."
fi

if $validate; then
	echo "Validating server..."
	info=$(determine_serverinfo_location)
	validate_server "$(cat $info)"
	echo "Server Validated."
fi
