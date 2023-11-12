#!/bin/bash
#
# Build script for the Bad Apple demo for the TI-99/4A.
#
# Usage:
#   build.sh [pal|ntsc]

cd $(dirname "$0")

if ! type -t java > /dev/null; then
  echo 'You still need to install java:'
  echo '  sudo apt install openjdk-17-jdk'
  EXIT=1
fi

if ! type -t convert > /dev/null; then
  echo 'You still need to install ImageMagick:'
  echo '  sudo apt install imagemagick'
  EXIT=1
fi

if ! type -t ffmpeg > /dev/null; then
  echo 'You still need to install ffmpeg:'
  echo '  sudo apt install ffmpeg'
  EXIT=1
fi

if ! type -t sox > /dev/null; then
  echo 'You still need to install sox'
  echo '  sudo apt install sox'
  EXIT=1
fi

if [[ ! -f videotools.jar ]]; then
  echo 'You still need to download the video tools jar:'
  echo '  https://github.com/EricLafortune/VideoTools/releases/latest'
  echo 'as videotools.jar'
  EXIT=1
fi

if ! type -t xas99.py > /dev/null; then
  echo 'You still need to set up xdt99:'
  echo '  https://github.com/endlos99/xdt99'
  EXIT=1
fi

if [[ ! -f data/BadApple.webm ]]; then
  echo 'You still need to download the Bad Apple video:'
  echo '  https://www.youtube.com/watch?v=G3C-VevI36s'
  echo 'as data/BadApple.webm'
  EXIT=1
fi

if [[ ! -f data/BadAppleMusic.vgm ]]; then
  echo 'You still need to download the Bad Apple chiptune:'
  echo '  https://github.com/bitshifters/bad-apple/blob/master/data/music.vgm?raw=true'
  echo 'as data/BadAppleMusic.vgm'
  EXIT=1
fi

if [[ ! -f data/BadAppleVocals.wav ]]; then
  echo 'You still need to download the Bad Apple vocals:'
  echo '  https://mega.nz/file/POpWDYCB#7mFaV6jeYKtcEG_rfZVc4UG7bv0rYwQpbWE4viNJdYg'
  echo 'as data/BadAppleVocals.wav'
  EXIT=1
fi

if [[ -v EXIT ]]; then
  exit 1
fi

if [[ $1 == "ntsc" ]]; then
  TARGET=ntsc
  VIDEO_FPS=59.922738
else
  TARGET=pal
  VIDEO_FPS=50.158969
fi

export CLASSPATH=videotools.jar

# A function to evaluate mathematical expressions in floating point.
function calc {
  bc <<< "scale=4; $*"
}

# A function to evaluate mathematical expressions in floating point,
# and return the result rounded to the nearest integer (non-negative).
function calci {
  bc <<< "scale=4; x=$* + 0.4999; scale=0; x / 1"
}

ANIMATION_FPS=$(calc "$VIDEO_FPS / 2")
SOUND_FPS=$VIDEO_FPS
SPEECH_FPS=40

ANIMATION_MP4=data/BadApple_small_$TARGET.mp4
ANIMATION_ZIP=data/BadApple_small_$TARGET.zip

TITLES_ZIP=data/titles.zip
CREDITS_ZIP=data/credits.zip
POSTCREDITS_ZIP=data/postcredits.zip

MUSIC_SND=data/music_simplified_$TARGET.snd

BAD_APPLE_RPK=out/BadApple_$TARGET.rpk

###############################################################################
# Animation.
###############################################################################

./createtitles.sh      $TITLES_ZIP
./createcredits.sh     $CREDITS_ZIP
./createpostcredits.sh $POSTCREDITS_ZIP

ffmpeg -i data/BadApple.webm \
  -y \
  -s 256x192 \
  -r $ANIMATION_FPS \
  -t 218 \
  $ANIMATION_MP4

mkdir -p data/animation

# Careful: extracting PBM frames without any processing introduces
# spurious noise (with ffmpeg 3.4.8-0ubuntu0.2).
ffmpeg -i $ANIMATION_MP4 \
  -y \
  -f lavfi -i color=gray:s=256x192 \
  -f lavfi -i color=black:s=256x192 \
  -f lavfi -i color=white:s=256x192 \
  -lavfi threshold \
  data/animation/%04d.pbm

