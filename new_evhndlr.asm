; File newevhandlt_v1b.asm
; Event handling code for the PIC18F25K80 and similar PICs

;The following #define must be declared with a value of 16 for up to 8EVs per event
;or 32 for modules that use more than 8 EVs per event up to and including 24 EVs per event
;don't forget the full stop to force decimal literals.

;Change History
; v1b	24/03/14 Correct bug in chkevdata

;#define EVBLK_SZ	.32

;#define FLIM_ONLY	;define if SLiM mode not supported by the module

;The followin constants are used to configure the event handling code

;BLK_SZ 	equ	EVBLK_SZ
;EN_NUM		equ .128
;EVENT_SZ	equ	BLK_SZ-8
;ERASE_SZ	equ	.64
;HASH_SZ 	equ .32
;HASH_MASK	equ	HASH_SZ-1
;EVSPER_BLK	equ ERASE_SZ/BLK_SZ

;The following equates must be declared to suit the hardware being used
;the following are examples used in the CANACC8
;They are only required for modules that support SLiM mode

;POL		equ 5	;pol switch bit
;UNLEARN	equ	0	;unlearn / setup bit

;UNLPORT	equ	PORTA	;port for the UNLEARN bit
;POLPORT	equ	PORTB	;port for the POL bit

;This equate will most likely be defined in the main code body
;EV_NUM	equ 2		;the number of EVs per event

;The following routines are avaiable in the code module
;Note that routines that use either EVidx or ENidx will
;check the value is within range, the indices must not
;be modified from the values supplied in the message

;The learn routine is an exception to this, the routine expects
;a zero based EVidx

;learn		;event information must be in ev0, ev1, ev2 & ev3
;			;EVidx must contain the zero based index
;			;EVdata must contain the data for the index

;unlearn	;event information must be in ev0, ev1, ev2 & ev3

;chkevdata	;must be called in setup, creates the event data
;			;structure if it does not exist.

;initevdata	;clears all events from the data structure
;			;and resets all EEPROM data

;enmatch	;checks for a match on the event information
;			;in ev0, ev1, ev2 & ev3
;			;returns 0 if successful and sets FSR0 to point at
;			;the data RAM location that would contain the 
;			;event information
;			;The routine does not load the data RAM with the
;			;event information, this must be done by
;			;calling the rdfbev subroutine, if the data is required

;rdfbev		;reads the 64 byte block which contains the event
;			;information into data RAM

;readev		;ev0,ev1, ev2, ev3 & EVidx must be set, reads
;			;the event variable for the associated index

;enrdi		;Reads the event at the requested index

;evsend		;returns the event variable at EVidx for the event
;			;with the index specified by ENidx

;enread		;reads all events insequence, returns the event 
;			;inforamtion and index for all events

;rdFreeSp	;returns the remaining free space for holding events

;evnsend	;returns the number of events

;This code module calls the following subroutines in the main code body

;sendTx
;sendTXa
;dely
;nnrel
;eeread
;eewrite
;errsub

;The following routine is not called if FLIM_ONLY is defined
;getop

;The following data items sre used by the code, any that do not aready exist
;in the main code body must be added

;	Mode
;	Datmode
;	Match		;match flag
;	ENcount		;which EN matched
;	ENcount1	;temp for count offset
;	EVtemp		;holds current EV pointer
;	EVtemp1	
;	EVtemp2		;holds current EV qualifier
;	Temp
;	Temp1
;	Count
;	TempINTCON
;	Saved_Fsr0H
;	Saved_Fsr0L
	
;	Tx1con			;start of transmit frame  1
;	Tx1sidh
;	Tx1sidl
;	Tx1eidh
;	Tx1eidl
;	Tx1dlc
;	Tx1d0
;	Tx1d1
;	Tx1d2
;	Tx1d3
;	Tx1d4
;	Tx1d5
;	Tx1d6
;	Tx1d7
;	Dlc

	;The following variables used by event handling code
	; All variables should be in Access Ram	

;	evaddrh			; event data ptr
;	evaddrl
;	prevadrh		; previous event data ptr
;	prevadrl
;	nextadrh		; next event data ptr
;	nextadrl
;	htaddrh			; current hash table ptr
;	htaddrl
;	htidx			; index of current hash table entry in EEPROM
;	hnum			; actual hash number
;	freadrh			; current free chain address
;	freadrl
;	initFlags		; used in intialising Flash from EEPROM events

	; four bytes containing the event data
