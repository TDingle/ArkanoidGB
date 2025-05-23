INCLUDE "hardware.inc"

DEF BRICK_LEFT EQU $05 ; Tile index for given tile, look in tile map debugger
DEF BRICK_RIGHT EQU $06
DEF BLANK_TILE EQU $08
DEF DIGIT_OFFSET EQU $16
DEF SCORE_TENS EQU $9870
DEF SCORE_ONES EQU $9871

SECTION "Header", ROM0[$100]

    jp EntryPoint

    ds $150 - @, 0 ; Make room for the header

EntryPoint:
    ; Do not turn the LCD off outside of VBlank
	;Turn on Audio
	ld a, %01110111	;-LLL-RRR Channel Volume
	ld [rAUDVOL], a
	
	ld a, %11111111
	ld [rAUDTERM], a

	; Do not turn the LCD off outside of VBlank
WaitVBlank:
	call PlayStartSound
    ld a, [rLY]
    cp 144
    jp c, WaitVBlank

    ; Turn the LCD off
    ld a, 0
    ld [rLCDC], a

    ; Copy the tile data
    ld de, Tiles
    ld hl, $9000
    ld bc, TilesEnd - Tiles
	call Memcopy

    ; Copy the Tilemap
    ld de, Tilemap
    ld hl, $9800
    ld bc, TilemapEnd - Tilemap
	call Memcopy

	; Clear OAM before enabling OBJs for the first time
	ld a, 0
	ld b, 160
	ld hl, _OAMRAM
clearOam:
	ld [hli], a
	dec b
	jp nz, clearOam

	; Initialize paddle sprite in OAM
	ld hl, _OAMRAM
	ld a, 128 + 16
	ld [hli], a
	ld a, 16 + 8
	ld [hli], a
	ld a, 0
	ld [hli], a
	ld [hli], a
	; Initialize ball sprite in OAM
	ld a, 100 + 16
	ld [hli], a
	ld a, 32 + 8
	ld [hli], a
	ld a, 1
	ld [hl+], a
	ld a, 0
	ld [hli], a

	;The ball starts out going up and to the right
	ld a, 1
	ld [wBallMomentumX], a
	ld a, -1
	ld [wBallMomentumY], a

	; Copy the paddle tile
	ld de, Paddle
	ld hl, $8000
	ld bc, PaddleEnd - Paddle
	call Memcopy

	; Copy the ball tile
	ld de, Ball
	ld hl, $8010
	ld bc, BallEnd - Ball
	call Memcopy
	
    ; Turn the LCD on
    ld a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJON
    ld [rLCDC], a

    ; During the first (blank) frame, initialize display registers
    ld a, %11100100
    ld [rBGP], a
	ld a, %11100100
	ld [rOBP0], a

	; Initialize global variables
	ld a, 0
	ld [wFrameCounter], a
	ld [wCurKeys], a
	ld [wNewKeys], a
	ld [wScore], a

Main:
    ; Wait until it's not VBlank
	ld a, [rLY]
	cp 144
	jp nc, Main
WaitVBlank2:
	ld a, [rLY]
	cp 144
	jp c, WaitVBlank2

	; Add the balls momentum to its position in OAM
	ld a, [wBallMomentumX]
	ld b, a
	ld a, [_OAMRAM + 5]
	add a, b
	ld [_OAMRAM + 5], a

	ld a, [wBallMomentumY]
	ld b, a
	ld a, [_OAMRAM + 4]
	add a, b
	ld [_OAMRAM + 4], a

BounceOnTop:
	; Remember to offset the OAM position!
	; (8, 16) in OAM coordinates is (0, 0) on the screen
	ld a, [_OAMRAM + 4]
	sub a, 16 + 1
	ld c, a
	ld a, [_OAMRAM + 5]
	sub a, 8
	ld b, a
	call GetTileByPixel ; returns the tile address in hl
	ld a, [hl]
	call IsWallTile
	jp nz, BounceOnRight
	call CheckAndHandleBrick
	ld a, 1
	ld [wBallMomentumY], a
	
