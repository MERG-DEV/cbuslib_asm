;Constant for CBUS code
;
;16-Apr-13 PJW Added CANSIG64/CANSIG8 equates
;
MTYP_SLIM       equ 0   ; default type code for SLiM nodes
MTYP_CANACC4    equ 1	; Solenoid point driver
MTYP_CANACC5    equ 2	; Motorised point driver
MTYP_CANACC8    equ 3	; 8 digital outputs
MTYP_CANACE3    equ 4	; Control panel switch/button encoder
MTYP_CANACE8C   equ 5	; 8 digital inputs
MTYP_CANLED     equ 6	; 64 led driver
MTYP_CANLED64   equ 7	; 64 led driver (multi leds per event)
MTYP_CANACC4_2  equ 8	; 12v version of CANACC4  
MTYP_CANCAB     equ 9	; CANCAB hand throttle   
MTYP_CANCMD     equ .10	; CANCMD command station
MTYP_CANSERVO   equ .11	; 8 servo driver (on canacc8 or similar hardware)
MTYP_CANBC      equ .12	; BC1a command station
MTYP_CANRPI     equ .13	; RPI and RFID interface
MTYP_CANTTCA    equ .14	; Turntable controller (turntable end)
MTYP_CANTTCB    equ .15 ; Turntable controller (control panel end)
MTYP_CANHS      equ .16	; Handset controller for old BC1a type handsets
MTYP_CANTOTI	equ .17	; Track occupancy detector
MTYP_CAN8I8O	equ .18	;8 input/8 output
MTYP_CANSERVO8C	equ .19	;Combi version of CANSERVO
MTYP_CANRFID	equ .20	;RFID module
MTYP_CANTC4	equ .21
MTYP_CANACE16C	equ .22	;16 input version of CANACE8C
MTYP_CANIO8	equ .23
MTYP_CANSNDx	equ .24
MTYP_CANETHER	equ .25	;Ethernet interface module
MTYP_CANSIG64	equ .26	;CANSIG firmware for CANLED64 hardware
MTYP_CANSIG8	equ .27	;CANSIG firmware for CANACC8 hardware
MTYP_CANBLANK	equ .254 ; Blank module for Bootloading only
MTYP_CANUSB	equ .253 ; USB module, only used for Bootloading


MANU_MERG       equ .165
MANU_ROCRAIL    equ .70

; Parameter index numbers (readable by OPC_RQNPN, returned in OPC_PARAN)
; Index numbers count from 1, subtract 1 for offset into parameter block
; Note that RQNPN with index 0 returns the parameter count

PAR_MANU      EQU   1    ; Manufacturer id
PAR_MINVER    EQU   2    ; Minor version letter
PAR_MTYP      EQU   3    ; Module type code
PAR_EVTNUM    EQU   4    ; Number of events supported
PAR_EVNUM     EQU   5    ; Event variables per event
PAR_NVNUM     EQU   6    ; Number of Node variables
PAR_MAJVER    EQU   7    ; Major version number
PAR_FLAGS     EQU   8    ; Node flags
PAR_CPUID     EQU   9    ; Processor type
PAR_BUSTYPE   EQU   .10   ; Bus type
PAR_LOAD      EQU   .11   ; load address, 4 bytes

; Offsets to other values stored at the top of the parameter block.
; These are not returned by opcode PARAN, but are present in the hex
; file for FCU.

PAR_COUNT    EQU    0x18 ; Number of parameters implemented
PAR_NAME     EQU    0x1A ; 4 byte Address of Module type name, up to 8 
			 ; characters null terminated
PAR_CKSUM    EQU    0x1E ; Checksum word at end of parameters

; Flags in PAR_FLAGS

PF_CONSUMER  equ    1
PF_PRODUCER  equ    2
PF_COMBI     equ    3
PF_FLiM      equ    4
PF_BOOT      equ    8

; BUS type that module is connected to

PB_CAN       equ    1
PB_ETH       equ    2

; Processor type codes (identifies to FCU for bootload compatiblity)

P18F2480     equ    1
P18F4480     equ    2
P18F2580     equ    3
P18F4580     equ    4
P18F2585     equ    5
P18F4585     equ    6
P18F2680     equ    7
P18F4680     equ    8
P18F2682     equ    9
P18F4682     equ    .10
P18F2685     equ    .11
P18F4685     equ    .12

P18F25K80    equ    .13
P18F45K80    equ    .14
P18F26K80    equ    .15
P18F46K80    equ    .16
P18F65K80    equ    .17
P18F66K80    equ    .18

P32MX534F064 equ    .30
P32MX564F064 equ    .31
P32MX564F128 equ    .32
P32MX575F256 equ    .33
P32MX575F512 equ    .34
P32MX764F128 equ    .35
P32MX775F256 equ    .36
P32MX775F512 equ    .37
P32MX795F512 equ    .38

