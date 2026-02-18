.MODEL SMALL
.STACK 100h

.DATA
    ; ----- Constants -----
    PADDLE_ROW      EQU 23
    PADDLE_WIDTH    EQU 7
    PADDLE_CHAR     EQU '='
    BALL_CHAR       EQU 'O'
    BLOCK_CHAR      EQU 219         
    BLOCK_START_ROW EQU 2
    BLOCK_END_ROW   EQU 4
    BLOCK_START_COL EQU 10
    BLOCK_END_COL   EQU 70
    BLOCK_STEP      EQU 2

    
    paddleX         DB 37
    oldPaddleX      DB 37
    ballX           DB 40
    ballY           DB 22
    oldBallX        DB 40
    oldBallY        DB 22
    ballDx          DB 1            ; +1 = right
    ballDy          DB -1           ; -1 = up
    blockCount      DW 0
    gameActive      DB 1

    ; ----- Messages -----
    winMsg      DB '>>> YOU WIN! <<< Press any key to exit.$'
    gameOverMsg DB '>>> GAME OVER <<< Press any key to exit.$'

.CODE
main PROC FAR
    mov ax, @data
    mov ds, ax
    mov es, ax

    ; ----- Video mode 80x25 colour text -----
    mov ah, 0
    mov al, 3
    int 10h

    ; ----- Hide cursor -----
    mov ah, 01h
    mov ch, 20h
    mov cl, 00h
    int 10h

    call clear_screen
    call draw_border        ; visual border – helps to see movement
    call draw_blocks
    call draw_paddle
    call draw_ball

main_loop:
    cmp [gameActive], 1
    jne game_ended

    ; ----- Move paddle with A / D -----
    call move_paddle

    ; ----- Save old ball position -----
    mov al, [ballX]
    mov [oldBallX], al
    mov al, [ballY]
    mov [oldBallY], al

    ; ----- Move ball (always moves) -----
    call move_ball

    ; ----- Collisions -----
    call check_walls
    cmp [gameActive], 0
    je  game_ended
    call check_paddle
    call check_blocks

    ; ----- Win ? -----
    cmp [blockCount], 0
    je  victory

    ; ----- Redraw -----
    call draw_paddle
    call draw_ball

    ; ----- Short delay (visible movement) -----
    call delay

    jmp main_loop

victory:
    mov [gameActive], 0
    call clear_screen
    lea dx, winMsg
    mov ah, 09h
    int 21h
    jmp wait_key

game_ended:
    call clear_screen
    lea dx, gameOverMsg
    mov ah, 09h
    int 21h

wait_key:
    mov ah, 00h
    int 16h
    mov ah, 0
    mov al, 3
    int 10h
    mov ah, 4Ch
    int 21h
main ENDP

; ============================================================
;                       GRAPHICS
; ============================================================
set_cursor PROC
    mov ah, 02h
    mov bh, 0
    int 10h
    ret
set_cursor ENDP

write_char PROC
    mov ah, 09h
    mov bh, 0
    mov cx, 1
    int 10h
    ret
write_char ENDP

clear_screen PROC
    mov ah, 06h
    mov al, 0
    mov bh, 07h
    mov cx, 0
    mov dh, 24
    mov dl, 79
    int 10h
    ret
clear_screen ENDP

; ----- Draw a simple border (top & bottom) -----
draw_border PROC
    push dx
    mov dh, 0
    mov dl, 0
    call set_cursor
    mov al, 201            ; top-left corner
    mov bl, 07h
    call write_char
    mov dh, 0
    mov dl, 79
    call set_cursor
    mov al, 187            ; top-right corner
    call write_char
    mov dh, 24
    mov dl, 0
    call set_cursor
    mov al, 200            ; bottom-left corner
    call write_char
    mov dh, 24
    mov dl, 79
    call set_cursor
    mov al, 188            ; bottom-right corner
    call write_char
    pop dx
    ret
draw_border ENDP

; ----- Draw blocks -----
draw_blocks PROC
    mov [blockCount], 0
    mov dh, BLOCK_START_ROW
row_loop:
    cmp dh, BLOCK_END_ROW
    jg  done_blocks
    mov dl, BLOCK_START_COL