;	ev0				NN Hi
;	ev1				NN Lo
;	ev2				EN Hi
;	ev3				EN Lo
	
;	EVidx		; EV index from learn cmd
;	EVdata		; EV data from learn cmd
;	ENidx		; event index from commands which access events by index
;	CountFb0	; counters used by Flash handling
;	CountFb1

;The event data is declared as 'evdata', unitialised in Flash. 
;It should be above any code or other initialisation and at the highest address
;allowing for its size and any space needed for debug code

;The area will need allow 2kb for modules that use no more than 8 EVs per event
; with 128 events in total
;For modules that need more than 8 EVS per event and up to 24 EVS per event,
; the date area will be 4kb
;
;The declaration will be of the form
;	ORG 0x7a00
;	evdata

; EEPROM data
; Thes data items must exist in EEPROM

;ENindex	de	0,0		;points to next available EN number (in lo byte)
					;free space in hi byte
;FreeCh	de  0,0
		
;hashtab	de	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
;		de	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
;		de	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
;		de	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
		
;hashnum	de	0,0,0,0,0,0,0,0
;		de	0,0,0,0,0,0,0,0
;		de	0,0,0,0,0,0,0,0
;		de	0,0,0,0,0,0,0,0

;The following Ram data area can be defined for any CBLOCK
;It is define for CBLOCK 1 below

;	if (EVBLK_SZ == .16)

;	CBLOCK 0x100		;bank 1
	; 64 bytes of event data - the quanta size for updating Flash
;	evt00				; Event number - 4 bytes
;	evt01
;	evt02
;	evt03
;	next0h				; next entry in list
;	next0l
;	prev0h				; previous entry in list
;	prev0l
;	ev00				; event variables - upto 8
;	ev01
;	ev02
;	ev03
;	ev04
;	ev05
;	ev06
;	ev07
;	
;	evt10				; Event number - 4 bytes
;	evt11
;	evt12
;	evt13
;	next1h				; next entry in list
;	next1l
;	prev1h				; previous entry in list
;	prev1l
;	ev10				; event variables - upto 8
;	ev11
;	ev12
;	ev13
;	ev14
;	ev15
;	ev16
;	ev17
;	
;	evt20				; Event number - 4 bytes
;	evt21
;	evt22
;	evt23
;	next2h				; next entry in list
;	next2l
;	prev2h				; previous entry in list
;	prev2l
;	ev20				; event variables - upto 8
;	ev21
;	ev22
;	ev23
;	ev24
;	ev25
;	ev26
;	ev27
;	
;	evt30				; Event number - 4 bytes
;	evt31
;	evt32
;	evt33
;	next3h				; next entry in list
;	next3l
;	prev3h				; previous entry in list
;	prev3l
;	ev30				; event variables - upto 8
;	ev31
;	ev32
;	ev33
;	ev34
;	ev35
;	ev36
;	ev37
;	
;	ENDC

;	else
	
;	if (EVBLK_SZ == .32)
;
;	CBLOCK 0x100	; bank 1
	; first event data block
;	evt00
;	evt01
;	evt02
;	evt03
;	next0h
;	next0l
;	prev0h
;	prev0l
;	ev00
;	ev01
;	ev02
;	ev03
;	ev04
;	ev05
;	ev06
;	ev07
;	ev08
;	ev09
;	ev0a
;	ev0b
;	ev0c
;	ev0d
;	ev0e
;	ev0f
;	ev10
;	ev11
;	ev12
;	ev13
;	ev14
;	ev15
;	ev16
;	ev17
	; second event data block
;	evt10
;	evt11
;	evt12
;	evt13
;	next1h
;	next1l
;	prev1h
;	prev1l
;	ev20
;	ev21
;	ev22
;	ev23
;	ev24
;	ev25
;	ev26
;	ev27
;	ev28
;	ev29
;	ev2a
;	ev2b
;	ev2c
;	ev2d
;	ev2e
;	ev2f
;	ev30
;	ev31
;	ev32
;	ev33
;	ev34
;	ev35
;	ev36
;	ev37
	
;	ENDC
	
;	else
	
;	error "EVBLK_SZ must be 16 or 32"
;	end
;	endif
	
;	endif

