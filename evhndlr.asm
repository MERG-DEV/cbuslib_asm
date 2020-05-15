; filename evhndlr_h.asm
; modified 05/12/11 - fix SLiM mode learning
; modified 06/12/11 - add learnin label
;           - add movwf TABLAT to nxtfb routine for 32nd byte
; Rev d 09/03/12  - add checks on EN index and EV index in evsend, correct error code
; Rev d 22/04/12  - remove off/on of LEDs in wrflsh routine
; Rev f             - added LOW before EEPROM addresses. Prevents error messages
; Rev g  23/08/12  - Extra code in 'isthere' for event delete in CANSERVO8C
; Rev h 08/08/15 pnb - Refactored newev as a subroutine createv that can be called from elsewhere
; Rev j 18/2/17  pnb - Make compatible with 25k80 by clearing EEADRH before EEPROM ops (only uses first 256 bytes of EEPROM except for high byte for bootloader)

;include file for handling flash event data

#define  Skip_If_Reloading_Events      btfss initFlags,0
#define  Skip_If_Not_Reloading_Events  btfsc initFlags,0
#define  Set_Reloading_Events          bsf initFlags,0
#define  Unset_Reloading_Events        bcf initFlags,0

;******************************************************************************
; RAM storage
  CBLOCK EVENT_RAM

  ; 64 bytes of event data (4 events of 16 bytes each)
  ;   - the quanta size for updating linked list in Flash
  evt00     ; Event Node Number high byte
  evt01     ; Event Node Number low byte
  evt02     ; Event Number high byte
  evt03     ; Event Number high byte
  next_entry_address_0_high
  next_entry_address_0_low
  previous_entry_address_0_high
  previous_entry_address_0_low
  ; Up to eight event variables
  ev00
  ev01
  ev02
  ev03
  ev04
  ev05
  ev06
  ev07

  evt10
  evt11
  evt12
  evt13
  next_entry_address_1_high
  next_entry_address_1_low
  previous_entry_address_1_high
  previous_entry_address_1_low
  ev10
  ev11
  ev12
  ev13
  ev14
  ev15
  ev16
  ev17

  evt20
  evt21
  evt22
  evt23
  next_entry_address_2_high
  next_entry_address_2_low
  previous_entry_address_2_high
  previous_entry_address_2_low
  ev20
  ev21
  ev22
  ev23
  ev24
  ev25
  ev26
  ev27

  evt30
  evt31
  evt32
  evt33
  next_entry_address_3_high
  next_entry_address_3_low
  previous_entry_address_3_high
  previous_entry_address_3_low
  ev30
  ev31
  ev32
  ev33
  ev34
  ev35
  ev36
  ev37

  ENDC



;******************************************************************************
;   Send number of learnt events currently stored

send_number_of_events
  clrf    EEADRH
  movlw   low free_event_space + 1
  call    read_ee_at_address
  movwf   Tx_d3
  movlw   OPC_NUMEV
  movwf   Tx_d0
  movlw   4
  movwf   Tx_dlc
  bra     tx_with_node_number



;******************************************************************************
;   Learn an event and if in FLiM learn an event variable, in SLiM modify event
;   variables based on switch settings
;     The event Node Number must be in ev0 and ev1
;     The Event Number must be in ev2 and ev3
;     The event variable offset, already converted from an index, must be in
;     event_variable_index and the event variable value in event_variable_value
;     Return:
;       W = 0 if successful, otherwise W != 0
;       Hash for event in current_hash_number
;       Hashtable entry for event in current_hashtable_entry
;       Head of list for hash in current_event_list_head_high,
;       current_event_list_head_low
;       Event entry address in current_event_address_high,
;       current_event_address_low

learn_event
; define FLIM_ONLY for CANSERVO
#ifndef  FLIM_ONLY
  Skip_If_SLiM
  bra     do_event_learn
  Skip_If_Not_Unlearn
  retlw   0
#endif

