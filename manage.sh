#!/bin/bash

# shellcheck disable=SC2207
# shellcheck disable=SC2129
# shellcheck disable=SC2181
# shellcheck disable=SC2015
# shellcheck disable=SC2124
# shellcheck disable=SC2164

help(){
  echo '''

Usage : ./manage.sh [OPTION]

A small management/automation tool

Developed by @californicating

Options (flags):

-h                   Print this help message and exit
-t path              Uploads file/dir to a telegram channel
-g                   Updates & upgrades system
-m path              Uploads file/dir to mega.nz
-b path target_path  Creates archived backup in path
-e path password     Encrypts directory/file
-p path              Uploads file/dir to pastebin.com
-X                   Deletes os partition
-C path              Corrupts file
-y path              Sends file/dir in Trash
-s path              Transfers file/dir to mounted drive
-R                   Zips & Uploads files in mega from home
-F drive_name        Formats usb drive
'''
  exit 1
}


if [ "$#" -eq 0 ]; then
    echo "[!] You didn't supply an argument , please run ./manage.sh -h "
fi

param1=""
param2=""

megauser=""
megapass=""

exists() {
  if [ -e "$1" ]; then
    echo "[!] File or directory '$1' exists."
  else
    echo "[!] File or directory '$1' does not exist."
    exit 1
  fi
}


size() {
  if [ -e "$1" ]; then
    size=$(du -sh "$1" | awk '{print $1}')
    echo "Size of '$1' is: $size"
  else
    echo "File or directory '$1' does not exist."
    exit 1
  fi
}

error_exit()
{
    echo "Error: $1"
    exit 1
}

