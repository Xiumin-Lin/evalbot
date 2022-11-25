	;; RK - Evalbot (Cortex M3 de Texas Instrument)
; programme - Pilotage 2 Moteurs Evalbot par PWM tout en ASM (Evalbot tourne sur lui meme)

		AREA    |.text|, CODE, READONLY

;;; ----- START DEFINE CONSTANTS -----

; This register controls the clock gating logic in normal Run mode
SYSCTL_PERIPH_GPIO	EQU		0x400FE108	; SYSCTL_RCGC2_R (p291 datasheet de lm3s9b92.pdf)

; The GPIODATA register is the data register
GPIO_PORTF_BASE		EQU		0x40025000	; GPIO Port F (APB) base: 0x4002.5000 (p416 datasheet de lm3s9B92.pdf)
GPIO_PORTD_BASE		EQU		0x40007000	; GPIO Port D (APB) base: 0x4000.7000 (p416 datasheet de lm3s9B92.pdf)
GPIO_PORTE_BASE		EQU		0x40024000	; GPIO Port E (APB) base: 0x4002.4000 (p416 datasheet de lm3s9B92.pdf)

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
LED_1				EQU		0x10
LED_2				EQU		0x20

BROCHE6_7			EQU 	0xC0		; bouton poussoir 1 et 2 sur broche 6 et 7
SWITCH_1			EQU		0x80
SWITCH_2			EQU		0x40

BROCHE0_1			EQU 	0x03		; bumpers 1 et 2 sur broche 0 et 1
BUMPER_G			EQU		0x01
BUMPER_D			EQU		0x02
; blinking frequency
DUREE   			EQU     0x002FFFFF

;;; ----- END DEFINE CONSTANTS -----
	
		ENTRY
		EXPORT	__main

		;; The IMPORT command specifies that a symbol is defined in a shared object at runtime.
		IMPORT	MOTEUR_INIT					; initialise les moteurs (configure les pwms + GPIO)

		IMPORT	MOTEUR_DROIT_ON				; activer le moteur droit
		IMPORT  MOTEUR_DROIT_OFF			; desactiver le moteur droit
		IMPORT  MOTEUR_DROIT_AVANT			; moteur droit tourne vers l'avant
		IMPORT  MOTEUR_DROIT_ARRIERE		; moteur droit tourne vers l'arri�re
		IMPORT  MOTEUR_DROIT_INVERSE		; inverse le sens de rotation du moteur droit

		IMPORT	MOTEUR_GAUCHE_ON			; activer le moteur gauche
		IMPORT  MOTEUR_GAUCHE_OFF			; desactiver le moteur gauche
		IMPORT  MOTEUR_GAUCHE_AVANT			; moteur gauche tourne vers l'avant
		IMPORT  MOTEUR_GAUCHE_ARRIERE		; moteur gauche tourne vers l'arri�re
		IMPORT  MOTEUR_GAUCHE_INVERSE		; inverse le sens de rotation du moteur gauche

;;; ----- START MAIN -----
__main
		
		;; Configurer les moteurs à la toute fin car le code fourni conserve les config précédentes 
		;; BL Branchement vers un lien (sous programme)
		; Configure les LEDs, SWITCHs et les BUMPERs
		BL	LED_SWITCH_BUMPER_INIT
		
		; Configure les PWM + GPIO
		BL	MOTEUR_INIT

; Attendre qu'un bouton switch soit actionne
		LDR r9, = GPIO_PORTD_BASE + (BROCHE6_7<<2)
checkSwitchState
		LDR r2,[r9]
		CMP r2,#SWITCH_1
		BEQ go_mode1
		CMP r2,#SWITCH_2
		BEQ go_mode2
		B	checkSwitchState

go_mode1
go_mode2
		; Activer les deux moteurs droit et gauche
		

		LDR r11, = GPIO_PORTE_BASE + (BROCHE0_1<<2)
		