do_event_learn
  call    find_event
  bnz     learn_new_event
  call    fetch_event_data

learn_event_variable
  Skip_If_Not_Reloading_Events
  bra     learn_indexed_event_variable
#ifndef   FLIM_ONLY
  Skip_If_FLiM
  bra     learn_in_slim
#endif

learn_indexed_event_variable
  movf    event_variable_index,W
  movff   event_variable_value, PLUSW0
  call    store_event_data
  movlw   OPC_WRACK
  Skip_If_Reloading_Events
  call    tx_without_data
  retlw   0

#ifndef FLIM_ONLY
learn_in_slim
  ; In SLiM selection and polarity switches are read then event variables for
  ; both activation and inversion are set appropriately
  call    get_selected_output_pair

  ; Set appropriate activation bit in first event variable
  movff   event_variable_1, copy_of_event_variable_1
  movf    copy_of_event_variable_1,W
  iorwf   INDF0,W                      ; Add already set bits for variable
  movwf   POSTINC0
  movwf   event_variable_1              ; Save for testing later

  btfsc   Polarity_Input
  bra     learn_normal_polarity

  ; Set appropriate inversion bit in second event variable
  movf    copy_of_event_variable_1,W
  iorwf   INDF0,F

store_learnt_event_variables
  movff   INDF0, event_variable_2       ; Save for testing later
  call    store_event_data
  retlw   0

learn_normal_polarity
  ; Clear appropriate inversion bit in second event variable
  comf    copy_of_event_variable_1,W
  andwf   INDF0
  bra     store_learnt_event_variables
#endif

learn_new_event
  call    create_new_event_entry
  sublw   0
  bz      learn_event_variable
  retlw   1



;******************************************************************************
;   Create a hashtable entry for a new event
;     The event Node Number must be in ev0 and ev1
;     The Event Number must be in ev2 and ev3
;     Hashtable entry for event must be in current_hashtable_entry
;     Head of list for hash must be in current_event_list_head_high,
;     current_event_list_head_low
;     Return:
;       W = 0 if successful, otherwise W != 0
;       Event entry address in current_event_address_high,
;       current_event_address_low
;       FSR0 addresses event variables in event entry

create_new_event_entry
  movlw   low free_event_space
  call    read_ee_at_address
  sublw   0
  btfsc   STATUS, Z
  retlw   1

  ; Event will be stored in the next free entry
  movlw   low next_free_event_entry
  call    read_ee_at_address
  movwf   current_event_address_high
  incf    EEADR,F
  call    read_ee
  movwf   current_event_address_low

  tstfsz  current_event_list_head_high
  bra     push_new_event_to_list_head
  bra     set_new_event_as_list_head

push_new_event_to_list_head
  ; Fetch current head of list and set FSR0 to point at entry
  call    fetch_event_list_data
  movf    current_event_list_head_low,W
  call    set_FSR0_to_event_entry

  ; Set previous event address for old list head as that of new event
  movlw   6
  addwf   FSR0L
  movff   current_event_address_high, POSTINC0
  movff   current_event_address_low, POSTINC0
  call    store_hashtable_data

set_new_event_as_list_head
  ; Fetch entry for new event and set FSR0 to point to it
  call    fetch_event_data
  movf    current_event_address_low,W
  call    set_FSR0_to_event_entry

  ; Set next free entry as next event address from new event
  movlw   4
  addwf   FSR0L

  movlw   low next_free_event_entry
  movwf   EEADR
  movf    POSTINC0,W
  call    write_ee

  movlw   low next_free_event_entry + 1
  movwf   EEADR
  movf    POSTINC0,W
  call    write_ee

  ; Update head of list address stored in hash table
  movff   current_hashtable_entry, EEADR
  movf    current_event_address_high,W
  call    write_ee
  incf    EEADR
  movf    current_event_address_low,W
  call    write_ee

  ; Write event details into list entry
  movf    current_event_address_low,W
  call    set_FSR0_to_event_entry
  movff   ev0, POSTINC0
  movff   ev1, POSTINC0
  movff   ev2, POSTINC0
  movff   ev3, POSTINC0

  ; Set next event to previous head of list
  movff   current_event_list_head_high, POSTINC0
  movff   current_event_list_head_low, POSTINC0

  ; No previous event as new event is now head of list
  clrf    POSTINC0
  clrf    POSTINC0

  ; Clear new event variables
  movlw   8
  movwf   flash_access_counter_0
  movlw   0