BounceOnRight:
	ld a, [_OAMRAM + 4] ; Y position of the ball
	sub a, 16 ; oam coord to screen coords
	ld c, a ; puts the new on screen y position into register c

	ld a, [_OAMRAM + 5] ; X position of the ball
	
	; sub a, 8 - 1; X coordinate conversion from OAM to on-screen
	; line commented out above, when converting x on right ball bounces inside right wall

	ld b, a ; puts the new on screen x position into register b

	; We must load x and y into these registers because GetTilePixel takes them as parameters
	call GetTileByPixel
	ld a, [hl]
	call IsWallTile
	jp nz, BounceOnLeft
	call CheckAndHandleBrick
	ld a, -1
	ld [wBallMomentumX], a

BounceOnLeft:
	ld a, [_OAMRAM + 4]
	sub a, 16
	ld c, a
	ld a, [_OAMRAM + 5]
	sub a, 8 + 1
	ld b, a
	call GetTileByPixel
	ld a, [hl]
	call IsWallTile
	jp nz, BounceOnBottom
	call CheckAndHandleBrick
	ld a, 1
	ld [wBallMomentumX], a

BounceOnBottom:
	ld a, [_OAMRAM + 4]
    sub a, 16 - 1
    ld c, a
    ld a, [_OAMRAM + 5]
    sub a, 8
    ld b, a
    call GetTileByPixel
    ld a, [hl]
    call IsWallTile
    jp nz, BounceDone
	call CheckAndHandleBrick
    jp WaitVBlank

BounceDone:

	; First, check if the ball is low enough to bounce off the paddle

	ld a, [_OAMRAM] ; Paddle Y position
	ld b, a
	ld a, [_OAMRAM + 4] ; Ball Y position
	add a, 5
	cp a, b
	jp nz, PaddleBounceDone ; If the ball isnt at the same Y lvl as the Paddle it cant Bounce

	; Now compare the X positions to see of they are touching

	ld a, [_OAMRAM + 5] ; Ball X position
	ld b, a
	ld a, [_OAMRAM + 1] ; Paddle X position
	sub a, 8
	cp a, b
	jp nc, PaddleBounceDone
	add a, 8 + 16 ; 8 to undo, 16 as the width
	cp a, b
	jp c, PaddleBounceDone
	call PlayPaddleSound
	ld a, -1
	ld [wBallMomentumY], a

PaddleBounceDone:


	; Check the current keys every fram and move left or right
	call UpdateKeys

	; First, check if the left button is pressed
CheckLeft:
	ld a, [wCurKeys]
	and a, PADF_LEFT
	jp z, CheckRight
Left:
	; move the paddle one pixel to the left
	ld a, [_OAMRAM + 1]
	dec a
	; If we've already hit the edge of the playfield , don't move
	cp a, 15
	jp z, Main
	ld [_OAMRAM + 1], a
	jp Main

;Check the right button
CheckRight:
	ld a, [wCurKeys]
	and a, PADF_RIGHT
	jp z, Main
Right:
	; Move the paddle one pixel to the right
	ld a, [_OAMRAM + 1]
	inc a
	; if we already hit the edge of the playfield, don't move
	cp a, 105
	jp z, Main
	ld [_OAMRAM + 1], a
	jp Main

	; Initialize global variables
	ld a, 0
	ld [wFrameCounter], a
	ld [wCurKeys], a
	ld [wNewKeys], a

PlayBrickSound:
	;Channel 2
	ld a, %00110000		; %DDLLLLLL Wave Duty (tone) and Sound Length (higher = shorter)
	ld [rAUD2LEN], a	; no effect unless c=1 in rAUD2HIGH 
	
	ld a, %11111100	;%VVVVDNNN C1 Volume / Direction 0=down / envelope number
	ld [rAUD2ENV], a	; (fade speed - higher is slower)
	
	ld a, 64			;%LLLLLLLL pitch L
	ld [rAUD2LOW], a
	
	ld a, %11000011 ; %IC---HHH C1 Initial / Counter 1=stop / pitch H
	ld [rAUD2HIGH], a

	ret
