#!/bin/bash
#
# This script launches Mame with the TI-99/4A, the speech synthesizer, and
# the Bad Apple cartridge mounted.

if [[ $1 == "ntsc" ]]; then
  TARGET=ntsc
  SYSTEM=ti99_4a
else
  TARGET=pal
  SYSTEM=ti99_4ae
fi

RPK=out/BadApple_$TARGET.rpk

if [ ! -f $RPK ]
then
  echo "Can't find the cartridge image $RPK"
  echo "Please build it with the build.sh script or download it from"
  echo "  https://github.com/EricLafortune/BadApple/releases/latest"
  exit 1
fi

mame $SYSTEM \
  -nomouse -window -resolution 1024x768 -nounevenstretch \
  -ioport peb \
  -ioport:peb:slot3 speech \
  -cart1 $RPK
