#!/bin/bash
#
# Create a title animation for the Bad Apple demo,
# using ImageMagick scripts.

ZIP=${1:-data/titles.zip}
DIR=${ZIP%.zip}
FRAME=$DIR/000.pbm

mkdir -p $DIR

convert \
  -size 256x192 \
  xc:black \
  -fill white \
  -draw 'gravity Center font-size 50 text 0,-20 "Bad Apple"' \
  -draw 'gravity Center font-size 33 text 0,30 "on the TI-99/4A"' \
  -draw 'gravity Center font-size 20 text 0,60 "Version 2.0"' \
  +dither \
  $FRAME

seq 1 124 | while read N
do
  NEW_FRAME=$(printf "$DIR/%03.0f.pbm" $N)
  echo "Creating $NEW_FRAME ..."

  convert \
    -interpolate nearest-neighbor \
    -virtual-pixel black \
    -fx "
      pp = rand() < 0.4+$N/400. ? 0 : p[1-2*rand(),-1-2*rand()];
      j < 150-$N ? p[0,0] : pp" \
    +dither \
    $FRAME \
    $NEW_FRAME

  FRAME=$NEW_FRAME
done

rm -f "$ZIP"

zip -q -j "$ZIP" $DIR/*.pbm

rm -f $DIR/*.pbm
rmdir $DIR
