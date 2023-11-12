#!/bin/bash
#
# Create a credits animation for the Bad Apple demo,
# using ImageMagick scripts.

ZIP=${1:-data/credits.zip}
DIR=${ZIP%.zip}
FRAME=$DIR/099.pbm

mkdir -p $DIR

convert \
  -size 256x192 \
  xc:black \
  -fill white \
  -draw 'font-size 16
    text 0,24  "Demo for TI-99/4A .... Eric Lafortune"
    text 0,56  "Animation ............... Anira and others"
    text 0,88  "Music ............. Team Shanghai Alice"
    text 0,120 "Vocals .................................... Nomico"
    text 0,152 "Remix .......... Masayoshi Minoshima"
    text 0,184 "Chiptune ................... Inverse Phase"' \
  +dither \
  $FRAME

seq 0 98 | while read N
do
  NEW_FRAME=$(printf "$DIR/%03.0f.pbm" $N)
  echo "Creating $NEW_FRAME ..."

  convert \
    -interpolate nearest-neighbor \
    -virtual-pixel black \
    -fx "
      dx = i - 128;
      j + dx*dx/1300 < 2.5*$N ? p[0,0] : 0" \
    +dither \
    $FRAME \
    $NEW_FRAME
done

seq 0 199 | while read N
do
  NEW_FRAME=$(printf "$DIR/%03.0f.pbm" $[N+100])
  echo "Creating $NEW_FRAME ..."

  convert \
    -interpolate nearest-neighbor \
    -virtual-pixel black \
    -fx "
      pp = rand() < 0.4+$N/550 ? 0 : p[1-2*rand(),-1-2*rand()];
      j < 192-$N ? p[0,0] : pp" \
    +dither \
    $FRAME \
    $NEW_FRAME

  FRAME=$NEW_FRAME
done

rm -f "$ZIP"

zip -q -j "$ZIP" $DIR/*.pbm

rm -f $DIR/*.pbm
rmdir $DIR
