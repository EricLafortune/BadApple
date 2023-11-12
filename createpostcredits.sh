#!/bin/bash
#
# Create a postcredits animation for the Bad Apple demo,
# using ImageMagick scripts.

ZIP=${1:-data/postcredits.zip}
DIR=${ZIP%.zip}
FRAME=$DIR.png

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
rmdir $DIR
