# MARS 4.5. Bitmap 512x512, units 4x4, base 0x10010000.
# Connect Keyboard and Display MMIO; lowercase R restart, Q quit.
.text
    j main
.include "../common/gui.asm"
.data
board: .space 36
turn: .word 1
game_state: .word 0             # 0 active, 1 X wins, 2 O wins, 3 draw
moves: .word 0
invalid: .word 0
lines: .word 0,1,2, 3,4,5, 6,7,8, 0,3,6, 1,4,7, 2,5,8, 0,4,8, 2,4,6
title: .asciiz "TIC TAC TOE"
hint: .asciiz "KEYS 1-9 TO PLACE"
footer: .asciiz "R:RESET  Q:QUIT"
xturn: .asciiz "X TO PLAY"
oturn: .asciiz "O TO PLAY"
xwin: .asciiz "X WINS"
owin: .asciiz "O WINS"
tie: .asciiz "DRAW"
badmove: .asciiz "CHOOSE AN EMPTY CELL"
xmark: .asciiz "X"
omark: .asciiz "O"
digit: .space 2
pass: .asciiz "SELFTEST PASS: tic-tac-toe wins, draw, invalid keys, occupied cells, frozen end state, reset.\n"
fail: .asciiz "SELFTEST FAIL: tic-tac-toe case "
draw_seq: .byte 49,50,51,53,52,54,56,55,57
win_seq: .byte 49,50,51,52,53,54,56,55,57
.text
.globl main
main:
    bnez $a0, selftest
    jal reset
    jal render
loop:
    li $t0, 0xffff0000
    lw $t1, 0($t0)
    andi $t1, $t1, 1
    beqz $t1, sleep
    lw $a0, 4($t0)
    jal key
    jal render
sleep:
    li $a0, 15
    li $v0, 32
    syscall
    j loop
reset:
    la $t0, board
    li $t1, 9
clear_board:
    sw $zero, 0($t0)
    addiu $t0, $t0, 4
    addiu $t1, $t1, -1
    bnez $t1, clear_board
    li $t0, 1
    sw $t0, turn
    sw $zero, moves
    sw $zero, game_state
    sw $zero, invalid
    jr $ra
key:
    beq $a0, 113, quit
    beq $a0, 114, reset
    lw $t0, game_state
    bnez $t0, key_return
    blt $a0, 49, key_invalid
    bgt $a0, 57, key_invalid
    addiu $t0, $a0, -49
    sll $t0, $t0, 2
    la $t1, board
    addu $t0, $t0, $t1
    lw $t1, 0($t0)
    bnez $t1, key_invalid
    lw $t1, turn
    sw $t1, 0($t0)
    sw $zero, invalid
    lw $t0, moves
    addiu $t0, $t0, 1
    sw $t0, moves
    addiu $sp, $sp, -8
    sw $ra, 4($sp)
    jal outcome
    sw $v0, game_state
    bnez $v0, key_done
    lw $t0, turn
    li $t1, 3
    subu $t0, $t1, $t0
    sw $t0, turn
key_done:
    lw $ra, 4($sp)
    addiu $sp, $sp, 8
key_return:
    jr $ra
key_invalid:
    li $t0, 1
    sw $t0, invalid
    jr $ra
quit:
    li $v0, 10
    syscall
# Pure board evaluation: wins take priority over a filled board.
outcome:
    la $t0, lines
    la $t1, board
    li $t2, 8
check_line:
    lw $t3, 0($t0)
    sll $t3, $t3, 2
    addu $t3, $t3, $t1
    lw $v0, 0($t3)
    beqz $v0, next_line
    lw $t3, 4($t0)
    sll $t3, $t3, 2
    addu $t3, $t3, $t1
    lw $t4, 0($t3)
    bne $v0, $t4, next_line
    lw $t3, 8($t0)
    sll $t3, $t3, 2
    addu $t3, $t3, $t1
    lw $t4, 0($t3)
    beq $v0, $t4, outcome_done
next_line:
    addiu $t0, $t0, 12
    addiu $t2, $t2, -1
    bnez $t2, check_line
    li $t2, 9
check_empty:
    lw $t0, 0($t1)
    beqz $t0, still_playing
    addiu $t1, $t1, 4
    addiu $t2, $t2, -1
    bnez $t2, check_empty
    li $v0, 3
    jr $ra
still_playing:
    move $v0, $zero
outcome_done:
    jr $ra
render:
    addiu $sp, $sp, -24
    sw $ra, 20($sp)
    sw $s0, 16($sp)
    sw $s1, 12($sp)
    sw $s2, 8($sp)
    sw $s3, 4($sp)
    box (0,0,128,128,0x101b2c)
    label (42,7,title,0x6de3c3)
    label (32,17,hint,0x9aacc4)
    box (23,29,82,70,0x1b2b42)
    box (49,29,1,70,0x628399)
    box (77,29,1,70,0x628399)
    box (23,52,82,1,0x628399)
    box (23,76,82,1,0x628399)
    li $s0, 0