;**************************************************************************
;
;	learn an event
;
;	The event must be in ev0, ev1, ev2 & ev3
;	The EV index in EVidx, zero based!!
;	and the value in EVdata
;
; define FLIM_ONLY for modules that do not support SLiM mode

learn
#ifdef	FLIM_ONLY
	bra	learna
#else
	btfsc	Mode,1
	bra		learna
	btfss	UNLPORT,UNLEARN	;don't do if unlearn
	retlw	0
	bra		learnb
#endif
	
learna
	btfsc	Datmode, 5		;don't do if unlearn
	retlw	0

learnb		; data is in ev(n), EVdata and EVidx
	call	enmatch	
	sublw	0
	bnz		newev
	call	rdfbev			;read events data
		
	; sort out EVs here
lrnevs	
	btfsc	initFlags,0
	bra		lrnevs1		;j if initialising event data
#ifndef		FLIM_ONLY
	btfss	Mode,1		;FLiM mode?
	bra		lrns
#endif

lrnevs1
	movf	EVidx,w		;FLiM mode or init, just write new ev to event data
	movff	EVdata, PLUSW0
	call	wrfbev		; write back to flash
	btfsc	initFlags,0
	retlw	0			;dont send WRACK on initialisation
	movlw	0x59
	call	nnrel		;send WRACK
	retlw	0

#ifndef	FLIM_ONLY	
lrns				;learn event values in SLiM mode
	call	getop	;returns switch data in EVtemp
	movff	EVtemp, EVtemp1	;make a copy
	movf	EVtemp1,W
	iorwf	INDF0,W
	movwf	POSTINC0	;write back to EV
	movwf	EVtemp		;save for testing
	btfsc	POLPORT, POL
	bra		lrns2
	movf	EVtemp1,w	;recover output bit
	iorwf	INDF0		;or in POL bit
lrns1
	movff	INDF0,EVtemp2		;save for testing
	call	wrfbev		;write back to flash
	retlw	0
	
lrns2
	comf	EVtemp1,w
	andwf	INDF0		;remove POL bit
	bra		lrns1
#endif
	
newev		
	; check remaining space

	clrf	EEADRH
	movlw	LOW ENindex
	movwf	EEADR
	call	eeread
	sublw	0
	bnz		lrn1
	retlw	1		; no space left
	
lrn1

	clrf	EEADRH
	movlw	LOW FreeCh	; get free chain pointer
	movwf	EEADR
	call	eeread
	movwf	evaddrh
	movlw	LOW FreeCh + 1
	movwf	EEADR
	call	eeread
	movwf	evaddrl
	
	; now check and update hash table pointer
	tstfsz	htaddrh
	bra		lrnhtok
	bra		newev2		;j if no hash table for this event

lrnhtok				; hash table pointer is valid so read data
	call	rdfbht		; read from hash table address
	movf	htaddrl, w
	call	setFsr0
	movlw	6
	addwf	FSR0L
	movff	evaddrh, POSTINC0
	movff	evaddrl, POSTINC0
	call	wrfbht		; write back using hash table address
	
newev2		; read free chain data block
	call	rdfbev		; read free chain entry	
	movf	evaddrl, w
	call	setFsr0
	movlw	4
	addwf	FSR0L		;point at nextnh
	
	; now update FreeCh with next event pointer from event data

	clrf	EEADRH
	movlw	LOW FreeCh
	movwf	EEADR
	movf	POSTINC0,W
	call	eewrite
	
	movlw	LOW FreeCh+1
	movwf	EEADR
	movf	POSTINC0,W
	call	eewrite	
	
	; write new event address to hash table
	movff	htidx, EEADR
	movf	evaddrh,w
	call	eewrite
	incf	EEADR
	movf	evaddrl,w
	call	eewrite

	movf	evaddrl, W
	call	setFsr0
	movff	ev0,POSTINC0
	movff	ev1,POSTINC0
	movff	ev2,POSTINC0
	movff	ev3,POSTINC0
	movff	htaddrh, POSTINC0		; copy previous head of chain address
	movff	htaddrl, POSTINC0
	clrf	POSTINC0				; clear previous ptr
	clrf	POSTINC0
	
	movlw	EVENT_SZ
	movwf	CountFb0
	movlw	0
	
