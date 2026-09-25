; ============================================================
;  PALA Y BOLA - ZX Spectrum 48K
;  Teclas:
;     O = pala a la izquierda     P = pala a la derecha
;     ESPACIO = lanzar la bola
;
;  La bola espera quieta encima del centro de la pala. Al pulsar
;  ESPACIO sale hacia arriba con un ángulo aleatorio de -10 a +10
;  grados y rebota contra los cuatro bordes de la pantalla y
;  contra la pala.
;
;  Versión para 8bitworkshop.com (plataforma ZX Spectrum):
;  el programa se carga en 0x5ccb y se ejecuta desde ahí.
;
;  Coordenadas de la bola en coma fija 8.8:
;     byte alto = fila/columna de carácter, byte bajo = fracción.
;  Así la bola puede avanzar menos de un carácter por paso y
;  seguir ángulos pequeños.
; ============================================================

        ORG 0x5ccb      ; dirección donde 8bitworkshop carga y ejecuta el programa

; ---------------- Constantes ----------------
CLS     EQU 0x0DAF      ; rutina ROM: borrar pantalla
FRAMES  EQU 23672       ; variable de sistema: contador de cuadros
FUENTE_X EQU 0x3D00+('X'-32)*8  ; dibujo de la "X" en la fuente de la ROM

FILA    EQU 20          ; fila de pantalla donde está la pala
ANCHO   EQU 5           ; número de caracteres de la pala
MAXX    EQU 32-ANCHO    ; columna máxima de la pala (27)
COLUMNAS EQU 32         ; ancho de la pantalla en caracteres
FILAS   EQU 24          ; alto de la pantalla en caracteres
N_ANG   EQU 21          ; número de ángulos en la tabla (-10..+10)

PUERTO_YP EQU 0xDFFE    ; semifila del teclado: P O I U Y
PUERTO_SP EQU 0x7FFE    ; semifila del teclado: SPACE SYM M N B

; ---------------- Programa principal ----------------
inicio:
        call CLS
        xor a
        ld (estado),a   ; bola esperando sobre la pala

bucle:
        halt            ; espera al refresco (50 Hz) -> sin parpadeo
        halt            ; segundo HALT: controla la velocidad

        call borra_bola ; borra la bola de su posición anterior
        call mover_pala ; lee O / P y mueve la pala

        ld a,(estado)
        or a
        jp nz,en_juego

; --- Bola esperando: se coloca encima del centro de la pala ---
        ld a,(posx)
        add a,ANCHO/2   ; columna de la X central
        ld (bx+1),a
        ld a,FILA-1     ; fila justo encima de la pala
        ld (by+1),a
        ld a,0x80       ; centro del carácter
        ld (bx),a
        ld (by),a

        ld bc,PUERTO_SP
        in a,(c)
        rra             ; bit 0 = SPACE -> acarreo (0 = pulsada)
        jp c,dibujar
        call lanzar
        jp dibujar

en_juego:
        call mover_bola

dibujar:
        call dibuja_pala
        ld a,(by+1)     ; celda que ocupa ahora la bola
        ld (bfila),a
        ld a,(bx+1)
        ld (bcol),a
        call dibuja_bola
        jp bucle

; ---------------- Pala ----------------
; mover_pala: O = izquierda, P = derecha (dentro de 0..MAXX)
mover_pala:
        ld bc,PUERTO_YP
        in a,(c)
        bit 1,a         ; bit 1 = O (0 = pulsada)
        jr nz,no_o
        ld a,(posx)
        or a            ; ¿ya en la columna 0?
        jr z,no_o
        call borra_pala
        ld hl,posx
        dec (hl)
no_o:
        ld bc,PUERTO_YP
        in a,(c)
        bit 0,a         ; bit 0 = P (0 = pulsada)
        ret nz
        ld a,(posx)
        cp MAXX         ; ¿ya en el borde derecho?
        ret nc
        call borra_pala
        ld hl,posx
        inc (hl)
        ret

; dibuja_pala / borra_pala: pinta ANCHO celdas en FILA, posx
dibuja_pala:
        ld de,FUENTE_X
        jr pinta_pala
borra_pala:
        ld de,vacio
pinta_pala:
        ld a,(posx)
        ld c,a
        ld b,FILA
        ld a,ANCHO
pp_lp:
        push af
        call pinta_car
        pop af
        inc c
        dec a
        jr nz,pp_lp
        ret

; ---------------- Bola ----------------
; lanzar: elige un ángulo aleatorio de la tabla y pone la bola en juego
lanzar:
        ld a,r          ; registro de refresco: cambia constantemente
        ld b,a
        ld a,(FRAMES)   ; cuadros transcurridos hasta pulsar ESPACIO
        add a,b         ; A = número "aleatorio" 0..255
modulo:
        cp N_ANG        ; A = A mod 21 -> índice 0..20
        jr c,mod_ok
        sub N_ANG
        jr modulo
