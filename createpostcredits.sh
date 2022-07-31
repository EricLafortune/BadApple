#!/bin/bash
#
# Create a postcredits animation for the Bad Apple demo,
# using ImageMagick scripts.

DIR=data/postcredits
FRAME=data/postcredits.png
ZIP=$DIR.zip

mkdir -p $DIR

seq 0 63 | while read N
do
  NEW_FRAME=$(printf "$DIR/%03.0f.png" $N)
  echo "Creating $NEW_FRAME ..."

  convert \
    -fx "126-2*$N <= i && i <= 129+2*$N ? p[0,0] : 0" \
    $FRAME \
    $NEW_FRAME
done

rm -f "$ZIP"

zip -q -j "$ZIP" $DIR/*.png

rm -f $DIR/*.pbm