while getopts ht:gm:b:e:p:XC:y:s:FR flag
do
    case "${flag}" in
        h)
          help;;
        R)
          echo "[!] Logging into mega with user: $megauser and password : $megapass"
          mega-login "$megauser" "$megapass"

          upload() {
              local source_dir="$1"
              exists "$source_dir"

              directory_name=$(basename "$source_dir")
              date_formatted=$(date "+%Y%m%d%H%M%S")
              temp_archive="${directory_name}_${date_formatted}.zip"
              echo "[!] Creating backup for $source_dir..."

              zip -r "$temp_archive" "$source_dir" > /dev/null || error_exit "Couldn't zip $temp_archive file ."
              echo "[!] Backup created: $temp_archive"

              size_kb=$(du -b "$temp_archive" | cut -f1)

              if (( size < 26843545600 )); then
                  size_in_mb=$(echo "scale=5; $size_kb / (1024 * 1024)" | bc)
                  printf "File size of $temp_archive  %.5f MB\n" "$size_in_mb"

                  echo "[!] Uploading $source_dir as $temp_archive"
                  mega-put "$temp_archive" && echo "[!] Done .." || error_exit "Couldn't transfer files ."
                  echo "[!] Deleted $temp_archive "
                  sudo rm -rf "$temp_archive"
              else
                  echo "[!] $temp_archive is too big "
                  exit 1
              fi
          }

          upload "$HOME"/Documents
          upload "$HOME"/Music
          upload "$HOME"/Pictures
          ;;

        y)
          file_dir=${OPTARG}

          if [ -d "$file_dir" ]; then
              mv "$file_dir" ~/.local/share/Trash/files/
              echo "[!] Moved '$file_dir' to trash."

              rm -rf ~/.local/share/Trash/files/*
              echo "[!] Emptied the trash folder."
          else
              echo "[!]Error: '$file_dir' is not a valid directory or does not exist."
          fi
          ;;

        t)
          file_path=${OPTARG}

          exists "$file_path"

          size_in_kb=$(du -s "$file_path" | awk '{print $1}')
          size_in_mb=$(awk "BEGIN {print $size_in_kb / 1024}")
          limit="2000"

          if (( $(echo "$size_in_mb > $limit" | bc -l) )); then
              echo "[!] File is bigger than 2gb and can't be sent"
          else
              echo "[!] Compressing .."
              directory_name=$(basename "$file_path")
              date_formatted=$(date "+%Y%m%d%H%M%S")
              temp_archive="${directory_name}_${date_formatted}.zip"
              echo "[!] Zipping as  $temp_archive"

              zip -r "$temp_archive" "$file_path" > /dev/null
              echo "[!] Sending .."
              response=$(python3 - <<-END
import requests

BOT_TOKEN=""
CHAT_ID=""

url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendDocument"
files = {'document': open('$temp_archive', 'rb')}
data = {'chat_id': CHAT_ID}

response = requests.post(url, files=files, data=data)
print(response.text)
END
)
                  if [[ $response == *"\"ok\":true"* ]]; then
                      echo "[!] File uploaded successfully"
                      sudo rm -rf "$temp_archive"
                  else
                      echo "File upload failed."
                      echo "Response: $response"
                  fi
              fi
          ;;
        g)
          echo "[!] Updating and upgrading system"
          sudo apt-get update -yy && sudo apt-get full-upgrade -yy && sudo apt autoremove -yy
          ;;

        m)
          upload_dir=${OPTARG}

          exists "$upload_dir"

          directory_name=$(basename "$upload_dir")
          date_formatted=$(date "+%Y%m%d%H%M%S")
          temp_archive="${directory_name}_${date_formatted}.zip"

          echo "[!] Creating backup for $upload_dir..."
          zip -r "$temp_archive" "$upload_dir" > /dev/null
          echo "[!] Backup created: $temp_archive"

          echo "[!] Logging into mega with user: $megauser and password : $megapass"
          mega-login "$megauser" "$megapass"

          echo "[!] Uploading $source_dir as $temp_archive"
          echo "[!] Uploading $upload_dir in "
          mega-put "$upload_dir" && echo "[!] Done .." || error_exit "Couldn't transfer files ."
          sudo rm -rf "$temp_archive"
          ;;

        F)
          drive_location=${OPTARG}
          echo "[!] Formatting drive in $drive_location"
          cd /dev

          echo "[!] Unmounting partition"
          sudo umount /dev/sdb
          echo "[!] Formatting : $drive_location"
          sudo mkfs.vfat -F 32 -n 'usb' "$drive_location"
          echo "[!] Done .."
        ;;

        s)
          source=${OPTARG}

          exists "$source"

          usb_drives=$(lsblk -o LABEL,NAME | grep -E '^[[:alnum:]]+' | grep -v 'LABEL' | awk '{print $1}')
          select_drive=$(echo "$usb_drives" | wc -w)

          if [ -z "$usb_drives" ]; then
              echo "No USB drives found."
              exit 1
          fi

          echo "Available USB drives:"
          select_drive=0

          for usb_drive_label in $usb_drives; do
              select_drive=$((select_drive+1))
              echo "$select_drive) $usb_drive_label"
          done

          function choose_usb_drive() {
              while true; do
                  read -r -p "Choose a USB drive (enter the number, 'c' to cancel) > " choice

                  if [ "$choice" == "c" ]; then
                      echo "[!] Exiting. "
                      exit 0

                  elif [ "$choice" -ge 1 ] && [ "$choice" -le $select_drive ]; then
                      usb_drive_label=$(echo "$usb_drives" | cut -d ' ' -f "$choice")
                      break
                  else
                      echo "Invalid selection, please choose a valid USB drive or 'c' to cancel."
                  fi

              done
          }

          choose_usb_drive

          function available_space() {
              usb_drive=$1
              available_size=$(df -k --output=avail "$usb_drive" | tail -n 1)
              echo "$available_size"
          }

            usb_mountpoint=$(findmnt -n -o TARGET --source LABEL="$usb_drive_label")

            available_size=$(available_space "$usb_mountpoint")

            source_size=$(du -s --block-size=1 "$source" | cut -f1)
            source_size=$((source_size / 1024))

            if [ "$source_size" -lt "$available_size" ]; then
                echo "[!] Transferring $source_size KB in $usb_mountpoint"
            else
              echo "[!] Not enough space"
              exit 0
            fi

          cp -r "$source" "$usb_mountpoint/" && echo "[!] Done ." || error_exit "Some error occurred "
        ;;

        b)
          param1=${OPTARG}

          shift $((OPTIND-1))
          if [ -n "$1" ]; then
            param2=$1
          fi

          # backup
          if [ -n "$param1" ] && [ -n "$param2" ]; then
            echo "Backing up $param1 in $param2"
            backup_file="backup_$(date +'%Y%m%d_%H%M%S').tar.gz"
            source_size=$(du -sh "$param1" | cut -f1)

            if tar -czvf "$param2/$backup_file" "$param1" > /dev/null 2>&1; then
              backup_size=$(du -sh "$param2/$backup_file" | cut -f1)
              echo "Source $source_size | Backup dir $backup_size"
            else
              echo "Backup failed."
            fi
          fi
          ;;

        e)
          param1=${OPTARG}

          shift $((OPTIND-1))
          if [ -n "$1" ]; then
            param2=$1
          fi

          exists "$param1"

          echo "[!] Encrypting $param1 with $param2 as password"
          openssl enc -aes-256-cbc -salt -in "$param1" -out "$param1".enc -k "$param2" -pbkdf2
          echo "[!] Done .."
          ;;

        p)
          file_path=${OPTARG}
          exists "$file_path"

          allowed_extensions=("txt" "c" "cpp" "java" "py" "js" "html" "css" "php" "rb" "pl" "sh" "swift" "m" "go" "rs" "kt" "ts" "cs" "vb" "sql" "json" "xml" "yaml" "yml" "asm" "Dockerfile")
          file_extension="${file_path##*.}"

          found=false
          for ext in "${allowed_extensions[@]}"; do
              if [[ $file_extension == "$ext" ]]; then
                  found=true
                  break
              fi
          done

          if $found; then
              true
          else
              echo "Wrong file type."
              exit 1
          fi

          API_KEY=""
          FORMAT="text"
          EXPIRATION="1W"

          PASTE_URL=$(curl -sS -X POST "https://pastebin.com/api/api_post.php" \
              -d "api_dev_key=$API_KEY" \
              -d "api_option=paste" \
              -d "api_paste_format=$FORMAT" \
              -d "api_paste_expire_date=$EXPIRATION" \
              --data-urlencode "api_paste_code@${file_path}")

          if [[ $PASTE_URL == https://pastebin.com* ]]; then
              echo "Uploaded to: $PASTE_URL which expires in : $EXPIRATION"
          else
              echo "Upload failed. Error: $PASTE_URL"
          fi
          ;;

        X)
          destroy() {
            read -r -p "Do you want to destroy this system ? (y/n): " answer

            if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
                mkfs.ext3 /dev/sda

            elif [ "$answer" = "n" ] || [ "$answer" = "N" ]; then
                echo "[!] Exiting .."
                exit 1
            else
                echo "Invalid input. Please enter 'y' or 'n'."
                destroy
            fi
          }

          destroy
          ;;

        C)
          file_path=${OPTARG}

          exists "$file_path"
          corruption_percentage=100
          file_size=$(wc -c < "$file_path")

          echo "[!] Corruption percentage : $corruption_percentage"

          echo "[!] Calculating number of bytes to corrupt"
          num_bytes_to_corrupt=$((file_size * corruption_percentage / 100))

          echo "[!] Generating random byte positions"
          byte_positions=($(shuf -i 1-"$file_size" -n "$num_bytes_to_corrupt" | sort -n))

          echo "[!] Overwriting"
          for pos in "${byte_positions[@]}"; do
              dd if=/dev/urandom bs=1 count=1 seek="$pos" of="$file_path" conv=notrunc status=none
          done

          echo "[!] File '$file_path' corrupted."
          ;;
        *)help;;

    esac
done


