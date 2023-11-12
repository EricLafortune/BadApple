* Bad Apple demo for the TI-99/4A home computer.
*
* Copyright (c) 2022 Eric Lafortune
*
* This program is free software; you can redistribute it and/or modify it
* under the terms of the GNU General Public License as published by the Free
* Software Foundation; either version 2 of the License, or (at your option)
* any later version.
*
* This program is distributed in the hope that it will be useful, but WITHOUT
* ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
* FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
* more details.
*
* You should have received a copy of the GNU General Public License along
* with this program; if not, write to the Free Software Foundation, Inc.,
* 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA

    aorg >6000

* Module header.
    byte >aa                   ; Header.
    byte 1                     ; Version.
    byte 1                     ; Number of programs.
    byte 0                     ; Unused.
    data 0                     ; Power-up list.
    data program_list          ; Program list (shown in reverse order).
    data 0                     ; DSR list.
    data 0                     ; Subprogram list.

* First element of the program list.
program_list
    data !                     ; Next element.
    data play_with_speech      ; Program start.
    stri 'BAD APPLE WITH VOCALS' ; Program name.

* Second element of the program list.
!   data 0                     ; Next element.
    data play_without_speech   ; Program start.
    stri 'BAD APPLE'           ; Program name.
    even

    copy "include/colors.asm"
    copy "include/vdp.asm"
    copy "include/sound.asm"
    copy "include/cru.asm"

play_without_speech
    limi 0
    lwpi >83e0

    clr  r11                   ; Cache a dummy speech address in r11.
    jmp  !

play_with_speech
    limi 0
    lwpi >83e0

    li   r11, spchwt           ; Cache the speech address in r11.
!   li   r13, sound            ; Cache the sound address in r13.
    li   r14, vdpwd            ; Cache the vdpwd address in r14.
    .vdpwa_in_register r15     ; Cache the vdpwa address in r15.

    .vdpwr 0, >02              ; Bitmap mode.
    .vdpwr 1, >c0              ; Disable screen interrupts.
    .vdpwr 2, >06              ; Set the screen image table       at >1800.
    .vdpwr 3, >ff              ; Set the color table              at >2000 (size >1800).
    .vdpwr 4, >03              ; Set the pattern descriptor table at >0000 (size >1800).
    .vdpwr 5, >70              ; Set the sprite attribute list    at >3800.
;   .vdpwr 6, >00              ; Keep the sprite descriptor table at >0000.
    .vdpwr 7, black            ; Set the background color.

* Initialize the pattern descriptor table and screen image table.
    li   r0, >4000
    .vdpwa r0
    clr  r0
    li   r1, >1800 + >0300
pattern_loop
    .vdpwd r0
    dec  r1
    jne  pattern_loop

* Initialize the color table.
    li   r0, >6000
    .vdpwa r0
    li   r0, (white * 16 + black) * 256
    li   r1, >1800
color_loop
    .vdpwd r0
    dec  r1
    jne  color_loop

* Initialize the sprite attribute table.
    li   r0, >7800
    .vdpwa r0
    li   r0, >d000
    .vdpwd r0

* Copy the player code to scratchpad RAM and run it.
    li   r0, code_start
    li   r1, >8300
copy_loop
    mov  *r0+, *r1+
    ci   r0, code_end
    jne  copy_loop

    b    @>8300

code_start
    xorg >8300

* Main loop that draws all frames, in scratchpad RAM for speed.
* Registers:
*   r0:  Current adress to set the module memory bank: >6000, >6002,...,>7ffe.
*   r1:  Data pointer in the current memory bank, starting at >60000.
*   r2:  Command and count.
*   r11: SPCHWT.
*   r13: SOUND.
*   r14: VDPWD.
*   r15: VDPWA.
movie_loop
    li   r0, >6002             ; Set the first bank.

* Switch to the current bank and update the number.
bank_loop
    movb *r0, *r0              ; Switch to the current bank.
    inct r0                    ; Increment the bank index.

    li   r1, >6000             ; Set the first frame in this bank.

* Render a frame (video, sound, and speech).
frame_loop
    movb *r1+, r2
    swpb r2
    movb *r1+, r2
    jlt  !

* Draw subsequent bytes of video data.

; Simple version without loop unrolling.
;                               ; Write the pre-swapped VDP address.
;    movb *r1+, *r15            ;: d-
;    nop
;    movb *r1+, *r15            ;: d-
;    nop
;
;video_loop                     ; Copy the frame to VDP RAM.
;    movb *r1+, *r14            ;: d-
;    dec  r2
;    jne  video_loop
;    jmp  frame_loop

; Faster version with loop unrolling.
                               ; Write the pre-swapped VDP address.
    movb *r1+, *r15            ;: d-
    mov  r2, r3                ; Inbetween: compute the branch offset into the
    andi r3, >0007             ; unrolled loop.
    sla  r3, 1
    neg  r3
    movb *r1+, *r15            ;: d-
    srl  r2, 3
    inc  r2
    b @unrolled_video_loop_end(r3)

unrolled_video_loop            ; Copy the frame to VDP RAM.
    movb *r1+, *r14            ;: d-
    movb *r1+, *r14            ;: d-
    movb *r1+, *r14            ;: d-
    movb *r1+, *r14            ;: d-
    movb *r1+, *r14            ;: d-
    movb *r1+, *r14            ;: d-
    movb *r1+, *r14            ;: d-
    movb *r1+, *r14            ;: d-
unrolled_video_loop_end
    dec  r2
    jne  unrolled_video_loop
    jmp  frame_loop

!   ai   r2, >0020             ; Did we get a sound frame?
    jlt  !

* Play subsequent bytes of sound data.
sound_loop                     ; Copy the frame to the sound processor.
    movb *r1+, *r13            ;: d-
    dec  r2
    jne  sound_loop
    jmp  frame_loop            ; Continue with the rest of the frame.

!   ai   r2, >0010             ; Did we get a speech frame?
    jlt  !

* Play subsequent bytes of speech data.
speech_loop                    ; Copy the frame to the speech synthesizer.
    movb *r1+, *r11            ;: d-
    dec  r2
    jne  speech_loop
    jmp  frame_loop            ; Continue with the rest of the frame.

!   inc  r2                    ; Did we get a VSYNC marker?
    jne  !

* Wait for VSYNC.
vsync_loop
    movb @vdpsta, r3           ; Check the VDP status byte.
    sla  r3, 1
    jnc  vsync_loop
    jmp  frame_loop            ; Continue with the rest of the frame.

!   inc  r2                    ; Did we get a NEXT_BANK marker?
    jeq  bank_loop

                               ; We got an EOF marker.
* Wait for a key press (in key column 0).
    li   r12, cru_write_keyboard_column
    clr  r0
    ldcr r0, cru_keyboard_column_bit_count
    li   r12, cru_read_keyboard_rows

key_press_loop
    stcr r0, cru_read_keyboard_row_bit_count
    ci   r0, >ff00
    jeq  key_press_loop

    li   r0, >6000             ; Reset to the first bank.
    movb *r0, *r0

    blwp @0                    ; Return to the title screen.

    .ifgt  $, >83e0
    .error 'Code block too large'
    .endif

    aorg
code_end

    .ifgt  $, >8000
    .error 'Cartridge code too large'
    .endif

* Put the video data in subsequent banks after the code,
* aligned to multiples of >2000.
    aorg >8000
    ;copy "../data/video.asm"
    bcopy "../data/video.tms"