newev3
	clrf	PLUSW0			; clear event data, leave FSR0 alone
	incf	WREG
	decfsz	CountFb0
	bra		newev3
	
	movf	hnum,w				; hash number of event
	addlw	LOW hashnum			; update count of events in this hash
	movwf	EEADR
	call	eeread
	incf	WREG
	call	eewrite
	
	movlw	LOW ENindex + 1		;update number of events
	movwf	EEADR
	call	eeread
	addlw	1
	call	eewrite
	decf	EEADR
	call	eeread
	decf	WREG
	call	eewrite				;update remaining space
	bra		lrnevs

;**************************************************************************
;
;	unlearn an event
;	The event must be in ev0, ev1, ev2 & ev3

unlearn			; on entry the target event number must be in ev0-3
	call	enmatch
	sublw	0
	bz		unl1			; j if event found
	return
	
unl1

	clrf	EEADRH
	movlw	LOW FreeCh		; get free chain address
	movwf	EEADR
	call	eeread
	movwf	freadrh
	movlw	LOW FreeCh+1
	movwf	EEADR
	call	eeread
	movwf	freadrl
	
	call	rdfbev				; read entry
	movf	evaddrl,W
	call	setFsr0				;point FSR0 at relevant data
	movlw	4
	addwf	FSR0L				;adjust to point at nextnh
	movff	INDF0, nextadrh		;save chain pointers
	movff	freadrh,POSTINC0	; set next ptr to current free chain
	movff	INDF0, nextadrl		; ditto with ls addr
	movff	freadrl, POSTINC0
	movff	INDF0, prevadrh		;save prevnh
	clrf	POSTINC0			; clear previous entry ponter
	movff	INDF0, prevadrl		;save prevnl
	clrf	POSTINC0

	movlw	LOW FreeCh		; update free chain address to current entry
	movwf	EEADR
	movf	evaddrh,w
	call	eewrite
	movlw	LOW FreeCh+1
	movwf	EEADR
	movf	evaddrl,w
	call	eewrite
	
	call	wrfbev			; write freed event data back
	
	tstfsz	prevadrh		; check if previous link id valid
	bra		unl2			; j if it is
	bra		unl3

unl2						; read and update previous event entry
	movff	prevadrh, evaddrh
	movff	prevadrl, evaddrl
	call	rdfbev
	movf	evaddrl,W
	call	setFsr0				;point FSR0 at relevant data
	movlw	4
	addwf	FSR0L
	movff	nextadrh, POSTINC0
	movff	nextadrl, POSTINC0
	call	wrfbev			; write back with updated next pointer
	
unl3						;must write next ptr to hash table
	movff	htidx, EEADR
	movf	nextadrh,w
	call	eewrite
	incf	EEADR
	movf	nextadrl,w
	call	eewrite

	tstfsz	nextadrh		; check if next link is valid
	bra		unl4			; j if it is
	bra		unl5			; no more to do
	
unl4
	movff	nextadrh, evaddrh
	movff	nextadrl, evaddrl
	call	rdfbev
	movf	evaddrl,W
	call	setFsr0				;point FSR0 at relevant data
	movlw	6
	addwf	FSR0L				;adjust to point at prevnh
	movff	prevadrh, POSTINC0
	movff	prevadrl, POSTINC0
	call	wrfbev

unl5
	movf	hnum, w				; hash number of event
	addlw	LOW hashnum			; update number of events for this hash
	movwf	EEADR
	call	eeread
	decf	WREG
	call	eewrite

	movlw	LOW ENindex + 1			;update no of events and free space 
	movwf	EEADR
	call	eeread
	decf	WREG
	call	eewrite					;no of events
	decf	EEADR
	call	eeread
	addlw	1
	call	eewrite					;free space
	return
	
;**************************************************************************
;
; checks if Free Chain exists, if not then creates it

chkevdata
	clrf	initFlags
	clrf	EEADRH
	movlw	LOW FreeCh
	movwf	EEADR
	call	eeread			;get free chain ptr ms
	movwf	Temp
	incf	EEADR
	call	eeread			;get free chain ptr ls
	iorwf	Temp			;total should be non-zero (v1b RH)
	tstfsz	Temp			; (v1b RH)
	return					; return if FreeCh is non-zero
	call	initevdata
	return					;Free chain set up so do nothing
	

;**************************************************************************
;
; clear all events and associated data structures
; Each event is stored as a 16 byte entity
; Bytes 0-3 are the event number
; Bytes 4-5 are the pointer to the next entry, 0 if none
; Bytes 6-7 are the pointer to the previous entry, 0 if none
; Bytes 8-15 contain the events data, usage depends on the actual module
;
; creates the free chain and initialises next and previous pointers
; in each entry
; clears the event data for each event in the free chain