clear_new_event_variables_loop
  clrf    PLUSW0
  incf    WREG,F
  decfsz  flash_access_counter_0,F
  bra     clear_new_event_variables_loop

  ; Increment number of events stored against this hash
  movf    current_hash_number,W
  addlw   low hash_number_event_counts
  call    read_ee_at_address
  incf    WREG,F
  call    write_ee

  ; Increment number of events stored
  movlw   low free_event_space + 1
  call    read_ee_at_address
  incf    WREG,F
  call    write_ee

  ; Decrement remaining event space
  decf    EEADR,F
  call    read_ee
  decf    WREG,F
  call    write_ee

  retlw   0



;******************************************************************************
;   Unlearn an event
;     The event Node Number must be in ev0 and ev1
;     The Event Number must be in ev2 and ev3

forget_event
  call    find_event
  btfss   STATUS, Z
  return

;   The event to unlearn is currently the member of an events list. It must be
;   removed from that list and placed as the new head of the free events list.

  ; Get address of current head of free events list
  movlw   low next_free_event_entry
  call    read_ee_at_address
  movwf   current_free_entry_address_high
  incf    EEADR,F
  call    read_ee
  movwf   current_free_entry_address_low

  ; Fetch entry for event to forget and set FSR0 to point to it
  call    fetch_event_data
  movf    current_event_address_low,W
  call    set_FSR0_to_event_entry

  ; For the event to forget set its next event address to the current head of
  ; the free entries list and previous event address to null
  ; Copy its next and previous event addresses as these will be needed to heal
  ; the events list from which it is being removed
  movlw   4
  addwf   FSR0L
  movff   INDF0, next_event_address_high
  movff   current_free_entry_address_high, POSTINC0
  movff   INDF0, next_event_address_low
  movff   current_free_entry_address_low, POSTINC0

  movff   INDF0, previous_event_address_high
  clrf    POSTINC0
  movff   INDF0, previous_event_address_low
  clrf    POSTINC0

  ; Make the event to forget the new head of the free event entries list
  movlw   low next_free_event_entry
  movwf   EEADR
  movf    current_event_address_high,W
  call    write_ee
  incf    EEADR,F
  movf    current_event_address_low,W
  call    write_ee

  call    store_event_data

  ; Heal the event list from which the event to forget is being removed
  tstfsz  previous_event_address_high
  bra     fix_previous_event
  bra     remove_event_from_head_of_list

fix_previous_event
  ; Fetch previous event and set FSR0 to point at entry
  movff   previous_event_address_high, current_event_address_high
  movff   previous_event_address_low, current_event_address_low
  call    fetch_event_data
  movf    current_event_address_low,W
  call    set_FSR0_to_event_entry

  ; Event to forget is no longer next event of its previous event
  movlw   4
  addwf   FSR0L
  movff   next_event_address_high, POSTINC0
  movff   next_event_address_low, POSTINC0
  call    store_event_data

  bra     check_if_there_was_a_next_event

remove_event_from_head_of_list
  movff   current_hashtable_entry, EEADR
  movf    next_event_address_high,W
  call    write_ee
  incf    EEADR
  movf    next_event_address_low,W
  call    write_ee

check_if_there_was_a_next_event
  tstfsz  next_event_address_high
  bra     fix_next_event
  bra     event_removed_from_list

