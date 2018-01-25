ORG 00H
		JMP Main

ORG 000BH		;timer0 intrupt

ORG 001BH		;timer1 intrupt
		MOV TL1,#0B0H;	;set time start from 15536
		MOV TH1,#3CH;	;
		PUSH ACC
		PUSH PSW

		CALL chime				
		CALL delay1sec
		CALL Alarm_trigger
		CALL snooze_trigger
		POP PSW
		POP ACC
		RETI

ORG 030H
	SEC_LOOP	EQU	030H
	DECI_LOOP	EQU	031H
	DIS_SEQ		EQU	032H
	FLASH_R		EQU	033H
	SETT_R		EQU	034H
	STAT_TR		EQU	035H		
	ALRM_BEEP	EQU	036H
;REALF bit configuration
;bit0=12/24display, bit1=AM/PM, bit2=beep_seq, 
;bit3=beep_trigger bit4-6=mode,bit7=alarm_on_off
	REALF		EQU	038H
	REALHOUR	EQU	039H
	REALMIN		EQU	03AH
	REALSEC		EQU	03BH
	
	ALRMHOUR	EQU	03CH
	ALRMMIN		EQU	03DH

	SNZ_hour	EQU	03EH
	SNZ_min		EQU	03FH
	SNZ_sec		EQU	040H

ORG 040H
Main:
;=================setup initial value=======================;
	MOV SEC_LOOP,#20
	MOV DECI_LOOP,#5
	MOV DIS_SEQ,#0

	MOV ALRMHOUR,#0
	MOV ALRMMIN,#1
	
	MOV REALF,#10000000B
	MOV REALHOUR,#0
	MOV REALMIN,#59H
	MOV REALSEC,#57
	CLR P0.7
;=================start interrupt===================;
	MOV TMOD,#10H	;16bit timer1
	CLR TR1		;stop timer1
	MOV TH1,#3CH;	;
	MOV TL1,#0B0H;	;set time start from 15536
	SETB TR1	;start timer1
	SETB EA		;enable global intrupt
	SETB ET1	;enable timer1 intrupt
;====================================main program============================;
;===================flash rate================;  
refresh:
	MOV R3,#5
	MOV SETT_R,#250
	REP_FLASH:
	MOV FLASH_R,#150
;================7segment display====================
display:
	
	CALL Real_Display

;====================================================

	MOV A,SETT_R		
	CJNE A,#0,dec_n_flash		
	JMP setr		
	dec_n_flash:
	DEC SETT_R
	setr:			
	DJNZ FLASH_R,display	
;=====================================led indicator========================
	CALL LED_24_indic
	CALL LED_AP_PM_indic
;==================================swtich jmp==========================
	MOV P3,#11111111B		;set p3 as input
	SETB P0.0
			MOV A,REALF
			ANL A,#00001000B
			JZ do_normal_swtch
				JB P2.7,skip_lap
				CALL close_alarm		;alarm_turnoff
				CALL medelay
				JMP skip_press
				skip_lap:

					do_normal_swtch:
					JB P2.7,skip_press
					CALL mode_switch
					skip_press:

		MOV A,REALF
		ANL A,#10001000B
		CJNE A,#136,snz_button_inactiv
				JNB P3.5,snz_jmp
				JNB P3.4,snz_jmp
				JNB P0.0,snz_jmp

		DJNZ R3,REP_FLASH
		JMP refresh
	snz_button_inactiv:
	JNB P3.5,timesett
	JNB P3.4,timemode
	JNB P0.0,timeformat

		
	
	DJNZ R3,REP_FLASH
	JMP refresh
;===================================snooze funct======================;
snz_jmp:
	MOV STAT_TR,#1
	CALL snooze_count
	JMP end_set
;==========================chg 12/24 switch=================;
timeformat:
	MOV A,REALF
	ANL A,#01H
	JNZ turn_to_12
	ORL REALF,#00000001B
	JMP switchend

	turn_to_12:
	ANL REALF,#11111110B
	switchend:
	CALL medelay
	JMP refresh

;===========================setting time====================;
timemode:
	CALL detect_mode_a
	JNZ chgmode
	MOV A,REALF
	ADD A,#50H		
	MOV REALF,A		
	JMP chgsame
		chgmode:
		ANL REALF,#10001111B
		chgsame:
		CALL medelay
		JMP refresh