zip -q --junk-paths $ANIMATION_ZIP \
  data/animation/*.pbm

rm -r data/animation

# Video:
#   dur:   218.005 s
# Music:
#   start:   1.315 s
#   end:   217.010 s
#   dur:   215.695 s
# Vocals:
# Part 1:
#   start:  29.100 s
#   end:   111.715 s
#   dur:    82.615 s
# Part 2:
#   start: 126.630 s
#   end:   209.725 s
#   dur:    83.095 s

###############################################################################
# Music.
###############################################################################

# Stretch the music to a speed that matches the animation.
java ConvertVgmToSnd $(calci "813 * 50 / $SOUND_FPS") \
   data/BadAppleMusic.vgm \
   data/music.snd

java SimplifySndFile \
  -addsilencecommands \
  data/music.snd \
  $MUSIC_SND

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
sox data/BadAppleVocals.wav \
  data/vocals_part1.wav \
  trim  =56.810 +83.665 \
  channels 1 \
  rate 8000

sox data/BadAppleVocals.wav \
  data/vocals_part2.wav \
  trim =167.900 +55.585 \
       =278.965 +28.790 \
  channels 1 \
  rate 8000

# We've tried to reduce the echo/reverb/overdub in the vocals, but the
# subsequent LPC computation doesn't work well on the result.
# In Audacity:
#   Effect -> Noise reduction... -> 20, 2, 3, Reduce, OK
#   Effect -> Amplify... -> OK
#   Tracks -> Resample... -> 8000, OK
#   Project rate: 8000
#   File -> Export -> Export as WAV -> OK -> Yes -> OK

# Compute the LPC speech coefficients.

# We initially used python_wizard.
# We then used Praat, with ConvertPraatToLpc from our own VideoTools.
# We now use ConvertWavToLpc from VideoTools.

java ConvertWavToLpc \
  -amplification 1 \
  -lpcwindowsize 400 \
  -frameoversampling 4 \
  -optimizationwindowsize 256 \
  -preemphasis 0.9373 \
  -linearpowershift 0.1 \
  -minfrequency 250 \
  -maxfrequency 550 \
  -trimsilenceframes \
  -addstopframe \
  data/vocals_part1.wav \
  data/vocals_part1.lpc

java ConvertWavToLpc \
  -amplification 1 \
  -lpcwindowsize 400 \
  -frameoversampling 4 \
  -optimizationwindowsize 256 \
  -preemphasis 0.9373 \
  -linearpowershift 0.1 \
  -minfrequency 250 \
  -maxfrequency 550 \
  -trimsilenceframes \
  -addstopframe \
  data/vocals_part2.wav \
  data/vocals_part2.lpc

###############################################################################
# Postcredit vocals.
###############################################################################

java ConvertTextToLpc \
  data/TI_HomeComputer.txt \
  data/TI_HomeComputer.lpc

java TuneLpcFile \
  data/TI_HomeComputer.lpc \
  data/music_simplified.snd,$(calci "(126.64 - 1.316) * $SOUND_FPS") \
  0.125 60 250 \
  data/TI_HomeComputer_tuned.lpc

###############################################################################
# Combine animation, music, and vocals in a complete video.
###############################################################################

# The lengths of the sections, expressed in animation frames (at ~ 25 / 30 fps).
TITLES_COUNT=$(     jar -tf $TITLES_ZIP      | wc -l)
ANIMATION_COUNT=$(  jar -tf $ANIMATION_ZIP   | wc -l)
CREDITS_COUNT=$(    jar -tf $CREDITS_ZIP     | wc -l)
POSTCREDITS_COUNT=$(jar -tf $POSTCREDITS_ZIP | wc -l)

# The lengths of the sections, expressed in video frames (at ~ 50 / 60 Hz).
TITLES=$[     TITLES_COUNT      * 2]
ANIMATION=$[  ANIMATION_COUNT   * 2]
CREDITS=$[    CREDITS_COUNT     * 2]
POSTCREDITS=$[POSTCREDITS_COUNT * 2]

# The offsets of the music and vocals inside the main animation, expressed
# in target frames (at ~ 50 / 60 Hz).
# Tweak for buffering and leading silence in the speech data.
MUSIC_START=$(       calci "   1.315         * $VIDEO_FPS")
VOCALS_PART1_START=$(calci "( 29.100 - 0.12) * $VIDEO_FPS")
VOCALS_PART2_START=$(calci "(126.630 - 0.65) * $VIDEO_FPS")

java ComposeVideo -$TARGET \
  $[0                                   ]:data/titles.zip \
  $[TITLES                              ]:$ANIMATION_ZIP \
  $[TITLES+MUSIC_START                  ]:$MUSIC_SND \
  $[TITLES+VOCALS_PART1_START           ]:data/vocals_part1.lpc \
  $[TITLES+VOCALS_PART2_START           ]:data/vocals_part2.lpc \
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

rm -f $BAD_APPLE_RPK

zip -q --junk-paths \
  $BAD_APPLE_RPK \
  layout.xml \
  out/romc.bin
