;***********************************************************
;*
;*	This is the skeleton file for Lab 6 of ECE 375
;*
;*	 Author: Sawyer Lamont
;*	   Date: 11/16/2026
;*
;***********************************************************

.include "m32U4def.inc"			; Include definition file

;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
.def	mpr = r16				; Multipurpose register

.equ	EngEnR = 5				; right Engine Enable Bit
.equ	EngEnL = 6				; left Engine Enable Bit
.equ	EngDirR = 4				; right Engine Direction Bit
.equ	EngDirL = 7				; left Engine Direction Bit

;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; beginning of code segment

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000
		rjmp	INIT			; reset interrupt

		; place instructions in interrupt vectors here, if needed

.org	$0056					; end of interrupt vectors

;***********************************************************
;*	Program Initialization
;***********************************************************
INIT:
		; Initialize the Stack Pointer
		ldi mpr, high(RAMEND)	; load immediate high byte of RAMEND into mpr
		out SPH, mpr			; set the high byte of the stack pointer	
		ldi mpr, low(RAMEND)	; load immediate low byte of RAMEND into mpr
		out SPL, mpr			; set the low byte of the stack pointer

		; Configure I/O ports
		ldi mpr, $FF		; load FF
		out DDRB, mpr		; set Port B as output
		ldi mpr, $00
		out PORTB, mpr		; set Port B output low
		
		
		ldi mpr, $00		; load 00
		out DDRD, mpr		; set Port D as in
		ldi mpr, $FF
		out PORTD, mpr		; set Port D pullup resistors
		; Configure External Interrupts, if needed

		; Configure 16-bit Timer/Counter 1A and 1B
    	
		
		ldi mpr, 0b11110001   ; Tells the timer set pins to high on a compare match and clear when it restarts, and holds the first 2 bits for mode selection
    	sts TCCR1A, mpr 

    	ldi mpr, 0b00001001   ; Tells the timer to use no prescaling and used the last 4 bits for mode selection
    	sts TCCR1B, mpr


		; Set TekBot to Move Forward (1<<EngDirR|1<<EngDirL) on Port B
		ldi mpr, (1<<EngDirR)|(1<<EngDirL)	; load direction bits into mpr
		out PORTB, mpr		; set Port B direction bits

		; Set initial speed, display on Port B pins 3:0
    
    clr  r17               ; Initialize Speed Level tracker to 0
    clr  r18               ; Initialize Duty Cycle tracker to 0

    ; Update the LEDs without destroying the Motor Direction bits
    in   mpr, PORTB        ; Read current Port B state (which holds motor directions)
    andi mpr, 0b11110000   ; Clear only the lower 4 LED bits (keep upper 4 motor bits)
    or   mpr, r17          ; Combine with initial speed level (0),
    out  PORTB, mpr        ; Write the combined data back to Port B

    ; Send the 0 Duty Cycle to the 16-bit hardware timers
    clr  mpr               ; Prepare a 0 for the High Bytes
    
    sts  OCR1AH, mpr       ; Write Right Motor High Byte FIRST
    sts  OCR1AL, r18       ; Write Right Motor Low Byte SECOND (Duty Cycle = 0)

    sts  OCR1BH, mpr       ; Write Left Motor High Byte FIRST
    sts  OCR1BL, r18       ; Write Left Motor Low Byte SECOND (Duty Cycle = 0)


		; Enable global interrupts (if any are used)


;***********************************************************
;*	Main Program
;***********************************************************
MAIN:


		; Button 7 is slow down, Button 6 is speed up, Button 5 is max speed, this will track left to right on the board
		; Will pole the buttons using sbis (Skip if Bit in I/O Register is Set) which checks for 1's
		; Once pressed, it will call the correct "action" subroutine, which will call the corresponding speed subroutine, and then wait until the button is released before returning to MAIN


        ; Check "Slow Down" button (PD7)
        sbis PIND, 7           ; If PD7 is 1 (unpressed), skip the next instruction
        rcall DOWN_ACTION      ; If PD7 is 0 (pressed), jump to the down handler

        ; Check "Speed Up" button (PD6)
        sbis PIND, 6           
        rcall UP_ACTION        

        ; Check "Speed Max" button (PD5)
        sbis PIND, 5           
        rcall MAX_ACTION       

        rjmp MAIN              ; Return to top of MAIN


DOWN_ACTION:
        rcall SPEED_DOWN       ; 1. Actually change the speed
WAIT_DOWN_RELEASE:
        sbis PIND, 7           ; 2. If PD7 is still 0 (held down), skip next line
        rjmp WAIT_DOWN_RELEASE ; 3. Keep looping here until they let go!
        ret                    ; 4. Return to MAIN only when released