initevdata		; clear all event info
	clrf	EEADRH		
	movlw	LOW	ENindex+1		;clear number of events
	movwf	EEADR
	movlw	0
	call	eewrite			; no events set up
	movlw	EN_NUM
	decf	EEADR
	call	eewrite			; set up no of free events

	movlw	HASH_SZ * 2
	movwf	Count	
	movlw	LOW hashtab
	movwf	EEADR
	
nextht						; clear hashtable
	movlw	0
	call	eewrite
	incf	EEADR
	decfsz	Count
	bra		nextht
	
	movlw	HASH_SZ
	movwf	Count
	movlw	LOW hashnum
	movwf	EEADR
	
nexthn						; clear hash table count
	movlw	0
	call	eewrite
	incf	EEADR
	decfsz	Count
	bra		nexthn
	
	call	clrev		; erase all event data
	movlw	LOW FreeCh	; set up free chain pointer in ROM
	movwf	EEADR
	movlw	HIGH evdata
	movwf	evaddrh
	call	eewrite
	movlw	LOW FreeCh + 1
	movwf	EEADR
	movlw	0
	movwf	evaddrl
	call	eewrite
	call	clrfb
	clrf	prevadrh
	clrf	prevadrl
	
	movlw	EN_NUM
	movwf	Count		; loop for all events

nxtblk
	movff	evaddrl, Temp
	movff	evaddrh, Temp1
nxtevent
	movf	Temp,W
	call	setFsr0
	movlw	BLK_SZ
	addwf	Temp
	movlw	0
	addwfc	Temp1
	clrf	POSTINC0
	clrf	POSTINC0
	clrf	POSTINC0
	clrf	POSTINC0
	decf	Count
	bz		lastev		; j if final event
	movff	Temp1,POSTINC0
	movff	Temp, POSTINC0
	movff	prevadrh, POSTINC0
	movff	prevadrl, POSTINC0
	movff	evaddrh, prevadrh
	movff	evaddrl, prevadrl
	movf	Count,w
	andlw	(ERASE_SZ/BLK_SZ)-1
	bz		nxtevent1
	movlw	BLK_SZ	
	addwf	evaddrl		; move on to next 16 byte block
	movlw	0
	addwfc	evaddrh	
	bra		nxtevent
nxtevent1
	call	wrfbev
	movlw	BLK_SZ	
	addwf	evaddrl		; move on to next 64 byte block
	movlw	0
	addwfc	evaddrh	
	bra		nxtblk
	
lastev	
	clrf	Temp
	movff	Temp,POSTINC0
	movff	Temp,POSTINC0
	movff	prevadrh,POSTINC0
	movff	prevadrl, POSTINC0
	call	wrfbev
	return

	
;**************************************************************************
;
; routines for reading the event data

rdfbht		; on entry htaddrh and htaddrl must point to valid entry
	movlw	0xc0
	andwf	htaddrl,w		; align to 64 byte boundary
	movwf	TBLPTRL
	movf	htaddrh,w
	movwf	TBLPTRH
	movlw	ERASE_SZ
	movwf	CountFb0
	bra		rdfb
	
rdfbev		; On entry evaddrh and evaddrl must point to the correct entry
	movlw	0xc0
	andwf	evaddrl,w		; align to 64 byte boundary
	movwf	TBLPTRL
	movf	evaddrh,w
	movwf	TBLPTRH
	clrf	TBLPTRU
	movlw	ERASE_SZ
	movwf	CountFb0
rdfb
	clrf	TBLPTRU
	movff	FSR0H, Saved_Fsr0H	;must preserve FSR0
	movff	FSR0L, Saved_Fsr0L
	lfsr	FSR0,evt00
nxtfbrd
	tblrd*+
	movf	TABLAT, w
	movwf	POSTINC0
	decfsz	CountFb0
	bra		nxtfbrd
	movff	Saved_Fsr0L, FSR0L	;recover FSR0
	movff	Saved_Fsr0H, FSR0H
	return
	
rdfbevblk
	clrf	TBLPTRU
	movff	evaddrh, TBLPTRH
	movff	evaddrl, TBLPTRL
	movlw	BLK_SZ
	movwf	CountFb0
	bra		rdfb
	
