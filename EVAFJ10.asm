; Player de EVAs para la Flashjacks.
; Basado en la versión de Sergio Guerrero Miralles, 18-4-2.001
;
; Ultima version: 01-6-2.020
;
; Formato EVA 10fps:
;
;     1 cuadro = 30 sectores = 15.360 bytes
;
;     Ventana screen 12, 128x106 = 13.568 bytes
;     Sonido PCM 15,75 KHz = 1.575 bytes (variable, cantidad exacta indicada
;                                         en los dos ultimos bytes del trigesimo
;                                         sector)
;     Resto no se usa.
;
;     [imagen * 13568] + [sonido * 1575 +o-] + [basura] + [tamanyo PCM]
;
;     Es necesario el uso de doble buffer para la imagen y el sonido.
;     Se copia un cuadro a la pagina oculta de VRAM/buffer de sonido mientras
;     se muestra/reproduce la otra.
;     Para reproducir el sonido hay que sincronizar los accesos al PCM con las
;     instrucciones de transferencia a VRAM y al buffer de sonido.
;
;
; Formato EVA 12fps:
;
;     1 cuadro = 30 sectores = 15.360 bytes
;
;     Ventana screen 12, 128x106
;     Sonido PCM 15,75 KHz = 1312 bytes (variable)
;
;     Imagen y sonido intercalados.
;
;     [{ PCM (1 byte) + PIC (11 bytes)} * 11 + PCM (1) + PIC (7)] * 106 lineas
;     + sonido + basura + tamanyo PCM
;
;     Sonido: 1312 bytes.
;
; Marca del formato MSX2 (screen8 y sonido PCM 4 bits a traves del PSG):
;
;     #02 en el bit anterior al tamanyo del PCM.
;
;-----------------------------------------------------------------------------


;-----------------------------------------------------------------------------
;Constantes del entorno.

; IDE registers:

IDE_BANK	equ	#4104
IDE_DATA	equ	#7C00
IDE_STATUS	equ	#7E07
IDE_CMD		equ	#7E07
IDE_ERROR	equ	#7E01
IDE_FEAT	equ	#7E01
IDE_SECCNT	equ	#7E02
IDE_LBALOW	equ	#7E03
IDE_LBAMID	equ	#7E04
IDE_LBAHIGH	equ	#7E05
IDE_HEAD	equ	#7E06
IDE_DEVCTRL	equ	#7E0E	;Device control register. Reset IDE por bit 2.
FJ_TIMER1	equ	#7E0D	;Temporizador de 100khz(100uSeg.) por registro. Decrece de 1 en 1 hasta llegar a 00h.

FJ_VDP_INST	equ	#7E20	;Petición instrucción al VDP desde la Flashjacks. 
FJ_VDP_R36	equ	#7E21	;Registro 36 del VDP.Destino eje X."DX7..0"
FJ_VDP_R37	equ	#7E22	;Registro 37 del VDP.Destino eje X."0,0,0,0,0,0,0,DX8"
FJ_VDP_R38	equ	#7E23	;Registro 38 del VDP.Destino eje Y."DY7..0"
FJ_VDP_NBLOQ	equ	#7E24	;Número de bloques de 512bytes a transferir al VDP.
FJ_VDP_R40	equ	#7E25	;Registro 40 del VDP.Número píxeles eje X."NX7..0"
FJ_VDP_R41	equ	#7E26	;Registro 41 del VDP.Número píxeles eje X."0,0,0,0,0,0,0,NX8"
FJ_VDP_R42	equ	#7E27	;Registro 42 del VDP.Número píxeles eje Y."NY7..0"
FJ_VDP_R43	equ	#7E28	;Registro 43 del VDP.Número píxeles eje Y."0,0,0,0,0,0,0,NY8"
FJ_VDP_R32	equ	#7E29	;Registro 32 del VDP.Origen eje X."SX7..0"
FJ_VDP_R34	equ	#7E2A	;Registro 34 del VDP.Origen eje Y."SY7..0"
FJ_VDP_R35	equ	#7E2B	;Registro 35 del VDP.Origen eje Y."0,0,0,0,0,0,SY9,SY8"
FJ_VDP_R39	equ	#7E2C	;Registro 39 del VDP.Destino eje Y."0,0,0,0,0,0,DY9,DY8"
FJ_CLUSH_FB	equ	#7E2D	;Byte alto cluster archivo Flashboy.
FJ_CLUSL_FB	equ	#7E2E	;Byte bajo cluster archivo Flashboy
FLAGS_FB	equ	#7E2F	;Flags info Flashboy. (0,0,0,0,0,0,0,AccessRAM). "7..0"
FJ_TAM3_FB	equ	#7E30	;Byte alto3 tamaño archivo Flashboy.
FJ_TAM2_FB	equ	#7E31	;Byte alto2 tamaño archivo Flashboy.
FJ_TAM1_FB	equ	#7E32	;Byte alto1 tamaño archivo Flashboy.
FJ_TAM0_FB	equ	#7E33	;Byte bajo tamaño archivo Flashboy.

; Bits in the status register

BSY	equ	7	;Busy
DRDY	equ	6	;Device ready
DF	equ	5	;Device fault
DRQ	equ	3	;Data request
ERR	equ	0	;Error

M_BSY	equ	(1 SHL BSY)
M_DRDY	equ	(1 SHL DRDY)
M_DF	equ	(1 SHL DF)
M_DRQ	equ	(1 SHL DRQ)
M_ERR	equ	(1 SHL ERR)

; Bits in the device control register register

SRST	equ	2	;Software reset
M_SRST	equ	(1 SHL SRST)

; Standard BIOS and work area entries
CLS	equ	000C3h
CHSNS	equ	0009Ch
KILBUF	equ	00156h
VDP	equ	0F3DFh

; Varios
CALSLT  equ     0001Ch
BDOS	equ	00005h
WRSLT	equ	00014h
ENASLT	equ	00024h
FCB	equ	0005ch
DMA	equ	00080h
RSLREG	equ	00138h
SNSMAT	equ	00141h
RAMAD1	equ	0f342h
RAMAD2	equ	0f343h
LOCATE	equ	0f3DCh
BUFTOP	equ	08000h
CHGET	equ	0009fh
POSIT	equ	000C6h
MNROM	equ	0FCC1h	; Main-ROM Slot number & Secondary slot flags table
DRVINV	equ	0FB22H	; Installed Disk-ROM

;Fin de las constantes del entorno.
;-----------------------------------------------------------------------------

;-----------------------------------------------------------------------------
; Macros:

;-----------------------------------------------------------------------------
;
; Execute a command
;
; Input:  A = Command code
;         Other command registers appropriately set
; Output: Cy=1 if ERR bit in status register set

macro	DO_IDE 
	ld	(IDE_CMD),a	; Envía un comand.

.WAIT_IDE:
	ld	a,(IDE_STATUS)
	bit	BSY,a
	jp	nz,.WAIT_IDE
endmacro

; Ejecuta un comando SD pero con buffer de sonido en la espera.
macro	DO_IDE_SND 
	ld	(IDE_CMD),a	; Envía un comand.

.WAIT_IDE_SND:
	exx
	ld	a,10		; La primera vez llega leidos 5. Aquí se le da el margen que tiene de mas, otros 5 (Total 10).
	cp	l
	jp	z, .WAIT_IDE_PASASND ; Si se acaba el buffer pues salta la salida de audio.
	outi			;Envia sonido. Send sound byte to DAC.Incrementa HL.
	ds	38, 0		; 38 x NOP.
.WAIT_IDE_PASASND:
	exx
	
	ld	a,(IDE_STATUS)
	bit	BSY,a
	jp	nz,.WAIT_IDE_SND
endmacro

;-----------------------------------------------------------------------------
;
; Enable or disable the IDE registers

;Note that bank 7 (the driver code bank) must be kept switched

macro	IDE_ON
	ld	a,1+7*32
	ld	(IDE_BANK),a
endmacro

macro	IDE_OFF
	ld	a,7*32
	ld	(IDE_BANK),a
endmacro

;-----------------------------------------------------------------------------
;
; Wait the BSY flag to clear and RDY flag to be set
; if we wait for more than 5s, send a soft reset to IDE BUS
; if the soft reset didn't work after 5s return with error
;
; Input:  Nothing
; Output: Cy=1 if timeout after soft reset 
; Preserves: DE and BC

macro	WAIT_CMD_RDY
	ld	de,1357		;Limite a 1357 veces.
.WAIT_RDY:
	ld	a,(IDE_STATUS)
	bit	BSY,a
	jp	z,.WAIT_RDY_END ; Hace una comprobación al inicio y deja paso cuando la FLASHJACKS informa que puede continuar.
	dec	de
	ld	a,d
	or	e
	jp	nz,.WAIT_RDY	;End of WAIT_RDY loop
	jp	error4
.WAIT_RDY_END:
endmacro

;-----------------------------------------------------------------------------
;
; Comprobación de que la unidad y los datos SD están disponibles.
macro ideready

.iderready:	
	ld	a,(IDE_STATUS)
	bit	BSY,a
	jp	nz,.iderready ; Hace una comprobación al inicio y deja paso cuando la FLASHJACKS informa que puede continuar.
	ld	hl, IDE_DATA
endmacro

; Cambia la salida de video por audio, saca audio por la salida out, vuelve al video.
macro XchgsndVDP_SND
	;ldi
	;inc	c
	
	;exx
	;outi
	;exx
	ld	c, d
	outi
	ld	c, e

endmacro

; Saca el audio del puntero HL actual en curso.
macro HL_VDP_SND
	exx
	outi
	exx
endmacro


;-----------------------------------------------------------------------------
;
; nop x16 ciclos de espera
macro nop_1
	nop
	nop
	nop
	nop
endmacro

macro nop_10
	nop_1
	nop_1
	nop_1
	nop_1
	nop_1
	nop_1
	nop_1
	nop_1
	nop_1
	nop_1
endmacro

macro nop_100
	nop_10
	nop_10
	nop_10
	nop_10
	nop_10
	nop_10
	nop_10
	nop_10
	nop_10
	nop_10
endmacro


macro nop_512
	outi_100
	outi_100
	outi_100
	outi_100
	outi_100
	outi_10
	outi_1
	outi_1
endmacro


;-----------------------------------------------------------------------------
;
; Envía al puerto de salida HL e incrementa su puntero.
macro outi_1
	;ld	a,(hl)
	;ld	a,30
	;out	(c),a
	;inc	hl
	outi
endmacro

macro outi_2
	outi_1
	outi_1
endmacro

macro outi_3
	outi_1
	outi_1
	outi_1
endmacro

macro outi_4
	outi_1
	outi_1
	outi_1
	outi_1
endmacro

macro outi_7
	outi_1
	outi_1
	outi_1
	outi_1
	outi_1
	outi_1
	outi_1
endmacro

macro outi_8
	outi_1
	outi_1
	outi_1
	outi_1
	outi_1
	outi_1
	outi_1
	outi_1
endmacro

macro outi_10
	outi_1
	outi_1
	outi_1
	outi_1
	outi_1
	outi_1
	outi_1
	outi_1
	outi_1
	outi_1
endmacro

macro outi_11
	outi_1
	outi_1
	outi_1
	outi_1
	outi_1
	outi_1
	outi_1
	outi_1
	outi_1
	outi_1
	outi_1
endmacro

macro outi_100
	outi_10
	outi_10
	outi_10
	outi_10
	outi_10
	outi_10
	outi_10
	outi_10
	outi_10
	outi_10
endmacro

macro outi_511
	outi_100
	outi_100
	outi_100
	outi_100
	outi_100
	outi_10
	outi_1
endmacro

macro outi_512
	outi_100
	outi_100
	outi_100
	outi_100
	outi_100
	outi_10
	outi_1
	outi_1
endmacro

;-----------------------------------------------------------------------------
;
; Envía al puerto de salida DE el puerto de HL e incrementa el puntero de ambos. Copia de memoria.
macro ldi_1
	;ld a,(hl)
	;ld (de),a
	;inc hl
	;inc de
	ldi