UP_ACTION:
        rcall SPEED_UP
WAIT_UP_RELEASE:
        sbis PIND, 6
        rjmp WAIT_UP_RELEASE
        ret

MAX_ACTION:
        rcall SPEED_MAX
WAIT_MAX_RELEASE:
        sbis PIND, 5
        rjmp WAIT_MAX_RELEASE
        ret
;***********************************************************
;*	Functions and Subroutines
;***********************************************************

;-----------------------------------------------------------
; Func:	SPEED_UP
; Desc:	Increase the speed of the TekBot by 1 level (max 15)
;-----------------------------------------------------------
SPEED_UP:
    push mpr               ; Save mpr context to stack

    cpi  r17, 15           ; Compare current speed level to max (15)
    breq SPEED_UP_EXIT     ; If already at 15, skip the math and exit

    ; Math: Increment speed and duty cycle
    inc  r17               ; Increment speed level tracker (0-15)
    subi r18, -17          ; Add 17 to duty cycle tracker (0-255) using subi with negative value to perform addition

    ; LEDs: Update display without altering motor direction
    in   mpr, PORTB        ; Read current Port B state
    andi mpr, 0b11110000   ; Clear the lower 4 LED bits 
    or   mpr, r17          ; Insert the new speed level
    out  PORTB, mpr        ; Write safely back to Port B

    ; Motors: Update 16-bit hardware timers
    clr  mpr               ; Prepare a 0 for the High Bytes
    
    sts  OCR1AH, mpr       ; Write Right Motor High Byte FIRST
    sts  OCR1AL, r18       ; Write Right Motor Low Byte SECOND

    sts  OCR1BH, mpr       ; Write Left Motor High Byte FIRST
    sts  OCR1BL, r18       ; Write Left Motor Low Byte SECOND

SPEED_UP_EXIT:
    pop  mpr               ; Restore mpr context
    ret

;-----------------------------------------------------------
; Func:	SLOW_UP
; Desc:	Decrease the speed of the TekBot by 1 level (min 0)
;-----------------------------------------------------------
SLOW_UP:
    push mpr               ; Save mpr context to stack

    cpi  r17, 0            ; Compare current speed level to min (0)
    breq SLOW_UP_EXIT      ; If already at 0, skip the math and exit

    ; Math: Decrement speed and duty cycle
    dec  r17               ; Decrement speed level tracker (0-15)
    subi r18, 17       ; Subtract 17 directly from the duty cycle tracker

    ; LEDs: Update display without altering motor direction
    in   mpr, PORTB        ; Read current Port B state
    andi mpr, 0b11110000   ; Clear the lower 4 LED bits 
    or   mpr, r17          ; Insert the new speed level
    out  PORTB, mpr        ; Write safely back to Port B

    ; Motors: Update 16-bit hardware timers
    clr  mpr               ; Prepare a 0 for the High Bytes
    
    sts  OCR1AH, mpr       ; Write Right Motor High Byte FIRST
    sts  OCR1AL, r18       ; Write Right Motor Low Byte SECOND

    sts  OCR1BH, mpr       ; Write Left Motor High Byte FIRST
    sts  OCR1BL, r18       ; Write Left Motor Low Byte SECOND

SLOW_UP_EXIT:
    pop  mpr               ; Restore mpr context
    ret

;-----------------------------------------------------------
; Func:	SPEED_MAX
; Desc:	Set the speed of the TekBot to maximum (15)

;-----------------------------------------------------------
SPEED_MAX:
    push mpr               ; Save mpr context to stack

	cpi  r17, 15           ; Compare current speed level to max (15)
	breq SPEED_MAX_EXIT     ; If already at 15, skip the math and exit

    ldi  r17, 15           ; Load maximum speed level into r17
    ldi  r18, 255          ; Load maximum duty cycle into r18

    ; LEDs: Update display without altering motor direction
    in   mpr, PORTB        ; Read current Port B state
    andi mpr, 0b11110000   ; Clear the lower 4 LED bits
    or   mpr, r17          ; Insert the new speed level
    out  PORTB, mpr        ; Write safely back to Port B

    ; Motors: Update 16-bit hardware timers
    clr  mpr               ; Prepare a 0 for the High Bytes

    sts  OCR1AH, mpr       ; Write Right Motor High Byte FIRST
    sts  OCR1AL, r18       ; Write Right Motor Low Byte SECOND

    sts  OCR1BH, mpr       ; Write Left Motor High Byte FIRST
    sts  OCR1BL, r18       ; Write Left Motor Low Byte SECOND

SPEED_MAX_EXIT:
    pop  mpr               ; Restore mpr context
    ret


