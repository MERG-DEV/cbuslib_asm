;  Process received messages valid in both SLiM and FLiM

Test_And_Handle_Received_Message macro candidate_opcode, message_handler

  movlw   candidate_opcode
  subwf   received_opcode,W
  btfsc   STATUS,Z
  bra     message_handler

  endm

  Test_And_Handle_Received_Message OPC_ACON,  process_long_event
  Test_And_Handle_Received_Message OPC_ACOF,  process_long_event
  Test_And_Handle_Received_Message OPC_ASON,  process_short_event
  Test_And_Handle_Received_Message OPC_ASOF,  process_short_event
  Test_And_Handle_Received_Message OPC_RQNPN, read_node_parameter
  Test_And_Handle_Received_Message OPC_RQNP,  read_key_node_parameters
  Test_And_Handle_Received_Message OPC_RQMN,  read_name
  Test_And_Handle_Received_Message OPC_BOOT,  reboot
  Test_And_Handle_Received_Message OPC_QNN,   respond_to_query_node

  Skip_If_FLiM
  bra     main_loop


  ; Process received messages only valid in FLiM

  Test_And_Handle_Received_Message OPC_SNN, set_node_number

  Skip_If_In_Learn_Mode
  bra     check_if_addressed_message

  Test_And_Handle_Received_Message OPC_EVULN, unlearn_event
  Test_And_Handle_Received_Message OPC_EVLRN, learn_event_and_variable
  Test_And_Handle_Received_Message OPC_REQEV, read_event_variable

check_if_addressed_message
  call    is_message_for_this_node
  btfss   STATUS, Z
  bra     main_loop


  ; Process received messages only valid in FLiM and addressed to this node

  Test_And_Handle_Received_Message OPC_CANID, set_link_id
  Test_And_Handle_Received_Message OPC_ENUM,  force_self_enumeration
  Test_And_Handle_Received_Message OPC_NNLRN, enter_learn_mode
  Test_And_Handle_Received_Message OPC_NNULN, exit_learn_mode
  Test_And_Handle_Received_Message OPC_NNCLR, clear_all_events
  Test_And_Handle_Received_Message OPC_NNEVN, read_free_event_space
  Test_And_Handle_Received_Message OPC_RQEVN, read_number_of_events
  Test_And_Handle_Received_Message OPC_NERD,  read_all_events
  Test_And_Handle_Received_Message OPC_NENRD, read_indexed_event
  Test_And_Handle_Received_Message OPC_REVAL, read_indexed_event_and_variable
  Test_And_Handle_Received_Message OPC_NVSET, set_node_variable
  Test_And_Handle_Received_Message OPC_NVRD,  read_node_variable

  bra     main_loop



;******************************************************************************
read_node_parameter
  call    is_message_for_this_node    ; Check message addressed to this node
  btfsc   STATUS, Z
  call    send_node_parameter
  bra     main_loop



;******************************************************************************
read_key_node_parameters
  Skip_If_Not_In_Setup
  call    send_key_node_parameters
  bra     main_loop



;******************************************************************************
read_name
  Skip_If_Not_In_Setup
  call    send_name
  bra     main_loop



;******************************************************************************
respond_to_query_node
  movf    node_number_high,W
  addwf   node_number_low,W
  btfsc   STATUS, Z
  bra     main_loop

  ; Send Node Number, Manufacturer Id, Module Id and Flags
  call    long_delay        ; Allow time for other nodes to also respond
  movlw   OPC_PNN
  movwf   Tx_d0
  movlw   MANUFACTURER_ID
  movwf   Tx_d3
  movlw   MODULE_TYPE
  movwf   Tx_d4
  call    get_flags
  movwf   Tx_d5
  movlw   6
  movwf   Tx_dlc
  call    tx_with_node_number

  bra     main_loop



;******************************************************************************
set_node_number
  Skip_If_In_Setup
  bra     main_loop

  movff   ev0, node_number_high
  movff   ev1, node_number_low

  movlw   low NodeID
  movwf   EEADR
  movf    node_number_high,W
  call    write_ee
  incf    EEADR
  movf    node_number_low,W
  call    write_ee

  movlw   Modstat
  movwf   EEADR
  movlw   B'00001000'       ; Module status = Node Number is set
  call    write_ee

  Unset_In_Setup
  Set_Running
  call    send_node_number_acknowledge
  Set_SLiM_LED_Off
  Set_FLiM_LED_On
  bra     main_loop



;******************************************************************************
unlearn_event
  call    find_event
  btfss   STATUS, Z
  bra     main_loop

  call    forget_event
  movlw   OPC_WRACK
  call    tx_without_data
  bra     main_loop



;******************************************************************************
learn_event_and_variable
  movf    event_variable_index,W
  bz      event_variable_index_invalid

  decf    event_variable_index  ; Convert index to offset
  movlw   VARIABLES_PER_EVENT
  cpfslt  event_variable_index
  bra     event_variable_index_invalid

  call    learn_event
  sublw   0
  btfsc   STATUS, Z
  bra     process_event

  movlw   CMDERR_TOO_MANY_EVENTS
  bra     abort_and_send_error_message



