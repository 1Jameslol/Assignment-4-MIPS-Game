# Single-deck blackjack for MARS 4.5 Bitmap Display + MMIO keyboard.
# Dealer stands on all 17s. No wagers, splitting, insurance or doubling.
.text
    j main
.include "../common/gui.asm"
.data
deck: .space 208
deck_pos: .word 0
player: .space 48
dealer: .space 48
player_n: .word 0
dealer_n: .word 0
game_state: .word 0             # 0 active, 1 win, 2 lose, 3 push, 4 natural
title: .asciiz "BLACKJACK"
dealer_label: .asciiz "DEALER"
player_label: .asciiz "YOUR HAND"
total_label: .asciiz "TOTAL"
hidden_label: .asciiz "HIDDEN"
rule_label: .asciiz "DEALER STANDS ON 17"
controls: .asciiz "H:HIT  S:STAND  R:DEAL"
quit_label: .asciiz "Q:QUIT"
playing_label: .asciiz "HIT OR STAND"
win_label: .asciiz "YOU WIN"
lose_label: .asciiz "DEALER WINS"
push_label: .asciiz "PUSH - TIE"
natural_label: .asciiz "BLACKJACK"
rank_names: .asciiz "A23456789TJQK"
suit_names: .asciiz "SHDC"
card_text: .space 3
pass: .asciiz "SELFTEST PASS: blackjack aces, naturals, push, busts, soft 17, deck uniqueness, limits, reset.\n"
fail: .asciiz "SELFTEST FAIL: blackjack case "
.text
.globl main
main:
    bnez $a0, selftest
    jal new_round
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
key:
    beq $a0, 113, quit
    beq $a0, 114, new_round
    lw $t0, game_state
    bnez $t0, key_done
    beq $a0, 104, hit
    beq $a0, 115, stand
key_done:
    jr $ra
quit:
    li $v0, 10
    syscall
# Build an ordered, unique deck. Also used for deterministic tests.
reset:
    sw $zero, deck_pos
    sw $zero, player_n
    sw $zero, dealer_n
    sw $zero, game_state
    la $t0, deck
    li $t1, 0
reset_deck:
    sw $t1, 0($t0)
    addiu $t0, $t0, 4
    addiu $t1, $t1, 1
    blt $t1, 52, reset_deck
    jr $ra
new_round:
    addiu $sp, $sp, -16
    sw $ra, 12($sp)
    sw $s0, 8($sp)
    jal reset
    li $s0, 51
shuffle:
    li $a0, 0
    addiu $a1, $s0, 1
    li $v0, 42
    syscall
    la $t0, deck
    sll $t1, $s0, 2
    addu $t1, $t1, $t0
    sll $t2, $a0, 2
    addu $t2, $t2, $t0
    lw $t3, 0($t1)
    lw $t4, 0($t2)
    sw $t3, 0($t2)
    sw $t4, 0($t1)
    addiu $s0, $s0, -1
    bgtz $s0, shuffle
    jal opening
    lw $s0, 8($sp)
    lw $ra, 12($sp)
    addiu $sp, $sp, 16
    jr $ra
# Deal alternately; resolve naturals before enabling player input.
opening:
    addiu $sp, $sp, -16
    sw $ra, 12($sp)
    jal deal_player
    jal deal_dealer
    jal deal_player
    jal deal_dealer
    jal player_total
    sw $v0, 0($sp)
    jal dealer_total
    lw $t0, 0($sp)
    beq $t0, 21, player_natural
    bne $v0, 21, opening_done
    li $t0, 2
    sw $t0, game_state
    j opening_done
player_natural:
    li $t0, 4
    bne $v0, 21, save_natural
    li $t0, 3
save_natural:
    sw $t0, game_state
opening_done:
    lw $ra, 12($sp)
    addiu $sp, $sp, 16
    jr $ra
deal_player:
    la $a0, player
    la $a1, player_n
    j deal
deal_dealer:
    la $a0, dealer
    la $a1, dealer_n
deal:
    # Bounds checks make malformed/test states safe as well.
    li $v0, 0
    lw $t0, 0($a1)
    bgeu $t0, 12, deal_done
    lw $t1, deck_pos
    bgeu $t1, 52, deal_done
    sll $t2, $t1, 2
    la $t3, deck
    addu $t2, $t2, $t3
    lw $t3, 0($t2)
    sll $t2, $t0, 2
    addu $t2, $t2, $a0
    sw $t3, 0($t2)
    addiu $t0, $t0, 1
    sw $t0, 0($a1)
    addiu $t1, $t1, 1
    sw $t1, deck_pos
    li $v0, 1