rdfbev16		; read 16 bytes of event data, on entry evaddrh and evaddr must be valid
	clrf	TBLPTRU
	movff	evaddrh, TBLPTRH
	movff	evaddrl, TBLPTRL
	movlw	.16
	movwf	CountFb0
	bra		rdfb
	
rdfbev8		; read first 8 bytes of event data, on entry evaddrh and evaddr must be valid
	clrf	TBLPTRU
	movff	evaddrh, TBLPTRH
	movff	evaddrl, TBLPTRL
	movlw	8
	movwf	CountFb0
	bra		rdfb

;**************************************************************************
;
;	routine for finding an event - returns 0 on success, 1 on failure
;	If successful, FSR0 points at the event data

enmatch		;on exit if success w = 0 and evaddrh/evaddrl point at led data
	movf	ev1,W		;ls NN byte
	xorwf	ev3,W		; exclusive or with ls EV byte
	andlw	0x1f		;ls 5 bits as hash
	movwf	Temp
	movwf	hnum
	rlncf	Temp		; times 2 as hash tab is 2 bytes per entry	
	clrf	EEADRH
	movlw	LOW hashtab
	addwf	Temp, w
	movwf	htidx		; save EEPROM offset of hash tab entry
	movwf	EEADR
	call	eeread
	movwf	evaddrh
	movwf	htaddrh		; save hash table point ms
	incf	EEADR
	call	eeread
	movwf	evaddrl
	movwf	htaddrl		; save hash table pointer ls
nextev
	tstfsz	evaddrh		;is it zero?, high address cannot be zero if valid
	bra		addrok
	retlw	1			; not found
	
addrok
	movf	evaddrl,w
	movwf	TBLPTRL
	movf	evaddrh,w
	movwf	TBLPTRH
	clrf	TBLPTRU
	
	clrf	Match
	tblrd*+
	movf	TABLAT,W
	cpfseq	ev0
	incf	Match
	tblrd*+
	movf	TABLAT,W
	cpfseq	ev1
	incf	Match
	tblrd*+
	movf	TABLAT,W
	cpfseq	ev2
	incf	Match
	tblrd*+
	movf	TABLAT,W
	cpfseq	ev3
	incf	Match
	tstfsz	Match
	bra		no_match
	movf	evaddrl,w
	call	setFsr0
	movlw	8
	addwf	FSR0L		;leave FSR0 pointing at EVs
	retlw	0
	
no_match		;get link address to next event
	tblrd*+
	movf	TABLAT,w
	movwf	evaddrh
	tblrd*+
	movf	TABLAT,w
	movwf	evaddrl
	bra		nextev
	


;**************************************************************************
;
; routines for clearing flash ram
	
clrev		; erase all of the event data area in flash
	movlw	EN_NUM/EVSPER_BLK
	movwf	Count		; 4 events per 64 bytes
	movlw	LOW evdata
	movwf	TBLPTRL
	movlw	high evdata
	movwf	TBLPTRH
	clrf	TBLPTRU
nxtclr
	call	clrflsh
	decfsz	Count
	bra		nxtblock
	return
nxtblock
	movlw	ERASE_SZ
	addwf	TBLPTRL,F
	movlw	0
	addwfc	TBLPTRH
	bra		nxtclr
	
clrflsh		; clears 64 bytes of flash ram, TBLPTR must point to target ram
	bsf		EECON1,EEPGD		;set up for erase
	bcf		EECON1,CFGS
	bsf		EECON1,WREN
	bsf		EECON1,FREE
	movff	INTCON,TempINTCON
	clrf	INTCON	;disable interrupts
	movlw	0x55
	movwf	EECON2
	movlw	0xAA
	movwf	EECON2
	bsf		EECON1,WR			;erase
	nop
	nop
	nop
	movff	TempINTCON,INTCON	;reenable interrupts

	return
	
clrfb		; clears the 64 bytes data ram for ev data
	lfsr	FSR0, evt00
	movlw	ERASE_SZ
	movwf	CountFb0
nxtone
	clrf	POSTINC0
	decfsz	CountFb0
	bra		nxtone
	return

;**************************************************************************
;
;	routines fot writing flash
;
; erases flash ram and the writes data back
; writes the 64 bytes of data ram back to flash ram