; boucle de clignotement des led
loop
		BL	MOTEUR_DROIT_ON
		BL	MOTEUR_GAUCHE_ON
		
		; ecoute si les bumper sont actives
		LDR r2,[r11]
		BL	WAIT_BLINK_INTERVALLE
		LDR r3,[r11]
		CMP r2, r3
		BNE	loop
		
		BL	MOTEUR_DROIT_OFF
		BL	MOTEUR_GAUCHE_OFF
		CMP r2,#BUMPER_G
		BEQ	go_bumper_g
		CMP r2,#BUMPER_D
		BEQ	go_bumper_d
		CMP r2,#0x0
		BEQ	go_bumper_both
		
		B 	loop
		
go_bumper_g	
		BL	BUMPER_G_ACTIVE_LED_G
		B	loop
go_bumper_d
		BL	BUMPER_D_ACTIVE_LED_D
		B	loop
go_bumper_both
		BL	BUMPER_BOTH_ACTIVE_LEDS
		B	loop

		B 	go_end

;;; ----- END MAIN -----

;;; ----- START LINK BRANCHEMENT -----

;; Initialise les LEDs, SWITCHs et BUMPERs
LED_SWITCH_BUMPER_INIT

		; Enable Port E, F & D peripheral clock (p291 datasheet de lm3s9B96.pdf)
		LDR r5, = SYSCTL_PERIPH_GPIO  			;; RCGC2
		mov r2, #0x00000038  					;; Enable clock sur GPIO E, D et F (0x38 == 0b00111000)
		STR r2, [r5]

		; "There must be a delay of 3 system clocks before any GPIO reg. access  (p413 datasheet de lm3s9B92.pdf)
		NOP	   									;; tres tres important....
		NOP
		NOP	   									;; pas necessaire en simu ou en debbug step by step...

		; ----- CONFIGURATION LED -----
		LDR r7, = GPIO_PORTF_BASE+GPIO_O_DIR    ;; 2 Pin du portF en sortie (broche 4&5 : 00110000)
		LDR r2, = BROCHE4_5
		STR r2, [r7]

		LDR r7, = GPIO_PORTF_BASE+GPIO_O_DEN	;; Enable Digital Function
		LDR r2, = BROCHE4_5
		STR r2, [r7]

		LDR r7, = GPIO_PORTF_BASE+GPIO_O_DR2R	;; Choix de l'intensit? de sortie (2mA)
		LDR r2, = BROCHE4_5
		STR r2, [r7]
		; ----- Fin configuration LED -----

		; ----- CONFIGURATION Switcher -----
		LDR r9, = GPIO_PORTD_BASE+GPIO_I_PUR	;; Pul_up
		LDR r2, = BROCHE6_7
		STR r2, [r9]

		LDR r9, = GPIO_PORTD_BASE+GPIO_O_DEN	;; Enable Digital Function
		LDR r2, = BROCHE6_7
		STR r2, [r9]

		LDR r9, = GPIO_PORTD_BASE + (BROCHE6_7<<2)  ;; @data Register = @base + (mask<<2) ==> Switcher
		; ----- Fin configuration Switcher -----

		; ----- CONFIGURATION Bumper -----
		LDR r11, = GPIO_PORTE_BASE+GPIO_I_PUR	;; Pul_up
		LDR r2, = BROCHE0_1
		STR r2, [r11]

		LDR r11, = GPIO_PORTE_BASE+GPIO_O_DEN	;; Enable Digital Function
		LDR r2, = BROCHE0_1
		STR r2, [r11]

		LDR r11, = GPIO_PORTE_BASE + (BROCHE0_1<<2)  ;; @data Register = @base + (mask<<2) ==> Bumper
		;----- Fin configuration Bumper -----
		
		BX	LR

; allumer la led broche 4&5 (BROCHE4_5)
LED_ACTIVE
		;MOV r2, #BROCHE4_5							;; Allume LED1&2 portF broche 4&5 : 00110000
		LDR r7, = GPIO_PORTF_BASE + (BROCHE4_5<<2)  ;; @data Register = @base + (mask<<2) ==> LED1&2
		STR r3, [r7]
		BX	LR

LED_DESACTIVE
		MOV r2, #0x000								;; Eteint LED1&2
		LDR r7, = GPIO_PORTF_BASE + (BROCHE4_5<<2)
		STR r2, [r7]
		BX 	LR

;; Boucle d'attente
WAIT_BLINK_INTERVALLE	
		LDR r1, = DUREE
wait1	SUBS r1, #1
		BNE wait1
		; retour a la suite du lien de branchement
		BX	LR

