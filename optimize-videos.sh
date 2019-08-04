#!/bin/bash

# James Ussery <James@Ussery.me>
#
# Required programs
# ffmpeg
#
# Usage: sh ./optimize-videos.sh source destination
# "/my/videos/directory" "my/export/directory"

SAVEIFS=$IFS
IFS=$(echo -en "\n\b")

#filesize in MB * 1000000
minmoviesize="800000000"    # min 800MB - Used for larger Movies
mintvsize="200000000"       # min 200MB - Used for TV shows
maxtvsize="400000000"       # max 400MB - Used for TV shows

DateTimeFormat="%Y%m%d_%H%M%S%3N"
DateStamp=$(date +"%Y%m%d")
DateTime=$(date +"%Y%m%d_%H%M%S%3N")
comma=","
apos="'"
underscore="_"
space=" "
dot="."

localUser=$USER

if [ -n $1 ]; then
    source_dir="/home/$localUser/Videos"
    read -e -i "$source_dir" -p "Source Directory: " source_in
    source_dir="${source_in:-$source_dir}"
else
    source_dir=$1
fi

if [ -n $2 ]; then
    export_dir="$source_dir/optimized"
    read -e -i "$export_dir" -p "Export Directory: (N for none) " export_in
    export_dir="${export_in:-$export_dir}"

    case $export_dir in
        [Nn]* ) inplace="Y";;
    esac
else
    export_dir=$2     # move files into export location upon completion (/home/user/Videos/optimized)
fi

echo " "
echo " "
echo "Starting in $source_dir"
if [ $inplace ]; then
    echo "Converted files will be created in place"
    else
    echo "Exporting files to $export_dir"
fi
echo " "
echo " "


# Enable special handling to prevent expansion to a
# literal '/tmp/backup/*' when no matches are found.
shopt -s nullglob

for d in "$start_dir"/*/
do
    cd $d
    echo "pwd: "$d
    optimize_dir="$export_dir/$(basename $d)"           # recreate the same folder structure onto the export location
    echo "export_dir=$optimize_dir"
    mkdir -p $optimize_dir
    for file in *
        do

        if [ -f "$file" ]; then

            MIMETYPE=`file -b --mime-type $file`

            extpos=${#file}-3                           # Position of extension (without dot)
            ext=${file:$extpos:4}                       # Store the extension
            extlc="$(echo $ext | tr '[A-Z]' '[a-z]')"   # echo "File extension: " $ext
            fwoext=${file:0:$extpos}                    # Store filename without extension

            # echo "Processing renaming rules for $file"

            fwoext=${fwoext//$comma/}                   # Remove comma
            fwoext=${fwoext//$apos/}                    # Remove apostrophe
            fwoext=${fwoext//$space/$underscore}        # Replace space with underscore
            #fwoext=${fwoext//$dot/$underscore}         # Replace dot with underscore
            fwoext=${fwoext//../.}                      # Remove double dots
            cleanfile=$fwoext$extlc
            mv "$file" "$cleanfile"

            filesize=$(wc -c "$cleanfile" | awk '{print $1}')

            if [[ $filesize -ge $mintvsize && $filesize -le $maxtvsize ] || [ $filesize -ge $minmoviesize ]]; then

                # Shrink video files and output as mp4
                #echo "compressing $cleanfile"
                #tar -cvzf "$fwoext"tar.gz $cleanfile
                newfile="$optimize_dir/$fwoext""mp4"

                case $MIMETYPE in
                    "video/x-msvideo"|"video/x-ms-asf")

                        ffmpeg -y -i $cleanfile -c:a aac -b:a 128k -c:v libx264 -crf 23 $newfile

                    ;;
                    "video/quicktime"|"video/3gpp"|"video/mpeg"|"video/x-matroska"|"video/mp4")

                        #ffmpeg -y -i $cleanfile -c:v libx264 -crf 30 $newfile
                        ffmpeg -y -i $cleanfile -vf "scale=iw/3:ih/3" -c:a copy -strict -2 $newfile

                    ;;
                esac

                # copy metadata to match
                chmod --reference="$cleanfile" "$newfile"
                chown --reference="$cleanfile" "$newfile"
                touch --reference="$cleanfile" "$newfile"

            fi
        fi
    done
done

shopt -u nullglob       # Unset shell option after use, if desired. Nullglob is unset by default.
IFS=$SAVEIFS            # restore $IFS