;******************************************************************************
read_event_variable
  movff   event_variable_index, Tx_d5   ; Save to echo back in response
  movf    event_variable_index,W
  bz      event_variable_index_invalid

  decf    event_variable_index          ; Convert from index to offset
  movlw   VARIABLES_PER_EVENT
  cpfslt  event_variable_index
  bra     event_variable_index_invalid

  call    find_event
  bnz     no_event_to_read

  call    fetch_event_data
  movf    event_variable_index,W
  movff   PLUSW0, Tx_d6
  movlw   OPC_EVANS
  movwf   Tx_d0
  movff   ev0, Tx_d1
  movff   ev1, Tx_d2
  movff   ev2, Tx_d3
  movff   ev3, Tx_d4
  movlw   7
  movwf   Tx_dlc
  call    tx_message
  bra     main_loop


no_event_to_read
  movlw   CMDERR_NO_EV
  call    send_error_message
  bra     main_loop




;******************************************************************************
event_variable_index_invalid
  movlw   CMDERR_INV_EV_IDX
  bra     abort_and_send_error_message



;******************************************************************************
enter_learn_mode
  Set_In_Learn_Mode
  Set_FLiM_LED_On
  bra     main_loop



;******************************************************************************
exit_learn_mode
  Unset_In_Learn_Mode
  bra     main_loop



;******************************************************************************
clear_all_events
  movlw   CMDERR_NOT_LRN
  Skip_If_In_Learn_Mode
  bra     abort_and_send_error_message

  call    initialise_event_data
  movlw   OPC_WRACK
  call    tx_without_data
  bra     main_loop



;******************************************************************************
read_free_event_space
  call    send_free_event_space
  bra     main_loop



;******************************************************************************
read_number_of_events
  call    send_number_of_events
  bra     main_loop



;******************************************************************************
read_all_events
  call    send_all_events
  bra     main_loop



;******************************************************************************
read_indexed_event
  movff   ev2, event_index
  call    send_indexed_event
  bra     main_loop



;******************************************************************************
read_indexed_event_and_variable
  movff   ev2, event_index
  movff   ev3, event_variable_index
  call    send_indexed_event_and_variable
  bra     main_loop



;******************************************************************************
;  Set a node variable by index

set_node_variable
  call    store_indexed_node_variable
  call    reload_timers
  bra     main_loop



;******************************************************************************
read_node_variable
  movlw   NUMBER_OF_NODE_VARIABLES + 1
  cpfslt  ev2
  bz      node_variable_index_invalid

  movf    ev2,W
  bz      node_variable_index_invalid

  decf    WREG                  ; Convert index to offset
  addlw   low node_variables
  call    read_ee_at_address
  movwf   Tx_d4

  movff   ev2, Tx_d3            ; Echo back requested node variable index

send_node_variable
  movff   ev0, Tx_d1            ; Echo back Node Number high
  movff   ev1, Tx_d2            ; Echo back Node Number low
  movlw   OPC_NVANS
  movwf   Tx_d0
  movlw   5
  movwf   Tx_dlc
  call    tx_message
  bra     main_loop

node_variable_index_invalid
  clrf    Tx_d3                 ; Return Node Variable index of zero
  clrf    Tx_d4                 ; Return Node Variable value of zero
  bra     send_node_variable



;******************************************************************************
;   Send error message and end processing of received message
;     Error number to return is in W
abort_and_send_error_message
  call  send_error_message
  bra   main_loop



;******************************************************************************
;   Check if received message was addressed to this node
;     Zero status on return indicates match

is_message_for_this_node
  movf    node_number_high,W
  subwf   ev0,W
  btfss   STATUS, Z       ; Skip if match ...
  return                  ; ... else return with non zero status

  movf    node_number_low,W
  subwf   ev1,W

  return



;******************************************************************************
reload_tx_sid_and_node_number
  movlw   low CANid
  call    read_ee_at_address

  ; Transform single byte CAN Id into SIDH and SIDL
  ; CAN Id 0HHHHLLL => SIDL LLL00000 & SIDH 000HHHH
  movwf   sid_high          ; CAN Id                     0HHHHLLL
  swapf   sid_high,F        ; Swap high and low nibbles  HLLL0HHH
  rlncf   sid_high,F        ; Rotate left one bit        LLL0HHHH
  movlw   B'11100000'
  andwf   sid_high,W        ; W = LLL00000
  movwf   sid_low           ; SIDL = LLL00000
  movlw   B'00001111'       ; Mask out upper nibble
  andwf   sid_high,F        ; SIDH = 0000HHHH

  ; Load SIDH into Tx buffer maintaining current priority value
  movlw   B'11110000'
  andwf   Tx_sidh,F
  movf    sid_high,W
  iorwf   Tx_sidh,F

  movff   sid_low, Tx_sidl

  movlw   low NodeID
  call    read_ee_at_address
  movwf   node_number_high
  incf    EEADR
  call    read_ee
  movwf   node_number_low

  movlb   15                ; Select RAM bank 15

