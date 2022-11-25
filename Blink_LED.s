;; RK - Evalbot (Cortex M3 de Texas Instrument)
	;; Les deux LEDs sont initialement allum�es
	;; Ce programme lis l'�tat du bouton poussoir 1 connect�e au port GPIOD broche 6
	;; Si bouton poussoir ferm� ==> fait clignoter les deux LED1&2 connect�e au port GPIOF broches 4&5.

; This register controls the clock gating logic in normal Run mode
SYSCTL_PERIPH_GPIO EQU		0x400FE108	; SYSCTL_RCGC2_R (p291 datasheet de lm3s9b92.pdf)

; The GPIODATA register is the data register
GPIO_PORTF_BASE		EQU		0x40025000	; GPIO Port F (APB) base: 0x4002.5000 (p416 datasheet de lm3s9B92.pdf)

; The GPIODATA register is the data register
GPIO_PORTD_BASE		EQU		0x40007000		; GPIO Port D (APB) base: 0x4000.7000 (p416 datasheet de lm3s9B92.pdf)


GPIO_PORTE_BASE		EQU		0x40024000
; configure the corresponding pin to be an output
; all GPIO pins are inputs by default
GPIO_O_DIR   		EQU 	0x00000400  ; GPIO Direction (p417 datasheet de lm3s9B92.pdf)

; The GPIODR2R register is the 2-mA drive control register
; By default, all GPIO pins have 2-mA drive.
GPIO_O_DR2R   		EQU 	0x00000500  ; GPIO 2-mA Drive Select (p428 datasheet de lm3s9B92.pdf)

; Digital enable register
; To use the pin as a digital input or output, the corresponding GPIODEN bit must be set.
GPIO_O_DEN  		EQU 	0x0000051C  ; GPIO Digital Enable (p437 datasheet de lm3s9B92.pdf)

; Pul_up
GPIO_I_PUR   		EQU 	0x00000510  ; GPIO Pull-Up (p432 datasheet de lm3s9B92.pdf)

; Broches select
BROCHE4_5			EQU		0x30		; led1 & led2 sur broche 4 et 5
BROCHE4				EQU		0x10		; led1 4
BROCHE5				EQU		0x20		; led2 5

BROCHE6				EQU 	0x40		; bouton poussoir 1

BROCHE0 			EQU     0x01		; bumper
; blinking frequency
DUREE   			EQU     0x002FFFFF

		AREA    |.text|, CODE, READONLY
		ENTRY

		;; The EXPORT command specifies that a symbol can be accessed by other shared objects or executables.
		EXPORT BLINKY_INIT
		EXPORT BLINKY_TEST

BLINKY_INIT
		;r6 -> r5
		;r0 -> r8
		;r1 -> r9

		; ;; Enable the Port F & D peripheral clock 		(p291 datasheet de lm3s9B96.pdf)
		; ;;
		ldr r5, = SYSCTL_PERIPH_GPIO  			;; RCGC2
		;; mov r0, #0x00000028  					;; Enable clock sur GPIO D et F o� sont branch�s les leds (0x28 == 0b101000)
		mov r8, #0x00000038 ;; port F E D
		; ;;														 									      (GPIO::FEDCBA)
		str r8, [r5]

		; ;; "There must be a delay of 3 system clocks before any GPIO reg. access  (p413 datasheet de lm3s9B92.pdf)
		nop	   									;; tres tres important....
		nop
		nop	   									;; pas necessaire en simu ou en debbug step by step...

		;^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^CONFIGURATION LED

		ldr r5, = GPIO_PORTF_BASE+GPIO_O_DIR    ;; 1 Pin du portF en sortie (broche 4 : 00010000)
		ldr r8, = BROCHE4_5
		str r8, [r5]

		ldr r5, = GPIO_PORTF_BASE+GPIO_O_DEN	;; Enable Digital Function
		ldr r8, = BROCHE4_5
		str r8, [r5]

		ldr r5, = GPIO_PORTF_BASE+GPIO_O_DR2R	;; Choix de l'intensit� de sortie (2mA)
		ldr r8, = BROCHE4_5
		str r8, [r5]

		 mov r2, #0x000       					;; pour eteindre LED

		; allumer la led broche 4 (BROCHE4_5)
		mov r3, #BROCHE4_5		;; Allume LED1&2 portF broche 4&5 : 00110000

		ldr r5, = GPIO_PORTF_BASE + (BROCHE4_5<<2)  ;; @data Register = @base + (mask<<2) ==> LED1
		;vvvvvvvvvvvvvvvvvvvvvvvFin configuration LED




		;^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^CONFIGURATION Switcher 1

		ldr r7, = GPIO_PORTD_BASE+GPIO_I_PUR	;; Pul_up
		ldr r8, = BROCHE6
		str r8, [r7]

		ldr r7, = GPIO_PORTD_BASE+GPIO_O_DEN	;; Enable Digital Function
		ldr r8, = BROCHE6
		str r8, [r7]

		ldr r7, = GPIO_PORTD_BASE + (BROCHE6<<2)  ;; @data Register = @base + (mask<<2) ==> Switcher

		;vvvvvvvvvvvvvvvvvvvvvvvFin configuration Switcher


				;^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^CONFIGURATION Bumper

		ldr r7, = GPIO_PORTE_BASE+GPIO_I_PUR	;; Pul_up
		ldr r8, = BROCHE0
		str r8, [r7]

		ldr r8, = GPIO_PORTE_BASE+GPIO_O_DEN	;; Enable Digital Function
		ldr r8, = BROCHE0
		str r8, [r7]

		ldr r7, = GPIO_PORTE_BASE + (BROCHE0<<2)  ;; @data Register = @base + (mask<<2) ==> Switcher

		BX	LR	; FIN du sous programme d'init.


BLINKY_TEST
		str r3, [r5]  							;; Allume LED1&2 portF broche 4&5 : 00110000 (contenu de r3)



		ldr r10,[r7]
		CMP r10,#0x00
		BNE ReadState

loop
		str r2, [r5]    						;; Eteint LED car r2 = 0x00
		ldr r9, = DUREE 						;; pour la duree de la boucle d'attente1 (wait1)

wait1	subs r9, #1
		bne wait1

		str r3, [r5]  							;; Allume LED1&2 portF broche 4&5 : 00110000 (contenu de r3)
		ldr r9, = DUREE							;; pour la duree de la boucle d'attente2 (wait2)

wait2   subs r9, #1
		bne wait2

		b loop
ReadState
		BX	LR	; FIN du sous programme d'init.


		END