mod_ok:
        add a,a
        add a,a         ; cada entrada de la tabla ocupa 4 bytes
        ld e,a
        ld d,0
        ld hl,tabla_ang
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (vx),de      ; velocidad horizontal
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (vy),de      ; velocidad vertical (negativa = hacia arriba)
        ld a,1
        ld (estado),a
        ret

; mover_bola: avanza la bola y la hace rebotar
mover_bola:
; --- Eje X: rebote en los bordes izquierdo y derecho ---
        ld hl,(bx)
        ld de,(vx)
        add hl,de
        ld a,h
        and 0xE0        ; columna fuera de 0..31 (o negativa)?
        jr z,x_ok
        ld hl,(vx)      ; rebote: invierte la velocidad X
        call neg_hl
        ld (vx),hl
        ld de,(bx)
        add hl,de       ; recalcula con la nueva dirección
x_ok:
        ld (bx),hl

; --- Eje Y: rebote en los bordes superior e inferior ---
        ld hl,(by)
        ld de,(vy)
        add hl,de
        ld a,h
        cp FILAS        ; fila fuera de 0..23 (o negativa)?
        jr c,y_dentro
        call rebote_y
        jr y_ok

; --- Rebote contra la pala: la bola entra en la fila de la pala ---
y_dentro:
        cp FILA         ; ¿la nueva fila es la de la pala?
        jr nz,y_ok
        ld a,(by+1)
        cp FILA         ; ¿ya estaba en esa fila? entonces no es choque
        jr z,y_ok
        ld a,(posx)
        ld b,a
        ld a,(bx+1)
        sub b           ; columna de la bola - posx
        jr c,y_ok       ; a la izquierda de la pala
        cp ANCHO
        jr nc,y_ok      ; a la derecha de la pala
        call rebote_y
y_ok:
        ld (by),hl
        ret

; rebote_y: invierte la velocidad Y y devuelve en HL la nueva posición
rebote_y:
        ld hl,(vy)
        call neg_hl
        ld (vy),hl
        ld de,(by)
        add hl,de
        ret

; neg_hl: HL = -HL
neg_hl:
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        ret

dibuja_bola:
        ld de,bola
        jr pinta_bola
borra_bola:
        ld de,vacio
pinta_bola:
        ld a,(bfila)
        ld b,a
        ld a,(bcol)
        ld c,a
        ; continúa en pinta_car

; ---------------- Pantalla ----------------
; pinta_car: copia 8 bytes desde DE a la celda (fila B, columna C)
; Dirección de pantalla: 010F F000 | LLLC CCCC   (F = fila/8, L = fila%8)
pinta_car:
        push bc
        push de
        ld a,b
        and 0x18
        or 0x40
        ld h,a          ; H = 0x40 + tercio de pantalla
        ld a,b
        and 7
        rrca
        rrca
        rrca
        or c
        ld l,a          ; L = (fila%8)*32 + columna
        ld b,8
pc_lp:
        ld a,(de)
        ld (hl),a
        inc de
        inc h           ; siguiente línea de píxeles del carácter
        djnz pc_lp
        pop de
        pop bc
        ret

; ---------------- Gráficos ----------------
bola:   defb 0x00,0x3C,0x7E,0x7E,0x7E,0x7E,0x3C,0x00
vacio:  defb 0,0,0,0,0,0,0,0

; Tabla de velocidades (vx, vy) para -10..+10 grados respecto a la
; vertical, velocidad 128/256 = medio carácter por paso:
;   vx = 128*sen(a)    vy = -128*cos(a)
tabla_ang:
        defw  -22, -126     ; -10 grados
        defw  -20, -126     ; -9 grados
        defw  -18, -127     ; -8 grados
        defw  -16, -127     ; -7 grados
        defw  -13, -127     ; -6 grados
        defw  -11, -128     ; -5 grados
        defw   -9, -128     ; -4 grados
        defw   -7, -128     ; -3 grados
        defw   -4, -128     ; -2 grados
        defw   -2, -128     ; -1 grados
        defw    0, -128     ; +0 grados
        defw    2, -128     ; +1 grados
        defw    4, -128     ; +2 grados
        defw    7, -128     ; +3 grados
        defw    9, -128     ; +4 grados
        defw   11, -128     ; +5 grados
        defw   13, -127     ; +6 grados
        defw   16, -127     ; +7 grados
        defw   18, -127     ; +8 grados
        defw   20, -126     ; +9 grados
        defw   22, -126     ; +10 grados

; ---------------- Variables ----------------
posx:   defb 13         ; columna de la pala (centrada)
estado: defb 0          ; 0 = bola sobre la pala, 1 = en movimiento
bx:     defw 0          ; columna de la bola (8.8)
by:     defw 0          ; fila de la bola (8.8)
vx:     defw 0          ; velocidad horizontal (8.8, con signo)
vy:     defw 0          ; velocidad vertical (8.8, con signo)
bfila:  defb FILA-1     ; celda donde está dibujada la bola
bcol:   defb 15

; Relleno hasta el final de la RAM de usuario (igual que el
; ejemplo "Hello World (ASM)" de 8bitworkshop)
        ORG 0xff57
        defb 0