;=============================================================
timesett:
	;5ALARM 4MIN 3HOUR // 2RMIN 1RHOUR //0RTIME
	MOV FLASH_R,#0
	CALL detect_mode_a
	CJNE A,#5,setamin
	CALL alarm_on_off
	JMP end_set		; CHECK 
	setamin:
	CJNE A,#4,setahour
		MOV A,ALRMMIN
		CJNE A,#59H,INC_ALRMMIN
		MOV ALRMMIN,#0
		JMP end_set
			INC_ALRMMIN:	
			INC ALRMMIN
			MOV A,ALRMMIN
			ANL A,#0FH
			CJNE A,#0AH,end_set
			MOV A,ALRMMIN
			CLR C
			ADD A,#6
			MOV ALRMMIN,A
			JMP end_set
			
	setahour:
	CJNE A,#3,setRmin
		MOV A,ALRMHOUR
		CJNE A,#23H,INC_ALRMHOUR
		MOV ALRMHOUR,#0
		JMP end_set
			INC_ALRMHOUR:		
			INC ALRMHOUR
			MOV A,ALRMHOUR
			ANL A,#0FH
			CJNE A,#0AH,end_set
			MOV A,ALRMHOUR
			CLR C
			ADD A,#6
			MOV ALRMHOUR,A
			JMP end_set
	setRmin:
		CJNE A,#2,setRhour
		MOV A,REALMIN
		CJNE A,#59H,INC_REALMIN
		MOV REALMIN,#0
		JMP end_set
			INC_REALMIN:	
			INC REALMIN
			MOV A,REALMIN
			ANL A,#0FH
			CJNE A,#0AH,end_set
			MOV A,REALMIN
			CLR C
			ADD A,#6
			MOV REALMIN,A
			JMP end_set
		JMP end_set
	setRhour:
		CJNE A,#1,normal
		MOV A,REALHOUR
		CJNE A,#23H,INC_REALHOUR
		MOV REALHOUR,#0
		ANL REALF,#11111101B
		JMP end_set
			INC_REALHOUR:		
			INC REALHOUR
			CALL pm_turn_on
			MOV A,REALHOUR
			ANL A,#0FH
			CJNE A,#0AH,end_set
			MOV A,REALHOUR
			CLR C
			ADD A,#6
			MOV REALHOUR,A
			JMP end_set
		JMP end_set
	normal:
		JMP refresh
	end_set:
	CALL smdelay
	MOV R5,#200
	loop_de_2:
	CALL Real_Display
	DJNZ R5,loop_de_2
	
	end_delay:
	CALL smdelay
	JMP refresh

;==============================1sec counter=================================
delay1sec:
	DJNZ SEC_LOOP,cyc20
	MOV SEC_LOOP,#20
	MOV DECI_LOOP,#5
	CALL RealTime
	
	RET
cyc20:
		CALL Beeping
		decimal_loop:
		MOV A,DECI_LOOP
		CJNE A,#0,return_cyc20
		RET
	return_cyc20:	
		DEC DECI_LOOP
		RET
;===============================REAL TIME====================================
RealTime:
	;sec
	MOV A,REALSEC
	CJNE A,#59,inc_sec	
	MOV REALSEC,#0
	JMP minute_for_alarm

	inc_sec:
		INC REALSEC
		RET

		minute_for_alarm:
		CALL close_alarm
		
		minute:
		MOV A,REALMIN
		CJNE A,#59H,inc_min
		MOV REALMIN,#0
		JMP hour

		inc_min:
			INC REALMIN
			MOV A,REALMIN
			ANL A,#0FH
			CJNE A,#0AH,normal_inc
			MOV A,REALMIN
			ADD A,#6
			MOV REALMIN,A
								
			normal_inc:
			MOV A,REALF
			ANL A,#10000000B
			JZ ended_checking
			CALL ALARM_CHECK
			ended_checking:
			RET
			
			hour:

			SETB P0.7
			ORL STAT_TR,#01110010B
			
			MOV A,REALHOUR
			CJNE A,#23H,inc_hour
			MOV REALHOUR,#0
			ANL REALF,#11111101B	;turn off pm
			MOV A,REALF
			ANL A,#10000000B
			JZ ended_checking2
			CALL ALARM_CHECK
			ended_checking2:		
			RET
			
			inc_hour:			
			INC REALHOUR
			MOV A,REALHOUR
			ANL A,#0FH
			CJNE A,#0AH,default_inc
			MOV A,REALHOUR
			ADD A,#6
			MOV REALHOUR,A
			RET
			default_inc:
			MOV A,REALF
			ANL A,#10000000B
			JZ ended_checking3
			CALL ALARM_CHECK
			ended_checking3:
			MOV A,REALHOUR
			CJNE A,#12H,hour_ret
			ORL REALF,#00000010B	;turn on pm
			RET
			hour_ret:	
			RET