deal_done:
    jr $ra
player_total:
    la $a0, player
    lw $a1, player_n
    j total
dealer_total:
    la $a0, dealer
    lw $a1, dealer_n
# Sum all aces as 11, then downgrade as many as necessary to 1.
total:
    li $v0, 0
    li $t0, 0
    li $t1, 13
total_loop:
    beqz $a1, adjust_aces
    lw $t2, 0($a0)
    divu $t2, $t1
    mfhi $t2
    addiu $t2, $t2, 1
    beq $t2, 1, ace
    ble $t2, 10, add_card
    li $t2, 10
    j add_card
ace:
    li $t2, 11
    addiu $t0, $t0, 1
add_card:
    addu $v0, $v0, $t2
    addiu $a0, $a0, 4
    addiu $a1, $a1, -1
    j total_loop
adjust_aces:
    ble $v0, 21, total_done
    beqz $t0, total_done
    addiu $v0, $v0, -10
    addiu $t0, $t0, -1
    j adjust_aces
total_done:
    jr $ra
hit:
    addiu $sp, $sp, -8
    sw $ra, 4($sp)
    jal deal_player
    beqz $v0, hit_done
    jal player_total
    bgt $v0, 21, player_bust
    bne $v0, 21, hit_done
    jal stand
    j hit_done
player_bust:
    li $t0, 2
    sw $t0, game_state
hit_done:
    lw $ra, 4($sp)
    addiu $sp, $sp, 8
    jr $ra
stand:
    addiu $sp, $sp, -16
    sw $ra, 12($sp)
dealer_play:
    jal dealer_total
    bge $v0, 17, compare
    jal deal_dealer
    bnez $v0, dealer_play
    # Exhausted deck cannot occur in a legal single hand; never loop forever.
    jal dealer_total
compare:
    sw $v0, 0($sp)
    jal player_total
    lw $t0, 0($sp)
    li $t1, 1
    bgt $t0, 21, save_result
    bgt $v0, $t0, save_result
    li $t1, 3
    beq $v0, $t0, save_result
    li $t1, 2
save_result:
    sw $t1, game_state
    lw $ra, 12($sp)
    addiu $sp, $sp, 16
    jr $ra
render:
    addiu $sp, $sp, -16
    sw $ra, 12($sp)
    box (0,0,128,128,0x103f36)
    box (0,0,128,20,0x102c29)
    label (46,5,title,0xffd68a)
    label (28,13,rule_label,0x91b9aa)
    label (5,24,dealer_label,0xf5ebd6)
    lw $t0, game_state
    bnez $t0, reveal_total
    label (96,24,hidden_label,0x91b9aa)
    j dealer_cards
reveal_total:
    jal dealer_total
    move $a2, $v0
    li $a0, 108
    li $a1, 24
    li $t9, 0xffd68a
    jal draw_number
dealer_cards:
    la $a0, dealer
    lw $a1, dealer_n
    li $a2, 33
    li $a3, 1
    jal draw_hand
    label (5,67,player_label,0xf5ebd6)
    jal player_total
    move $a2, $v0
    li $a0, 108
    li $a1, 67
    li $t9, 0xffd68a
    jal draw_number
    la $a0, player
    lw $a1, player_n
    li $a2, 76
    li $a3, 0
    jal draw_hand
    box (0,109,128,19,0x102c29)
    li $a0, 42
    li $a1, 111
    li $t9, 0xffd68a
    lw $t0, game_state
    la $a2, playing_label
    beqz $t0, result_label
    la $a2, win_label
    beq $t0, 1, result_label
    la $a2, lose_label
    beq $t0, 2, result_label
    la $a2, push_label
    beq $t0, 3, result_label
    la $a2, natural_label
result_label:
    jal draw_text
    label (22,119,controls,0xf5ebd6)
    lw $ra, 12($sp)
    addiu $sp, $sp, 16
    jr $ra