col_loop:
    cmp dl, BLOCK_END_COL
    jg  next_row
    push dx
    call set_cursor
    pop dx
    mov al, BLOCK_CHAR
    mov bl, 0Eh
    call write_char
    inc [blockCount]
    add dl, BLOCK_STEP
    jmp col_loop
next_row:
    inc dh
    jmp row_loop
done_blocks:
    ret
draw_blocks ENDP

; ----- Draw paddle (erase old, draw new) -----
draw_paddle PROC
    ; erase old paddle
    mov dh, PADDLE_ROW
    mov dl, [oldPaddleX]
    mov cx, PADDLE_WIDTH
erase_pdl:
    call set_cursor
    mov al, ' '
    mov bl, 07h
    call write_char
    inc dl
    loop erase_pdl

    ; save current position for next erase
    mov al, [paddleX]
    mov [oldPaddleX], al

    ; draw new paddle
    mov dh, PADDLE_ROW
    mov dl, [paddleX]
    mov cx, PADDLE_WIDTH
draw_pdl:
    call set_cursor
    mov al, PADDLE_CHAR
    mov bl, 0Bh
    call write_char
    inc dl
    loop draw_pdl
    ret
draw_paddle ENDP

; ----- Draw ball -----
draw_ball PROC
    ; erase old
    mov dh, [oldBallY]
    mov dl, [oldBallX]
    call set_cursor
    mov al, ' '
    mov bl, 07h
    call write_char

    ; draw new
    mov dh, [ballY]
    mov dl, [ballX]
    call set_cursor
    mov al, BALL_CHAR
    mov bl, 0Ch
    call write_char
    ret
draw_ball ENDP

; ============================================================
;                       INPUT
; ============================================================
move_paddle PROC
    push ax
    mov ah, 01h
    int 16h
    jz  no_key
    mov ah, 00h
    int 16h
    ; ---- ASCII keys: A = left, D = right ----
    cmp al, 'a'
    je  left
    cmp al, 'd'
    je  right
    cmp al, 'A'
    je  left
    cmp al, 'D'
    je  right
    jmp no_key
left:
    cmp [paddleX], 0
    jle no_key
    dec [paddleX]
    jmp no_key
right:
    cmp [paddleX], 80 - PADDLE_WIDTH
    jge no_key
    inc [paddleX]
no_key:
    pop ax
    ret
move_paddle ENDP

; ============================================================
;                       BALL PHYSICS
; ============================================================
move_ball PROC
    mov al, [ballDx]
    add [ballX], al
    mov al, [ballDy]
    add [ballY], al
    ret
move_ball ENDP

check_walls PROC
    ; left
    cmp [ballX], 0
    jg  no_left
    mov [ballX], 0
    neg [ballDx]
no_left:
    ; right (max 79)
    cmp [ballX], 79
    jl  no_right
    mov [ballX], 79
    neg [ballDx]
no_right:
    ; top
    cmp [ballY], 0
    jg  no_top
    mov [ballY], 0
    neg [ballDy]
no_top:
    ; bottom -> game over
    cmp [ballY], 24
    jl  no_bottom
    mov [gameActive], 0
no_bottom:
    ret
check_walls ENDP

check_paddle PROC
    cmp [ballY], PADDLE_ROW
    jne no_hit
    mov al, [ballX]
    cmp al, [paddleX]
    jl  no_hit
    mov bl, [paddleX]
    add bl, PADDLE_WIDTH - 1
    cmp al, bl
    jg  no_hit
    ; hit paddle
    neg [ballDy]
    dec [ballY]         ; avoid sticking
no_hit:
    ret
check_paddle ENDP

check_blocks PROC
    ; read character at ball position
    mov dh, [ballY]
    mov dl, [ballX]
    call set_cursor
    mov ah, 08h
    mov bh, 0
    int 10h
    cmp al, BLOCK_CHAR
    jne no_block
    ; remove block
    mov al, ' '
    mov bl, 07h
    call write_char
    dec [blockCount]
    ; bounce
    neg [ballDx]
    neg [ballDy]
no_block:
    ret
check_blocks ENDP

; ----- Short delay (about 0.05 sec on DOSBox) -----
delay PROC
    push cx
    mov cx,800
d1:
    loop d1
    pop cx
    ret
delay ENDP

END main

