verareg =$9f20
veralo  =verareg+0
veramid =verareg+1
verahi  =verareg+2
veradat =verareg+3
veradat2=verareg+4
veractl =verareg+5
veraien =verareg+6
veraisr =verareg+7

;***************
monitor:
	jsr bjsrfar
	.word $c000
	.byte BANK_MONITOR

;***************
geos:
	jsr bjsrfar
	.word $c000 ; entry
	.byte BANK_GEOS

;***************
color	jsr getcol ; fg
	lda coltab,x
	jsr bsout
	jsr chrgot
	bne :+
	rts
:	jsr chkcom
	jsr getcol ; bg
	lda #1 ; swap fg/bg
	jsr bsout
	lda coltab,x
	jsr bsout
	lda #1 ; swap fg/bg
	jmp bsout


getcol	jsr getbyt
	cpx #16
	bcc :+
	jmp fcerr
:	rts

coltab	;this is an unavoidable duplicate from KERNAL
	.byt $90,$05,$1c,$9f,$9c,$1e,$1f,$9e
	.byt $81,$95,$96,$97,$98,$99,$9a,$9b

;***************
vpeek	jsr chrget
	jsr chkopn ; open paren
	jsr getbyt ; byte: bank
	stx verahi
	jsr chkcom
	lda poker
	pha
	lda poker + 1
	pha
	jsr frmadr ; word: offset
	sty veralo
	sta veramid
	pla
	sta poker + 1
	pla
	sta poker
	jsr chkcls ; closing paren
	ldy veradat
	jmp sngflt

;***************
vpoke	jsr getbyt ; bank
	stx verahi
	jsr chkcom
	jsr getnum
	lda poker
	sta veralo
	lda poker+1
	sta veramid
	stx veradat
	rts

;***************
vload	jsr plsv   ;parse the parameters
	bcc vld1   ;require bank/addr
	jmp snerr
vld1	lda andmsk ;bank number
	adc #2
	jmp cld10  ;jump to load command

;***************
old	beq old1
	jmp snerr
old1	lda txttab+1
	ldy #1
	sta (txttab),y
	jsr lnkprg
	clc
	lda index
	adc #2
	sta vartab
	lda index+1
	adc #0
	sta vartab+1
	jmp init2

;***************
dos	beq ptstat      ;no argument: print status
	jsr frmstr      ;length in .a
	cmp #0
	beq ptstat      ;no argument: print status
	sta verck       ;save length
	ldx index1
	ldy index1+1
	jsr setnam
	ldy #0
	lda (index1),y
; dir?
	cmp #'$'
	beq disk_dir
; switch default drive?
	cmp #'8'
	beq dossw
	cmp #'9'
	beq dossw

;***************
; DOS command
	jsr listen_cmd
	ldy #0
:	lda (index1),y
	jsr iecout
	iny
	cpy verck       ;length?
	bne :-
	jmp unlstn

listen_cmd:
	jsr getfa
	jsr listen
	lda #$6f
	jsr second
	jsr readst
	bmi :+
	rts
device_not_present:
	ldx #5 ; "DEVICE NOT PRESENT"
	jmp error


;***************
; print status
ptstat	jsr listen_cmd
	jsr unlstn
	jsr getfa
	jsr talk
	lda #$6f
	jsr tksa
dos11	jsr iecin
	jsr bsout
	cmp #13
	bne dos11
	jmp untalk

;***************
; switch default drive
dossw	and #$0f
	sta basic_fa
	rts

getfa:
	lda #8
	cmp basic_fa
	bcs :+
	lda basic_fa
:	rts


;***************
;  read & display the disk directory

LOGADD = 15

.export disk_dir
disk_dir
	lda #8
	tax
	lda #LOGADD     ;la
	ldy #$60        ;sa
	jsr setlfs
	jsr open        ;open directory channel
	bcs disk_done   ;...branch on error
	ldx #LOGADD
	jsr chkin       ;make it an input channel

	jsr crdo

	ldy #4          ;first pass only- trash first four bytes read

@d20
@d25	jsr basin
	jsr readst
	bne disk_done   ;...branch if error
	dey
	bne @d25        ;...loop until done

	jsr basin       ;get # blocks low
	pha
	jsr readst
	tay
	pla
	cpy #0
	bne disk_done   ;...branch if error
	tax
	jsr basin       ;get # blocks high
	pha
	jsr readst
	tay
	pla
	cpy #0
	bne disk_done   ;...branch if error
	jsr linprt      ;print # blocks

	lda #' '
	jsr bsout       ;print space  (to match loaded directory display)

@d30	jsr basin       ;read & print filename & filetype
	beq @d40        ;...branch if eol
	pha
	jsr readst
	tax
	pla
	cpx #0
	bne disk_done   ;...branch if error
	jsr bsout
	bcc @d30        ;...loop always

@d40	jsr crdo        ;start a new line
	jsr cstop
	beq disk_done   ;...branch if user hit STOP
	ldy #2
	bne @d20        ;...loop always

disk_done
	jsr clrch
	lda #LOGADD
	sec
	jsr close


	lda 0
	jsr printhex8
	lda 1
	jsr printhex8
	lda 2
	jsr printhex8
	lda 3
	jsr printhex8
	lda 4
	jsr printhex8
	lda 5
	jsr printhex8
	lda 6
	jsr printhex8
	lda 7
	jsr printhex8
	jmp *

printhex8:
	pha
	lsr
	lsr
	lsr
	lsr
	jsr printhex4
	pla
	jsr printhex4
	lda #' '
	jmp $ffd2

printhex4:
	and #$0f
	cmp #$0a
	bcc :+
	adc #$66
:	eor #$30
	jmp $ffd2

mouse:
	jsr getbyt
	txa
	ldx #0 ; keep scale
	jmp mouse_config

mx:
	jsr chrget
	ldx #fac
	jsr mouse_get
	lda fac+1
	ldy fac
	jmp givayf

my:
	jsr chrget
	ldx #fac
	jsr mouse_get
	lda fac+3
	ldy fac+2
	jmp givayf

mb:
	jsr chrget
	ldx #fac
	jsr mouse_get
	tay
	jmp sngflt

joy:
	jsr chrget
	jsr chkopn ; open paren
	jsr getbyt ; byte: joystick number (1 or 2)
	cpx #1
	beq :+
	cpx #2
	beq :+
	jmp fcerr
:	phx
	jsr chkcls ; closing paren
	pla
	dec ; KERNAL uses #0 and #1
	jsr joystick_get
	eor #$ff
	tay
	jmp sngflt

reset:	
	ldx #5
:	lda reset_copy,x 
	sta $0100,x 
	dex
	bpl :-
	jmp $0100

reset_copy:
	stz d1prb 
	jmp ($fffc)

cls:
	lda #$93
	jmp outch

; BASIC's entry into jsrfar
.setcpu "65c02"
via1	=$9f60                  ;VIA 6522 #1
d1prb	=via1+0
d1pra	=via1+1
.export bjsrfar
bjsrfar:
.include "jsrfar.inc"