PlayPaddleSound:
	;Channel 2
	ld a, %00100000		; Wave Duty (tone) and Sound Length (higher = shorter)
	ld [rAUD2LEN], a	; no effect unless c=1 in rAUD2HIGH 
	
	ld a, %11111100	;%VVVVDNNN C1 Volume / Direction 0=down / envelope number
	ld [rAUD2ENV], a	; (fade speed - higher is slower)
	
	ld a, 64			;%LLLLLLLL pitch L
	ld [rAUD2LOW], a
	
	ld a, %11000100 ; %IC---HHH C1 Initial / Counter 1=stop / pitch H
	ld [rAUD2HIGH], a
	ret
PlayStartSound:
	;Channel 1
	ld a, %01110011 ;Channel 1 sweep register
	ld [rAUD1SWEEP], a ;-TTTDNNN T=time, D=Direction, N=numberof shifts

	ld a, %11100000		; Wave Duty (tone) and Sound Length (higher = shorter)
	ld [rAUD1LEN], a	; no effect unless c=1 in rAUD2HIGH 
	
	ld a, %11111100	;%VVVVDNNN C1 Volume / Direction 0=down / envelope number
	ld [rAUD1ENV], a	; (fade speed - higher is slower)
	
	ld a, 64			;%LLLLLLLL pitch L
	ld [rAUD1LOW], a
	
	ld a, %10000100 ; %IC---HHH C1 Initial / Counter 1=stop / pitch H
	ld [rAUD1HIGH], a
	ret

; Copy bytes from one area to another
; @param de: Source
; @param hl: Destination
; @param bc: Length
Memcopy:
	ld a, [de]
	ld [hli], a
	inc de
	dec bc
	ld a, b
	or a, c
	jp nz, Memcopy
	ret


; Convert a pixel position to a tilemap address
; hl = $9800 + X + Y * 32
; @param b: X
; @param c: Y
; @return hl: tile address
GetTileByPixel:
	;First, we need to divide by 8 to convert a pixel position to a tile position
	; After this we want to multiply the Y position by 32
	; These operations effectively cancel out so we only need to mask the Y value
	ld a, c
	and a, %11111000
	ld l, a
	ld h, 0
	; Now we have the position * 8 in hl
	add hl, hl ; position * 16
	add hl, hl ; position * 32
	; Convert the X position to and offset
	ld a, b
	srl a ; a / 2
	srl a ; a / 4
	srl a ; a / 8
	; Add the two offsets together
	add a, l
	ld l, a
	adc a, h
	sub a, l
	ld h, a
	; add the offset to the tilemaps base address, and we are done
	ld bc, $9800
	add hl, bc
	ret 

; @param a: tile ID
; @return z: set if a is a wall
IsWallTile:
	cp a, $00
	ret z
	cp a, $01
	ret z
	cp a, $02
	ret z
	cp a, $04
	ret z
	cp a, $05
	ret z
	cp a, $06
	ret z
	cp a, $07
	ret 

; Increase the score by 1 and store it as a 1 byte packed BCD number
; changes A and HL
IncreaseScorePackedBCD:
	xor a				; clear the carry flag and a
	inc a				; a = 1
	ld hl, wScore		; load score into hl
	adc [hl]			; add 1
	daa					; convert to BCD
	ld [hl], a			; store score
	call UpdateScoreBoard
	ret

; Reads the packed BCD score from wScore and updates the score display
UpdateScoreBoard:
	ld a, [wScore]		; Get the store packed score
	and %11110000		; mask the lower nibble
	rrca 				; move the upper nibble to the lower nibble (divde by 16)
	rrca 
	rrca 
	rrca 
	add a, DIGIT_OFFSET	; add the digit offset to a to get the correct digit tile
	ld [SCORE_TENS], a	; Show the digit on screen

	ld a, [wScore]		; load the packed score into a again
	and %00001111		; Mask the upper nibble
	add a, DIGIT_OFFSET
	ld [SCORE_ONES], a
	ret