endmacro

macro ldi_8
	ldi_1
	ldi_1
	ldi_1
	ldi_1
	ldi_1
	ldi_1
	ldi_1
	ldi_1
endmacro

macro ldi_10
	ldi_1
	ldi_1
	ldi_1
	ldi_1
	ldi_1
	ldi_1
	ldi_1
	ldi_1
	ldi_1
	ldi_1
endmacro

;-----------------------------------------------------------------------------
;
; Ignora el dato de HL e incrementa el puntero.

macro ignora_HL_1
	ld	a,(HL)
	inc	hl
endmacro

macro ignora_HL_8
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
endmacro

macro ignora_HL_9
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
endmacro

macro ignora_HL_10
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
endmacro

macro ignora_HL_15
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
endmacro

macro ignora_HL_20
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
	ignora_HL_1
endmacro

;-----------------------------------------------------------------------------
;
; Fin de las macros.
;
;------------------------------------------------------------------------------
	

;------------------------------------------------------------------------------
;
; bytes de opciones:
;
;  options:                            options2:
;
;      bit0 -> Forzar12fps                 bit0 -> loop mode ON
;      bit1 -> no usado                    bit1 -> reproduccion abortada
;      bit2 -> Flashjacks sync OFF         bit2 -> no usado
;      bit3 -> YJK OFF -> screen 8         bit3 -> no usado
;      bit4 -> salida Music Module         bit4 -> Background
;      bit5 -> salida PCM                  bit5 -> no usado
;      bit6 -> salida Covox                bit6 -> definido cuadro inicial
;      bit7 -> salida PSG                  bit7 -> definido cuadro final
;
;------------------------------------------------------------------------------


;-----------------------------------------------------------------------------
;-----------------------------------------------------------------------------
; Programa principal:

	org	0100h

	jp	inicio

textoini:
	db	13,10
	db	"                    EVA Player para Flashjacks ver 1.00", 13, 10
	db	"           Basado en el programa original de Sergio Guerrero 2.001", 13, 10
fintextoini:	db	13,10
	db	"Modo de uso:",13,10
	db	" EVAFJ [path]evafile.eva [opciones]",13,10
	db	13,10
	db	"Opciones:",13,10
	db	" /W -> Apagar sincronismo Flashjacks      /8 -> Activa screen 8",13,10
	db	" /A -> Activa salida MSX-AUDIO            /Sn -> Start frame", 13,10
	db	" /X -> Activa salida Covox(por defecto)   /En -> End frame", 13,10
	db	" /M -> Activa salida PCM                  /L -> Modo bucle", 13,10
	db	" /P -> Activa salida PSG                  /C -> Forzar formato 12fps",13,10
	db	" /B archivo -> Carga un archivo imagen de fondo (.SCC)",13,10
	db	13,10
	db	" Tecla ESC -> salida",13,10
	db	" Tecla TAB -> pausa"	;,13,10
	db	#1A,"$"