fix_next_event
  ; Fetch next event and set FSR0 to point at entry
  movff   next_event_address_high, current_event_address_high
  movff   next_event_address_low, current_event_address_low
  call    fetch_event_data
  movf    current_event_address_low,W
  call    set_FSR0_to_event_entry

  ; Event to forget is no longer previous event of its next event
  movlw   6
  addwf   FSR0L
  movff   previous_event_address_high, POSTINC0
  movff   previous_event_address_low, POSTINC0
  call    store_event_data

event_removed_from_list
  movf    current_hash_number,W
  addlw   low hash_number_event_counts
  call    read_ee_at_address
  decf    WREG,F
  call    write_ee

  ; Increase free event space count
  movlw   low free_event_space
  call    read_ee_at_address
  incf    WREG,F
  call    write_ee

  ; Decrease stored events count
  incf    EEADR,F
  call    read_ee
  decf    WREG,F
  bra     write_ee



;******************************************************************************
;   Test if events areCopy all EEPROM events to Flash if FLASH not initialised.
; initialises Free chain and moves all existing events to Flash
;

reload_events
  Unset_Reloading_Events
  movlw   low free_event_space
  call    read_ee_at_address
  movwf   Temp
  incf    EEADR
  call    read_ee      ;get num of events
  addwf   Temp      ;total should equal NUMBER_OF_EVENTS
  movlw   NUMBER_OF_EVENTS
  cpfseq  Temp
  bra     events_not_loaded
  return          ;Free chain set up so do nothing

events_not_loaded
  call    copy_events_to_ram
  movlw   low free_event_space + 1
  call    read_ee_at_address
  movwf   ENcount     ;save count

  call    initialise_event_data    ;create free chain

  tstfsz  ENcount     ;check if any events to copy
  bra     docopy      ;j if there are...
  return          ;...else no more to do

docopy
  Set_Reloading_Events
  lfsr    FSR1, EN1
  lfsr    FSR2, EV1

cynxten
  movff   POSTINC1, ev0
  movff   POSTINC1, ev1
  movff   POSTINC1, ev2
  movff   POSTINC1, ev3

cynxten_variables
  movlw   VARIABLES_PER_EVENT
  movwf   event_variable_index
  movff   POSTINC2, event_variable_value
  call    learn_event
  decfsz  event_variable_index
  bra     cynxten_variables

  decfsz  ENcount
  bra     cynxten

  Unset_Reloading_Events
  return



;******************************************************************************
;   Clear all event data, clear hash table, and initialise free event list
;
; Each event is stored as a 16 byte entry in the list:
;   Bytes 0-1 are the event Node Number
;   Bytes 2-3 are the Event Number
;   Bytes 4-5 are the pointer to the next entry, 0 if none
;   Bytes 6-7 are the pointer to the previous entry, 0 if none
;   Bytes 8-15 contain the events data, usage depends on the actual module

initialise_event_data
  ; Initialise free event space count
  movlw   low free_event_space
  movwf   EEADR
  movlw   NUMBER_OF_EVENTS
  call    write_ee

  ; Clear stored events count
  incf    EEADR,F
  clrf    WREG
  call    write_ee

  movlw   NUMBER_OF_HASH_TABLE_ENTRIES * 2
  movwf   loop_counter
  movlw   low hashtable
  movwf   EEADR

clear_hashtable
  clrf    WREG
  call    write_ee
  incf    EEADR,F
  decfsz  loop_counter
  bra     clear_hashtable

  movlw   NUMBER_OF_HASH_TABLE_ENTRIES
  movwf   loop_counter
  movlw   low hash_number_event_counts
  movwf   EEADR

clear_hash_event_count
  clrf    WREG
  call    write_ee
  incf    EEADR,F
  decfsz  loop_counter
  bra     clear_hash_event_count

  call    clear_event_store

  ; Initially all events are in the free event list
  movlw   low next_free_event_entry
  movwf   EEADR
  movlw   high event_storage
  movwf   current_event_address_high
  call    write_ee
  incf    EEADR,F
  clrf    WREG
  movwf   current_event_address_low
  call    write_ee

  lfsr    FSR0, evt00
  movlw   64
  movwf   loop_counter

