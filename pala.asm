; ============================================================
;  PALA HORIZONTAL - ZX Spectrum 48K
;  Mueve una pala de 5 caracteres "X" con las teclas:
;     O = izquierda      P = derecha      ESPACIO = salir
;
;  Ensamblar (pasmo):
;     pasmo --tapbas pala.asm pala.tap
;  o bien cargar el binario en 32768 y ejecutar RANDOMIZE USR 32768
; ============================================================

        ORG 32768

; ---------------- Constantes ----------------
CLS     EQU 0x0DAF      ; rutina ROM: borrar pantalla
CHANOPEN EQU 0x1601     ; rutina ROM: abrir canal (A = n. de canal)
AT_CTRL EQU 22          ; código de control AT fila,columna

FILA    EQU 20          ; fila de pantalla donde está la pala
ANCHO   EQU 5           ; número de caracteres de la pala
MAXX    EQU 32-ANCHO    ; columna máxima (27)

PUERTO_YP EQU 0xDFFE    ; semifila del teclado: P O I U Y
PUERTO_SP EQU 0x7FFE    ; semifila del teclado: SPACE SYM M N B

; ---------------- Programa principal ----------------
inicio:
        call CLS
        ld a,2
        call CHANOPEN   ; salida por la pantalla superior (canal 2)
        call dibuja     ; pinta la pala en su posición inicial

bucle:
        halt            ; espera al refresco (50 Hz) -> sin parpadeo
        halt            ; segundo HALT: controla la velocidad

; --- Tecla O: mover a la izquierda ---
        ld bc,PUERTO_YP
        in a,(c)
        bit 1,a         ; bit 1 = O (0 = pulsada)
        jr nz,no_o
        ld a,(posx)
        or a            ; ¿ya en la columna 0?
        jr z,no_o
        call borra
        ld hl,posx
        dec (hl)
        call dibuja
no_o:

; --- Tecla P: mover a la derecha ---
        ld bc,PUERTO_YP
        in a,(c)
        bit 0,a         ; bit 0 = P (0 = pulsada)
        jr nz,no_p
        ld a,(posx)
        cp MAXX         ; ¿ya en el borde derecho?
        jr nc,no_p
        call borra
        ld hl,posx
        inc (hl)
        call dibuja
no_p:

; --- ESPACIO: salir a BASIC ---
        ld bc,PUERTO_SP
        in a,(c)
        rra             ; bit 0 = SPACE -> acarreo
        jr c,bucle      ; no pulsada: seguir
        ret

; ---------------- Subrutinas ----------------
; dibuja: pinta la pala ("XXXXX") en FILA, posx
dibuja:
        ld c,'X'
        jr pinta

; borra: pinta espacios sobre la pala en FILA, posx
borra:
        ld c,' '

; pinta: escribe ANCHO veces el carácter C en FILA, posx
pinta:
        ld a,AT_CTRL
        rst 16
        ld a,FILA
        rst 16
        ld a,(posx)
        rst 16
        ld b,ANCHO
pinta_lp:
        push bc
        ld a,c
        rst 16          ; imprime el carácter
        pop bc
        djnz pinta_lp
        ret

; ---------------- Variables ----------------
posx:   defb 13         ; columna inicial (pala centrada)

        END inicio