;==============================display function=====================
Real_Display:
		MOV P1,#0H
		CALL display_blink
		CALL fetch
		CALL smdelay
		RET
;================================================================
display_blink:
	MOV A,DIS_SEQ
	CJNE A,#0,chg_seq
	MOV P3,#11111110B
	RET
	chg_seq:
	CJNE A,#1,chg_seq1
	MOV P3,#11111101B
	RET	
	chg_seq1:
	CJNE A,#2,chg_seq2
	MOV P3,#11111011B
	RET
	chg_seq2:
	CJNE A,#3,chg_seq3
	MOV P3,#11110111B
	chg_seq3:	
	RET
;==================7segment sequence==================;
fetch:
		CALL detect_mode_a
		CJNE A,#1,search_2
			JMP input_mode1
		search_2:
		CJNE A,#2,search_3
			JMP input_mode2
		search_3:
		CJNE A,#3,search_4
			JMP input_mode1
		search_4:
		CJNE A,#4,fetch_proc
			JMP input_mode2
				fetch_proc:
				CALL check1
				CALL number
				finish_proc:
				INC DIS_SEQ
				MOV A,DIS_SEQ
				CJNE A,#4,four_fet
				MOV DIS_SEQ,#0
				four_fet:
				RET
;=================================particula section blinking in mode3,2,1,0
					input_mode1:
					MOV A,DIS_SEQ
					CJNE A,#0,input_01
					JMP detect_SETTR
					input_01:
					CJNE A,#1,input_non
					JMP detect_SETTR
					input_non:
					JMP fetch_proc
;=================================
				input_mode2:
				MOV A,DIS_SEQ
				CJNE A,#2,input_23
				JMP detect_SETTR
				input_23:
				CJNE A,#3,input_null
				JMP detect_SETTR
				input_null:
				JMP fetch_proc
;====================================
			detect_settR:
			MOV A,SETT_R
			JNZ fetch_proc
			CALL check1
			CALL number
			ANL P1,#10000000B
			JMP finish_proc
		detect_mode_A:
		MOV A,REALF
		SWAP A
		ANL A,#07H
		RET
	
;===================0 to 9 number===================== 
number:
	CJNE A,#9,number8
	MOV A,#01101111B
	CALL decimal
	MOV P1,A
	RET
number8:
	CJNE A,#8,number7
	MOV A,#01111111B
	CALL decimal
	MOV P1,A
	RET
number7:
	CJNE A,#7,number6
	MOV A,#0111B
	CALL decimal
	MOV P1,A
	RET
number6:
	CJNE A,#6,number5
	MOV A,#01111101B
	CALL decimal
	MOV P1,A
	RET
number5:
	CJNE A,#5,number4
	MOV A,#01101101B
	CALL decimal
	MOV P1,A
	RET
number4:
	CJNE A,#4,number3
	MOV A,#01100110B
	CALL decimal
	MOV P1,A
	RET
number3:
	CJNE A,#3,number2
	MOV A,#01001111B
	CALL decimal
	MOV P1,A
	RET
number2:
	CJNE A,#2,number1
	MOV A,#01011011B
	CALL decimal
	MOV P1,A
	RET
number1:
	CJNE A,#1,number0
	MOV A,#0110B
	CALL decimal
	MOV P1,A
	RET
number0:
	MOV A,#00111111B
	CALL decimal
	MOV P1,A
	RET
