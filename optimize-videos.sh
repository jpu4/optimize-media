#!/bin/bash

# James Ussery <James@Ussery.me>
#
# Required programs
# ffmpeg
#
# Usage: sh ./optimize-videos.sh source destination
# "/my/videos/directory" "my/export/directory"

debug=

if [ $debug ]; then
    clear
    echo "DEBUG ENABLED"
fi

SAVEIFS=$IFS
IFS=$(echo -en "\n\b")
COUNTER=1

minmoviesize="800000000"    # min 800MB - Used for larger Movies
mintvsize="300000000"       # min 300MB - Used for TV shows
maxtvsize="458892810"       # max 450MB - Used for TV shows

DateTimeFormat="%Y%m%d_%H%M%S%3N"
DateStamp=$(date +"%Y%m%d")
DateTime=$(date +"%Y%m%d_%H%M%S%3N")
comma="," ; apos="'" ; underscore="_" ; space=" " ; dot="."

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
    export_dir=$2
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

function processfile(){

    echo "FILE: " $file
    humanfilesize=$(du -h "$file" | awk '{print $1}')
    echo "FILESIZE: " $humanfilesize

    originalfile=$file

    MIMETYPE=`file -b --mime-type $originalfile`

    extpos=${#originalfile}-3                   # Position of extension (without dot)
    ext=${originalfile:$extpos:4}               # Store the extension
    extlc="$(echo $ext | tr '[A-Z]' '[a-z]')"   # Setting Extension to lowercase
    fwoext=${originalfile:0:$extpos}            # Store filename without extension

    # Rules for cleaning the filename
    fwoext=${fwoext//$comma/}                   # Remove comma
    fwoext=${fwoext//$apos/}                    # Remove apostrophe
    fwoext=${fwoext//$space/$underscore}        # Replace space with underscore
    fwoext=${fwoext//../.}                      # Remove double dots
    cleanfile=$fwoext$extlc

    dogearfile=${file/"."$extlc/"-optimized.txt"}

    if [ ! -f $dogearfile ]; then

        if [ "$cleanfile" != "$originalfile" ]; then
            if [ $debug ]; then
                echo "mv $originalfile $cleanfile"
            else
                mv "$originalfile" "$cleanfile"
            fi
        fi

        if [ $inplace ]; then
            echo "EXTENSION: $extlc"
            newfile="${cleanfile%/*}/$fwoext""mp4"
            newfile="$fwoext""mp4"
            if [[ $extlc == "mp4" ]]; then
                #rename mp4 file to old
                oldfile=${fwoext//$dot/"-old.$extlc"}
                if [ $debug ]; then
                    echo "mv $cleanfile $oldfile"
                else
                    mv "$cleanfile" "$oldfile"
                fi
                cleanfile=$oldfile
                echo "RENAMED TO: $cleanfile"
            fi
            echo "NEWFILE: $newfile"
        else
            newfile=${cleanfile/$source_dir/$export_dir}
            optimized_dir=${newfile%/*}
            mkdir -p $optimized_dir
            newfile="$optimized_dir/$(basename $fwoext)""mp4"
            echo "NEWFILE: $newfile"
        fi

        case $MIMETYPE in
            "video/x-msvideo"|"video/x-ms-asf")

                # ffmpeg -y -i $cleanfile -c:a aac -b:a 128k -c:v libx264 -crf 23 $newfile     # changed 20190805 JU produced no sound
                if [ $debug ]; then
                    echo "ffmpeg -y -i $cleanfile -c:a aac -b:a 128k -c:v libfdk_aac -crf 23 $newfile"
                else
                    ffmpeg -y -i $cleanfile -c:v libx264 -crf 19 -preset slow -c:a aac -b:a 192k -ac 2 $newfile

                fi

            ;;
            "video/quicktime"|"video/3gpp"|"video/mpeg"|"video/x-matroska"|"video/mp4")

                #ffmpeg -y -i $cleanfile -c:v libx264 -crf 30 $newfile
                if [ $debug ]; then
                    echo "ffmpeg -y -i $cleanfile -vf "scale=iw/3:ih/3" -c:a copy -strict -2 $newfile"
                else
                    ffmpeg -y -i $cleanfile -vf "scale=iw/3:ih/3" -c:a copy -strict -2 $newfile
                fi

            ;;
        esac

        # copy metadata to match
        chmod --reference="$cleanfile" "$newfile"
        chown --reference="$cleanfile" "$newfile"
        touch --reference="$cleanfile" "$newfile"

        echo "Files Processed: "$COUNTER
        COUNTER=$((COUNTER + 1))

        newfilesize=$(du -h "$newfile" | awk '{print $1}')

        dogearfile=${cleanfile/"."$extlc/"-optimized.txt"}
        echo "FILE PROCESSED: $(basename $cleanfile)" >> $dogearfile
        echo "BATCH NUMBER: $COUNTER" >> $dogearfile
        echo "DATE PROCESSED: $DateStamp" >> $dogearfile
        echo "ORIGINAL FILESIZE: $humanfilesize" >> $dogearfile
        if [ $oldfile ]; then
            echo "NEW FILENAME AFTER CONVERSION: $newfile" >> $dogearfile
        fi
        echo "NEW FILE: $newfile" >> $dogearfile
        echo "NEW FILESIZE: $newfilesize" >> $dogearfile
        echo "DOGEARFILE: " $dogearfile
    else
        echo "Skipping $(basename $file), already processed"
    fi
}

shopt -s nullglob
shopt -s dotglob # allow for dotfolders

find $source_dir -type f \( -iname \*.mp4 -o -iname \*.mkv -o -iname \*.avi -o -iname \*.mov -o -iname \*.mpg \) -print0 | while IFS= read -r -d '' file; do

    filesize=$(wc -c "$file" | awk '{print $1}')

    # MOVIE LOOP
    if [[ $filesize -ge $minmoviesize ]] ; then
            echo "TYPE: MOVIE or LARGE TV EPISODE"
            processfile
            echo ""
    else
        # TV LOOP
        if [[ $filesize -ge $mintvsize ]] && [[ $filesize -le $maxtvsize ]] ; then
                echo "TYPE: TV"
                processfile
                echo ""
        fi
    fi
done

#shopt -u nullglob       # Unset shell option after use, if desired. Nullglob is unset by default.
IFS=$SAVEIFS            # restore $IFS