clear_event_ram
  clrf    POSTINC0
  decfsz  loop_counter,F
  bra     clear_event_ram

  clrf    previous_event_address_high
  clrf    previous_event_address_low

  movlw   NUMBER_OF_EVENTS
  movwf   loop_counter

initialise_next_event_block
  movff   current_event_address_low, Temp
  movff   current_event_address_high, Temp1

initialise_next_event
  movf    Temp,W
  call    set_FSR0_to_event_entry
  movlw   16
  addwf   Temp
  clrf    WREG
  addwfc  Temp1

  ; Clear event Node Number and Event Number
  clrf    POSTINC0
  clrf    POSTINC0
  clrf    POSTINC0
  clrf    POSTINC0
  decf    loop_counter
  bz      initialise_last_event

  ; Initialise next and previous event addresses
  movff   Temp1, POSTINC0
  movff   Temp, POSTINC0
  movff   previous_event_address_high, POSTINC0
  movff   previous_event_address_low, POSTINC0

  ; Current event will be previous event for next event
  movff   current_event_address_high, previous_event_address_high
  movff   current_event_address_low, previous_event_address_low

  movf    loop_counter,W
  andlw   0x03                      ; Each block contains 4 events
  bz      event_block_initialised

  ; Move on to next event, each event occupies 16 bytes
  movlw   16
  addwf   current_event_address_low
  clrf    WREG
  addwfc  current_event_address_high
  bra     initialise_next_event

event_block_initialised
  call    store_event_data

  ; Move on to next 64 byte block (4 events)
  movlw   16
  addwf   current_event_address_low,F
  clrf    WREG
  addwfc  current_event_address_high
  bra     initialise_next_event_block

initialise_last_event
  ; There is no next event for the very last event
  clrf    Temp
  movff   Temp, POSTINC0
  movff   Temp, POSTINC0

  ; Initialise previous event addresses
  movff   previous_event_address_high, POSTINC0
  movff   previous_event_address_low, POSTINC0
  call    store_event_data
  return



;******************************************************************************
;   Read 64 bytes of event list data
;     current_event_list_head_high, current_event_list_head_low contain
;     address to read from
;     Data is read into RAM starting at evt00

fetch_event_list_data
  movlw   0xc0
  andwf   current_event_list_head_low,W   ; Align to 64 byte boundary
  movwf   TBLPTRL
  movf    current_event_list_head_high,W
  movwf   TBLPTRH
  bra     read_event_table



;******************************************************************************
;   Read first 16 bytes of event data
;     current_event_address_high, current_event_address_low contain address to
;     read from
;     Data is read into RAM starting at evt00

fetch_16_bytes_of_event_data
  movff   current_event_address_high, TBLPTRH
  movff   current_event_address_low, TBLPTRL
  movlw   16
  bra     read_flash_table

;******************************************************************************
;   Read first 8 bytes of event data
;     current_event_address_high, current_event_address_low contain address to
;     read from
;     Data is read into RAM starting at evt00

fetch_8_bytes_of_event_data
  movff   current_event_address_high, TBLPTRH
  movff   current_event_address_low, TBLPTRL
  movlw   8
  bra     read_flash_table

;******************************************************************************
;   Read 64 bytes of event data
;     current_event_address_high, current_event_address_low contain address to
;     read from
;     Data is read into RAM starting at evt00

fetch_event_data
  movlw   0xc0
  andwf   current_event_address_low,W      ; Align to 64 byte boundary
  movwf   TBLPTRL
  movf    current_event_address_high,W
  movwf   TBLPTRH

read_event_table
  movlw   64

read_flash_table
  movwf   flash_access_counter_0
  clrf    TBLPTRU
  movff   FSR0H, saved_FSR0H
  movff   FSR0L, saved_FSR0L
  lfsr    FSR0, evt00

