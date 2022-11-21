	;; RK - Evalbot (Cortex M3 de Texas Instrument)
; programme - Pilotage 2 Moteurs Evalbot par PWM tout en ASM (Evalbot tourne sur lui meme)


		AREA    |.text|, CODE, READONLY
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


__main

		
		;;; Configurer les moteurs à la toute fin car le code fourni conserve les config précédentes 
		;; BL Branchement vers un lien (sous programme)
		; Configure les PWM + GPIO
		BL	MOTEUR_INIT

		; Activer les deux moteurs droit et gauche
		BL	MOTEUR_DROIT_ON
		BL	MOTEUR_GAUCHE_ON

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

		;; Boucle d'attente
WAIT	ldr r1, =0xAFFFFF
wait1	subs r1, #1
		bne wait1

		;; retour a la suite du lien de branchement
		BX	LR

		NOP
		END
