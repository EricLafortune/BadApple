#!/bin/bash

cd $(dirname "$0")

if ! type -t java > /dev/null; then
  echo 'You still need to to install java:'
  echo '  sudo apt install openjdk-17-jdk'
  EXIT=1
fi

if ! type -t convert > /dev/null; then
  echo 'You still need to to install ImageMagick:'
  echo '  sudo apt install imagemagick'
  EXIT=1
fi

if ! type -t ffmpeg > /dev/null; then
  echo 'You still need to to install ffmpeg:'
  echo '  sudo apt install ffmpeg'
  EXIT=1
fi

if ! type -t praat > /dev/null; then
  echo 'You still need to to install praat:'
  echo '  sudo apt install praat'
  EXIT=1
fi

if [[ ! -f videotools.jar ]]; then
  echo 'You still need to to download the video tools jar:'
  echo '  https://github.com/EricLafortune/VideoTools/releases/latest'
  echo 'as videotools.jar'
  EXIT=1
fi

if ! type -t xas99.py > /dev/null; then
  echo 'You still need to to set up xdt99:'
  echo '  https://github.com/endlos99/xdt99'
  EXIT=1
fi

if [[ ! -f data/BadApple.webm ]]; then
  echo 'You still need to to download the Bad Apple video:'
  echo '  https://www.youtube.com/watch?v=G3C-VevI36s'
  echo 'as data/BadApple.webm'
  EXIT=1
fi

if [[ ! -f data/BadAppleMusic.vgm ]]; then
  echo 'You still need to to download the Bad Apple chiptune:'
  echo '  https://github.com/bitshifters/bad-apple/blob/master/data/music.vgm?raw=true'
  echo 'as data/BadAppleMusic.vgm'
  EXIT=1
fi

if [[ ! -f data/BadAppleVocals.wav ]]; then
  echo 'You still need to to download the Bad Apple vocals:'
  echo '  https://mega.nz/file/POpWDYCB#7mFaV6jeYKtcEG_rfZVc4UG7bv0rYwQpbWE4viNJdYg'
  echo 'as data/BadAppleVocals.wav'
  EXIT=1
fi

if [[ -v EXIT ]]; then
  exit 1
fi

export CLASSPATH=videotools.jar

###############################################################################
# Animation.
###############################################################################

./createtitles.sh
./createcredits.sh
./createpostcredits.sh

ffmpeg -i data/BadApple.webm \
  -y \
  -s 256x192 \
  -r 25 \
  -t 218 \
  data/BadApple_small_25fps.mp4

mkdir -p data/animation

# Careful: extracting PBM frames without any processing introduces
# spurious noise (in 3.4.8-0ubuntu0.2).
ffmpeg -i data/BadApple_small_25fps.mp4 \
  -y \
  -f lavfi -i color=gray:s=256x192 \
  -f lavfi -i color=black:s=256x192 \
  -f lavfi -i color=white:s=256x192 \
  -lavfi threshold \
  data/animation/%04d.pbm