read_next_flash_table_entry
  tblrd*+
  movf    TABLAT,W
  movwf   POSTINC0
  decfsz  flash_access_counter_0
  bra     read_next_flash_table_entry

  movff   saved_FSR0L, FSR0L
  movff   saved_FSR0H, FSR0H

  return



;******************************************************************************
;   Find entry for event
;     The event Node Number must be in ev0 and ev1
;     The Event Number must be in ev2 and ev3
;     Return:
;       STATUS, Zset if successful, otherwise STATUS, Zclear
;       Hash for event in current_hash_number
;       Hashtable entry for event in current_hashtable_entry
;       Head of list for hash in current_event_list_head_high,
;       current_event_list_head_low
;       Event entry address in current_event_address_high,
;       current_event_address_low
;       FSR0 addresses event variables in event entry

find_event
  ; Form hash from last 3 bit of Event Number
  movlw   0x07
  andwf   ev3,W
  movwf   Temp
  movwf   current_hash_number

  ; Convert hash into table entry address in EEPROM
  rlncf   Temp                      ; x 2 as two bytes per table entry
  movlw   low hashtable
  addwf   Temp,W
  movwf   current_hashtable_entry

  ; Get event list base start address from hash table entry
  call    read_ee_at_address
  movwf   current_event_address_high
  movwf   current_event_list_head_high
  incf    EEADR
  call    read_ee
  movwf   current_event_address_low
  movwf   current_event_list_head_low

find_event_loop
  tstfsz  current_event_address_high
  bra     current_event_address_valid
  bcf     STATUS, Z
  return

current_event_address_valid
  movf    current_event_address_low,W
  movwf   TBLPTRL
  movf    current_event_address_high,W
  movwf   TBLPTRH
  clrf    TBLPTRU

  clrf    Match
  tblrd*+
  movf    TABLAT,W
  cpfseq  ev0
  incf    Match

  tblrd*+
  movf    TABLAT,W
  cpfseq  ev1
  incf    Match

  tblrd*+
  movf    TABLAT,W
  cpfseq  ev2
  incf    Match

  tblrd*+
  movf    TABLAT,W
  cpfseq  ev3
  incf    Match

  tstfsz  Match
  bra     try_next_event_entry

  movf    current_event_address_low,W
  call    set_FSR0_to_event_entry
  movlw   8
  addwf   FSR0L
  bsf     STATUS, Z
  return

try_next_event_entry
  tblrd*+
  movf    TABLAT,W
  movwf   current_event_address_high
  tblrd*+
  movf    TABLAT,W
  movwf   current_event_address_low
  bra     find_event_loop



;******************************************************************************

clear_event_store
  ; Store is blocks of 64 bytes each of which can store 4 event
  movlw   NUMBER_OF_EVENTS/4
  movwf   loop_counter

  movlw   low event_storage
  movwf   TBLPTRL
  movlw   high event_storage
  movwf   TBLPTRH
  clrf    TBLPTRU

clear_event_block
  call    erase_flash_block
  movlw   64
  addwf   TBLPTRL,F
  clrf    WREG
  addwfc  TBLPTRH
  decfsz  loop_counter
  bra     clear_event_block
  return



;******************************************************************************
;   Erase 64 bytes of flash addressed by TBLPTR

erase_flash_block
  bsf     EECON1, EEPGD
  bcf     EECON1, CFGS
  bsf     EECON1, WREN
  bsf     EECON1, FREE
  movff   INTCON, TempINTCON
  clrf    INTCON
  movlw   0x55
  movwf   EECON2
  movlw   0xAA
  movwf   EECON2
  bsf     EECON1, WR
  nop
  nop
  nop
  movff   TempINTCON, INTCON

  return



;******************************************************************************
;   Store 64 bytes of hash table data
;     current_event_list_head_high, current_event_list_head_low contain address
;     at which to store the data