LED_BLINK_ONCE
		; Warning, ne pas oublier de push dans le stack le link registre
		; utilisation d'une autre fonction (à part dans le main)
		PUSH	{LR}
		
		BL		LED_ACTIVE   			; Allume LED 1 & 2 Port F broche 4&5 : 00110000
		BL		WAIT_BLINK_INTERVALLE	; pour la duree de WAIT_BLINK_INTERVALLE

		BL		LED_DESACTIVE   		;; Eteint LED 1 & 2 car r2 = 0x00
		BL		WAIT_BLINK_INTERVALLE	; pour la duree de WAIT_BLINK_INTERVALLE
		
		; Puis ne pas oublier de le pop l'@ de retour qu'on avait push
		POP		{LR}
		BX 		LR

BUMPER_G_ACTIVE_LED_G
		MOV r3, #LED_2
		
		PUSH	{LR}
		;BL		BUMPER_EN_MORSE
		BL		D_EN_MORSE
		POP		{LR}
		BX 	LR

BUMPER_D_ACTIVE_LED_D
		MOV r3, #LED_1
		
		PUSH	{LR}
		;BL		BUMPER_EN_MORSE
		BL		G_EN_MORSE
		POP		{LR}
		BX 	LR
		
BUMPER_BOTH_ACTIVE_LEDS
		MOV r3, #BROCHE4_5
		
		PUSH	{LR}
		BL		MUR_EN_MORSE
		POP		{LR}
		BX 	LR

LED_ACTIVE_LONG
		PUSH {LR}
		BL  LED_ACTIVE
		BL  WAIT_BLINK_INTERVALLE
		BL  WAIT_BLINK_INTERVALLE
		BL  LED_DESACTIVE
		BL 	WAIT_BLINK_INTERVALLE
		POP {LR}
		BX 	LR

LED_ACTIVE_COURT
		PUSH {LR}
		BL  LED_ACTIVE
		BL  WAIT_BLINK_INTERVALLE
		BL  LED_DESACTIVE
		BL 	WAIT_BLINK_INTERVALLE
		POP {LR}
		BX 	LR
		
D_EN_MORSE
		PUSH {LR}
		BL  LED_ACTIVE_LONG
		BL  LED_ACTIVE_COURT
		BL  LED_ACTIVE_COURT
		POP {LR}
		BX 	LR

G_EN_MORSE
		PUSH {LR}
		BL  LED_ACTIVE_LONG
		BL  LED_ACTIVE_LONG
		BL  LED_ACTIVE_COURT
		POP {LR}
		BX LR
		
		
MUR_EN_MORSE
		PUSH {LR}
		;M
		BL  LED_ACTIVE_LONG
		BL  LED_ACTIVE_LONG
		
		BL  WAIT_BLINK_INTERVALLE
		
		;U
		BL  LED_ACTIVE_COURT
		BL  LED_ACTIVE_COURT
		BL  LED_ACTIVE_LONG
		
		;R
		BL  LED_ACTIVE_COURT
		BL  LED_ACTIVE_LONG
		BL  LED_ACTIVE_COURT
		POP {LR}
		BX LR

BUMPER_EN_MORSE
		PUSH {LR}
		;A
		BL  LED_ACTIVE_COURT
		BL  LED_ACTIVE_LONG
		
		BL  WAIT_BLINK_INTERVALLE
		
		;N
		BL  LED_ACTIVE_LONG
		BL  LED_ACTIVE_COURT
		
		BL  WAIT_BLINK_INTERVALLE
		
		;G
		BL  LED_ACTIVE_LONG
		BL  LED_ACTIVE_LONG
		BL  LED_ACTIVE_COURT
		
		BL  WAIT_BLINK_INTERVALLE
		
		;L
		BL  LED_ACTIVE_COURT
		BL  LED_ACTIVE_LONG
		BL  LED_ACTIVE_COURT
		BL  LED_ACTIVE_COURT
		
		BL  WAIT_BLINK_INTERVALLE
		
		;E
		BL 	LED_ACTIVE_COURT
		POP {LR}
		BX 	LR
;;; ----- END LINK BRANCHEMENT -----

go_end
		NOP
		NOP
		END