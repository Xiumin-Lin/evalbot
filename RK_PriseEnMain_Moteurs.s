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

BROCHE6_7			EQU 	0xC0		; bouton poussoir 1 et 2 sur broche 6 et 7

BROCHE0_1			EQU 	0x03		; bumpers 1 et 2 sur broche 0 et 1

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

		; Activer les deux moteurs droit et gauche
		BL	MOTEUR_DROIT_ON
		BL	MOTEUR_GAUCHE_ON

		; Allume LED1&2 portF broche 4&5 : 00110000 (contenu de r3)
		str r3, [r7]
		
		; Boucle de pilotage des 2 Moteurs (Evalbot tourne sur lui meme)
loop
		; Evalbot avance droit devant
		BL	MOTEUR_DROIT_AVANT
		BL	MOTEUR_GAUCHE_AVANT

		; Avancement pendant une période (deux WAIT)
		BL	WAIT	; BL (Branchement vers le lien WAIT); possibilite de retour a la suite avec (BX LR)
		BL	WAIT

		; Rotation a droite de l'Evalbot pendant une demi-periode (1 seul WAIT)
		BL	MOTEUR_DROIT_ARRIERE   ; MOTEUR_DROIT_INVERSE
		BL	WAIT

		b	loop

		b go_end

;;; ----- END MAIN -----

;;; ----- START LINK BRANCHEMENT -----
;; Boucle d'attente
WAIT	
		ldr r1, =0xAFFFFF
wait1	subs r1, #1
		bne wait1

		;; retour a la suite du lien de branchement
		BX	LR

;; Initialise les LEDs, SWITCHs et BUMPERs
LED_SWITCH_BUMPER_INIT

		; Enable Port E, F & D peripheral clock (p291 datasheet de lm3s9B96.pdf)
		ldr r5, = SYSCTL_PERIPH_GPIO  			;; RCGC2
		mov r2, #0x00000038  					;; Enable clock sur GPIO E, D et F (0x38 == 0b00111000)
		str r2, [r5]

		; "There must be a delay of 3 system clocks before any GPIO reg. access  (p413 datasheet de lm3s9B92.pdf)
		nop	   									;; tres tres important....
		nop
		nop	   									;; pas necessaire en simu ou en debbug step by step...

		; ----- CONFIGURATION LED -----
		ldr r7, = GPIO_PORTF_BASE+GPIO_O_DIR    ;; 2 Pin du portF en sortie (broche 4&5 : 00110000)
		ldr r2, = BROCHE4_5
		str r2, [r7]

		ldr r7, = GPIO_PORTF_BASE+GPIO_O_DEN	;; Enable Digital Function
		ldr r2, = BROCHE4_5
		str r2, [r7]

		ldr r7, = GPIO_PORTF_BASE+GPIO_O_DR2R	;; Choix de l'intensit? de sortie (2mA)
		ldr r2, = BROCHE4_5
		str r2, [r7]

		mov r2, #0x000       					;; pour eteindre LED

		; allumer la led broche 4 (BROCHE4_5)
		mov r3, #BROCHE4_5		;; Allume LED1&2 portF broche 4&5 : 00110000

		ldr r7, = GPIO_PORTF_BASE + (BROCHE4_5<<2)  ;; @data Register = @base + (mask<<2) ==> LED1
		; ----- Fin configuration LED -----

		; ----- CONFIGURATION Switcher -----
		ldr r9, = GPIO_PORTD_BASE+GPIO_I_PUR	;; Pul_up
		ldr r2, = BROCHE6_7
		str r2, [r9]

		ldr r9, = GPIO_PORTD_BASE+GPIO_O_DEN	;; Enable Digital Function
		ldr r2, = BROCHE6_7
		str r2, [r9]

		ldr r9, = GPIO_PORTD_BASE + (BROCHE6_7<<2)  ;; @data Register = @base + (mask<<2) ==> Switcher
		; ----- Fin configuration Switcher -----

		; ----- CONFIGURATION Bumper -----
		ldr r11, = GPIO_PORTE_BASE+GPIO_I_PUR	;; Pul_up
		ldr r2, = BROCHE0_1
		str r2, [r11]

		ldr r11, = GPIO_PORTE_BASE+GPIO_O_DEN	;; Enable Digital Function
		ldr r2, = BROCHE0_1
		str r2, [r11]

		ldr r11, = GPIO_PORTE_BASE + (BROCHE0_1<<2)  ;; @data Register = @base + (mask<<2) ==> Bumper
		;----- Fin configuration Bumper -----
		
		BX	LR
;;; ----- END LINK BRANCHEMENT -----

go_end
		NOP
		END