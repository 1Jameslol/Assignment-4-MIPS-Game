# Shared 128x128 bitmap GUI. Include after an initial jump to main.
.data 0x10010000
framebuffer: .space 65536
glyph_keys: .asciiz "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ -:/"
.align 2
glyphs: .word 0x7b6f,0x2492,0x73e7,0x73cf,0x5bc9,0x79cf,0x79ef,0x7249,0x7bef,0x7bcf
 .word 0x2bed,0x6bae,0x7927,0x6b6e,0x79e7,0x79e4,0x796f,0x5bed,0x7497,0x124f
 .word 0x5bad,0x4927,0x5fed,0x5f6d,0x7b6f,0x7be4,0x7b7b,0x7bad,0x79cf,0x7492
 .word 0x5b6f,0x5b6a,0x5bfd,0x5aad,0x5a92,0x72a7,0,0x01c0,0x0410,0x12a4

.text
# rect(x,y,w,h), t9 RGB. Caller supplies in-bounds coordinates.
rect:
    blez $a2, rect_done
    blez $a3, rect_done
    sll $t0, $a1, 7
    addu $t0, $t0, $a0
    sll $t0, $t0, 2
    la $t1, framebuffer
    addu $t0, $t0, $t1
    move $t3, $a3
rect_row:
    move $t1, $t0
    move $t2, $a2
rect_col:
    sw $t9, 0($t1)
    addiu $t1, $t1, 4
    addiu $t2, $t2, -1
    bnez $t2, rect_col
    addiu $t0, $t0, 512
    addiu $t3, $t3, -1
    bnez $t3, rect_row
rect_done:
    jr $ra

# text(x,y,string), t9 RGB. 3x5 glyphs, four pixel advance.
draw_text:
    move $t8, $a2
text_char:
    lbu $t0, 0($t8)
    beqz $t0, text_done
    la $t1, glyph_keys
    li $t2, 0
text_lookup:
    lbu $t3, 0($t1)
    beqz $t3, text_advance
    beq $t0, $t3, text_found
    addiu $t1, $t1, 1
    addiu $t2, $t2, 4
    j text_lookup
text_found:
    la $t1, glyphs
    addu $t1, $t1, $t2
    lw $t2, 0($t1)
    sll $t3, $a1, 7
    addu $t3, $t3, $a0
    sll $t3, $t3, 2
    la $t1, framebuffer
    addu $t3, $t3, $t1
    li $t4, 0x4000
    li $t5, 5
text_row:
    li $t6, 3
    move $t7, $t3
text_pixel:
    and $t0, $t2, $t4
    beqz $t0, text_skip
    sw $t9, 0($t7)
text_skip:
    srl $t4, $t4, 1
    addiu $t7, $t7, 4
    addiu $t6, $t6, -1
    bnez $t6, text_pixel
    addiu $t3, $t3, 512
    addiu $t5, $t5, -1
    bnez $t5, text_row
text_advance:
    addiu $a0, $a0, 4
    addiu $t8, $t8, 1
    j text_char
text_done:
    jr $ra

# Three decimal digits, including leading zeroes; value in a2.
draw_number:
    addiu $sp, $sp, -16
    sw $ra, 12($sp)
    li $t0, 100
    div $a2, $t0
    mflo $t1
    mfhi $t2
    addiu $t1, $t1, 48
    sb $t1, 0($sp)
    li $t0, 10
    div $t2, $t0
    mflo $t1
    mfhi $t2
    addiu $t1, $t1, 48
    addiu $t2, $t2, 48
    sb $t1, 1($sp)
    sb $t2, 2($sp)
    sb $zero, 3($sp)
    move $a2, $sp
    jal draw_text
    lw $ra, 12($sp)
    addiu $sp, $sp, 16
    jr $ra


.macro box (%x,%y,%w,%h,%rgb)
 li $a0, %x
 li $a1, %y
 li $a2, %w
 li $a3, %h
 li $t9, %rgb
 jal rect
.end_macro
.macro label (%x,%y,%str,%rgb)
 li $a0, %x
 li $a1, %y
 la $a2, %str
 li $t9, %rgb
 jal draw_text
.end_macro