;====================decimal(1sec blink)======================;
decimal:
	PUSH ACC
	MOV A,REALF
	SWAP A
	ANL A,#0111B
		CJNE A,#3,no_dec
		JMP nobk
		no_dec:
		JC plus_dec
		JMP nobk	
	plus_dec:
	MOV A,DIS_SEQ
	CJNE A,#1,Nobk
	MOV A,DECI_LOOP
	JZ Nobk
	POP ACC
	ORL A,#10000000B
	RET
	Nobk:
	POP ACC
	RET

;====================fetch time value=====================;
check1:	
	MOV A,DIS_SEQ
	CJNE A,#0,hrplay
	CALL choose_mode
	CLR C
	CLR AC
	DA A
	SWAP A
	ANL A,#0FH
	RET
		hrplay:
		CJNE A,#1,minplay
		CALL choose_mode
		CLR C
		CLR AC
		DA A
		ANL A,#0FH
		RET
			minplay:
			CJNE A,#2,lasplay
			CALL choose_mode1
			CLR C
			CLR AC
			DA A
			SWAP A
			ANL A,#0FH
			RET
				lasplay:
				CALL choose_mode1
				CLR C
				CLR AC
				DA A
				ANL A,#0FH
				RET

;================================================================
choose_mode:
			CALL detect_mode_a
			CJNE A,#3,c_alm
			CALL hour_alarm1
			RET
			c_alm:
			JC c_clk
			CALL hour_alarm1
			RET
			c_clk:
			CALL hour_dis1
			RET
;================================================================
choose_mode1:
			CALL detect_mode_a
			CJNE A,#3,min_alm
			CALL min_alarm1
			RET
			min_alm:
			JC min_clk
			CALL min_alarm1
			RET
			min_clk:
			CALL min_dis1
			RET
;================================================================
hour_dis1:
	MOV A,REALF
	ANL A,#00000001B
	JNZ hour_24		;;;;;;;;;;;;hour_24
	MOV A,REALHOUR
		JNZ	zerodis
		MOV A,#12H
		RET
		zerodis:
		CJNE A,#13H,n1
		MOV A,REALHOUR
		CLR C
		SUBB A,#12H
		RET
					n1:
					JC n2
						CJNE A,#20H,a1
						MOV A,REALHOUR
						CLR C
						SUBB A,#18H
						RET
								a1:
								JC a2
									MOV A,REALHOUR
									CLR C
									SUBB A,#18H
									RET
									a2:
									MOV A,REALHOUR
									CLR C
									SUBB A,#12H
									RET
					n2:
					MOV A,REALHOUR
					RET
	hour_24:
	MOV A,REALHOUR
	RET
;===================================================================
min_dis1:
	MOV A,REALMIN
	RET
;;================================================================
hour_alarm1:
	MOV A,REALF
	ANL A,#00000001B
	JNZ alrmhour_24		;;;;;;;;;;;;hour_24
	MOV A,ALRMHOUR
		JNZ	zerodis1
		MOV A,#12H
		RET
		zerodis1:
		CJNE A,#13H,alm1
		MOV A,ALRMHOUR
		CLR C
		SUBB A,#12H
		RET
					alm1:
					JC alm2
						CJNE A,#20H,alrm1
						MOV A,ALRMHOUR
						CLR C
						SUBB A,#18H
						RET
								alrm1:
								JC alrm2
									MOV A,ALRMHOUR
									CLR C
									SUBB A,#18H
									RET
									alrm2:
									MOV A,ALRMHOUR
									CLR C
									SUBB A,#12H
									RET
					alm2:
					MOV A,ALRMHOUR
					RET
	alrmhour_24:
	MOV A,ALRMHOUR
	RET
;===================================================================
min_alarm1:
	MOV A,ALRMMIN
	RET
;================================mode switch=========================
mode_switch:
		CALL detect_mode_a
		CJNE A,#0,mode_switch_check
		ANL REALF,#10001111B
		ORL REALF,#00100000B
		JMP end_switch_check
		
		mode_switch_check:
		CJNE A,#1,mode_switch_check1
		ANL REALF,#10001111B
		JMP end_switch_check
		
		mode_switch_check1:
		CJNE A,#2,mode_switch_check2
		ANL REALF,#10001111B
		ORL REALF,#00010000B
		JMP end_switch_check
		
		mode_switch_check2:
		CJNE A,#3,mode_switch_check3
		ANL REALF,#10001111B
		ORL REALF,#01010000B
		JMP end_switch_check
		mode_switch_check3:
		CJNE A,#4,mode_switch_check4
		ANL REALF,#10001111B
		ORL REALF,#00110000B
		JMP end_switch_check
		mode_switch_check4:
		CJNE A,#5,end_switch_check
		ANL REALF,#10001111B
		ORL REALF,#01000000B
		
		end_switch_check:
		CALL medelay
		RET
