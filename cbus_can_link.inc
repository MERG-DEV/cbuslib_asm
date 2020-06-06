;******************************************************************************
;   High priority interrupt. Used for CAN receive and transmit error.

high_priority_interrupt_routine
  movff   CANSTAT, TempCANSTAT

	; Save registers to protect during interrupt
	movff   FSR2L, HPInt_FSR2L
	movff   FSR2H, HPInt_FSR2H
	movff   FSR1L, HPInt_FSR1L
	movff   FSR1H, HPInt_FSR1H

  movlw high cstatab
  movwf PCLATH
  movf  TempCANSTAT,W
  andlw B'00001110'
  addwf PCL,F

cstatab
  bra   exit_high_priority_interrupt
  bra   errint
  bra   exit_high_priority_interrupt
  bra   exit_high_priority_interrupt
  bra   exit_high_priority_interrupt
  bra   copy_rx_buffer1
  bra   copy_rx_buffer0
  bra   exit_high_priority_interrupt


  ; Error handling here, only acts on lost Tx arbitration
errint
  movlb   15                            ; Select RAM bank 15
  btfss   TXB1CON, TXLARB
  bra     exit_error_interrupt

  decfsz  tx_arbitration_count,F
  bra     exit_error_interrupt

  movlw   B'00111111'
  andwf   TXB1SIDH,F                    ; Change priority of transmitted frame

exit_error_interrupt
  bcf     RXB1CON, RXFUL
  movlb   0                             ; Select RAM bank 0
  bcf     RXB0CON, RXFUL
  bcf     COMSTAT, RXB0OVFL
  bcf     COMSTAT, RXB1OVFL
  bra     exit_high_priority_interrupt

copy_rx_buffer1
  bcf     PIR3, RXB1IF
  lfsr    FSR1, RXB1D7                  ; Source for received buffer copy
  bra     copy_rx_buffer

copy_rx_buffer0
  bcf     PIR3, RXB0IF
  lfsr    FSR1, RXB0D7                  ; Source for received buffer copy

copy_rx_buffer
  ; Copy relevant Rx buffer into working RAM
  lfsr    FSR2, Rx_d7                   ; Destination for received buffer copy

unload_rx_buffer
  movff   POSTDEC1, POSTDEC2
  movlw   Rx_sidh                       ; Test for end of Rx copy ...
  cpfseq  FSR2L                         ; ... skip if reached ...
  bra     unload_rx_buffer              ; ... else keep copying

  movff   POSTDEC1, INDF2               ; Copy last byte
  bcf     INDF1, RXFUL                  ; Mark Rx buffer available for use

  btfsc   Rx_dlc, RXRTR                 ; Skip if not received an RTR
  bra     respond_to_RTR

  Skip_If_Not_Enumerating
  bra     record_received_can_id

  movf    Rx_dlc,F                      ; Test length of received data ...
  btfss   STATUS, Z                     ; ... do nothing if zero

  Skip_If_New_Rx_Message
  Set_New_Rx_Message

#ifdef AUTOID
  ; Include automatic CAN ID enumeration (may cause problems with CANCAN)
  Skip_If_FLiM
  bra     exit_high_priority_interrupt  ; Don't do Can ID check if SLiM mode

  ; Check for ID conflict
  movf    Rx_sidh,W
  xorwf   Tx_sidh,W
  andlw   0x0f
  bnz     exit_high_priority_interrupt

  movf    Rx_sidl,W
  xorwf   Tx_sidl,W
  andlw   0xe0
  bnz     exit_high_priority_interrupt

  bsf     Datmode, MD_IDCONF
#endif

exit_high_priority_interrupt
  movlw   B'00000011'
  andwf   PIR3                          ; Clear all but Rx interrupt flags

  ; Restore registers to protected during interrupt
  movff   HPInt_FSR1L, FSR1L
  movff   HPInt_FSR1H, FSR1H
  movff   HPInt_FSR2L, FSR2L
  movff   HPInt_FSR2H, FSR2H

  retfie  1                             ; Restore from shadow registers


respond_to_RTR
  Skip_If_Not_Enumerating
  bra     exit_high_priority_interrupt

  Skip_If_FLiM
  bra     exit_high_priority_interrupt

  movlb   15                            ; Select RAM bank 15

RTR_response_Tx_wait
  btfsc   TXB2CON, TXREQ
  bra     RTR_response_Tx_wait

  bsf     TXB2CON, TXREQ
  movlb   0                             ; Select RAM bank 0
  bra     exit_high_priority_interrupt


record_received_can_id
  tstfsz  Rx_dlc                        ; Only zero length frames for setup
  bra     exit_high_priority_interrupt

  ; Get received CAN Id into a single byte
  swapf   Rx_sidh,W
  rrcf    WREG
  andlw   B'01111000'
  movwf   Temp
  swapf   Rx_sidl,W
  rrncf   WREG
  andlw   B'00000111'
  iorwf   Temp,W
  movwf   received_can_id

  lfsr    FSR1, in_use_can_ids          ; Reference used CAN Id bitmask table
  clrf    received_can_id_bitmask       ; Initialise bitmask ...
  bsf     received_can_id_bitmask,0     ; ... to 0000 0001
  movlw   8                             ; Bits in each bitmask table byte

