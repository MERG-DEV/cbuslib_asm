
; CBUS definitions for use in PIC assembler

; These definitions taken from CBUS specifications document rev 7e
; Pete Brownlow  6 April 2011

; Manufacturers

MANU_MERG	equ	.165


; Module types

MTYP_SLIM       equ 0   ; default NN for SLiM nodes
MTYP_CANACC4    equ 1	; Solenoid point driver
MTYP_CANACC5    equ 2	; Motorised point driver
MTYP_CANACC8    equ 3	; 8 digital outputs
MTYP_CANACE3    equ 4	; Control panel switch/button encoder
MTYP_CANACE8C   equ 5	; 8 digital inputs
MTYP_CANLED     equ 6	; 64 led driver
MTYP_CANLED64   equ 7	; 64 led driver (multi leds per event)
MTYP_CANACC4_2  equ 8	; 12v version of CANACC4  
MTYP_CANCAB     equ 9	; CANCAB hand throttle   
MTYP_CANCMD     equ 10	; CANCMD command station
MTYP_CANBC1a	equ 11	; BC1a command station


;  CBUS opcodes list 
;  Ref: CBUS Specifications rev 7d

; Packets with no data bytes

OPC_ACK     EQU 0x00    ; General ack
OPC_NAK     EQU 0x01    ; General nak
OPC_HLT     EQU	0x02    ; Bus Halt
OPC_BON     EQU	0x03    ; Bus on
OPC_TOF     EQU	0x04    ; Track off
OPC_TON     EQU	0x05    ; Track on
OPC_ESTOP   EQU	0x06    ; Track stopped
OPC_ARST    EQU	0x07    ; System reset
OPC_RTOF    EQU	0x08    ; Request track off
OPC_RTON    EQU	0x09    ; Request track on
OPC_RESTP   EQU	0x0a    ; Request emergency stop all
OPC_RVER    EQU 0x0b    ; Request firmware version
OPC_RSTAT   EQU 0x0c    ; Request node status
OPC_RQNN    EQU 0c0d    ; Request node number
OPC_RQNP    EQU 0x10    ; Read node parameters

; Packets with 1 data byte

OPC_STAT    EQU 0x20    ; Command station status report
OPC_KLOC    EQU 0x21    ; Release engine by handle
OPC_QLOC    EQU	0x22    ; Query engine by handle

OPC_DBG1    EQU 0x30    ; Debug message with 1 status byte
OPC_EXTC    EQU 0x3F    ; Extended opcode

; Packets with 2 data bytes

OPC_RLOC    EQU 0x40    ; Request session for loco
OPC_QCON    EQU	0x41    ; Query consist
OPC_SNN     EQU	0x42    ; Set node number
OPC_STMOD   EQU	0x44    ; Set Throttlle mode
OPC_PCON    EQU	0x45    ; Consist loco
OPC_KCON    EQU	0x46    ; De-consist loco
OPC_DSPD    EQU	0x47    ; Loco speed/dir
OPC_DFLG    EQU 0x48    ; Set engine flags
OPC_SSTAT   EQU	0x4C    ; Service mode status

OPC_NNACK	EQU	0x50    ; Node number acknowledge
OPC_NNREL	EQU	0x51    ; Node number release
OPC_NNREF	EQU	0x52    ; Node keepalive
OPC_NNLRN	EQU	0x53    ; Set learn mode
OPC_NNULN	EQU	0x54    ; Release learn mode
OPC_NNCLR	EQU	0x55    ; Clear all events
OPC_NNEVN	EQU	0x56    ; Read available event slots
OPC_NERD    EQU 0x57    ; Read all stored events
OPC_RQEVN   EQU 0x58    ; Read number of stored events
OPC_WRACK	EQU 0x59	; Write acknowledge
OPC_RQDAT	EQU	0x5A	; Request node data event
OPC_BOOT	EQU	0x5C    ; Put node into boot mode
OPC_EXTC1   EQU 0x5F    ; Extended opcode with 1 data byte

; Packets with 3 data bytes

OPC_DFUN    EQU	0x60    ; Set engine functions
OPC_ERR     EQU	0x63    ; Command station error
OPC_CMDERR  EQU 0x6F    ; Errors from nodes during config

OPC_EVNLF	EQU	0x70    ; Event slots left response
OPC_NVRD	EQU	0x71    ; Request read of node variable
OPC_NENRD   EQU 0x72    ; Reqeust read stored event by index
OPC_RQNPN	EQU	0x73	; Request read module paramters
OPC_NUMEV   EQU 0x74    ; Number of events stored response
OPC_EXTC2   EQU 0x7F    ; Extended opcode with 2 data bytes