CheckAndHandleBrick:
	ld a, [hl] ; points to the memory address in hl holding the tile the ball is over (obtained by GetTileByPixel)
	cp a, BRICK_LEFT ; check to see of tiles are the same
	jr nz, CheckAndHandleBrickRight
	; Break a brick from the left side
	ld [hl], BLANK_TILE 
	inc hl ; sets hl to point at the tile to the right
	ld [hl], BLANK_TILE
	call IncreaseScorePackedBCD
	call PlayBrickSound

CheckAndHandleBrickRight:
	cp a, BRICK_RIGHT
	ret nz
	; Break a brick from the right side
	ld [hl], BLANK_TILE
	dec hl ; sets hl to point at the tile to the left
	ld [hl], BLANK_TILE
	call IncreaseScorePackedBCD
	call PlayBrickSound
	ret

UpdateKeys:
	; Poll half the controller
	ld a, P1F_GET_BTN
	call .onenibble
	ld b, a ; B7-4 = 1; B3-0 = unpressed buttons
  
	; Poll the other half
	ld a, P1F_GET_DPAD
	call .onenibble
	swap a ; A7-4 = unpressed directions; A3-0 = 1
	xor a, b ; A = pressed buttons + directions
	ld b, a ; B = pressed buttons + directions
  
	; And release the controller
	ld a, P1F_GET_NONE
	ldh [rP1], a
  
	; Combine with previous wCurKeys to make wNewKeys
	ld a, [wCurKeys]
	xor a, b ; A = keys that changed state
	and a, b ; A = keys that changed to pressed
	ld [wNewKeys], a
	ld a, b
	ld [wCurKeys], a
	ret
  
.onenibble
	ldh [rP1], a ; switch the key matrix
	call .knownret ; burn 10 cycles calling a known ret
	ldh a, [rP1] ; ignore value while waiting for the key matrix to settle
	ldh a, [rP1]
	ldh a, [rP1] ; this read counts
	or a, $F0 ; A7-4 = 1; A3-0 = unpressed keys
.knownret
	ret