wrfbht
	; htaddrh and htaddrl must contain the flash address on entry
	movlw	0xc0
	andwf	htaddrl,w		; align to 64 byte boundary
	movwf	TBLPTRL
	movf	htaddrh, W
	movwf	TBLPTRH
	bra		wrfb
	
	; erases flash ram and the writes data back
	; writes the 64 bytes of data ram back to flash ram
	
	; evaddrh and evaddrl must contain the flash address on entry
wrfbev
	movlw	0xc0
	andwf	evaddrl,w		; align to 64 byte boundary
	movwf	TBLPTRL
	movf	evaddrh, W
	movwf	TBLPTRH
	
wrfb
	clrf	TBLPTRU
	call	clrflsh
	lfsr	FSR0, evt00

	movlw	ERASE_SZ-1			;first 63 bytes
	movwf	CountFb0
nxtfb
	movf	POSTINC0, W
	movwf	TABLAT
	tblwt*+
	decfsz	CountFb0
	bra 	nxtfb
	movf	POSTINC0,W
	movwf	TABLAT
	tblwt*				; must leave TBLPTR pointing into 64 byte block
	call 	wrflsh
	return
	
wrflsh		; write 64 bytes of flash	
	bsf		EECON1, EEPGD
	bcf		EECON1,CFGS
	bcf		EECON1,FREE			;no erase
	bsf		EECON1, WREN
	movff	INTCON,TempINTCON
	clrf	INTCON
	movlw	0x55
	movwf	EECON2
	movlw	0xAA
	movwf	EECON2
	bsf		EECON1,WR
	nop
	movff	TempINTCON,INTCON
	return
	
;**************************************************************************
;
; setFsr0 
; Om entry w contains the Flash address of the event
; FSR0 is set to point to the correct block of event data in RAM
; data is not copied to ram by this routine

	if EVBLK_SZ == .16
setFsr0
	swapf	WREG
	andlw	0x03
	tstfsz	WREG
	bra 	nxtev1
	lfsr	FSR0, evt00
	return
nxtev1
	decf	WREG
	tstfsz	WREG
	bra		nxtev2
	lfsr	FSR0, evt10
	return
nxtev2
	decf	WREG
	tstfsz	WREG
	bra		nxtev3
	lfsr	FSR0, evt20
	return
nxtev3
	lfsr	FSR0, evt30
	return	
	
	else
setFsr0
	andlw	0x20
	bnz	nxtev1
	lfsr	FSR0, evt00
	return
	
nxtev1
	lfsr	FSR0, evt10
	return
	
	endif
		
		

;**************************************************************************
;
; read event variable, ev0, ev1, ev2, ev3 & EVidx must be set
	
readev
	call	enmatch
	sublw	0
	bz		readev1			; j if event found
	clrf	EVdata
	clrf	EVidx
	bra		endrdev
	
readev1
	movf	EVidx,w
	bz		noens			;check for zero index
	decf	EVidx
	movlw	EV_NUM
	cpfslt	EVidx			; skip if in range
	bra		noens
	call	rdfbevblk		; get 16 bytes of event data
	lfsr	FSR0, ev00		; point at EVs
	movf	EVidx,w
	movf	PLUSW0,w		; get the byte
	movwf	EVdata
	incf	EVidx			; put back to 1 based
	
endrdev
	movlw	0xD3
	movwf	Tx1d0
	movff	evt00,Tx1d1
	movff	evt01,Tx1d2
	movff	evt02,Tx1d3
	movff	evt03,Tx1d4
	movff	EVidx,Tx1d5
	movff	EVdata,Tx1d6
	movlw	7
	movwf	Dlc
	call	sendTXa
	return
	
;*************************************************************************

;		read back all events in sequence

enread	clrf	Temp
		movlw	LOW ENindex+1
		movwf	EEADR
		call	eeread
		sublw	0
		bz		noens		;no events set
		
		clrf	Tx1d7		; first event
		movlw	HASH_SZ			; hash table size
		movwf	ENcount	
		movlw	LOW hashtab
		movwf	EEADR
nxtht
		call	eeread
		movwf	evaddrh
		incf	EEADR
		call	eeread
		movwf	evaddrl
nxten
		tstfsz	evaddrh		; check for valid entry
		bra		evaddrok
nxthtab
		decf	ENcount
		bz		lasten
		incf	EEADR
		bra		nxtht
		