zip -q --junk-paths data/animation.zip \
  data/animation/*.pbm

rm -r data/animation

# Video:
#   dur:   218.005 s = 5450 frames (25 fps)
# Music:
#   start:   1.315 s =   33        ->   66 (50 fps)
#   end:   217.010 s = 5425
#   dur:   215.695 s = 5392 frames
# Vocals:
# Part 1:
#   start:  29.100 s =  727        -> 1454
#   end:   111.715 s = 2793
#   dur:    82.615 s = 2066 frames
# Part 2:
#   start: 126.630 s = 3166        -> 6332
#   end:   209.725 s = 5243
#   dur:    83.095 s = 2077 frames

###############################################################################
# Music.
###############################################################################

# Stretch the music to a speed that matches the animation.
java ConvertVgmToSnd 813 \
   data/BadAppleMusic.vgm \
   data/music.snd

java SimplifySndFile \
  -addsilencecommands \
  data/music.snd \
  data/music_simplified.snd

###############################################################################
# Vocals.
###############################################################################

# Vocals sound file:
# Part 1:
#   start:  56.810 s
#   end:   140.475 s
#   dur:    83.665 s
# Part 2a:
#   start: 167.900 s
#   end:   223.485 s
#   dur:    55.585 s
# Part 2b:
#   start: 278.965 s
#   end:   308.255 s
#   dur:    28.790 s
# Part 2:
#   dur:    84.900 s
# Added approximately 75ms to all silent ends, for the LPC analysis.

# Extract the vocals. Notably, trim the additional stanzas from the second part
# to get a version matching the animation.
ffmpeg -i data/BadAppleVocals.wav \
  -y \
  -map_channel -1 \
  -map_channel 0.0.1 \
  -ac 1 \
  -ss 56.810 -t 83.665 \
  data/vocals_part1.wav \
  -ss 167.900 -t 55.585 \
  data/vocals_part2a.wav \
  -ss 278.965 -t 28.790 \
  data/vocals_part2b.wav

ffmpeg -y -f concat -safe 0 -i <(
  echo file $PWD/data/vocals_part2a.wav
  echo file $PWD/data/vocals_part2b.wav) \
  -c copy \
  data/vocals_part2.wav

# We initially used python_wizard.
#python_wizard \
#  --tablesVariant tms5200 \
#  --preEmphasis \
#  --pitchRange 250,550 \
#  --unvoicedThreshold 0.4 \
#  --outputFormat hex \
#  data/vocals_part1_8000Hz.wav \
#| xxd -ps -r \
#> data/vocals_part1.lpc

# Use Praat to compute the LPC speech coefficients.
praat --run lpc.praat \
  $PWD/data/vocals_part1.wav \
  $PWD/data/vocals_part1.Pitch \
  $PWD/data/vocals_part1.LPC \
  250 550 0.02 0.40 0.20 0.20 0.03

praat --run lpc.praat \
  $PWD/data/vocals_part2.wav \
  $PWD/data/vocals_part2.Pitch \
  $PWD/data/vocals_part2.LPC \
  250 550 0.02 0.40 0.20 0.20 0.03

# Convert the Praat files to our own LPC files.
# Careful: these file names are case-sensitive.
java ConvertPraatToLpc \
  -addstopframe \
  data/vocals_part1.Pitch \
  data/vocals_part1.LPC \
  0.4 0.6 \
  data/vocals_part1.lpc

java ConvertPraatToLpc \
  -addstopframe \
  data/vocals_part2.Pitch \
  data/vocals_part2.LPC \
  0.3 0.5 \
  data/vocals_part2.lpc

# Trim the silences of these particular speech files.
java CutLpcFile \
  -addstopframe \
  data/vocals_part1.lpc \
  1 3325 \
  data/vocals_part1_trimmed.lpc

java CutLpcFile \
  -addstopframe \
  data/vocals_part2.lpc \
  4 3357 \
  data/vocals_part2_trimmed.lpc

# The computed vocals are still out of tune. Tune them to the music.
# Pick a lower pitch that works better for the speech synthesizer.
java TuneLpcFile \
  data/vocals_part1_trimmed.lpc \
  data/music_simplified.snd,$[1454-66] \
  0.5 300 535 \
  data/vocals_part1_tuned.lpc

java TuneLpcFile \
  data/vocals_part2_trimmed.lpc \
  data/music_simplified.snd,$[6332-66] \
  0.5 300 535 \
  data/vocals_part2_tuned.lpc

###############################################################################
# Postcredit vocals.
###############################################################################

java ConvertTextToLpc \
  data/TI_HomeComputer.txt \
  data/TI_HomeComputer.lpc

java TuneLpcFile \
  data/TI_HomeComputer.lpc \
  data/music_simplified.snd,$[6332-66] \
  0.125 60 250 \
  data/TI_HomeComputer_tuned.lpc

###############################################################################
# Combine animation, music, and vocals in a complete video.
###############################################################################

# The lengths of the sections, expressed in frames (at 50 Hz).
TITLES=$[125*2]
ANIMATION=$[5450*2]
CREDITS=$[300*2]
POSTCREDITS=$[64*2]

# Account for the speech buffering delay.
java ComposeVideo -50Hz \
  $[0                                   ]:data/titles.zip \
  $[TITLES                              ]:data/animation.zip \
  $[TITLES+66                           ]:data/music_simplified.snd \
  $[TITLES+1454-10                      ]:data/vocals_part1_tuned.lpc \
  $[TITLES+6332-5                       ]:data/vocals_part2_tuned.lpc \
  $[TITLES+ANIMATION                    ]:data/credits.zip \
  $[TITLES+ANIMATION+CREDITS            ]:data/postcredits.zip \
  $[TITLES+ANIMATION+CREDITS+POSTCREDITS]:data/TI_HomeComputer_tuned.lpc \
  data/video.tms

###############################################################################
# Assemble the player and the video in an RPK cartridge file for Mame.
###############################################################################

mkdir -p out
xas99.py --register-symbols --binary \
  --output out/romc.bin \
  src/player.asm

rm -f out/BadApple.rpk

zip -q --junk-paths \
  out/BadApple.rpk \
  layout.xml \
  out/romc.bin

