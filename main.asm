INCLUDE "hardware.inc"

SECTION "Header", ROM0[$100]

    jp EntryPoint

    ds $150 - @, 0 ; Make room for the header

EntryPoint:
    ; Do not turn the LCD off outside of VBlank
WaitVBlank:
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

	;Draw object properties
	ld hl, _OAMRAM
	ld a, 128 + 16
	ld [hli], a
	ld a, 16 + 8
	ld [hli], a
	ld a, 0
	ld [hli], a
	ld [hli], a

	; Copy the paddle tile
	ld de, Paddle
	ld hl, $8000
	ld bc, PaddleEnd - Paddle
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

Main:
    ; Wait until it's not VBlank
	ld a, [rLY]
	cp 144
	jp nc, Main
WaitVBlank2:
	ld a, [rLY]
	cp 144
	jp c, WaitVBlank2

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
	dw `22222222
	dw `20000000
	dw `20111111
	dw `20111111
	dw `20111111
	dw `20111111
	dw `22222222
	dw `33333333;6
	dw `22222223
	dw `00000023
	dw `11111123
	dw `11111123
	dw `11111123
	dw `11111123
	dw `22222223
	dw `33333333;7
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
	
TilesEnd:

Tilemap:
	db $00, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $02, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
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
    dw `13333331
    dw `30000003
    dw `13333331
    dw `00000000
    dw `00000000
    dw `00000000
    dw `00000000
    dw `00000000
PaddleEnd:

SECTION "Counter", wram0
wFrameCounter: db

SECTION "Input Variables", WRAM0
wCurKeys: db
wNewKeys: db