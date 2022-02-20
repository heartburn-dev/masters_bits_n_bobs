<?php
// Curl command to upload a file
// curl -v -F "fileToUpload=@/tmp/systemd.timer.png" -F "submit=Upload Image" http://localhost/upload.php

// Code adapted from:
// https://www.w3schools.com/php/php_file_upload.asp

$target_dir = "voulezvousmyguycomehere/";
$target_file = $target_dir . basename($_FILES["fileToUpload"]["name"]);
$uploadOk = 1;
$imageFileType = strtolower(pathinfo($target_file,PATHINFO_EXTENSION));

// Check if image file is a actual image or fake image
if(isset($_POST["submit"])) {
  $check = getimagesize($_FILES["fileToUpload"]["tmp_name"]);
  if($check !== false) {
    $uploadOk = 1;
  } else {
    $uploadOk = 0;
  }
}

// Check if file already exists
if (file_exists($target_file)) {
  $uploadOk = 0;
}

// Check file size
if ($_FILES["fileToUpload"]["size"] > 500000) {
  $uploadOk = 0;
}

// Allow certain file formats
if($imageFileType != "png") {
  $uploadOk = 0;
}

// Check if $uploadOk is set to 0 by an error
if ($uploadOk == 0) {
} else {
  if (move_uploaded_file($_FILES["fileToUpload"]["tmp_name"], $target_file)) {
    #echo "The file ". htmlspecialchars( basename( $_FILES["fileToUpload"]["name"])). " has been uploaded.";
  } else {
    #echo "Sorry, there was an error uploading your file.";
  }
}

// Allow a way to delete the file when it's been read
if(isset($_POST["delete"])) {
  system("rm /var/www/html/voulezvousmyguycomehere/*");
}

?>