;===================================================================
pm_turn_on:
		MOV A,REALHOUR
		CJNE A,#12H,hour_set_pm
		ORL REALF,#00000010B	;turn on pm
		hour_set_pm:
		RET
;===================================================================
Alarm_trigger:
		MOV A,REALF
		ANL A,#00001000B
		JZ nothing_done
		MOV A,REALF
		ANL A,#00001100B
		CJNE A,#12,trigger_nth
		SETB P0.7
		RET
		trigger_nth:
		CLR P0.7
		nothing_done:
		RET
;=======================================================================
Beeping:
		MOV A,SEC_LOOP
		CJNE A,#19,off_beep
		MOV A,REALF
		ORL A,#00000100B
		MOV REALF,A
		JMP beep_end
		
		off_beep:
		CJNE A,#18,on_beep
		MOV A,REALF
		ANL A,#11111011B		
		MOV REALF,A
		JMP beep_end

		on_beep:
		CJNE A,#16,off_beep1
		MOV A,REALF
		ORL A,#00000100B
		MOV REALF,A
		JMP beep_end
		
		off_beep1:
		CJNE A,#15,on_beep2
		MOV A,REALF
		ANL A,#11111011B
		MOV REALF,A
		JMP beep_end
		
		on_beep2:
		CJNE A,#12,off_beep2
		MOV A,REALF
		ORL A,#00000100B
		MOV REALF,A
		JMP beep_end
		
		off_beep2:
		CJNE A,#9,beep_end
		MOV A,REALF
		ANL A,#11111011B
		MOV REALF,A
		beep_end:
		RET
;============================alarm check===============
ALARM_CHECK:
		MOV A,ALRMHOUR
		CJNE A,REALHOUR,no_alarm
			MOV A,ALRMMIN
			CJNE A,REALMIN,no_alarm
			ORL REALF,#00001000B
		no_alarm:
		RET
;======================on_off alrm switch==============
alarm_on_off:
		MOV A,REALF
		ANL A,#10000000B
		JZ Status_no
		ANL REALF,#01111111B
		CALL disp_OFF
		RET
		Status_no:
		ORL REALF,#10000000B
		CALL disp_ON
		RET
;=============================on_off pattern========================bcd dt, g dt
disp_OFF:
		MOV R0,#30
		multi_flash:
		MOV R2,#90
		multi_flash1:
		MOV P1,#0H
		MOV P3,#11111101B
		MOV P1,#00111111B
		CALL smdelay
		MOV P1,#0H
		MOV P3,#11111011B
		MOV P1,#01110001B
		CALL smdelay
		MOV P1,#0H
		MOV P3,#11110111B
		MOV P1,#01110001B
		CALL smdelay
		MOV P1,#0H
		DJNZ R2,multi_flash1
		JNB P0.0,end_ON_OFF
		JNB P2.7,end_ON_OFF
		JNB P3.4,end_ON_OFF
		JNB P3.5,end_ON_OFF
		DJNZ R0,multi_flash
		end_ON_OFF:
		CALL medelay
		RET

disp_ON:
		MOV R0,#25
		multi_flash2:
		MOV R2,#100
		multi_flash3:
		MOV P1,#0H
		MOV P3,#11111101B
		MOV P1,#00111111B
		CALL smdelay
		MOV P1,#0H
		MOV P3,#11111011B
		MOV P1,#00110111B
		CALL smdelay
		MOV P3,#11111101B
		MOV P1,#00111111B
		CALL smdelay
		MOV P1,#0H
		MOV P3,#11111011B
		MOV P1,#00110111B
		CALL smdelay
		MOV P1,#0H
		DJNZ R2,multi_flash3
		JNB P0.0,end_ON_OFF1
		JNB P2.7,end_ON_OFF1
		JNB P3.4,end_ON_OFF1
		JNB P3.5,end_ON_OFF1
		DJNZ R0,multi_flash2
		end_ON_OFF1:
		CALL medelay
		RET
