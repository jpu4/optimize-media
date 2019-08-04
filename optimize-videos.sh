#!/bin/bash

# James Ussery <James@Ussery.me>
#
# Required programs
# ffmpeg
#
# Usage: sh ./optimize-videos.sh source destination
# "/my/videos/directory" "my/export/directory"
# TODO: exclude export_dir from processing

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
shopt -s dotglob # allow for dotfolders

cd $source_dir
find $source_dir/* -type d | while read -r d
do
    if [ "$d" != "$export_dir" ]; then
        find $d/* -type f -mindepth 1 -maxdepth 1 | while read -r f
        do
            originalfile=$f

            MIMETYPE=`file -b --mime-type $originalfile`

            extpos=${#originalfile}-3                   # Position of extension (without dot)
            ext=${originalfile:$extpos:4}               # Store the extension
            extlc="$(echo $ext | tr '[A-Z]' '[a-z]')"   # Setting Extension to lowercase
            fwoext=${originalfile:0:$extpos}            # Store filename without extension

            # Rules for cleaning the filename
            fwoext=${fwoext//$comma/}                   # Remove comma
            fwoext=${fwoext//$apos/}                    # Remove apostrophe
            fwoext=${fwoext//$space/$underscore}        # Replace space with underscore
            #fwoext=${fwoext//$dot/$underscore}         # Replace dot with underscore
            fwoext=${fwoext//../.}                      # Remove double dots
            cleanfile=$fwoext$extlc
            mv "$originalfile" "$cleanfile"

            filesize=$(wc -c "$cleanfile" | awk '{print $1}')

            if [[ $filesize -ge $mintvsize && $filesize -le $maxtvsize ] || [ $filesize -ge $minmoviesize ]]; then

                if [ $inplace ]; then
                    cd ${cleanfile%/*}
                    tar --remove-files -czvf $(basename $f).tar.gz $(basename $f)
                    newfile="${cleanfile%/*}/$fwoext""mp4"
                    echo $newfile
                else
                    newfile=${f/$source_dir/$export_dir}
                    optimized_dir=${newfile%/*}
                    mkdir -p $optimized_dir
                    newfile="$optimized_dir/$fwoext""mp4"
                fi

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
        done
    fi
done

shopt -u dotglob
shopt -u nullglob       # Unset shell option after use, if desired. Nullglob is unset by default.
IFS=$SAVEIFS            # restore $IFS