inicio:
	ld	sp, (#0006)
	ld	a, (DMA)	
	or	a	
	jp	nz, readline	;Si encuentra parámetros continua.

muestratexto:			;Sin parámetros muestra el texto explicativo y sale.
	; Hace un clear Screen o CLS.
	xor    a		; Pone a cero el flag Z.
	ld     ix, CLS          ; Petición de la rutina BIOS. En este caso CLS (Clear Screen).
	ld     iy,(MNROM)       ; BIOS slot
        call   CALSLT           ; Llamada al interslot. Es necesario hacerlo así en MSXDOS para llamadas a BIOS.
	; Saca el texto de ayuda.
	ld	de, textoini	;Fija el puntero en el texto de ayuda.
	ld	c, 9
	call	BDOS		;Imprime por pantalla el texto.
	ld	c, 0
	call	BDOS		;Salida al MSXDOS.

readline:
	ld	hl, #0082	;Extrae parametros de la linea de comandos.
	ld	de, filename
	call	saltaspacio	;Salta todos los espacios encontrados.
	jp	c, muestratexto ;Si no hay nombre de archivo ejecuta salir al MSXDOS.
	cp	"/"
	jp	z, muestratexto ;Si hay barra y no nombre de archivo ejecuta salir al MSXDOS.

leefilename:	
	ldi
	ld	a, (hl)
	cp	" "
	jp	z, leeoptions	;Lee las opciones si encuentra la barra espacio.
	jp	c, abre		;Va a operación de abrir archivo si no encuentra opciones. Programa secundario.
	jp	leefilename	;Bucle lectura nombre de archivo.

leeoptions:
	call	saltaspacio	;Salta todos los espacios encontrados.
	ld	a, (hl)
	cp	"/"
	jp	nz, abre	;Si no encuentra una barra abre archivo. Programa secundario.
	inc	hl
	ld	a, (hl)
	cp	" "
	jp	z, muestratexto
	jp	c, muestratexto ;Si es una barra con un espacio muestra el texto de opciones y fin.
	ld	b, %1000	;Selecciona la marca del bit a guardar.
	cp	"8"
	jp	z, setoption	;Si es un 8 guarda el valor en variale options
	or	#20		;Pasa de si es mayusculas o minusculas.
	ld	b, %1		;Selecciona la marca del bit a guardar.
	cp	"c"
	jp	z, setoption	;Si es una c guarda el valor en variale options
	ld	b, %100		;Selecciona la marca del bit a guardar.
	cp	"w"		
	jp	z, setoption	;Si es una w guarda el valor en variale options
	ld	b, %10000	;Selecciona la marca del bit a guardar.
	cp	"a"
	jp	z, setoption	;Si es una a guarda el valor en variale options
	ld	b, %100000	;Selecciona la marca del bit a guardar.
	cp	"m"
	jp	z, setoption	;Si es una m guarda el valor en variale options
	ld	b, %1000000	;Selecciona la marca del bit a guardar.
	cp	"x"
	jp	z, setoption	;Si es una x guarda el valor en variale options
	ld	b, %10000000	;Selecciona la marca del bit a guardar.
	cp	"p"
	jp	z, setoption	;Si es una p guarda el valor en variale options
	ld	b, %1		;Selecciona la marca del bit a guardar.
	cp	"l"
	jp	z, setoption2	;Si es una l guarda el valor en variale options2
	cp	"b"
	jp	z, setback	;Si es una b va al bucle de lectura nombre archivo .SCC . Llamada a subproceso.
	cp	"s"
	jp	z, setstart	;Si es una s recoge el valor del cuadro inicial. Llamada a subproceso.
	cp	"e"
	jp	z, setend	;Si es una e recoge el valor del cuadro final. Llamada a subproceso.

	jp	muestratexto	;Si es cualquier otra opción muestra el texto de opciones y fin.

;Fin del programa principal.
;-----------------------------------------------------------------------------

;-----------------------------------------------------------------------------	
;Subprocesos del programa principal:

;Almacena variable en options.
setoption:			
	ld	a, (options)
	or	b
	ld	(options), a
	inc	hl
	jp	leeoptions	;Vuelve al bucle principal.

;Almacena variable en options2.
setoption2:
	ld	a, (options2)	
	or	b
	ld	(options2), a
	inc	hl
	jp	leeoptions	;Vuelve al programa principal.

;Bucle de lectura nombre archivo .SCC
setback:			
	inc	hl
	ld	a, (hl)
	cp	" "
	jp	nz, muestratexto;Si encuentra un espacio en lugar del nombre archivo va a muestra el texto de opciones y fin.
	call	saltaspacio	;Salta todos los espacios encontrados.
	cp	"/"
	jp	z, muestratexto	;Si encuentra una barra de opciones en lugar del nombre archivo va a muestra el texto de opciones y fin.
	ld	de, backfile	;Carga variable nombre del archivo .SCC
leefile2:	
	ldi
	ld	a, (hl)
	cp	" "
	jp	nz, leefile2	;hace la lectura hasta encontrar barra de espacio.

	ld	a, (options2)
	or	%10000
	ld	(options2), a	;Guarda una marca de Background en options2.

	xor	a
	ld	(de), a		;Pone un cero al final de la variable nombre del archivo .SCC

	jp	leeoptions	;Vuelve al programa principal.

;Recoge el valor del cuadro inicial.
setstart:	;
	call	dec2hex		;Llamada a subrutina.Convierte el cuadro inicial indicado decimal a hexadecimal.
	                        
	ld	a, %11111110
	and	d
	ld	d, a

	push	hl
	push	af
	ld	(start), bc	;Guarda en variable start y start2 el frame de inicio.
	ld	(start+2), de	
	call	mulbcdx10	;Llamada a subrutina.Multiplica en BCD x10.
	call	mulbcdx3	;Llamada a subrutina.Multiplica en BCD x3.
	ld	h, d
	ld	e, c
	ld	d, b
	ld	l, 0
	or	a
	rl	h
	rl	e
	rl	d
	ld	(start_), hl	;Guarda en variable start_ y start2_ el frame de inicio.
	ld	(start_+2), de

	ld	a, (options2)	;Hace una marca en options2 de definido cuadro de inicio.
	or	%1000000
	ld	(options2), a
	pop	af
	
	jp	c, abre		;Si no encuentra nada mas abre archivo. Programa secundario.
	
	pop	hl
	inc	hl		;Avanza un lugar en la linea de comandos.
	jp	leeoptions	;Si hay mas opciones vuelve al programa principal.

;recoge el valor del cuadro final.
setend:	;
	call	dec2hex		;Llamada a subrutina.Convierte el cuadro final indicado decimal a hexadecimal.
	
	push	hl	
	push	af
	ld	(final), bc	;Guarda en variable final y final2 el frame de fin.
	ld	(final+2), de
	call	mulbcdx10	;Llamada a subrutina.Multiplica en BCD x10.
	call	mulbcdx3	;Llamada a subrutina.Multiplica en BCD x3.	
	ld	h, d
	ld	e, c
	ld	d, b
	ld	l, 0
	or	a
	rl	h
	rl	e
	rl	d
	ld	(final_), hl	;Guarda en variable final_ y final2_ el frame de fin.
	ld	(final_+2), de
	
	ld	a, (options2)	;Hace una marca en options2 de definido cuadro de fin.
	or	%10000000
	ld	(options2), a
	pop	af
	
	jp	c, abre		;Si no encuentra nada mas abre archivo. Programa secundario.
	
	pop	hl
	inc	hl		;Avanza un lugar en la linea de comandos.
	jp	leeoptions	;Si hay mas opciones vuelve al programa principal.

;Fin de los subprocesos del programa principal.
;-----------------------------------------------------------------------------


; Fin del programa principal.
;
;-----------------------------------------------------------------------------
;-----------------------------------------------------------------------------


;-----------------------------------------------------------------------------
;
; Programa secundario. Fase de apertura del archivo ya con todas la opciones definidas.
; 

abre:
	
	ld	de, filename	;Obtiene el File Info Block del
	ld	b, 0		;fichero.
	ld	hl, 0
	ld	ix, FIB
	ld	c, #40
	call	BDOS
	or	a
	jp	nz, error2	;Salta si error del archivo no se puede abrir.	

	ld	a, (options)	;Salta a searchslot si VideoIn es la opción seleccionada.
	and	%10
	jp	nz, searchslot


	ld	hl, FIB+24	;Extrae del FIB 21-24 el tamaño del archivo.
	ld	b, (hl)		;Calcula el numero de cuadros.
	dec	hl
	ld	d, (hl)
	dec	hl
	ld	e, (hl)
	ld	l, b
	call	div60		

	ld	b, l
	ld	hl, tamanyo	;Convierte el tamaño del archivo a número de cuadros y lo guarda en variable tamanyo.
	ld	(hl), b
	inc	hl
	ld	(hl), d
	inc	hl
	ld	(hl), e		;Va incorporando todos los bytes a tamanyo.

	ld	a, (options2)	;si hay un cuadro final especificado:
	and	%10000000	;si cuadro final > ultimo cuadro -> tamanyo = ultimo cuadro
	jp	z, compstart	;si cuadro final < ultimo cuadro -> tamanyo = cuadro final

	ld	de, tamanyo
	ld	hl, final+1
	ld	a, (de)
	cp	(hl)
	jp	c, compstart
	jp	nz, restaend
	inc	de
	dec	hl
	ld	a, (de)
	cp	(hl)
	jp	c, compstart
	jp	nz, restaend
	inc	hl
	inc	hl
	inc	hl
	inc	de
	ld	a, (de)
	cp	(hl)
	jp	c, compstart
	jp	z, compstart
restaend:
	ld	hl, tamanyo
	ld	a, (final+1)
	ld	(hl), a
	inc	hl
	ld	a, (final)
	ld	(hl), a
	inc	hl
	ld	a, (final+3)
	ld	(hl), a

compstart:	                ;Si hay cuadro inicial especificado:
	ld	a, (options2)	;si cuadro ini > cuadro final -> aborta
	and	%1000000	;si cuadro ini < cuadro final -> tamanyo = cuadro final - cuadro ini
	jp	z, searchslot	;aborta estas opciones si final<inicial. Va a la búsqueda de slot directamente.

	ld	de, tamanyo
	ld	hl, start+1
	ld	a, (de)
	cp	(hl)
	jp	c, muestratexto
	jp	nz, restastart
	inc	de
	dec	hl
	ld	a, (de)
	cp	(hl)
	jp	c, muestratexto
	jp	nz, restastart
	inc	hl
	inc	hl
	inc	hl
	inc	de
	ld	a, (de)
	cp	(hl)
	jp	c, muestratexto
	jp	z, muestratexto
restastart:
	ld	de, tamanyo+2
	ld	hl, start+3
	ld	a, (de)
	sub	(hl)
	ld	(de), a
	dec	hl
	dec	hl
	dec	hl
	dec	de
	ld	a, (de)
	sbc	(hl)
	ld	(de), a
	inc	hl
	dec	de
	ld	a, (de)
	sbc	(hl)
	ld	(de), a

searchslot:
	ld	de, (tamanyo)	;Guarda el Nº de cuadros en tamanyoc
	ld	bc, (tamanyo+2)
	ld	(tamanyoc), de
	ld	(tamanyoc+2), bc

	ld	a, (FIB+25)	;Averigua la unidad lógica actual.
	ld	b, a		
	ld	d, #FF		
	ld	c, #6A		
	call	BDOS
	
	ld	a, d
	dec	a		;Le resta 1 ya que el cero cuenta.
	ld	(unidad), a	;Guarda el número de unidad lógica de acceso.
		
	ld	hl, #FB21	;Mira el número de unidades conectado en la interfaz de disco 1.	
	cp	(hl)		
	jp	c, tipodisp	;Si coincide selecciona esta unidad y va a tipo de dispositivo.
	sub	a, (hl)
	inc	hl
	inc	hl		;Mira el número de unidades conectado en la interfaz de disco 2.
	cp	(hl)
	jp	c, tipodisp	;Si coincide selecciona esta unidad y va a tipo de dispositivo.
	sub	a, (hl)
	inc	hl
	inc	hl		;Mira el número de unidades conectado en la interfaz de disco 3.
	cp	(hl)
	jp	c, tipodisp	;Si coincide selecciona esta unidad y va a tipo de dispositivo.
	sub	a, (hl)
	inc	hl
	inc	hl		;Mira el número de unidades conectado en la interfaz de disco 4.
tipodisp:
	inc	hl		;Va al slot address disk de la unidad seleccionada.
	ld	(unidad), a	;Guarda el número de unidad lógica de acceso.
	ld	a, (hl)
	ld	(slotide), a	;Guarda en slotide la dirección de esa unidad.
	di
	ld	hl,4000h
	call	ENASLT		;Pagina el slotide en la página 4000h. (Con esto fijamos la unidad SD la página 4000h o página 1).

;Detección de la Flashjacks

	ld	a,019h		; Carga en un posible FMPAC el modo recepción instrucciones EPROM.
	ld	(5FFEh),a
	ld	a,076h
	ld	(5FFFh),a

	ld	a,(4000h)	; Hace una lectura para tirar cualquier intento pasado de petición.
	
	ld	a,0aah
	ld	(4340h),a	; Petición acceso comandos FlashJacks. 
	ld	a,055h
	ld	(43FFh),a	; Autoselect acceso comandos FlashJacks. 
	ld	a,020h
	ld	(4340h),a	; Petición código de verificación de FlashJacks

	ld	b,16
	ld	hl,4100h	; Se ubica en la dirección 4100h (Es donde se encuentra la marca de 4bytes de FlashJacks)
RDID_BCL:
	ld	a,(hl)		; (HL) = Primer byte info FlashJacks
	cp	057h		; El primer byte debe ser 57h.
	jp	z,ID_2
	ld	a,000h		; Descarga en un posible FMPAC el modo recepción instrucciones EPROM.
	ld	(5FFEh),a
	ld	a,000h
	ld	(5FFFh),a
	ei			; Activa interrupciones.
	jp	error1		; Salta a error1 sin cierre de fichero(no lo ha abierto) si no es una Flashjacks.

ID_2:	inc	hl
	ld	a,(hl)		; (HL) = Segundo byte info FlashJacks
	cp	071h		; El segundo byte debe ser 71h.
	jp	z,ID_3
	ld	a,000h		; Descarga en un posible FMPAC el modo recepción instrucciones EPROM.
	ld	(5FFEh),a
	ld	a,000h
	ld	(5FFFh),a
	ei			; Activa interrupciones.
	jp	error1		; Salta a error1 sin cierre de fichero(no lo ha abierto) si no es una Flashjacks.

ID_3:	inc	hl
	ld	a,(hl)		; (HL) = Tercer byte info FlashJacks
	cp	098h		; El tercer byte debe ser 98h.
	jp	z,ID_4
	ld	a,000h		; Descarga en un posible FMPAC el modo recepción instrucciones EPROM.
	ld	(5FFEh),a
	ld	a,000h
	ld	(5FFFh),a
	ei			; Activa interrupciones.
	jp	error1		; Salta a error1 sin cierre de fichero(no lo ha abierto) si no es una Flashjacks.

ID_4:	inc	hl
	ld	a,(hl)		; (HL) = Cuarto byte info FlashJacks
	cp	022h		; El cuarto byte debe ser 22h.

	jp	z,ID_OK		; Salta si da todo OK.
	
	ld	a,000h		; Descarga en un posible FMPAC el modo recepción instrucciones EPROM.
	ld	(5FFEh),a
	ld	a,000h
	ld	(5FFFh),a
	ei			; Activa interrupciones.
	jp	error1		; Salta a error1 sin cierre de fichero(no lo ha abierto) si no es una Flashjacks.

ID_OK:	inc	hl
	ld	a,(hl)		; Al incrementar a 104h sale del modo info FlashJacks
	ld	a,000h		; Descarga en un posible FMPAC el modo recepción instrucciones EPROM.
	ld	(5FFEh),a
	ld	a,000h
	ld	(5FFFh),a
	ei

;Fin de la detección de la Flashjacks. Si sigue por aquí es que ha detectado una Flashjacks

	ld	b, #FF		;Borra los buffers de disco.
	ld	d, b
	xor	a
	ld	c, #5F		;Flush buffers de disco.
	call	BDOS

	ld	de, FIB		;Abre el fichero. Acordarse de cerrar el archivo.
	xor	a
	ld	c, #43
	call	BDOS
	or	a
	jp	nz, error2	;Salta error2 si el archivo no se puede abrir.
	
	ld	a, b
	ld	(filehandle), a	;Guarda en filehandle en su variable.

	ld	hl, (start_)	;Desplazamiento hasta el cuadro inicial.
	ld	de, (start_+2)
	ld	c, #4A		;Mueve el puntero filehandle al cuadro inicial.
	ld	a, (filehandle)
	ld	b, a
	xor	a
	call	BDOS		;Llamada a 4A de la gestión de archivos. (Mover el puntero del archivo). 

	ld	a, (filehandle)	;Lee el primer byte.
	ld	b, a
	ld	de, buffer
	ld	hl, 1
	ld	c, #48		;Leer el byte del puntuero filehandle.
	call	BDOS
	or	a
	jp	nz, error3	;Salta error3 si el archivo no se puede leer.

	di	;En este punto se va a leer el puntero IDE despues de la petición anterior de lectura de primer byte desde MSXDOS.
		;Con esto se consigue saber el puntero IDE solicitando desde MSXDOS el primer byte del archivo(o de la busqueda de inicio del cuadro a reproducir).
	IDE_ON	;Activa la unidad IDE.
	ld	a,(IDE_LBALOW)	; Guarda los punteros del IDE LBALOW
	ld	(regside1), a	; 
	ld	(regside1c), a

	ld	a,(IDE_LBAMID)	; Guarda los punteros del IDE LBAMID
	ld	(regside2), a	; 
	ld	(regside2c), a

	ld	a,(IDE_LBAHIGH) ; Guarda los punteros del IDE LBAHIGH
	ld	(regside3), a	; 
	ld	(regside3c), a

	ld	a,(IDE_HEAD)	; Guarda los punteros del IDE HEAD
	ld	(regside4), a	; 
	ld	(regside4c), a

	ld	a, #EC		; Comando ATA Identify device.
	DO_IDE			; Pide parámetros de la tarjeta SD de la unidad Flashjacks.

	ld	hl, IDE_DATA	; Guarda los 512 parámetros de la tarjeta SD en idevice
	ld	de, idevice	
	ld	bc, 512	
	ldir			; Volcado ldir de los 512 parámetros de la tarjeta SD.

	; En este punto se averigua que tipo de archivo EVA es.
leepcmsize:
	IDE_OFF
	ei
	ld	a, (filehandle)	; desplazamiento hasta el final del primer cuadro.
	ld	b, a		
	ld	a, 0
	ld	de, 0
	ld	hl, 15357	; Avanza hasta los dos últimos bytes del primer cuadro.
	ld	c, #4A		; Mueve el puntero filehandle a esos dos últimos bytes.
	call	BDOS				
	or	a
	jp	nz, error3	;Salta error3 si el archivo no se puede leer.

	ld	a, (filehandle)
	ld	b, a
	ld	a, b		; Lee los dos ultimos bytes del primer
	ld	(filehandle), a	; frame = numero de datos PCM.
	ld	de, buffer
	ld	hl, 3
	ld	c, #48		; Lee el contenido del puntero filehandle a esos dos últimos bytes y lo pone en buffer.
	call	BDOS
	or	a
	jp	nz, error3	;Salta error3 si el archivo no se puede leer.

	ld	a, (buffer)	; Comprueba si el formato es EVA normal o screen8 con sonido PCM 4 bits a traves del PSG.
	cp	2		; Si es un 2 es formato MSX2.
	call	z, msx2format	; Hace llamada a subrutina para activar en options la versión MSX2 o Screen8

	ld	a, (buffer+2)	; Con el tamanyo del PCM se diferencia entre 10 y 12fps.
	sub	5		; 5 es 12 FPS, otro valor es 10 FPS.
	call	z, option12fps	; Hace llamada a subrutina para activar en options la versión 12FPS.
	
	; En este punto prepara el VDP y la pantalla para iniciar video.
screen12:
	ld	a, 8		;Pasa a Screen 8
	rst	#30
	db	0
	dw	005FH

	di			
	in	a, (#99)	;Color bordes=0.
	ld	a, 0
	out	(#99), a
	ld	a, 128+7
	out	(#99), a

	ld	a, (#F3E0)	;Desactiva la pantalla.
	and	%10111111	;Screen OFF.
	out	(#99), a
	ld	a, 128+1
	out	(#99), a

	ld	a, (options)	;Si la opcion /8 esta activada no pone el modo YJK.
	and	%1000		
	jp	nz, nosc12	;Salta a nosc12 para no activar el modo YJK.

	ld	a, 8		;Activa el modo YJK.
	out	(#99), a
	ld	a, 25+128
	out	(#99), a
nosc12:
	ld	a, 1110b	;Sprites OFF. 
	out	(#99), a
	ld	a, 8+128
	out	(#99), a

	ld	a, (options2)	;Si hay carga de fondo de pantalla ejecuta subproceso loadback.
	and	%10000
	jp	nz, loadback

	ld	a, 36		;Si no borra la pantalla entera mediante un CLS.
	out	(#99), a
	ld	a, 17+80H
	out	(#99), a
	ld	hl, HMMV
	ld	b, 11
	ld	c, #9b
	otir
waitvdp:
	ld	a, 2		;Espera a que el comando CLS acabe.
	out	(#99), a
	ld	a, 128+15
	out	(#99), a
	in	a, (#99)
	and	1
	jp	nz, waitvdp	;Bucle de espera hasta que la función CLS finalice.
	xor	a
	out	(#99), a
	ld	a, 128+15
	out	(#99), a

	ld	a, (#FFE8)	; 60 Hz
	and	%11111101
	or	%00001000	; Interlaced.
	out	(#99), a
	ld	a, 128+9
	out	(#99), a

	ld	a, (#F3E0)	;Activa la pantalla.
	or	%01000000	;Screen ON.
	out	(#99), a
	ld	a, 128+1
	out	(#99), a

	ld	hl, #8000	;Limpia la zona del buffer de sonido y sonido 2.
	ld	(hl), #80	;Pone un 80 (signed audio 80 es el punto medio).
	ld	de, #8001	;Copia el dato anterior del 8000h al resto de bytes.
	ld	bc, 3584
	ldir			;Repite el bucle 3584 bytes.

	;Comprobación y carga del puerto PCM

	ld	a, (options)	;Salta a PSG si es la opción seleccionada.
	and	%10000000
	jp	nz, setpsgpcm	

	ld	a, (options)	;Salta a Music Module si es la opción seleccionada.
	and	%10000	
	jp	nz, mmodule	

	ld	a, (options)	;Salta a PCM si es la opción seleccionada.
	and	%100000
	jp	nz, pcmaudio	
	
	ld	a, #91		;Si no, carga en a el puerto del COVOX por defecto.
	ld	(PCMport), a	;Carga el puerto seleccionado a PCMport.
	jp	compMSX		;Se va a comprobar tipo de MSX existente. 

setpsgpcm:
	xor	a		;Define al PSG el estado de sus puertos.
	out	(#A0), a
	xor	a
	out	(#A1), a
	ld	a, 1
	out	(#A0), a
	xor	a
	out	(#A1), a
	ld	a, 7
	out	(#A0), a
	ld	a, #BE
	out	(#A1), a
	ld	a, 8
	out	(#A0), a
	ld	a, #A1		;Asigna a "a" un puerto del PSG.
	ld	(PCMport), a	;Carga el puerto seleccionado a PCMport.
	jp	compMSX		;Se va a comprobar tipo de MSX existente. 

mmodule:
	ld	a, #18		;Activa PCM Music Module.
	out	(#C0), a
	ld	a, 1
	out	(#C1), a
	ld	a, #19
	out	(#C0), a
	ld	a, 1
	out	(#C1), a
	ld	a, #0A		;Carga en a el puerto 0Ah del Music Module.
	ld	(PCMport), a	;Carga el puerto seleccionado a PCMport.
	jp	compMSX		;Se va a comprobar tipo de MSX existente. 

pcmaudio:
	ld	a, 3		;PCM del Turbo-R en modo DAC.
	out	(#A5), a	;Turbo-R PCM DAC mode.
	ld	a, #A4
	ld	(PCMport), a	;Carga el puerto seleccionado a PCMport.

	;Fin de la comprobación y carga del puerto PCM

compMSX:
	xor	a		;Comprueba si es un Turbo-R.
	ld	hl, #002D	;Pide de la BIOS MSXVER
	rst	#30
	db	0
	dw	#000C
	di
	cp	3		;Un 3 es un MSX Turbo R.
	jp	z, msxturbor	;si es un TurboR salta a msxturbor.
	
	;Configuración del MSX2Plus.

	ld	a, #FF
	ld	(modor800), a	;La variable modor800 la deja todo a 1. Fuera de servicio.
	
	ld	a, 8		;Vuelca a la variable Z80B una posible configuración de un turbo A1-WX's.
	out	(#40), a
	in	a, (#41)
	ld	(Z80B), a	

	ld	a, 8
	out	(#40), a
	ld	a, 1		;Set Z80-B 3,57Mhz. En todos los casos.
	out	(#41), a

	jp	acascarla	;Va al retorno del programa principal.
	
	;Fin configuración del MSX2Plus.
		
	;Configuración del MSX TurboR.  
	
msxturbor:	
	rst	#30		;Guarda en modor800 como viene configurado para restaurarlo a posterior.
	db	0
	dw	#183		;GETCPU mismo config que CHGCPU.
	ld	(modor800),a	;Lo guarda en la variable.
		
	ld	a, #80		;Cambia a modo Z80. Fuerza el sistema en Z80. (R800 incompatible).
	rst	#30
	db	0
	dw	#180		;CHGCPU mismo config que GETCPU.   

	;Fin configuración del MSX TurboR.
	
acascarla:			;Nexo de unión MSX2PLUS y MSXTURBOR
	ld	a,(PCMport)	;Recarga el puerto seleccionado a PCMport.
	ld	c,a		;Lo carga en c también para que empiece a tirar del puerto seleccionado.

	ld	a, #F7		;Establece la fila 7 de la matriz del teclado en el PPI.
	out	(#AA), a	
	ld	hl, #8700	;Direcciones doble buffer de sonido. En 8700h buffer sonido2.
	ld	(sonido2), hl
	ld	hl, #8000	;En 8000h buffer sonido. Por defecto ambos buffer están con valor 80 (Es un 0 signed PCM).
	ld	(sonido), hl
	di

	ld	a, (options)
	and	%1
	jp	nz, playback12	;Mira en las opciones detectadas si está activo el modo 12Fps y salta si lo está.
	; Si no, va al modo 10fps.

;---------------------------------------------------------------------------
; Subprograma Formato EVA 10fps. Ver inicio para estructura de datos. (Getlucky)

	di
	IDE_ON			;Activa los comandos IDE.
playback: 
	ld	hl, (sonido)	;HL' = Sound buffer 1 pointer. Restablece el puntero a inicio 8000h.
	outi			;Envia sonido. Send sound byte to DAC.Incrementa HL.
	exx		        

	call	framecount	;Llama contador de frames. Si es cero sale de este subprograma a gestion fin del video.
	
	exx
	outi			;Envia sonido. Send sound byte to DAC.Incrementa HL.
	exx
	
	call	readkeyb	;Llama lectura del teclado para pausa TAB o salida ESC. Si es salida va a gestion fin del video.
	
	exx
	outi			;Envia sonido. Send sound byte to DAC.Incrementa HL.
	exx

	call	chgpage		;Cambia la página de video a mostrar. 0 por 1 y viceversa.

	exx
	outi		        ;Envia sonido. Send sound byte to DAC.Incrementa HL.
	exx		              
	
	exx
	outi			;Envia sonido. Send sound byte to DAC.Incrementa HL.
	exx

	ld	a, (regside1)	;Reestablece los punteros del IDE para
	ld	(IDE_LBALOW), a	;que apunten al sector en curso.
	ld	a, (regside2)	;Reestablece los punteros del IDE para
	ld	(IDE_LBAMID), a	;que apunten al sector en curso.
	ld	a, (regside3)	;Reestablece los punteros del IDE para
	ld	(IDE_LBAHIGH), a;que apunten al sector en curso.
	ld	a, (regside4)	;Reestablece los punteros del IDE para
	ld	(IDE_HEAD), a	;que apunten al sector en curso.
	ld	a, 30		;Manda comando Read Sectors
	ld	(IDE_SECCNT), a	;al IDE. Lee 30 sectores=1cuadro.
	ld	a, #20
	
	DO_IDE_SND		;Hace espera de ejecución comando IDE-SD con descarga de sonido del buffer.

	exx
	outi			;Envia sonido. Send sound byte to DAC.Incrementa HL.
	exx

	ld	hl, IDE_DATA	;Inicia el puntero IDE_DATA a posición inicial.

	ld	c, #99		;Envia comando HMMC al VDP junto al primer punto.    
	ld	a, 36	
	out	(c), a
	ld	a, 17+80H
	out	(c), a
	ld	hl, HMMC1
	inc	c
	inc	c

	ld	a, (IDE_DATA)	;Lee el primer valor del IDE-SD.

	exx
	outi			;Envia sonido. Send sound byte to DAC.Incrementa HL.
	exx		

	outi		        ;Envia el comando al VDP.
	outi		        ;Send the command to VDP.
	outi
	outi
	outi
	outi
	outi
	outi
	out	(c), a		;Envía el primer valor del IDE-SD al VDP.
	outi

	exx
	outi			;Envia sonido. Send sound byte to DAC.Incrementa HL.    
	exx		              

	outi
	ld	a, 44+80H
	out	(#99), a
	ld	a, 17+80H
	out	(#99), a
	ld	c, #9b
	ld	hl, IDE_DATA+1	;Selecciona dato+1 al puntero del VDP para envío.		
	outi			;Envía segundo dato al VDP.

	exx
	outi			;Envia sonido. Send sound byte to DAC.Incrementa HL.    
	exx

	ld	(oldstack), sp	;Guarda de la pila donde deja la secuencia existente.	
newstack:	
	ld	sp, play10stack	;Carga en la pila la secuencia de rutinas de reproduccion.
	ret			;Es como un CALL. al hacer un RET coge de la pila donde debe saltar.

return2:
	ld	sp, (oldstack)	;Vuelve.Total datos leidos: 13568bytes para graficos, 1792bytes para audio.

	ld	hl, (sonido)	;El segundo buffer de sonido pasa al primer plano y el primero al segundo.
	ld	de, (sonido2)	
	ld	(sonido), de
	ld	(sonido2), hl

	exx		
	outi			;Envia sonido. Send sound byte to DAC.Incrementa HL.  
	exx
	
	call	inc30		;Incrementa los punteros de lectura del IDE en 30 para leer el siguiente cuadro.

retardo:			;Prepara el siguiente buffer de audio para su recepción.
	exx
	ld	a, (options)
	and	%100
	jp	z, retardo3	;Saca de options si tiene habilitado el PCM sync. Si no, no lee el puerto de espera del PCM
retardo2:
	outi
	ds	33, 0		;33 x NOP. 160T-states es el ciclo entre sonido y sonido.(160-10_del_jp-16_del_LD_siguiente=134/4_por_NOP=33_NOPs.
				;Aquí ya ha leido todo el buffer activo 1575bytes. En la siguiente lectura necesita un cambio de buffer.
	jp	playback	;Vuelve a empezar el siguiente cuadro si procede.
retardo3:
	ld	a, (FJ_TIMER1)	;Lee el temporizador1 de la Flashjacks.
	cp	00h		;Si llega a cero es que ya ha consumido el tiempo que debería haber realizado el transfer.
	jp	nz, retardo3	;Si no, repite el bucle hasta llegar a cero.
	ld	a, 81
	ld	(FJ_TIMER1),a	;Carga en el Timer1 el tiempo que debería durar el siguiente transfer.	
	outi
	ds	33, 0		;33 x NOP. 160T-states es el ciclo entre sonido y sonido.(160-10_del_jp-16_del_LD_siguiente=134/4_por_NOP=33_NOPs.
				;Aquí ya ha leido todo el buffer activo 1575bytes. En la siguiente lectura necesita un cambio de buffer.
	jp	playback	;Vuelve a empezar el siguiente cuadro si procede.

; Fin subprograma Formato EVA 10fps. Ver inicio para estructura de datos. (Getlucky)
;---------------------------------------------------------------------------

;---------------------------------------------------------------------------
; Subprograma Formato EVA 12fps. Ver inicio para estructura de datos. (Salamander)

playback12:
	IDE_ON			;Activa los comandos IDE.
	;WAIT_CMD_RDY		;Espera a que el IDE-SD esté disponible y no ocupado.
playback12_: 
	outi			;Envia sonido. Send sound byte to DAC.Incrementa HL.
	exx

	call	framecount	;Llama contador de frames. Si es cero sale de este subprograma a gestion fin del video.

	call	readkeyb	;Llama lectura del teclado para pausa TAB o salida ESC. Si es salida va a gestion fin del video.

	call	chgpage		;Cambia la página de video a mostrar. 0 por 1 y viceversa.

	ld	a, (regside1)	; Reestablece los punteros del IDE para
	ld	(IDE_LBALOW), a	; que apunten a la unidad y al primer sector.
	ld	a, (regside2)	; Reestablece los punteros del IDE para
	ld	(IDE_LBAMID), a	; que apunten a la unidad y al primer sector.
	ld	a, (regside3)	; Reestablece los punteros del IDE para
	ld	(IDE_LBAHIGH), a; que apunten a la unidad y al primer sector.
	ld	a, (regside4)	; Reestablece los punteros del IDE para
	ld	(IDE_HEAD), a	; que apunten a la unidad y al primer sector.
	ld	a, 30		;Manda comando Read Sectors
	ld	(IDE_SECCNT), a	;al IDE. Lee 30 sectores=1cuadro.
	ld	a, #20
	
	DO_IDE			;Hace espera de ejecución comando IDE-SD con descarga de sonido del buffer.

	exx
	outi			;Envia sonido. Send sound byte to DAC.Incrementa HL.
	exx

	ld	hl, IDE_DATA	;Inicia el puntero IDE_DATA a posición inicial.

	ld	c, #99		;Envia comando HMMC al VDP junto al primer punto.    
	ld	a, 36	
	out	(c), a
	ld	a, 17+80H
	out	(c), a
	ld	hl, HMMC1
	inc	c
	inc	c

	ld	e, c		;Guarda el puerto c en e.
	ld	a, (PCMport)	;Carga el puerto PCM en a.
	ld	c, a		;Lo transfiere a c para su ejecución.
	ld	a, (IDE_DATA)	;Carga el primer valor de la tarjeta SD.
	ex	af,af'		;Guarda el primer dato de audio para su envío mas adelante.
	ld	d, c		;Pasa el puerto de audio a d.
	ld	c, e		;Recupera el puerto c del VDP.
	ld	a, (IDE_DATA+1) ;Carga el siguiente dato de la SD.

	exx
	outi			;Envia sonido. Send sound byte to DAC.Incrementa HL.
	exx

	outi			;Envia el comando al VDP.
	outi			;Send the command to VDP.
	outi
	outi
	outi
	outi
	outi
	outi
	out	(c), a		;Envía el primer valor del IDE-SD al VDP.
	
	exx
	outi
	exx

	outi			;Envia el comando al VDP.
	outi

	ld	a, 44+80H
	out	(#99), a
	ld	a, 17+80H	
	out	(#99), a
	ld	hl, IDE_DATA + 2;Selecciona dato+2 al puntero del VDP para envío.
	
	ld	(oldstack), sp	;Guarda de la pila donde deja la secuencia existente.
newstack2:	
	ld	sp, play12stack	;Carga en la pila la secuencia de rutinas de reproduccion.

	ex	af,af'		;Recupera el primer dato de audio y lo vuelca para envío.
	ld	c, d
	out	(c),a
	ld	c, e
			
	ret			;Es como un CALL. al hacer un RET coge de la pila donde debe saltar.

return:
	ld	sp, (oldstack)	;Vuelve.Total datos leidos:  xx bytes para graficos, xx bytes para audio.

	
	ld	de, (sonido)	;HL' = Sound buffer 1 pointer. Restablece el puntero a inicio 8000h.
	
	ldi
	ldi
	ldi
	ldi
	
	exx
	ld	hl, (sonido)	;HL' = Sound buffer 1 pointer. Restablece el puntero a inicio 8000h.
	exx
	
	
	ldi			;Vuelca el audio en el el buffer de sonido.
	ldi
	ldi
	ldi
	

	ideready		;Prepara los siguientes 512 bytes de la tarjeta SD.

	ldi			;Vuelca el audio en el el buffer de sonido.
	ldi
	

	
	call	transfsnd2	;Transfiere un paquete de bytes de audio al buffer.


	
	
	ldi			;Vuelca el audio en el el buffer de sonido, los bytes restantes de audio de la trama.
	ldi
	
	ignora_HL_10

	ld	a, 32		;Carga un contador para  bytes de desecho. 
sendpcm2:
	exx
	outi			;Envia sonido. Send sound byte to DAC.Incrementa HL.
	exx
	
	ld	b,a		;Guarda el contador en b.
	ignora_HL_10		;Ignora 14 HL.
	ignora_HL_1		
	ignora_HL_1		
	ignora_HL_1		
	ignora_HL_1		
	ld	a,b		;Devuelve de nuevo el contador a 'a'.

	dec	a		;Decrementa en 1 el conteo.
	jp	nz, sendpcm2	;Bucle hasta que finalice el contador de 'a'.

	exx
	outi			;Envia sonido. Send sound byte to DAC.Incrementa HL.
	exx

	ignora_HL_1		;Ignora 12 HL.
	ignora_HL_1		
	ignora_HL_10		


	exx
	outi			;Envia sonido. Send sound byte to DAC.Incrementa HL.
	exx
	
	ignora_HL_8		;Ignora 8 HL.

	ld	a,(HL)		;Reserva los dos últimos bytes del cuadro donde indican tipo de archivo y tamaño del PCM
	ld	(tamanyoPCM), a	
	inc	hl
	ld	a,(HL)
	ld	(tamanyoPCM + 1), a
	inc	hl		;Ultimo byte del cuadro leido.
	
	call	inc30		;Incrementa los punteros de lectura del IDE en 30 para leer el siguiente cuadro.

	exx

retardox:		                       
	; No procede espera en 12FPS. El z80 va apurado al último ciclo. Tal como está clava el video en los segundos que le toca.
	
	;ld	a, (options)	;Comprueba si está el retraso por software o por hardware.
	;and	%100
	;jp	z, retardo3x
	jp	playback12_	;Va al siguiente cuadro.

retardo3x:	
	ld	a, (FJ_TIMER1)	;Lee el temporizador1 de la Flashjacks.
	cp	00h		;Si llega a cero es que ya ha consumido el tiempo que debería haber realizado el transfer.
	jp	nz, retardo3x	;Si no, repite el bucle hasta llegar a cero.
	ld	a, 79
	ld	(FJ_TIMER1),a	;Carga en el Timer1 el tiempo que debería durar el siguiente transfer.
	jp	playback12_	;Va al siguiente cuadro.

; Fin subprograma Formato EVA 12fps. Ver inicio para estructura de datos. (Salamander)
;---------------------------------------------------------------------------

;---------------------------------------------------------------------------
; Subprograma finalización del programa y salida estable al sistema


finvideo:		                ; Acaba la reproducción.
	ld	a, (options2)		; Si no esta activa la opcion /L salta a finvideo3
	and	%1	
	jp	z, finvideo3

	ld	de, (tamanyoc)		; Restablece el tamanyo del video a reproducir
	ld	(tamanyo), de
	ld	de, (tamanyoc+2)
	ld	(tamanyo+2), de

	ld	a, (regside1c)		; Restablece los punteros del IDE para nueva reproducción.
	ld	(regside1), a
	ld	(IDE_LBALOW), a
	ld	a, (regside2c)	
	ld	(regside2), a
	ld	(IDE_LBAMID), a
	ld	a, (regside3c)
	ld	(regside3), a
	ld	(IDE_LBAHIGH), a
	ld	a, (regside4c)
	ld	(regside4), a
	ld	(IDE_HEAD), a

	ld	a, (PCMport)		; Carga en c el canal PCM de audio.
	ld	c, a			

	IDE_OFF
	ei
	jp	acascarla		; Salta a las rutinas de reproduccion nuevamente.
	
finvideo3:
	IDE_OFF
	ei
	ld	a, (filehandle)		; Cierra el fichero.
	ld	b, a
	ld	c, #45
	call	BDOS

	ld	a, (modor800)		; Si es un Turbo-R reestablece el modo del procesador.
	cp	#FF	
	jp	z, notr			; Si lee FF no es un TurboR y pasa de reestablecer nada.
	or	#80
	rst	#30
	db	0
	dw	#180
	jp	resrefr			; Salta a restaurar refrescos del VDP.

notr:					; si es un 2+ de Panasonic a 6Mhz lo vuelve a poner a 6Mhz.
	ld	a, (Z80B)
	cp	#FA
	jp	z, tresMhz		; Si no lo es fuerza a frecuencia de un Z80 normal.

	ld	a, 8			; Fuerza a 6 Mhz si la variable z80B de inicio así lo tenía. 
	out	(#40), a
	ld	a, 0
	out	(#41), a
	jp	resrefr			; Salta a restaurar refrescos del VDP.
tresMhz:
	ld	a, 8			; Si no habían turbos definidos, por si acaso fuerza a frecuencia normal del MSX.
	out	(#40), a
	ld	a, 1
	out	(#41), a

resrefr:
	
	ld	a, (#FFE8)		; Recupera los refrescos normales del VDP.
	out	(#99), a
	ld	a, 128+9
	out	(#99), a

	xor	a			; Vuelve a Screen 0.
	rst	#30
	db	0
	dw	#005F

	ld	a,(RAMAD1)		;Esto devuelve los mappers del MSX en un estado lógico y estable.
	ld	hl,4000h
	call	ENASLT			;Select Main-RAM at bank 4000h~7FFFh
	ld	a,(RAMAD2)
	ld	hl,8000h
	call	ENASLT			;Select Main-RAM at bank 8000h~BFFFh

	ei				; Activa interrupciones.

	ld	a, "$"
	ld	(fintextoini), a	; Marca el final del texto a mostrar. (las dos primeras líneas).	
	ld	c, 9			; Escribe solo las dos primeras líneas del texto de presentación.
	ld	de, textoini
	call	BDOS

	ld	a, (options)		;Salta a printexin2 si VideoIn es la opción seleccionada.
	and	%10
	jp	nz, printexin2

	ld	a, (options2)		;Si sale abortando indica el numero del ultimo frame.
	and	%10	
	jp	z, printexin2		;Si no, salta al mensaje de video finalizado y fin del programa.

	ld	hl, nframe+7		;Conversión de los frames a texto en nframe para imprimir por pantalla.
	exx

	or	a

	ld	a, (tamanyo+2)		;Ordena la variable tamanyo en su formato numérico. Resta del total para calcular el tamaño en curso.
	ld	b, a
	ld	a, (tamanyoc+2)
	sub	b
	ld	e, a
	ld	a, (tamanyo+1)
	ld	b, a
	ld	a, (tamanyoc+1)
	sbc	b
	ld	d, a
	ld	a, (tamanyo)
	ld	b, a
	ld	a, (tamanyoc)
	sbc	b
	ld	l, a

	or	a

	ld	a, (start+3)		;Suma el numero del ultimo cuadro al cuadro inicial para obtener el cuadro absouluto dentro del fichero.
	add	e	
	ld	e, a	
	ld	a, (start)
	adc	d
	ld	d, a
	ld	a, (start+1)
	adc	l
	ld	l, a

	jp	bin2dec_		;Bucle transformación de binario a decimal.
nocero:
	ld	c, 10
	call	div_LDE_by_C
	ld	a, h
	or	#30
	exx
	dec	hl
	ld	(hl), a
	exx
	ld	a, l
bin2dec_:	or	d
	jp	nz, nocero
	ld	a, e
	cp	10
	jp	nc, nocero
	exx
	or	#30			;Transforma el número decimal a ASCII.
	dec	hl
	ld	(hl), a
	exx

printframe:
	exx
	ld	de, ndecframe		;Fija el puntero del número en la cadena de carácteres de textin3.
	ld	bc, 12
	ldir				;Los vuelca todos a la variable.

	ld	de, texin3		;Imprime por pantalla el frame en el que se ha interrumpido.
	ld	c, 9
	call	BDOS
	ld	c, 0
	call	BDOS			;Devuelve el control al sistema y fin.

printexin2:
	ld	de, texin2		;Imprime por pantalla Video finalizado.
	ld	c, 9
	call	BDOS
	ld	c, 0			;Devuelve el control al sistema y fin.
	call	BDOS

; Textos de la finalización del programa.
texin3:	db	13,10,"Interrumpido en el frame "
ndecframe:	db	"        ",13,10,"$"
texin2:	db	13,10,"Video finalizado.",13,10,"$"

nframe:	db	"       !!",13,10,"$"


; Fin subprograma finalización del programa y salida estable al sistema
;---------------------------------------------------------------------------


;-----------------------------------------------------------------------------	
;Subproceso de carga de una imagen de fondo pantalla:

loadback:
	ld	de, backfile	;Abre el fichero del puntero backfile. Acordarse de cerrar el archivo.
	xor	a
	ld	c, #43
	call	BDOS
	or	a
	jp	nz, error2_	;Si hay un error de no se puede abrir lo indica por pantalla y fin del programa.

	ld	a, b
	ld	(filehandle2), a;Pasa el resultado del inicio del puntero del archivo a filehandle2.
	ld	de, #8000
	ld	hl, #3507	;Cantidad de bytes a transferir a la dirección 8000h.
	ld	c, #48		;Lee el contenido del puntero filehandle2
	call	BDOS
	or	a
	jp	nz, error3_	;Si hay error de lectura lo indica por pantalla y fin del programa.

	ld	a, (#8007)
	ld	(transback+8), a;Pasa la marca de 8007 a la variable transback +8.

	di
	in	a, (#99)
	ld	a, 36
	out	(#99), a
	ld	a, 17+128
	out	(#99), a
	ld	hl, transback	;Envía los datos de transback al primer punto de pantalla cantidad 0bh.
	ld	bc, #0b9b
	otir			;Repite 0bh veces.

	ld	a, 44+128
	out	(#99), a
	ld	a, 17+128
	out	(#99), a
	ld	hl, #8008
	ld	a, 53
	ld	bc, #FF9b	;Envía el byte 8008 en adelante a pantalla . Se programa contador 0FFh veces.
pptransfer:	
	otir			;Ejecuta el envio del datos al VDP 0FFh veces.
	dec	a		
	jp	nz, pptransfer	;Bucle de lo anterior 53 veces. (Total transferidos 13.515 bytes).

	call	read2vram	;Lee del filehandle2 3500bytes y lo envía al VDP.
	call	read2vram	;Lee del filehandle2 3500bytes y lo envía al VDP.
	call	read2vram	;Lee del filehandle2 3500bytes y lo envía al VDP.

	ld	a, (filehandle2);Cierra el fichero abierto.
	ld	b, a
	ld	c, #45
	call	BDOS

	di
	in	a, (#99)
	ld	a, 32
	out	(#99), a
	ld	a, 17+128
	out	(#99), a
	ld	hl, transback2	;Envía los datos de transback2 al primer punto de pantalla cantidad 0bh.
	ld	bc, #0f9b
	otir			;Repite 0Fh veces.

	jp	waitvdp		;Devuelve el control al proceso principal.

;Fin subproceso de carga de una imagen de fondo pantalla.
;-----------------------------------------------------------------------------	


;-----------------------------------------------------------------------------	
;Subproceso de salida del programa con mensaje de error:

txterror:	db	"Error: $"

error:	;Salida normal con mensaje de error.
	push	de		;Guarda el mensaje de error a mostrar.
	
		
	ld	a,(RAMAD1)	;Esto devuelve los mappers del MSX en un estado lógico y estable.
	ld	hl,4000h
	call	ENASLT		;Select Main-RAM at bank 4000h~7FFFh
	ld	a,(RAMAD2)
	ld	hl,8000h
	call	ENASLT		;Select Main-RAM at bank 8000h~BFFFh

	ld	de, txterror	;Imprime por pantalla la palabrar Error.
	ld	c, #09
	call	BDOS

	pop	de		;Recupera e imprime por pantalla el mensaje del error.
	ld	c, #09
	call	BDOS

	ld	a, (#FFE8)	;Acceso al VDP para devolver los refrescos.	
	out	(#99), a
	ld	a, 128+9
	out	(#99), a
	
	ei			;Activa interrupciones. Por si acaso se han quedado desactivadas.
	ld	c, 0		;Salida al MSXDOS y fin del programa.
	call	BDOS

error9: ;Salida cerrando archivo con mensaje de error:
	push	de

	ld	a, (filehandle)	;Cierra el archivo
	ld	b, a
	ld	c, #45
	call	BDOS

	ei
	ld	a, (#FFE8)	;Acceso al VDP para devolver los refrescos.
	out	(#99), a
	ld	a, 128+9
	out	(#99), a

	xor	a		;Screen 0.
	rst	#30
	db	0
	dw	#005F

	ld	a,(RAMAD1)	;Esto devuelve los mappers del MSX en un estado lógico y estable.
	ld	hl,4000h
	call	ENASLT		;Select Main-RAM at bank 4000h~7FFFh
	ld	a,(RAMAD2)
	ld	hl,8000h
	call	ENASLT		;Select Main-RAM at bank 8000h~BFFFh

	ld	c, 9
	ld	de, txterror	;Imprime por pantalla la palabrar Error.
	call	BDOS

	pop	de		;Recupera e imprime por pantalla el mensaje del error.
	ld	c, #09
	call	BDOS
	
	ei			;Activa interrupciones. Por si acaso se han quedado desactivadas.
	ld	c, 0		;Salida al MSXDOS y fin del programa.
	call	BDOS


;Mensajes de error:
txterror1:	db	"FLASHJACKS no detectada!!",13,10,"$"
error1:
	ld	de, txterror1	;Error de Flashjacks no detectada.
	jp	error

txterror2:	db	"el archivo no se puede abrir!!",13,10,"$"
error2:
	ld	de, txterror2	;Error del archivo que no se puede abrir.
	jp	error

error2_:
	ld	de, txterror2	;Error del archivo que no se puede abrir cerrando archivo.
	jp	error9

txterror3:	db	"el archivo no se puede leer!!",13,10,"$"
error3:
	ld	de, txterror3	;Error del archivo que no se puede leer.
	jp	error

error3_:
	ld	de, txterror3	;Error del archivo que no se puede leer cerrando archivo.
	jp	error9

txterror4:	db	"la Flashjacks no está preparada!!",13,10,"$"
error4:
	xor	a		;Screen 0.
	rst	#30		
	db	0
	dw	#005F
	ld	de, txterror4	;Error de la Flashjacks no está preparada.
	jp	error

txterror5:	db	"no es un archivo EVA!!",13,10,"$"
error5:				;Error de no es un archivo EVA.
	ld	de, txterror5
	jp	error

txterror6:	db	"IDE BIOS 1.92 or greater needed!!",13,10,"$"
error6:				;Error de BIOS 1.92 o superior necesaria.
	ld	de, txterror6
	jp	error

txterror7:	db	"error de la unidad!!",13,10,"$"
error7:				;Error en la unidad.
	ld	de, txterror7
	jp	error


;Fin del subproceso de salida del programa con mensaje de error.
;-----------------------------------------------------------------------------	


;-----------------------------------------------------------------------------
;
; Subrutinas (vienen de un CALL):

;-----------------------------------------------------------------------------
;
; Espera al ideready de la tarjeta SD.
_ideready:
	ideready
	ret

;-----------------------------------------------------------------------------
;
; Saltar espacios de una cadena de carácteres

saltaspacio:			;Salta todos los espacios en la lectura de cadena de carácteres.
	ld	a, (hl)
	cp	" "
	ret	nz		;Si hay otra cosa que no sea espacios fin de la subrutina.
	inc	hl
	jp	saltaspacio	;Bucle saltar espacios.

;-----------------------------------------------------------------------------
;
; Convierte una cadena numérica de decimal a hexadecimal.
; El resultado lo pone en bc y de

dec2hex:
	ld	bc, 0
	ld	de, 0
dec2hex2:
	inc	hl		;lee la cadena numérica en texto.
	ld	a, (hl)
	cp	" "
	ret	z		;Si hay un espacio fin de la lectura. Sale de la subrutina
	ret	c		;Si no hay nada fin de la lectura. Sale de la subrutina.
	sub	#30		;Lo pasa a número de variable.(30 a 39 ASCII).
	cp	10
	jp	nc, dec2hex3	;Si no es un número muestra texto y fin.
	push	af
	call	mulbcdx10	;Multiplica por 10 el número.
	pop	af
	add	a, d
	ld	d, a
	ld	a, c
	adc	a, 0
	ld	c, a
	ld	a, b
	adc	a, 0
	ld	b, a
	jp	dec2hex2	;Va haciendo bucle hasta tener el número en HEX.
dec2hex3:
	pop	hl		;Mata el RET del stack pointer. (Extrae del SP la llamada del CALL y lo pone en HL por ejemplo).
	jp	muestratexto	;Salto incondicional de muestra texto y fin.

;-----------------------------------------------------------------------------
;
; Multiplica un valor BCD x10

mulbcdx10:
	or	a
	rl	d
	rl	c
	rl	b
	ld	ixh, b
	ld	ixl, c
	ld	iyh, d
	or	a
	rl	d
	rl	c
	rl	b
	or	a
	rl	d
	rl	c
	rl	b
	ld	a, d
	add	a, iyh
	ld	d, a
	ld	a, c
	adc	a, ixl
	ld	c, a
	ld	a, b
	adc	a, ixh
	ld	b, a
	ret

;-----------------------------------------------------------------------------
;
; Multiplica un valor BCD x3

mulbcdx3:
	ld	ixh, b
	ld	ixl, c
	ld	iyh, d
	or	a
	rl	d
	rl	c
	rl	b
	ld	a, d
	add	a, iyh
	ld	d, a
	ld	a, c
	adc	a, ixl
	ld	c, a
	ld	a, b
	adc	a, ixh
	ld	b, a
	ret

;-----------------------------------------------------------------------------
;Contador de frames.Se va decrementando hasta llegar a 0, entonces sale.

framecount:
	ld	bc, (tamanyo+1)	;Contador de frames.
	ld	a, b		;Se va decrementando hasta llegar a 0, entonces sale.
	sub	a, 1		
	ld	b, a
	ld	a, c
	sbc	a, 0
	ld	c, a
	ld	a, (tamanyo)
	sbc	a, 0
	jp	c, framecountfin;Si llega a cero sale a fin de video matando el CALL.
	ld	(tamanyo), a
	ld	(tamanyo+1), bc
	ret
framecountfin:
	pop	hl		;Mata el RET del stack pointer. (Extrae del SP la llamada del CALL y lo pone en HL por ejemplo).
	jp	finvideo	;Salta a finvideo reestableciendo punteros IDE.

;-----------------------------------------------------------------------------
;Detecta la pulsacion de la tecla ESC o TAB y sale o pausa respectivamente
;A posterior, coge la tecla pulsada y la almacena en FJ_KEYB_MSX.
;La configuración del teclado es editable y se puede asignar y desasignar teclas

readkeyb:	
	in	a, (#A9)	;Detecta la pulsacion de la tecla ESC o TAB y sale o pausa respectivamente.
	bit	2, a		
	jp	z, readkeybfin	;Si es ESC salta para finalizar video.
	bit	3, a
	jp	z, readkeyb	;Si es TAB bucle de lectura tecla hasta dejar de pulsar la tecla.(Pausa del video).

	ret

readkeybfin:
	pop	hl		;Mata el RET del stack pointer. (Extrae del SP la llamada del CALL y lo pone en HL por ejemplo).
	jp	finvideo3	;Salta a finvideo2.

;-----------------------------------------------------------------------------
;Hace una espera hasta sincronismo del VDP.

waitint:
	ld	hl, frmxint	; Espera a la interrupcion del retrazado
	dec	(hl)		; cada dos cuadros.
	ret	nz
	ld	(hl), 2
	in	a, (#99)
wait:
	in	a, (#99)
	and	%10000000
	jp	z, wait
	ret

;-----------------------------------------------------------------------------
;Cambia la pagina de video a mostrar. 0 por 1 y viceversa.

chgpage:	                ;Cambia la pagina de video a mostrar.
	ld	a, (pagvram)
	or	a
	jp	z, page1	;Si está en la página 0 va a la 1.
	xor	a
	ld	(pagvram), a	;Cambia a página 0.
	ld	a, (#F3E1)
	or	%00100000
	out	(#99), a
	ld	a, #82
	out	(#99), a
	ret
page1:
	ld	a, 1
	ld	(pagvram), a	;Cambia a página 1.
	ld	a, (#F3E1)
	and	%11011111
	out	(#99), a
	ld	a, #82
	out	(#99), a
	ret

;-----------------------------------------------------------------------------
;Cambia la pagina de video a mostrar en videoin. 0 por 1 y viceversa.

chgpage2:	                ;Cambia la pagina de video a mostrar.
	ld	a,(FJ_VDP_R39)	;Le solicita la nueva página a la Flashjacks.
	or	a
	jp	nz, page1b	;Si está en la página 0 va a la 1.
	xor	a
	ld	(pagvram2), a	;Cambia a página 0.
	ld	a, (#F3E1)
	or	%00100000
	out	(#99), a
	ld	a, #82
	out	(#99), a
	jp	page2fin
page1b:
	ld	a, 1
	ld	(pagvram2), a	;Cambia a página 1.
	ld	a, (#F3E1)
	and	%11011111
	out	(#99), a
	ld	a, #82
	out	(#99), a

page2fin: ; Actualiza registro pagína en HMMM y hace lectura de teclado en cada cámbio de página.	
	ld	a,(pagvram2)	;Envia el comando al VDP. Registro R#39 del VDP.
	out	(#99), a	
	ld	a, 39+80H	;Registro R#39 NY8-9. Cambio de página destino.	Es para el HMMC.
	out	(#99), a
	
	call	readkeyb	;Llama lectura del teclado para pausa TAB o salida ESC. Si es salida va a gestion fin del video.
				;También hace la lectura de la tecla pulsada y lo envía a la Flashjacks

	ret



;-----------------------------------------------------------------------------
; Activa en las opciones el modo 12FPS.

option12fps:
	ld	a, (options)	; activa opcion 12fps
	or	%1
	ld	(options), a
	ret

;-----------------------------------------------------------------------------
; Activa en las opciones el formato MSX2 Screen8

msx2format:
	ld	a, (options)
	or	%10001000
	ld	(options), a
	ret

;-----------------------------------------------------------------------------
; Incrementa en 30 los sectores IDE. (1 cuadro completo).

inc1:
	ld	a, 1
	jp	inclba30
inc30:
	ld	a, 30
inclba30:
	ld	b,a
	ld	a, (regside1)	;incrementa en 30 los punteros LBA
	add	a, b
	ld	(regside1),a
	ld	(IDE_LBALOW),a
	jp	c, inclba30_2
	jp	z, inclba30_2
	ret

inclba30_2:
	ld	a, (regside2)
	add	a, 1
	ld	(regside2),a
	ld	(IDE_LBAMID),a
	jp	c,inclba30_3
	jp	z,inclba30_3
	ret

inclba30_3:
	ld	a, (regside3)
	add	a, 1
	ld	(regside3),a
	ld	(IDE_LBAHIGH),a
	jp	c,inclba30_4
	jp	z,inclba30_4
	ret

inclba30_4:
	ld	a, (regside4)
	add	a, 1
	ld	(regside4),a
	ld	(IDE_HEAD),a
	ret

;-----------------------------------------------------------------------------
;division: LDE/C=>LDE, remainder=>h, b:=0
;by Jon De Schrijder

div60:
	ld	c, 60
	jp	div_LDE_by_C

div_LDE_by_C:	
	xor	a
	ld	h,a
	ld	b,24
divide:	
	ex	de,hl
	add	hl,hl
	ex	de,hl
	adc	hl,hl
	ld	a,h
	sub	c
	jp	c,notenough
	ld	h,a
	inc	e
notenough	djnz	divide
	ret


;-----------------------------------------------------------------------------
;Lee de filehandle2 3500bytes y los pone en la memoria 8000h

read2vram:
	ld	a, (filehandle2);Lee de filehandle2 3500bytes y los pone en la memoria 8000h.
	ld	b, a
	ld	de, #8000	;Read 53 lines.
	ld	hl, #3500
	ld	c, #48
	call	#5

	di
	ld	hl, #8000
	ld	a, 53
	ld	bc, #009b
pptransfer2:	
	otir			
	dec	a
	jp	nz, pptransfer2;Envía los datos de 8000h al puerto del VDP 53bytes.
	ret

;
; Fin de las subrutinas (vienen de un CALL)
;-----------------------------------------------------------------------------

;;;;;;;;;;;;;;; Rutinas de transferencia ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Para transferencias de 12FPS

transf12_00:
	XchgsndVDP_SND
	outi_3
transf12_0:
	outi_4
transf12_1:
	XchgsndVDP_SND
	outi_1
transf12_1x:	
	outi_1
	outi_1
transf12_1__:	
	outi_4
transf12_1_:	
	outi_4
transf12_2:	
	XchgsndVDP_SND
	outi_3
transf12_2__:	
	outi_4
transf12_2_:	
	outi_4
transf12_3:	
	XchgsndVDP_SND
	outi_3
transf12_3__:	
	outi_4
transf12_3_:	
	outi_4
transf12_4:	
	XchgsndVDP_SND
	outi_3
transf12_4__:	
	outi_4
transf12_4_:	
	outi_4
transf12_5:	
	XchgsndVDP_SND
	outi_7
transf12_5_:	
	outi_4	
transf12_6:	
	XchgsndVDP_SND
	outi_3
transf12_6__:	
	outi_4
transf12_6_:	
	outi_4
transf12_7:	
	XchgsndVDP_SND
	outi_3
transf12_7__:	
	outi_4
transf12_7_:	
	outi_4
transf12_8:	
	XchgsndVDP_SND
	outi_3
transf12_8__:	
	outi_4
transf12_8_:	
	outi_4
transf12_9:	
	XchgsndVDP_SND
	outi_7
transf12_9_:	
	outi_4
transf12_10:	
	XchgsndVDP_SND
	outi_3
transf12_10x:	
	outi_4
transf12_10_:	
	outi_4
transf12_11:	
	XchgsndVDP_SND
	outi_3
transf12_11x:	
	outi_4
transf12_11_:	
	outi_4
transf12_12:	
	XchgsndVDP_SND
	outi_7
	ret

transf13_1:
	XchgsndVDP_SND
	outi_11
transf13_2:	
	XchgsndVDP_SND
	outi_11
transf13_3:	
	XchgsndVDP_SND
	outi_11
transf13_4:	
	XchgsndVDP_SND
	outi_7
transf13_4_:	
	outi_4
transf13_5:	
	XchgsndVDP_SND
	outi_11
transf13_6:	
	XchgsndVDP_SND
	outi_11
transf13_7:	
	XchgsndVDP_SND
	outi_11
transf13_8:	
	XchgsndVDP_SND
	outi_7
transf13_8_:	
	outi_4
transf13_9:	
	XchgsndVDP_SND
	outi_11
transf13_10:	
	XchgsndVDP_SND
	outi_11
transf13_11:	
	XchgsndVDP_SND
	outi_11
transf13_12:	
	XchgsndVDP_SND
	outi_3

	ideready

	ret

transf14_1:
	XchgsndVDP_SND
	outi_3
transf14_1__:	
	outi_4
transf14_1_:	
	outi_4
transf14_2:	
	XchgsndVDP_SND
	outi_11
transf14_3:	
	XchgsndVDP_SND
	outi_11
transf14_4:	
	XchgsndVDP_SND
	outi_3
transf14_4__:	
	outi_4
transf14_4_:	
	outi_4
transf14_5:	
	XchgsndVDP_SND
	outi_11
transf14_6:	
	XchgsndVDP_SND
	outi_11
transf14_7:	
	XchgsndVDP_SND
	outi_11
transf14_8:	
	XchgsndVDP_SND
	outi_3
tranf14_8__:	
	outi_4
transf14_8_:	
	outi_4
transf14_9:	
	XchgsndVDP_SND
	outi_11
transf14_10:	
	XchgsndVDP_SND
	outi_11
transf14_11:	
	XchgsndVDP_SND
	outi_11

	ideready

	ret

esperatransf:
	; No procede espera en 12FPS. El z80 va apurado al último ciclo. Tal como está clava el video en los segundos que le toca.

	; Aquí poner el bucle de espera del timer.
	;ld	a, (options)
	;and	%100
	;jp	nz, noestransf	;Saca de options si tiene habilitado el PCM sync. Si no, no lee el puerto de espera del PCM
;eswaitrf:	
;	ld	a, (FJ_TIMER1)	;Lee el temporizador1 de la Flashjacks.
;	cp	00h		;Si llega a cero es que ya ha consumido el tiempo que debería haber realizado el transfer.
;	jp	nz, eswaitrf	;Si no, repite el bucle hasta llegar a cero.
;	ld	a, 79
;	ld	(FJ_TIMER1),a	;Carga en el Timer1 el tiempo que debería durar el siguiente transfer.
noestransf:
	ret



;Para transferencias de 10FPS

pretransfer:
	ideready
transfer:
	exx
	ld	a, (options)
	and	%100
	jp	nz, nopcmwait1	;Saca de options si tiene habilitado el PCM sync. Si no, no lee el puerto de espera del PCM
pcmwait1:	
	ld	a, (FJ_TIMER1)	;Lee el temporizador1 de la Flashjacks.
	cp	00h		;Si llega a cero es que ya ha consumido el tiempo que debería haber realizado el transfer.
	jp	nz, pcmwait1	;Si no, repite el bucle hasta llegar a cero.
	ld	a, 81
	ld	(FJ_TIMER1),a	;Carga en el Timer1 el tiempo que debería durar el siguiente transfer.
nopcmwait1:
	outi_1			;Envia sonido. Send sound byte to DAC.Incrementa HL.
	exx
	outi_2			;2
transferbis:	
	outi_8			;8
	HL_VDP_SND		;Envia sonido. Send sound byte to DAC.Incrementa HL.
	outi_10			;18
	HL_VDP_SND		;Envia sonido. Send sound byte to DAC.Incrementa HL.
	outi_10			;28
	HL_VDP_SND		;Envia sonido. Send sound byte to DAC.Incrementa HL.
	outi_10			;38
	HL_VDP_SND		;Envia sonido. Send sound byte to DAC.Incrementa HL.
	outi_10			;48
	HL_VDP_SND		;Envia sonido. Send sound byte to DAC.Incrementa HL.	
	outi_10			;58
	HL_VDP_SND		;Envia sonido. Send sound byte to DAC.Incrementa HL.
	outi_10			;68
	HL_VDP_SND		;Envia sonido. Send sound byte to DAC.Incrementa HL.
	outi_10			;78
	HL_VDP_SND		;Envia sonido. Send sound byte to DAC.Incrementa HL.
	outi_10			;88
	HL_VDP_SND		;Envia sonido. Send sound byte to DAC.Incrementa HL.
	outi_10			;98
	HL_VDP_SND		;Envia sonido. Send sound byte to DAC.Incrementa HL.
	outi_10			;108
	HL_VDP_SND		;Envia sonido. Send sound byte to DAC.Incrementa HL.
	outi_10			;118
	HL_VDP_SND		;Envia sonido. Send sound byte to DAC.Incrementa HL.
	outi_8			;126
	ret

tranfskk:
	ld	de, (sonido2)	;Carga en "de" lo que hay en el puntero de sonido2.
	jp	tranfsound
tranfsjj:
	ideready
tranfsound:
	exx
	ld	a, (options)
	and	%100
	jp	nz, nopcmwait2	;Saca de options si tiene habilitado el PCM sync. Si no, no lee el puerto de espera del PCM
pcmwait2:	
	ld	a, (FJ_TIMER1)	;Lee el temporizador1 de la Flashjacks.
	cp	00h		;Si llega a cero es que ya ha consumido el tiempo que debería haber realizado el transfer.
	jp	nz, pcmwait2	;Si no, repite el bucle hasta llegar a cero.
	ld	a, 81
	ld	(FJ_TIMER1),a	;Carga en el Timer1 el tiempo que debería durar el siguiente transfer.
nopcmwait2:
	outi_1			;Envia sonido. Send sound byte to DAC.Incrementa HL.
	exx
	ldi_10			;10
	HL_VDP_SND		;Envia sonido. Send sound byte to DAC.Incrementa HL.
	ldi_10			;20
	HL_VDP_SND		;Envia sonido. Send sound byte to DAC.Incrementa HL.
	ldi_10			;30
	HL_VDP_SND		;Envia sonido. Send sound byte to DAC.Incrementa HL.
	ldi_10			;40
	HL_VDP_SND		;Envia sonido. Send sound byte to DAC.Incrementa HL.
	ldi_10			;50
	HL_VDP_SND		;Envia sonido. Send sound byte to DAC.Incrementa HL.
	ldi_10			;60	
	HL_VDP_SND		;Envia sonido. Send sound byte to DAC.Incrementa HL.
	ldi_10			;70
	HL_VDP_SND		;Envia sonido. Send sound byte to DAC.Incrementa HL.
	ldi_10			;80	
	HL_VDP_SND		;Envia sonido. Send sound byte to DAC.Incrementa HL.
	ldi_10			;90
	HL_VDP_SND		;Envia sonido. Send sound byte to DAC.Incrementa HL.	
	ldi_10			;10
	HL_VDP_SND		;Envia sonido. Send sound byte to DAC.Incrementa HL.
transfsnd2:	
	ldi_10			;20
	HL_VDP_SND		;Envia sonido. Send sound byte to DAC.Incrementa HL.		
	ldi_10			;30
	HL_VDP_SND		;Envia sonido. Send sound byte to DAC.Incrementa HL.	
	ldi_8			;38
	ret

;;;;;;;;;;;;;;;;;;;; secuencias de transferencia ;;;;;;;;;;;;;;;;;;;;;;;;;;;;


play10stack:			;Secuencia 10fps sin setmultiple
	dw	transferbis	;12SND+126	
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128. Total 510 mas 2 del Start 512
	dw	pretransfer	;Ideready+13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128. Total 1024.
	dw	pretransfer	;13Ideready+13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;SND+128. Total 1536.
	dw	pretransfer	;13Ideready+13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128. Total 2048.
	dw	pretransfer	;Ideready+13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128. Total 2560.
	dw	pretransfer	;Ideready+13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128. Total 3072.
	dw	pretransfer	;Ideready+13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128. Total 3584.
	dw	pretransfer	;Ideready+13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128. Total 4096.
	dw	pretransfer	;Ideready+13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128. Total 4608.
	dw	pretransfer	;Ideready+13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128. Total 5120.
	dw	pretransfer	;Ideready+13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128. Total 5632.
	dw	pretransfer	;Ideready+13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128. Total 6144.
	dw	pretransfer	;Ideready+13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128. Total 6656.
	dw	pretransfer	;Ideready+13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128. Total 7168.
	dw	pretransfer	;Ideready+13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128. Total 7680.
	dw	pretransfer	;Ideready+13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128. Total 8192.
	dw	pretransfer	;Ideready+13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128. Total 8704.
	dw	pretransfer	;Ideready+13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128. Total 9216.
	dw	pretransfer	;Ideready+13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128. Total 9728.
	dw	pretransfer	;Ideready+13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128. Total 10240.
	dw	pretransfer	;Ideready+13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128. Total 10752.
	dw	pretransfer	;Ideready+13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128. Total 11264.
	dw	pretransfer	;Ideready+13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128. Total 11776.
	dw	pretransfer	;Ideready+13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128. Total 12288.
	dw	pretransfer	;Ideready+13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128. Total 12800.
	dw	pretransfer	;Ideready+13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128
	dw	transfer	;13SND+128. Total 13312.
	dw	pretransfer	;Ideready+13SND+128
	dw	transfer	;13SND+128
	dw	tranfskk	;"de"<--sonido2 13SND+128S
	dw	tranfsound	;13SND+128S.Total 13824.
	dw	tranfsjj	;Ideready+13SND+128S
	dw	tranfsound	;13SND+128S
	dw	tranfsound	;13SND+128S
	dw	tranfsound	;13SND+128S.Total 14336.
	dw	tranfsjj	;Ideready+13SND+128S
	dw	tranfsound	;13SND+128S
	dw	tranfsound	;13SND+128S
	dw	tranfsound	;13SND+128S.Total 14848.
	dw	tranfsjj	;Ideready+13SND+128S
	dw	tranfsound	;13SND+128S
	dw	tranfsound	;13SND+128S
	dw	tranfsound	;13SND+128S.Total 15360.
	dw	return2		;Total datos leidos: 13568bytes para graficos, 1792bytes para audio.(Leidos del buffer 1559bytes)

play12stack:
	dw	transf12_1x	;138G 11A
	dw	esperatransf
	dw	transf12_1	;140G 12A	
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf12_5	; 92G  7A
	dw	_ideready	;                 512
	dw	transf12_8_	; 48G  4A
	dw	esperatransf
	; 4 lines.                560
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf12_9	; 44G  3A
	dw	_ideready	;                 512
	dw	transf12_4_	; 96G  8A
	dw	esperatransf
	; 8 lines.                560
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf13_1	;136G 12A
	dw      _ideready       ;                 512
	dw	esperatransf
	dw	transf12_0	;144G 12A
	dw	esperatransf
	; 12 lines.               560
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf13_5	; 88G  8A
	dw      _ideready       ;                 512
	dw	transf12_8__	; 52G  4A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	; 16 lines.               560
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf13_9	; 40G  4A
	dw      _ideready       ;                 512
	dw	transf12_4__	;100G  8A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	; 20 lines.               560
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf14_1	;132G 11A
	dw	esperatransf
	dw      _ideready       ;                 512
	dw	transf12_00	;148G 13A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	; 24 lines                560
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf14_5	; 84G  7A
	dw      _ideready       ;                 512
	dw	transf12_8	; 56G  5A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	; 28 lines.               560
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf14_9	; 36G  3A
	dw      _ideready       ;                 512
	dw	transf12_4	;104G  9A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	; 32 lines.               560
	dw	transf12_2	;128G 11A
	dw	_ideready	;                 512
	dw	transf12_11_	; 12G  1A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	; 36 lines.               560
	dw	transf12_6	; 80G  7A
	dw	_ideready	;                 512
	dw	transf12_7_	; 60G  5A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	; 40 lines.               560
	dw	transf12_10	; 32G  2A
	dw	_ideready	;                 512
	dw	transf12_3_	;108G  9A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf13_2	;124G 11A
	dw      _ideready       ;                 512
	dw	transf12_11x	; 16G  1A
	dw	esperatransf
	; 44 lines.               560
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf13_6	; 76G  7A
	dw      _ideready       ;                 512
	dw	transf12_7__	; 64G  5A
	dw	esperatransf
	; 48 lines.              560
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf13_10	; 28G  3A
	dw      _ideready
	dw	transf12_3__	;112G  9A
	dw	esperatransf
	; 52 lines.
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf14_2	;120G 10A
	dw      _ideready
	dw	transf12_11	; 20G  2A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	; 56 lines.
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf14_6	; 72G  6A
	dw      _ideready
	dw	transf12_7	; 68G  6A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	; 60 lines.
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf14_10	; 24G  2A
	dw      _ideready
	dw	transf12_3	;116G 10A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	; 64 lines.
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf12_3	;116G 10A
	dw	_ideready
	dw	transf12_10_	; 24G  2A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	; 68 lines.
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf12_7	; 68G  6A
	dw	_ideready
	dw	transf12_6_	; 72G  6A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	; 72 lines.
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf12_11	; 20G  2A
	dw	_ideready
	dw	transf12_2_	;120G 10A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	; 76 lines.
	dw	transf13_3	;112G 10A
	dw      _ideready
	dw	transf12_10x	; 28G  2A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	; 80 lines.
	dw	transf13_7	; 64G  6A
	dw      _ideready
	dw	transf12_6__	; 76G  6A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	; 84 lines.
	dw	transf13_11	; 16G  2A
	dw      _ideready
	dw	transf12_2__	;124G 10A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf14_3	;108G  9A
	dw      _ideready
	dw	transf12_10	; 32G  2A
	dw	esperatransf
	; 88 lines.
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf14_7	; 60G  5A
	dw      _ideready
	dw	transf12_6	; 80G  7A
	dw	esperatransf
	; 92 lines.
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf14_11	; 12G  1A
	dw      _ideready
	dw	transf12_2	;128G 11A
	dw	esperatransf
	;96 lines.
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf12_4	;104G  9A
	dw	_ideready
	dw	transf12_9_	; 36G  3A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	;100 lines.
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf12_8	; 56G  5A
	dw	_ideready
	dw	transf12_5_	; 84G  7A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	;104 lines.
	dw	transf12_1	;140G 12A
	dw	esperatransf
	dw	transf12_1	;140G 12A
	dw	esperatransf
	;106 lines.
	dw	return

; Total 1255A

;-----------------------------------------------------------------------------
;Variables del entorno.

oldstack:	dw	0
PCMport:	db	0
tamanyoPCM:	dw	0
options:	db	%0
options2:	db	%0
pcmsize:	dw	0
tamanyo:	db	0,0,0,0
tamanyoc:	db	0,0,0,0
unidad:		db	0
slotide:	db	0
cabezas:	db	0
sectores:	db	0
devicetype:	db	0
atapic:		ds	18
start:		db	0,0,0,0
start_:		db	0,0,0,0
final:		db	0,0,0,0
final_:		db	0,0,0,0
frmxint:	db	2
HMMV:		db	0,0,0,0,0,0,212,1,0,0,#C0
HMMC1:		db	64,0,53
pagvram:	db	0
		db	128,0,106,0,0,#F0

HMMC2:		db	0,0,0
pagvram2:	db	0
		db	0,1,212,0,0,#F0

transback:	db	0,0,0,0,0,1,212,0,0,0,#F0
transback2:	db	0,0,0,0,0,0,0,1,0,1,212,0,0,0,#D0

datovideo:	db	0
TempejeY:	db	0
MultiVDP:	db	0
regside1:	db	0
regside2:	db	0
regside3:	db	0
regside4:	db	0
regside1c:	db	0
regside2c:	db	0
regside3c:	db	0
regside4c:	db	0
atapiread:	db	#A8,0,0,0,0,0,0,0,0,0,0,0
modor800:	db	0
Z80B:		db	0
filehandle:	db	0
filehandle2:	db	0
filename:	ds	64
backfile:	ds	64
safe38:		ds	5
buffer:		ds	2
FIB:		ds	64
sonido:		dw	0
sonido2:	dw	0
idevice:	dw	0

;Fin de las variables del entorno.
;-----------------------------------------------------------------------------

;Fin del programa completo.
;-----------------------------------------------------------------------------
end