store_hashtable_data
  movlw   0xc0
  andwf   current_event_list_head_low,W    ; Align to 64 byte boundary
  movwf   TBLPTRL
  movf    current_event_list_head_high,W
  movwf   TBLPTRH
  bra     write_flash_table



;******************************************************************************
;   Store 64 bytes of event data
;     current_event_address_high, current_event_address_low contain address at
;     which to write data
;     the data

store_event_data
  movlw   0xc0
  andwf   current_event_address_low,W              ; Align to 64 byte boundary
  movwf   TBLPTRL
  movf    current_event_address_high,W
  movwf   TBLPTRH

write_flash_table
  clrf    TBLPTRU
  call    erase_flash_block
  lfsr    FSR0, evt00
  movlw   2                                 ; Write 2 blocks
  movwf   flash_access_counter_1

write_next_flash_table_block
  movlw   31                                ; Write 32 bytes per block
  movwf   flash_access_counter_0

load_next_flash_table_entry
  movf    POSTINC0,W
  movwf   TABLAT
  tblwt*+
  decfsz  flash_access_counter_0,F
  bra     load_next_flash_table_entry

  movf    POSTINC0,W
  movwf   TABLAT
  tblwt*                                    ; Leave TBLPTR at end of block

  movlw   B'10000100'
  movwf   EECON1

  movff   INTCON, TempINTCON
  clrf    INTCON

  movlw   0x55
  movwf   EECON2
  movlw   0xAA
  movwf   EECON2
  bsf     EECON1, WR
  nop

  movff   TempINTCON, INTCON

  incf    TBLPTRL,F                        ; Advance to next 32 byte block
  movlw   0
  addwfc  TBLPTRH,F
  decfsz  flash_access_counter_1,F
  bra     write_next_flash_table_block

  return



;******************************************************************************
;   Set FSR0 to access RAM copy of event entry in event list

set_FSR0_to_event_entry
  swapf   WREG,W
  andlw   B'00000011'
  tstfsz  WREG
  bra     not_evt00

  lfsr    FSR0, evt00
  return

not_evt00
  decf    WREG,W
  tstfsz  WREG
  bra     not_evt10

  lfsr    FSR0, evt10
  return

not_evt10
  decf    WREG,W
  tstfsz  WREG
  bra     not_evt20

  lfsr    FSR0, evt20
  return

not_evt20
  lfsr    FSR0, evt30
  return



;******************************************************************************
send_all_events
  clrf    Temp
  movlw   low free_event_space + 1
  call    read_ee_at_address
  sublw   0
  bz      no_events_to_send

  clrf    Tx_d7                         ; Initialise event index to 0
  movlw   NUMBER_OF_HASH_TABLE_ENTRIES
  movwf   ENcount
  movlw   low hashtable
  movwf   EEADR

next_hash_table_entry
  call    read_ee
  movwf   current_event_address_high
  incf    EEADR,F
  call    read_ee
  movwf   current_event_address_low

send_next_event_in_chain
  tstfsz  current_event_address_high
  bra     got_event_to_send

  decf    ENcount
  bz      all_events_sent

  incf    EEADR,F
  bra     next_hash_table_entry

got_event_to_send
  call    fetch_8_bytes_of_event_data
  incf    Tx_d7
  movff   evt00, Tx_d3
  movff   evt01, Tx_d4
  movff   evt02, Tx_d5
  movff   evt03, Tx_d6

  movlw   OPC_ENRSP
  movwf   Tx_d0
  movlw   8
  movwf   Tx_dlc
  call    tx_with_node_number
  call    delay
  call    delay

  movff   next_entry_address_0_high, current_event_address_high
  movff   next_entry_address_0_low, current_event_address_low
  bra     send_next_event_in_chain

all_events_sent
  return

no_events_to_send
  movlw   CMDERR_INVALID_EVENT
  bra     send_error_message



;******************************************************************************
;   Find an event by its index
;     event_index - Index of event, must be valid and in range

find_indexed_event
  clrf    current_hash_number
  clrf    ENcount
  clrf    ENcount1