;===================================led===========================
LED_24_indic:
		MOV A,REALF
		ANL A,#00000001B
		JZ off_led24
		CLR P2.0
		RET
		off_led24:
		SETB P2.0
		RET
;====================================led_PM===============================
LED_AP_PM_indic:
		CALL detect_mode_a
		CJNE A,#2,larger_t_2
			JMP REAL_AM_PM
				larger_t_2:
				JC smaller_2
					JMP ALRM_AM_PM
						smaller_2:
						JMP REAL_AM_PM
;==========================                        ==========================
REAL_AM_PM:
		MOV A,REALF
		ANL A,#00000010B
		JZ off_led_ampm
		CLR P2.1
		RET
		off_led_ampm:
		SETB P2.1
		RET
;===========================                       ===========================
ALRM_AM_PM:
		MOV A,ALRMHOUR
		CJNE A,#11H,larger_t_11
			SETB P2.1
			RET
				larger_t_11:
				JC smaller_11
					CLR P2.1
					RET
						smaller_11:
						SETB P2.1
						RET
;==========================================================
close_alarm:
	MOV A,REALF
	ANL A,#00001000B
	CJNE A,#8,continu_loop
	ANL REALF,#11110111B
	CLR P0.7
	continu_loop:

	RET
;===========================================================
snooze_trigger:
	MOV A,STAT_TR
	ANL A,#00000001B
	JZ no_trigg
			MOV A,REALSEC
			CJNE A,SNZ_SEC,no_trigg
				MOV A,REALMIN
				CJNE A,SNZ_MIN,no_trigg
					MOV A,REALHOUR
					CJNE A,SNZ_HOUR,no_trigg
						ORL REALF,#00001000B
						ANL STAT_TR,#11111110B
	no_trigg:
	RET

;===========================================================
snooze_count:
	MOV SNZ_SEC,REALSEC

	MOV SNZ_MIN,REALMIN

	MOV SNZ_HOUR,REALHOUR

		MOV R5,#5
		snoozer:
		MOV A,SNZ_MIN
		CJNE A,#59H,incre_min
		MOV SNZ_MIN,#0
		JMP snooze_hour
			incre_min:
			INC SNZ_MIN
			MOV A,SNZ_MIN
			ANL A,#0FH
			CJNE A,#0AH,normal_increment_snz
			MOV A,SNZ_MIN
			ADD A,#6
			MOV SNZ_MIN,A
						
			normal_increment_snz:
			JMP fin_incre
			
			snooze_hour:
			MOV A,SNZ_HOUR
			CJNE A,#23H,incre_hour
			MOV SNZ_HOUR,#0		
			JMP fin_incre
			
			incre_hour:			
			INC SNZ_HOUR
			MOV A,SNZ_HOUR
			ANL A,#0FH
			CJNE A,#0AH,fin_incre
			MOV A,SNZ_HOUR
			ADD A,#6
			MOV SNZ_HOUR,A
			fin_incre:
			DJNZ R5,snoozer

			ANL REALF,#11110111B
			RET	

;==================================chime==================================
chime:
		MOV A,STAT_TR
		ANL A,#00000010B
		JZ end_chime	;JMP for no trigger
			MOV A,STAT_TR
			SWAP A
			ANL A,#00001111B
			DEC A
				CJNE A,#5,next_chime
				CLR P0.7
				JMP cont_chime
				next_chime:
					CJNE A,#3,las_chime
					SETB P0.7
					JMP cont_chime
					las_chime:
						CJNE A,#0,cont_chime
						ANL STAT_TR,#00001101B
						CLR P0.7
						JMP end_chime
				cont_chime:
				SWAP A
				ANL STAT_TR,#00001111B
				ORL STAT_TR,A
				end_chime:
				RET

;=================ldelay===================;
medelay:
	MOV R0,#1
mreprep:
	MOV R1,#200
reprep:	
	MOV R2,#250;
	DJNZ R2,$;
	DJNZ R1,reprep
	DJNZ R0,mreprep
	RET

;=================sdelay===================;
smdelay:
	MOV R1,#200;
	DJNZ R1,$;
	RET
;=================