evaddrok					; ht address is valid
		call	rdfbev8		; read 8 bytes from event info
		incf	Tx1d7
		movff	evt00, Tx1d3
		movff	evt01, Tx1d4
		movff	evt02, Tx1d5
		movff	evt03, Tx1d6
		
		movlw	0xF2
		movwf	Tx1d0
		movlw	8
		movwf	Dlc
		call	sendTX
		call	dely
		call	dely
		
		movff	next0h, evaddrh
		movff	next0l,	evaddrl
		bra		nxten

noens	movlw	7				;no events set
		call	errsub
		return
	
lasten	return	

;*************************************************************************
;
;	findEN - finds the event by its index

findEN					; ENidx must be valid and in range
		clrf	hnum
		clrf	ENcount
		clrf	ENcount1
findloop
		movf	hnum,w
		addlw	LOW hashnum
		movwf	EEADR
		call	eeread
		addlw	0
		bz		nxtfnd
		addwf	ENcount1
		movf	ENcount1,w
		cpfslt	ENidx		;skip if ENidx < ENcount1
		bra		nxtfnd
		bra		htfound
nxtfnd
		movff	ENcount1, ENcount
		incf	hnum
		bra		findloop
htfound
		rlncf	hnum,w
		addlw	LOW hashtab
		movwf	EEADR
		call	eeread
		movwf	evaddrh
		incf	EEADR
		call	eeread
		movwf	evaddrl
nxtEN
		movf	ENidx,w
		cpfslt	ENcount
		return
		
nxtEN1
		incf	ENcount
		call	rdfbev8
		movff	next0h, evaddrh
		movff	next0l, evaddrl
		bra		nxtEN
		
;*************************************************************************

;	send individual event by index, ENidx must contain index

enrdi	movlw	LOW ENindex+1	; no of events set
		movwf	EEADR
		call	eeread
		sublw	0
		bz		noens1		;no events set
		
		movf	ENidx,w		; index starts at 1
		bz		noens1
		
		decf	ENidx		; make zero based for lookup
		movlw	LOW ENindex+1
		movwf	EEADR
		call	eeread		; read no of events
		cpfslt	ENidx		; required index is in range
		bra		noens1
		
		call	findEN
		call	rdfbev8		; get event data
		
		movff	evt00, Tx1d3
		movff	evt01, Tx1d4
		movff	evt02, Tx1d5
		movff	evt03, Tx1d6
		incf	ENidx
		movff	ENidx, Tx1d7
		movlw	0xF2
		movwf	Tx1d0
		movlw	8
		movwf	Dlc
		call	sendTX
		return
		
noens1	movlw	7				;inavlid event index
		call	errsub
		return
		
;***********************************************************

;		send EVs by reference to EN index, ENidx must be set

evsend
		movlw	LOW ENindex+1	; no of events set
		movwf	EEADR
		call	eeread
		sublw	0
		bz		noens1		;no events set
		
		movf	ENidx,w		; index starts at 1
		bz		noens1
		
		decf	ENidx		; make zero based for lookup
		movlw	LOW ENindex+1
		movwf	EEADR
		call	eeread		; read no of events
		cpfslt	ENidx		; required index is in range
		bra		noens1
		
		movf	EVidx,w		; index starts at 1
		bz		notEV		; zero is invalid
		decf	EVidx
		movlw	EV_NUM
		cpfslt	EVidx		; skip if in range
		bra		notEV
		
		call	findEN
		
		call	rdfbevblk	; read event data
		lfsr	FSR0,ev00
		movf	EVidx,w
		movff	PLUSW0, Tx1d5
		incf	EVidx		; make 1 based again...
		incf	ENidx		; ... ditto
		movlw	0xB5
		movwf	Tx1d0
		movff	ENidx,Tx1d3
		movff	EVidx,Tx1d4
		movlw	6
		movwf	Dlc
		call	sendTX
		return

notEV	movlw	6		;invalid EN#
		call	errsub
		return

;***********************************************************

;		send free event space


rdFreeSp
		movlw	LOW ENindex		;read free space
		movwf	EEADR
		call	eeread
		movwf	Tx1d3
		movlw	0x70
		movwf	Tx1d0
		movlw	4
		movwf	Dlc
		call	sendTX
		return
		
;************************************************************************
		
;		send number of events

evnsend
		movlw	LOW ENindex+1
		movwf	EEADR
		call	eeread
		movwf	Tx1d3
		movlw	0x74
		movwf	Tx1d0
		movlw	4
		movwf	Dlc
		call	sendTX
		return