search_for_event_in_hash
  movf    current_hash_number,W
  addlw   low hash_number_event_counts
  call    read_ee_at_address
  addlw   0
  bz      search_for_event_in_next_hash

  addwf   ENcount1
  movf    ENcount1,W
  cpfslt  event_index       ; Skip if index is within event list for this hash
  bra     search_for_event_in_next_hash

  ; Get start address of events list for this hash
  rlncf   current_hash_number,W
  addlw   low hashtable
  call    read_ee_at_address
  movwf   current_event_address_high
  incf    EEADR
  call    read_ee
  movwf   current_event_address_low

check_next_event_list_entry
  movf    event_index,W
  cpfslt  ENcount
  return

  incf    ENcount,F
  call    fetch_8_bytes_of_event_data
  movff   next_entry_address_0_high, current_event_address_high
  movff   next_entry_address_0_low, current_event_address_low
  bra     check_next_event_list_entry

search_for_event_in_next_hash
  movff   ENcount1, ENcount
  incf    current_hash_number,F
  bra     search_for_event_in_hash



;******************************************************************************
;   Send event by its index
;
;     event_index - Index of event

send_indexed_event
  movlw   low free_event_space + 1
  call    read_ee_at_address
  sublw   0
  bz      event_index_invalid ; No events stored

  movf    event_index,W
  bz      event_index_invalid

  decf    event_index   ; Convert index to offset
  movlw   low free_event_space + 1
  call    read_ee_at_address
  cpfslt  event_index    ; Skip if offset in range
  bra     event_index_invalid

  call    find_indexed_event
  call    fetch_8_bytes_of_event_data   ; get event data

  movff   evt00, Tx_d3
  movff   evt01, Tx_d4
  movff   evt02, Tx_d5
  movff   evt03, Tx_d6
  incf    event_index
  movff   event_index, Tx_d7
  movlw   OPC_ENRSP
  movwf   Tx_d0
  movlw   8
  movwf   Tx_dlc
  bra     tx_with_node_number

event_index_invalid
  movlw   7
  bra     send_error_message



;******************************************************************************
;   Send event and a single event variable by their indices
;
;     event_index          - Index of event
;     event_variable_index - Index of event variable

send_indexed_event_and_variable
  ; Get number of events stored
  movlw   low free_event_space + 1
  call    read_ee_at_address
  sublw   0
  bz      event_index_invalid ; No events stored

  movf    event_index,W
  bz      event_index_invalid

  decf    event_index   ; Convert index to offset
  movlw   low free_event_space + 1
  call    read_ee_at_address
  cpfslt  event_index    ; Skip if offset in range
  bra     event_index_invalid

  movf    event_variable_index,W
  bz      variable_index_invalid

  decf    event_variable_index    ; Convert index to offset
  movlw   VARIABLES_PER_EVENT
  cpfslt  event_variable_index    ; Skip if offset in range
  bra     variable_index_invalid

  call    find_indexed_event

  call    fetch_16_bytes_of_event_data  ; read event data
  lfsr    FSR0, ev00
  movf    event_variable_index,W
  movff   PLUSW0, Tx_d5
  incf    event_variable_index    ; Convert offset to index
  incf    event_index             ; Convert offset to index

  movlw   OPC_NEVAL
  movwf   Tx_d0
  movff   event_index, Tx_d3
  movff   event_variable_index, Tx_d4
  movlw   6
  movwf   Tx_dlc
  bra     tx_with_node_number

variable_index_invalid
  movlw 6
  bra   send_error_message



;******************************************************************************
;   Send free event space

send_free_event_space
  movlw   low free_event_space
  call    read_ee_at_address
  movwf   Tx_d3
  movlw   0x70
  movwf   Tx_d0
  movlw   4
  movwf   Tx_dlc
  bra     tx_with_node_number



;******************************************************************************
;
; End of evhndlr_h.asm
;
;******************************************************************************
