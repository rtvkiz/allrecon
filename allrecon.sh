#!/bin/bash

# Define variables
source_dir="output"
directory="output/$1"
dir_host="$directory/dir"

# Clean up the source directory
if [ -d "$source_dir" ]; then
    rm -r "$source_dir"/*
fi

# Remove old hosts.txt if it exists
if test -f "$directory/hosts.txt"; then
    rm "$directory/hosts.txt"
fi

# Remove the directory if it exists
if [ -d "$directory/dir" ]; then
    rm -r "$directory/dir"
fi

# Run Subfinder to find subdomains and save them to hosts.txt
subfinder -d "$1" -o "$directory/hosts.txt"
mkdir -p "$directory/dir"

# Function to check if a command is available in PATH
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if dirsearch and subfinder are available
if ! command_exists "dirsearch"; then
    echo "Error: 'dirsearch' is not found in your PATH. Please install it or add it to your PATH."
    exit 1
fi

if ! command_exists "subfinder"; then
    echo "Error: 'subfinder' is not found in your PATH. Please install it or add it to your PATH."
    exit 1
fi

# Loop through each host in hosts.txt
while IFS= read -r host
do
    # Check if the line is not empty
    if [ -n "$host" ]; then
        # Execute dirsearch for the current host
        dirsearch -u "$host" -o "$dir_host/${host}.txt"
    fi
done < "$directory/hosts.txt"

# Check if the "final.txt" file exists in the specified directory
if test -f "$directory/final.txt"; then
    # If it exists, remove the file
    rm "$directory/final.txt"
fi

# Initialize an empty "final.txt" file
final_file="$directory/final.txt"
> "$final_file"

# Iterate through each file in the source directory
for file in "$dir_host"/*
do
    # Check if the file exists and is a regular file
    if [ -f "$file" ]; then

        # Remove the first two lines from the file
        sed -i '1,2d' "$file"
        
        # Loop through each line in the file
        while IFS= read -r line
        do
            # Read the first 3 characters (HTTP status) from the line
            http_status=$(echo "$line" | awk '{print $1}')

            # Check if the HTTP status is "200"
            if [ "$http_status" = "200" ]; then
                # Extract the third column as content
                content=$(echo "$line" | awk '{print $3}')

                # Append the content to the "final.txt" file
                echo "$content" >> "$final_file"
            fi
        done < "$file"
    fi
done

echo "Web reconnaissance completed. Results saved to $final_file"