find_received_can_id_byte
  cpfsgt  received_can_id               ; Skip if CAN Id greater than eight ...
  bra     find_received_can_id_bit      ; ... else found byte, now find bit

  subwf   received_can_id,F             ; Reduce received CAN Id by eight
  incf    FSR1L                         ; Move on to next byte in bitmap table
  bra     find_received_can_id_byte

find_received_can_id_bit
  dcfsnz  received_can_id,F
  bra     found_received_can_id_bit

  rlncf   received_can_id_bitmask,F     ; Shift bitmask one bit left
  bra     find_received_can_id_bit

found_received_can_id_bit
  movf    received_can_id_bitmask,W     ; Set bit for received CAN Id ...
  iorwf   INDF1,F                       ; ... in bitmap table
  bra     exit_high_priority_interrupt



;******************************************************************************
set_link_id
  movff   ev2, unused_can_id
  call    update_link_id
  call    send_node_number_acknowledge
  bra     main_loop



;******************************************************************************
force_self_enumeration
  call    self_enumerate
  call    send_node_number_acknowledge
  bra     main_loop



;******************************************************************************
;   Find an unused CAN Id to adopt for self, report an error if non available

self_enumerate
  ; Enable high and low priority interrupts
  movlw   B'11000000'
  movwf   INTCON

  Set_Enumerating

  movlw   14
  movwf   loop_counter
  lfsr    FSR0, in_use_can_ids

clear_in_use_can_ids_loop
  clrf    POSTINC0
  decfsz  loop_counter
  bra     clear_in_use_can_ids_loop

  ; Set up RTR frame for transmission with fixed default CAN Id
  movlw   B'10111111'
  movwf   Tx_sidh
  movlw   B'11100000'
  movwf   Tx_sidl
  movlw   B'01000000'
  movwf   Tx_dlc

  ; Set 100 mSec timer to allow other nodes to report their CAN Ids
  movlw   0x3C
  movwf   TMR3H
  movlw   0xAF
  movwf   TMR3L
  movlw   B'10110001'
  movwf   T3CON

  call    tx_message                ; Send RTR frame
  clrf    Tx_dlc                    ; Prevent sending more RTR frames

self_enumeration_wait
  btfss   PIR2, TMR3IF
  bra     self_enumeration_wait

  ; Disable Timer3
  bcf     T3CON, TMR3ON
  bcf     PIR2, TMR3IF

  movlw   1
  movwf   unused_can_id             ; CAN Id starts at 1
  movwf   unused_can_id_bitmask     ; Initialise bitmask to 0000 0001
  lfsr    FSR0, in_use_can_ids      ; Reference used CAN Id bitmask table

find_unused_can_id_byte
  incf    INDF0,W                   ; Test current table byte ...
  bnz     find_unused_can_id_bit    ; ... jump if it contains at least one zero

  movlw   8
  addwf   unused_can_id,F           ; Increase CAN Id by eight
  incf    FSR0L                     ; Move on to next byte in bitmap table
  bra     find_unused_can_id_byte

find_unused_can_id_bit
  movf    unused_can_id_bitmask,W
  andwf   INDF0,W
  bz      update_link_id

  rlcf    unused_can_id_bitmask,F   ; Shift bitmask one bit left
  incf    unused_can_id,F           ; Increment CAN Id
  bra     find_unused_can_id_bit

update_link_id
  movlw   MAXIMUM_NUMBER_OF_CAN_IDS
  cpfslt  unused_can_id
  bra     can_segment_full

store_link_id
  movlw   low CANid
  movwf   EEADR
  movf    unused_can_id,W
  call    write_ee
  call    reload_tx_sid_and_node_number
  Unset_Enumerating

  return

can_segment_full
  movlw   CMDERR_INVALID_EVENT
  call    send_error_message
  setf    unused_can_id
  bcf     unused_can_id,7
  bra     store_link_id



;******************************************************************************
;   Send message after adding CAN Standard Identifier

tx_message
  movlw   B'00001111'       ; Clear priority of previous transmission
  andwf   Tx_sidh,F
  movlw   B'10110000'
  iorwf   Tx_sidh,F         ; Set low transmission priority
  movlw   10
  movwf   tx_arbitration_count

  ; Send contents of Tx_ buffer via CAN TXB1
  lfsr    FSR1, TXB1CON

tx_wait
  btfsc   INDF1, TXREQ    ; Skip if Tx buffer available ...
  bra     tx_wait         ; ... otherwise wait

  lfsr    FSR0, Tx_d7
  lfsr    FSR1, TXB1D7

load_tx_buffer
  movff   POSTDEC0, POSTDEC1
  movlw   Tx_sidh
  cpfseq  FSR0L
  bra     load_tx_buffer
  movff   INDF0, POSTDEC1 ; Copy last byte

  bsf     INDF1, TXREQ

  return