wait_if_TXB2_is_busy
  btfsc   TXB2CON, TXREQ
  bra     wait_if_TXB2_is_busy

  movff   sid_high, TXB2SIDH
  movff   sid_low, TXB2SIDL
  movlw   0xB0
  iorwf   TXB2SIDH          ; Set priority
  clrf    TXB2DLC           ; No data nor RTR
  movlb   0                 ; Select RAM bank 0

  return



;******************************************************************************
;   Send first seven node parameters

send_key_node_parameters
  movlw   low node_parameters
  movwf   TBLPTRL
  movlw   8
  movwf   TBLPTRH

  lfsr    FSR0, Tx_d1
  movlw   7
  movwf   loop_counter
  bsf     EECON1, EEPGD

parameter_tx_load_loop
  tblrd*+
  movff   TABLAT, POSTINC0
  decfsz  loop_counter
  bra     parameter_tx_load_loop

  bcf     EECON1, EEPGD

  movlw   8
  movwf   Tx_dlc
  movlw   0xEF
  movwf   Tx_d0
  bra     tx_message



;******************************************************************************
;   Send module name - 7 bytes

send_name
  movlw   low node_type_name
  movwf   TBLPTRL
  movlw   high node_type_name
  movwf   TBLPTRH

  lfsr    FSR0, Tx_d1
  movlw   7
  movwf   loop_counter
  bsf     EECON1, EEPGD

name_tx_load_loop
  tblrd*+
  movff   TABLAT, POSTINC0
  decfsz  loop_counter
  bra     name_tx_load_loop

  bcf     EECON1, EEPGD

  movlw   8
  movwf   Tx_dlc
  movlw   OPC_NAME
  movwf   Tx_d0
  bra     tx_message



;******************************************************************************
;   Send and individual parameter
;   ev2 contains index of parameter to send, index 0 sends number of parameters

send_node_parameter
  movf    ev2,W
  bz      tx_number_of_parameters

  movlw   NODE_PARAMETER_COUNT
  movff   ev2, Temp
  decf    Temp                  ; Convert index to offset
  cpfslt  Temp
  bra     parameter_index_invalid

  movlw   7
  subwf   Temp,W
  bz      tx_flags_parameter

  movlw   low node_parameters
  movwf   TBLPTRL
  movlw   high node_parameters
  movwf   TBLPTRH
  clrf    TBLPTRU
  decf    ev2,W                 ; Convert index to offset
  addwf   TBLPTRL
  bsf     EECON1, EEPGD
  tblrd*
  movff   TABLAT, Tx_d4

tx_parameter
  movff   ev2, Tx_d3            ; Echo back requested index
  movlw   5
  movwf   Tx_dlc
  movlw   OPC_PARAN
  movwf   Tx_d0
  bra     tx_with_node_number

tx_number_of_parameters
  movlw   NODE_PARAMETER_COUNT
  movwf   Tx_d4
  bra     tx_parameter

parameter_index_invalid
  movlw   CMDERR_INV_PARAM_IDX
  bra     send_error_message

tx_flags_parameter
  call    get_flags
  movwf   Tx_d4
  bra     tx_parameter



;******************************************************************************
;   Send a CMDERR message response
;      Error number is in W

send_error_message
  movwf   Tx_d3
  movlw   OPC_CMDERR
  movwf   Tx_d0
  movlw   4
  movwf   Tx_dlc
  bra     tx_with_node_number



send_node_number_acknowledge
  movlw   OPC_NNACK
  ; Drop through to tx_without_data


;******************************************************************************
;   Send message comprising just opcode and Node Number
;      Opcode passed in W

tx_without_data
  movwf   Tx_d0
  movlw   3
  movwf   Tx_dlc
  ; Drop through to tx_with_node_number

;******************************************************************************
;   Send message after adding Node Number

tx_with_node_number
  movff   node_number_high, Tx_d1
  movff   node_number_low, Tx_d2
  bra     tx_message



;******************************************************************************
request_new_node_number
  movlw   OPC_RQNN
  bra     tx_without_data



;******************************************************************************
;  Store a node variable by index
;
;    ev2 - Index of Node Variable
;    ev3 - Value for Node Variable

store_indexed_node_variable
  movlw   NUMBER_OF_NODE_VARIABLES + 1
  cpfslt  ev2
  return

  movf    ev2,W
  bnz     node_variable_index_in_range
  return

node_variable_index_in_range
  decf    WREG                  ; Convert index to offset
  addlw   low node_variables
  movwf   EEADR
  movf    ev3,W
  goto    write_ee



;******************************************************************************
;   Reset Node Variables to default values

reset_trigger_times
  movlw   8
  movwf   loop_counter
  movlw   low trigger_time_defaults
  movwf   Temp
  movwf   EEADR

trigger_times_reset_loop
  call    read_ee
  movwf   Temp1
  movlw   low node_variables - low trigger_time_defaults
  addwf   EEADR,F
  movf    Temp1,W
  call    write_ee
  dcfsnz  loop_counter
  return

  incf    Temp,F
  movf    Temp,W
  movwf   EEADR
  bra     trigger_times_reset_loop



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
