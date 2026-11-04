#!/bin/bash

# Converts all .pgm files in the same directory as the script
# to .png files, and stores them in the parent directory.
# Requires the 'imagemagick' tool.
#
# WARNING!!!
# This WILL overwrite files in the parent directory if they share the same name

inPath="$(pwd)/*"
for file in $inPath; do
    if [[ $file == *.pgm ]]; then
        filenamePgm=$(echo "$file" | rev | cut -d "/" -f 1 | rev)
        filenamePng=${filenamePgm/%.pgm/.png}
        savePath="$(echo "$file" | rev | cut -d "/" -f 3- | rev)/$filenamePng"
        echo "$savePath"
        magick $file $savePath
    fi
done