# draw_hand(pointer, count, top, hide second card when a3=1 and active).
# Up to 12 cards: six per row, both rows stay inside the viewport.
draw_hand:
    addiu $sp, $sp, -40
    sw $ra, 36($sp)
    sw $s0, 32($sp)
    sw $s1, 28($sp)
    sw $s2, 24($sp)
    sw $s3, 20($sp)
    sw $s4, 16($sp)
    sw $s5, 12($sp)
    sw $s6, 8($sp)
    sw $s7, 4($sp)
    move $s0, $a0
    move $s1, $a1
    move $s2, $a2
    move $s3, $a3
    li $s4, 0
hand_loop:
    bge $s4, $s1, hand_done
    li $t0, 6
    div $s4, $t0
    mfhi $s5
    mflo $s6
    mul $s5, $s5, 20
    addiu $s5, $s5, 5
    mul $s6, $s6, 16
    addu $s6, $s6, $s2
    move $a0, $s5
    move $a1, $s6
    li $a2, 17
    li $a3, 14
    li $t9, 0xf5ebd6
    jal rect
    beqz $s3, face_up
    bne $s4, 1, face_up
    lw $t0, game_state
    bnez $t0, face_up
    addiu $a0, $s5, 1
    addiu $a1, $s6, 1
    li $a2, 15
    li $a3, 12
    li $t9, 0x416d99
    jal rect
    addiu $a0, $s5, 4
    addiu $a1, $s6, 3
    li $a2, 9
    li $a3, 8
    li $t9, 0x244564
    jal rect
    j hand_next
face_up:
    sll $t0, $s4, 2
    addu $t0, $t0, $s0
    lw $t0, 0($t0)
    li $t1, 13
    div $t0, $t1
    mflo $s7
    mfhi $t0
    la $t1, rank_names
    addu $t0, $t0, $t1
    lbu $t0, 0($t0)
    sb $t0, card_text
    la $t1, suit_names
    addu $t1, $t1, $s7
    lbu $t0, 0($t1)
    sb $t0, card_text+1
    sb $zero, card_text+2
    li $t9, 0x203845
    beq $s7, 0, card_ink
    beq $s7, 3, card_ink
    li $t9, 0xba4242
card_ink:
    addiu $a0, $s5, 3
    addiu $a1, $s6, 4
    la $a2, card_text
    jal draw_text
hand_next:
    addiu $s4, $s4, 1
    j hand_loop
hand_done:
    lw $s7, 4($sp)
    lw $s6, 8($sp)
    lw $s5, 12($sp)
    lw $s4, 16($sp)
    lw $s3, 20($sp)
    lw $s2, 24($sp)
    lw $s1, 28($sp)
    lw $s0, 32($sp)
    lw $ra, 36($sp)
    addiu $sp, $sp, 40
    jr $ra
selftest:
    li $s7, 1
    jal reset
    # A A 9 = 21; A A 9 K = 21; A A 9 K K = 31.
    la $t0, player
    sw $zero, 0($t0)
    li $t1, 13
    sw $t1, 4($t0)
    li $t1, 8
    sw $t1, 8($t0)
    li $t1, 12
    sw $t1, 12($t0)
    li $t1, 25
    sw $t1, 16($t0)
    li $t1, 3
    sw $t1, player_n
    jal player_total
    bne $v0, 21, failed
    li $t1, 4
    sw $t1, player_n
    jal player_total
    bne $v0, 21, failed
    li $t1, 5
    sw $t1, player_n
    jal player_total
    bne $v0, 31, failed
    li $s7, 2
    jal reset
    # Both natural: A, A, K, K.
    la $t0, deck
    sw $zero, 0($t0)
    li $t1, 13
    sw $t1, 4($t0)
    li $t1, 12
    sw $t1, 8($t0)
    li $t1, 25
    sw $t1, 12($t0)
    jal opening
    lw $t0, game_state
    bne $t0, 3, failed
    li $a0, 104
    jal key
    lw $t0, player_n
    bne $t0, 2, failed
    li $s7, 3
    jal reset
    # Player natural only: A, 2, K, 4.
    la $t0, deck
    li $t1, 12
    sw $t1, 8($t0)
    jal opening
    lw $t0, game_state
    bne $t0, 4, failed
    li $s7, 4
    jal reset
    # Dealer natural only: 2, A, 4, K.
    la $t0, deck
    li $t1, 1
    sw $t1, 0($t0)
    sw $zero, 4($t0)
    li $t1, 3
    sw $t1, 8($t0)
    li $t1, 12
    sw $t1, 12($t0)
    jal opening
    lw $t0, game_state
    bne $t0, 2, failed
    li $s7, 5
    jal reset
    # Dealer soft 17 stands; player 18 wins.
    la $t0, player
    li $t1, 9
    sw $t1, 0($t0)
    li $t1, 7
    sw $t1, 4($t0)
    la $t0, dealer
    sw $zero, 0($t0)
    li $t1, 5
    sw $t1, 4($t0)
    li $t1, 2
    sw $t1, player_n
    sw $t1, dealer_n
    jal stand
    lw $t0, game_state
    bne $t0, 1, failed
    lw $t0, dealer_n
    bne $t0, 2, failed
    li $s7, 6
    # Equal totals push.
    la $t0, player
    li $t1, 6
    sw $t1, 4($t0)
    jal stand
    lw $t0, game_state
    bne $t0, 3, failed
    li $s7, 7
    # Dealer 16 draws a king and busts.
    la $t0, dealer
    li $t1, 9
    sw $t1, 0($t0)
    li $t1, 5
    sw $t1, 4($t0)
    la $t0, deck
    li $t1, 12
    sw $t1, 0($t0)
    jal stand
    lw $t0, game_state
    bne $t0, 1, failed
    li $s7, 8
    # Player 17 draws a ten and busts.
    sw $zero, game_state
    la $t0, deck
    li $t1, 22
    sw $t1, 4($t0)
    li $a0, 104
    jal key
    lw $t0, game_state
    bne $t0, 2, failed
    li $s7, 9
    jal new_round
    # Every card must be in range and unique after Fisher-Yates shuffle.
    li $s0, 0