; Packets with 4 data bytes

OPC_RDCC3   EQU	0x80    ; 3 byte DCC packet
OPC_WCVO    EQU	0x82    ; Write CV byte Ops mode by handle
OPC_WCVB    EQU	0x83    ; Write CV bit Ops mode by handle
OPC_QCVS    EQU	0x84    ; Read CV
OPC_PCVS    EQU	0x85    ; Report CV

OPC_ACON	EQU	0x90	; on event
OPC_ACOF	EQU	0x91	; off event
OPC_AREQ	EQU	0x92    ; Accessory request event
OPC_ARSPO   EQU 0x93    ; Accessory response event on
OPC_ARSPN   EQU 0x94    ; Accessory response event off
OPC_EVULN	EQU	0x95    ; Unlearn event
OPC_NVSET	EQU	0x96    ; Set a node variable
OPC_NVANS	EQU	0x97    ; Node variable value response
OPC_ASON	EQU	0x98    ; Short event on
OPC_ASOF	EQU	0x99    ; Short event off
OPC_ASRQ	EQU	0x9A    ; Short request event
OPC_PARAN   EQU 0x9B    ; Single node parameter response
OPC_REVAL   EQU 0x9C    ; Request read of event variable
OPC_EXTC3   EQU 0x9F    ; Extended opcode with 3 data bytes

; Packets with 5 data bytes

OPC_RDCC4   EQU	0xA0    ; 4 byte DCC packet
OPC_WCVS    EQU	0xA2    ; Write CV service mode

OPC_ACON1   EQU 0xB0    ; On event with one data byte
OPC_ACOF1   EQU 0xB1    ; Off event with one data byte
OPC_AREQ1	EQU	0xB2    ; Read event variable in learn mode
OPC_ARSP1O  EQU 0xB4    ; Accessory on response 
OPC_NEVAL   EQU 0xB5    ; Event variable by index read response
OPC_ARSP1N  EQU 0xB6    ; Accessory off response
OPC_EXTC4   EQU 0xBF    ; Extended opcode with 4 data bytes

; Packets with 6 data bytes

OPC_RDCC5   EQU	0xC0    ; 5 byte DCC packet
OPC_WCVOA   EQU	0xC1    ; Write CV ops mode by address

OPC_ACON2   EQU 0xD0    ; On event with two data bytes
OPC_ACOF2   EQU 0xD1    ; Off event with two data bytes
OPC_EVLRN	EQU	0xd2    ; Teach event
OPC_EVANS	EQU	0xd3    ; Event variable read response in learn mode
OPC_ARSP2O  EQU 0xD4    ; Accessory on response 
OPC_ARSP2N  EQU 0xD5    ; Accessory off response
OPC_EXTC5   EQU 0xBF    ; Extended opcode with 5 data bytes

; Packets with 7 data bytes

OPC_RDCC6  	EQU	0xE0    ; 6 byte DCC packets
OPC_PLOC	EQU	0xE1    ; Loco session report
OPC_ACDAT   EQU 0xE3    ; Accessory data event: 5 bytes of node data (eg: RFID)
OPC_ARDAT	EQU 0xE4	; Accessory data response
OPC_PARAMS	EQU	0xEF    ; Node parameters response

OPC_ACON3   EQU 0xF0    ; On event with 3 data bytes
OPC_ACOF3   EQU 0xF1    ; Off event with 3 data bytes
OPC_ENRSP	EQU	0xF2    ; Read node events response
OPC_ARSP3O  EQU 0xF3    ; Accessory on response 
OPC_ARSP3N  EQU 0xF4    ; Accessory off response
OPC_EVLRNI	EQU	0xF5    ; Teach event using event indexing

; Modes for STMOD

TMOD_SPD_MASK   EQU	3
TMOD_SPD_128    EQU	0
TMOD_SPD_14     EQU	1
TMOD_SPD_28I    EQU	2
TMOD_SPD_28     EQU	3

; Error codes for OPC_ERR
ERR_LOCO_STACK_FULL     EQU	1
ERR_LOCO_ADDR_TAKEN     EQU	2
ERR_SESSION_NOT_PRESENT EQU	3
ERR_NO_MORE_ENGINES     EQU	4
ERR_ENGINE_NOT_FOUND    EQU	5

; Status codes for OPC_SSTAT
SSTAT_NO_ACK    EQU	1
SSTAT_OVLD      EQU	2
SSTAT_WR_ACK    EQU	3
SSTAT_BUSY      EQU	4
SSTAT_CV_ERROR  EQU	5


