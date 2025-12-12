Configure_CAN_with_Rx_FIFO macro
  local   can_config_wait, clear_rx_masks_loop, can_normal_wait

  banksel CANCON
  bsf     CANCON,REQOP2     ; Request CAN module configure mode

can_config_wait
  movf    CANSTAT, W
  andlw   b'11100000'       ; Mask out all except operation mode bits
  xorlw   b'10000000'       ; Test for configuration mode
  tstfsz  WREG              ; Skip if in configuration mode ...
  bra     can_config_wait   ; ... else wait

  ; Set CAN bit rate and sample point

  movlw   b'00000011'       ; Synchronisation jump width = 1 Tq
                            ; Tq = 8/Fosc
  movwf   BRGCON1

  movlw   b'11011110'       ; Phase segment 2 freely programmable, SEG2PHTS
                            ; Bus sampled three times up to sample point
                            ; Phase segment 1 = 4 Tq
                            ; Propogation segment = 7 Tq
  movwf   BRGCON2

  movlw   b'00000011'       ; Enable bus activity wake up
                            ; Bus line filter not used for wake up
                            ; Phase segment 2 (4 Tq) but ignored as ...
                            ; ... SEG2PHTS is set so = Phase segment 1 (4 Tq)
  movwf   BRGCON3

  ; Sum of segments (syncronisation fixed at 1 Tq) = 16 Tq => 125,000 Kb/s, ...
  ; ... sample point is nominally 12 Tq = 75% of nominal bit time

  movlw   b'00100000'       ; CAN Tx to Vdd when recesive
                            ; Disable message capture
  movwf   CIOCON

  movlw   ECANMODE
  movwf   ECANCON

  movlw   b'00100100'       ; Receive valid messages as per acceptance filters
  movwf   RXB0CON

  clrf    RXB1CON           ; Receive valid messages as per acceptance filters

  clrf    RXF0SIDL
  clrf    RXF1SIDL

  lfsr    FSR0, RXM0SIDH    ; Clear Rx acceptance masks
  movlw   low RXM1EIDL + 1

clear_rx_masks_loop
  clrf    POSTINC0
  cpfseq  FSR0L
  bra     clear_rx_masks_loop

  clrf    CANCON            ; Request CAN module normal mode

can_normal_wait
  movf    CANSTAT, W
  andlw   b'11100000'       ; Mask out all except operation mode bits
  bnz     can_normal_wait   ; Loop if CAN module not in normal mode

  bcf     COMSTAT, RXB0OVFL ; Ensure overflow flags are clear
  bcf     COMSTAT, RXB1OVFL

  endm


;******************************************************************************
Handle_CAN_Tx_Error macro lost_arbitration_count
  local   at_raised_priority, raise_priority, error_done, not_can_tx_error

  banksel TXB1CON
  movlw   (1 << TXABT) | (1 << TXLARB) | (1 << TXERR)
  andwf   TXB1CON, W
  btfsc   STATUS, Z
  bra     not_can_tx_error

  btfss   TXB1CON, TXLARB
  bra     error_done

  incfsz  lost_arbitration_count, W
  movwf   lost_arbitration_count

  ; Bits 7 and 6 of SIDH used for Tx message priority,
  ;   10 = Normal, 01 = High, 00 = Top
  btfss   TXB1SIDH, SID10           ; Skip if priority is normal ...
  bra     at_raised_priority        ; ... else already at high or top priority

  movlw   CAN_LOST_ARBITRATION_LIMIT
  cpfsgt  lost_arbitration_count    ; Skip if need to raise priority
  bra     error_done
  bra     raise_priority

at_raised_priority
  btfss   TXB1SIDH, SID9            ; Skip if priority is high ...
  bra     error_done                ; ... else already at top priority

  movlw   CAN_LOST_ARBITRATION_LIMIT * 2
  cpfsgt  lost_arbitration_count    ; Skip if need to raise priority
  bra     error_done

raise_priority
  movlw   CAN_RAISE_SIDH_PRIORITY
  addwf   TXB1SIDH, F

error_done
  bsf     TXB1CON, TXREQ    ; Repeat transmission, clears CAN Tx error flags

not_can_tx_error

  endm


;******************************************************************************
If_Tx_Busy macro do_this

  banksel TXB1CON
  btfsc   TXB1CON, TXREQ
  do_this

  endm


;******************************************************************************
Tx_CBUS_Msg macro opcode, db0, db1, db2, db3, db4, db5, db6, sidh, sidl

  banksel TXB1D0
  movff   opcode, TXB1D0
  movff   db0, TXB1D1
  movff   db1, TXB1D2
  movff   db2, TXB1D3
  movff   db3, TXB1D4
  movff   db4, TXB1D5
  movff   db5, TXB1D6
  movff   db6, TXB1D7

  ; Number of bytes for transmission derived from opcode
  swapf   TXB1D0, W
  rrncf   WREG, W
  andlw   0x07
  incf    WREG, W
  movwf   TXB1DLC

  movlw   sidh
  movwf   TXB1SIDH
  movlw   sidl
  movwf   TXB1SIDL

  bsf     TXB1CON, TXREQ

  endm


;******************************************************************************
If_Rx_FIFO_Empty macro do_this

  btfss   COMSTAT, NOT_FIFOEMPTY
  do_this

  endm


;******************************************************************************
Rx_From_FIFO macro len, sidh, sidl, db0, db1, db2, db3, db4, db5, db6, db7

  ; Select next FIFO buffer
  movlw   0x07
  andwf   CANCON, W
  iorlw   ECANMODE
  movwf   ECANCON

  movff   RXB0DLC, len
  movff   RXB0SIDH, sidh
  movff   RXB0SIDL, sidl
  movff   RXB0D0, db0
  movff   RXB0D0, db1
  movff   RXB0D0, db2
  movff   RXB0D0, db3
  movff   RXB0D0, db4
  movff   RXB0D0, db5
  movff   RXB0D0, db6
  movff   RXB0D0, db7

  bcf     RXB0CON, RXFUL

  endm