render_cell:
    li $t0, 3
    div $s0, $t0
    mflo $s1
    mfhi $s2
    mul $s1, $s1, 24
    mul $s2, $s2, 28
    addiu $s1, $s1, 33
    addiu $s2, $s2, 27
    addiu $t0, $s0, 49
    sb $t0, digit
    sb $zero, digit+1
    move $a0, $s2
    move $a1, $s1
    la $a2, digit
    li $t9, 0x628399
    jal draw_text
    sll $t0, $s0, 2
    la $t1, board
    addu $t0, $t0, $t1
    lw $s3, 0($t0)
    beqz $s3, cell_next
    # Large X uses two diagonals; O uses a hollow square ring.
    addiu $s1, $s1, 3
    addiu $s2, $s2, 6
    beq $s3, 2, draw_o
    li $s3, 0
draw_x:
    addu $a0, $s2, $s3
    addu $a1, $s1, $s3
    li $a2, 2
    li $a3, 2
    li $t9, 0x6de3c3
    jal rect
    addiu $a0, $s2, 11
    subu $a0, $a0, $s3
    addu $a1, $s1, $s3
    jal rect
    addiu $s3, $s3, 1
    blt $s3, 12, draw_x
    j cell_next
draw_o:
    move $a0, $s2
    move $a1, $s1
    li $a2, 13
    li $a3, 13
    li $t9, 0xffbc72
    jal rect
    addiu $a0, $s2, 2
    addiu $a1, $s1, 2
    li $a2, 9
    li $a3, 9
    li $t9, 0x1b2b42
    jal rect
cell_next:
    addiu $s0, $s0, 1
    blt $s0, 9, render_cell
    li $a0, 46
    li $a1, 105
    li $t9, 0x6de3c3
    lw $t0, game_state
    la $a2, xwin
    beq $t0, 1, status_draw
    la $a2, owin
    beq $t0, 2, status_draw
    la $a2, tie
    beq $t0, 3, status_draw
    la $a2, xturn
    lw $t0, turn
    beq $t0, 1, status_draw
    la $a2, oturn
status_draw:
    jal draw_text
    lw $t0, invalid
    beqz $t0, normal_footer
    label (26,116,badmove,0xffbc72)
    j render_done
normal_footer:
    label (36,116,footer,0x9aacc4)
render_done:
    lw $s3, 4($sp)
    lw $s2, 8($sp)
    lw $s1, 12($sp)
    lw $s0, 16($sp)
    lw $ra, 20($sp)
    addiu $sp, $sp, 24
    jr $ra
selftest:
    li $s7, 1
    jal reset
    li $a0, 48
    jal key
    li $a0, 58
    jal key
    lw $t0, moves
    bnez $t0, failed
    li $a0, 49
    jal key
    li $a0, 49
    jal key
    lw $t0, moves
    bne $t0, 1, failed
    lw $t0, turn
    bne $t0, 2, failed
    li $s7, 2
    li $s0, 1
test_mark:
    la $s1, lines
    li $s2, 8
test_line:
    jal reset
    li $s3, 0
test_place:
    addu $t0, $s1, $s3
    lw $t0, 0($t0)
    sll $t0, $t0, 2
    la $t1, board
    addu $t0, $t0, $t1
    sw $s0, 0($t0)
    addiu $s3, $s3, 4
    blt $s3, 12, test_place
    jal outcome
    bne $v0, $s0, failed
    addiu $s1, $s1, 12
    addiu $s2, $s2, -1
    bnez $s2, test_line
    addiu $s0, $s0, 1
    ble $s0, 2, test_mark
    li $s7, 3
    jal reset
    la $s0, draw_seq
    li $s1, 9
test_draw:
    lbu $a0, 0($s0)
    jal key
    addiu $s0, $s0, 1
    addiu $s1, $s1, -1
    bnez $s1, test_draw
    lw $t0, game_state
    bne $t0, 3, failed
    li $a0, 49
    jal key
    lw $t0, moves
    bne $t0, 9, failed
    jal render
    li $s7, 4
    li $a0, 114
    jal key
    lw $t0, moves
    bnez $t0, failed
    lw $t0, game_state
    bnez $t0, failed
    li $s7, 5
    # A win on move nine must be a win, not a full-board draw.
    la $s0, win_seq
    li $s1, 9
test_last_win:
    lbu $a0, 0($s0)
    jal key
    addiu $s0, $s0, 1
    addiu $s1, $s1, -1
    bnez $s1, test_last_win
    lw $t0, game_state
    bne $t0, 1, failed
    li $a0, 50
    jal key
    lw $t0, game_state
    bne $t0, 1, failed
    lw $t0, moves
    bne $t0, 9, failed
    jal render
    jal reset
    # Preview an in-progress game with both marks.
    li $a0, 49
    jal key
    li $a0, 53
    jal key
    li $a0, 51
    jal key
    jal render
    li $v0, 4
    la $a0, pass
    syscall
    li $a0, 0
    li $v0, 17
    syscall
failed:
    li $v0, 4
    la $a0, fail
    syscall
    move $a0, $s7
    li $v0, 1
    syscall
    move $a0, $s7
    li $v0, 17
    syscall