Tiles:
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33322222
	dw `33322222
	dw `33322222
	dw `33322211
	dw `33322211;1
	dw `33333333
	dw `33333333
	dw `33333333
	dw `22222222
	dw `22222222
	dw `22222222
	dw `11111111
	dw `11111111;2
	dw `33333333
	dw `33333333
	dw `33333333
	dw `22222333
	dw `22222333
	dw `22222333
	dw `11222333
	dw `11222333;3
	dw `22222222
	dw `23333332
	dw `23001132
	dw `23011132
	dw `23111132
	dw `23111132
	dw `23333332
	dw `22222222;4
	dw `33322211
	dw `33322211
	dw `33322211
	dw `33322211
	dw `33322211
	dw `33322211
	dw `33322211
	dw `33322211;5
	dw `23333333
	dw `31222222
	dw `32000000
	dw `32011111
	dw `32011111
	dw `32011111
	dw `31222222
	dw `23333333;6
	dw `33333332
	dw `22222213
	dw `00000023
	dw `11111123
	dw `11111123
	dw `11111123
	dw `22222213
	dw `33333332;7
	dw `11222333
	dw `11222333
	dw `11222333
	dw `11222333
	dw `11222333
	dw `11222333
	dw `11222333
	dw `11222333;8
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000;9
	dw `11001100
	dw `11111111
	dw `11111111
	dw `21212121
	dw `22222222
	dw `22322232
	dw `23232323
	dw `33333333;10
	dw `22222222;0 - Begin Logo
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222
	dw `22222222;1
	dw `22222222
	dw `22222222
	dw `22222333
	dw `22223300
	dw `22330011
	dw `22301111
	dw `23333113
	dw `22311111;2
	dw `22222222
	dw `22222222
	dw `33332222
	dw `00033322
	dw `11112332
	dw `11111232
	dw `33111233
	dw `11111123;3
	dw `22331111
	dw `23003233
	dw `23003230
	dw `30003130
	dw `33033233
	dw `33031233
	dw `30312230
	dw `30322230;4
	dw `31111123
	dw `03111123
	dw `00311123
	dw `00311123
	dw `00311133
	dw `00311131
	dw `00311131
	dw `00311121;5
	dw `22222222
	dw `22222222
	dw `22222222
	dw `33222222
	dw `13322222
	dw `11322222
	dw `11322222
	dw `31322222;6
	dw `23312223
	dw `23101222
	dw `23212222
	dw `23222222
	dw `23222233
	dw `23322332
	dw `22333321
	dw `22232211;7
	dw `03311111
	dw `32331111
	dw `22233113
	dw `22223113
	dw `33333112
	dw `22221112
	dw `11111111
	dw `11111111;8
	dw `21322222
	dw `13322222
	dw `13222222
	dw `33322222
	dw `30332222
	dw `33032222
	dw `23033322
	dw `23003322;9
	dw `22231111
	dw `22223333
	dw `22222322
	dw `22223311
	dw `22233331
	dw `22230003
	dw `22333000
	dw `23323330;10
	dw `11133111
	dw `33332111
	dw `22221112
	dw `11111122
	dw `11111223
	dw `33322333
	dw `00333300
	dw `00000003;11
	dw `23003332
	dw `23003233
	dw `33033213
	dw `30032212
	dw `30332122
	dw `03321221
	dw `03221212
	dw `33212121;end logo
	; digits
    ; 0
    dw `33333333
    dw `33000033
    dw `30033003
    dw `30033003
    dw `30033003
    dw `30033003
    dw `33000033
    dw `33333333
    ; 1
    dw `33333333
    dw `33300333
    dw `33000333
    dw `33300333
    dw `33300333
    dw `33300333
    dw `33000033
    dw `33333333
    ; 2
    dw `33333333
    dw `33000033
    dw `30330003
    dw `33330003
    dw `33000333
    dw `30003333
    dw `30000003
    dw `33333333
    ; 3
    dw `33333333
    dw `30000033
    dw `33330003
    dw `33000033
    dw `33330003
    dw `33330003
    dw `30000033
    dw `33333333
    ; 4
    dw `33333333
    dw `33000033
    dw `30030033
    dw `30330033
    dw `30330033
    dw `30000003
    dw `33330033
    dw `33333333
    ; 5
    dw `33333333
    dw `30000033
    dw `30033333
    dw `30000033
    dw `33330003
    dw `30330003
    dw `33000033
    dw `33333333
    ; 6
    dw `33333333
    dw `33000033
    dw `30033333
    dw `30000033
    dw `30033003
    dw `30033003
    dw `33000033
    dw `33333333
    ; 7
    dw `33333333
    dw `30000003
    dw `33333003
    dw `33330033
    dw `33300333
    dw `33000333
    dw `33000333
    dw `33333333
    ; 8
    dw `33333333
    dw `33000033
    dw `30333003
    dw `33000033
    dw `30333003
    dw `30333003
    dw `33000033
    dw `33333333
    ; 9
    dw `33333333
    dw `33000033
    dw `30330003
    dw `30330003
    dw `33000003
    dw `33330003
    dw `33000033
    dw `33333333
	
TilesEnd:

Tilemap:
	db $00, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $02, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $07, $03, $03, $16, $16, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $0A, $0B, $0C, $0A, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $0A, $0D, $0E, $0F, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $0A, $10, $11, $12, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $0A, $13, $14, $15, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
TilemapEnd:

Paddle:
    dw `03333330
    dw `31111113
    dw `21111112
    dw `32222223
    dw `03333330
    dw `00000000
    dw `00000000
    dw `00000000
PaddleEnd:

Ball:
    dw `00233200
    dw `02311320
    dw `03101130
    dw `03111130
    dw `02311320
    dw `00233200
    dw `00000000
    dw `00000000
BallEnd:

SECTION "Counter", wram0
wFrameCounter: db

SECTION "Input Variables", WRAM0
wCurKeys: db
wNewKeys: db

SECTION "Ball Data", wram0
wBallMomentumX: db
wBallMomentumY: db

SECTION "Score", wram0
wScore: db