test_deck_outer:
    la $t0, deck
    sll $t1, $s0, 2
    addu $t0, $t0, $t1
    lw $t2, 0($t0)
    bgeu $t2, 52, failed
    addiu $s1, $s0, 1
test_deck_inner:
    bge $s1, 52, test_deck_next
    la $t0, deck
    sll $t1, $s1, 2
    addu $t0, $t0, $t1
    lw $t3, 0($t0)
    beq $t2, $t3, failed
    addiu $s1, $s1, 1
    j test_deck_inner
test_deck_next:
    addiu $s0, $s0, 1
    blt $s0, 52, test_deck_outer
    li $s7, 10
    li $t0, 52
    sw $t0, deck_pos
    jal deal_player
    bnez $v0, failed
    sw $zero, deck_pos
    li $t0, 12
    sw $t0, player_n
    jal deal_player
    bnez $v0, failed
    # Draw all 12 valid card slots to check maximum hand layout.
    la $t0, player
    li $t1, 0
test_fill:
    sw $t1, 0($t0)
    addiu $t0, $t0, 4
    addiu $t1, $t1, 1
    blt $t1, 12, test_fill
    jal render
    li $s7, 11
    jal reset
    jal opening
    lw $t0, player_n
    bne $t0, 2, failed
    lw $t0, dealer_n
    bne $t0, 2, failed
    lw $t0, game_state
    bnez $t0, failed
    li $a0, 120
    jal key
    lw $t0, deck_pos
    bne $t0, 4, failed
    li $s7, 12
    # Player 11 + K reaches 21, automatically stands, beats dealer 20.
    jal reset
    la $t0, player
    li $t1, 4
    sw $t1, 0($t0)
    li $t1, 5
    sw $t1, 4($t0)
    la $t0, dealer
    li $t1, 9
    sw $t1, 0($t0)
    li $t1, 22
    sw $t1, 4($t0)
    li $t1, 2
    sw $t1, player_n
    sw $t1, dealer_n
    la $t0, deck
    li $t1, 12
    sw $t1, 0($t0)
    li $a0, 104
    jal key
    lw $t0, game_state
    bne $t0, 1, failed
    lw $t0, player_n
    bne $t0, 3, failed
    jal render
    li $s7, 13
    # Dealer wins an ordinary comparison, not just a player bust.
    li $t0, 2
    sw $t0, player_n
    sw $zero, game_state
    jal stand
    lw $t0, game_state
    bne $t0, 2, failed
    li $a0, 115
    jal key
    lw $t0, game_state
    bne $t0, 2, failed
    li $a0, 114
    jal key
    lw $t0, deck_pos
    bne $t0, 4, failed
    # Restore a deterministic active hand for preview and hidden-card checks.
    jal reset
    jal opening
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
