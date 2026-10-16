# MIPS DOOM -- an original, small Doom-style raycaster for MARS 4.5.
# Bitmap: 4x4 units, 512x512 display, base 0x10010000.
# Connect Bitmap Display AND Keyboard and Display MMIO Simulator before Run.
# Default memory configuration; pseudo instructions ON; delayed branches OFF.
# Coordinates/directions are Q8 fixed point (256 = one map tile).

.data 0x10010000
framebuffer: .space 65536
pixel_depth: .space 65536
player_x: .word 640
player_y: .word 640
angle: .word 0
dir_x: .word 256
dir_y: .word 0
health: .word 100
ammo: .word 50
kills: .word 0
state: .word 0                 # 0 playing, 1 victory, 2 defeated
flash: .word 0
show_map: .word 1
last_tick: .word 0
test_mode: .word 0
test_result: .word 0
cosines: .word 256,251,237,213,181,142,98,50,0,-50,-98,-142,-181,-213,-237,-251
         .word -256,-251,-237,-213,-181,-142,-98,-50,0,50,98,142,181,213,237,251
# Each record is x, y, hit points. All five start on open tiles.
spawn_data: .word 1408,640,2, 2688,640,2, 3200,1664,2, 1664,2688,2, 640,3200,2
enemies: .space 60
world:
.ascii "1111111111111111"
.ascii "1000000100000001"
.ascii "1000000000000001"
.ascii "1000000100022001"
.ascii "1110111100020001"
.ascii "1000000000020001"
.ascii "1000000000000001"
.ascii "1002200111000001"
.ascii "1000000100000001"
.ascii "1000000100000001"
.ascii "1000000000000001"
.ascii "1000111000220001"
.ascii "1000000000000001"
.ascii "1000000000000001"
.ascii "1000000000000001"
.ascii "1111111111111111"
# Transparent / dark outline / red skin / teeth / yellow eyes.
demon:
.ascii "01000010"
.ascii "01222210"
.ascii "12222221"
.ascii "12422421"
.ascii "12222221"
.ascii "01233210"
.ascii "11222211"
.ascii "12222221"
.ascii "10222201"
.ascii "00122100"
.ascii "01200210"
.ascii "01100110"
.align 2
palette: .word 0,0x28171e,0xb93636,0xe8d9a0,0xffcc36
glyph_keys: .asciiz "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ -:/"
.align 2
glyphs: .word 0x7b6f,0x2492,0x73e7,0x73cf,0x5bc9,0x79cf,0x79ef,0x7249,0x7bef,0x7bcf
 .word 0x2bed,0x6bae,0x7927,0x6b6e,0x79e7,0x79e4,0x796f,0x5bed,0x7497,0x124f
 .word 0x5bad,0x4927,0x5fed,0x5f6d,0x7b6f,0x7be4,0x7b7b,0x7bad,0x79cf,0x7492
 .word 0x5b6f,0x5b6a,0x5bfd,0x5aad,0x5a92,0x72a7,0,0x01c0,0x0410,0x12a4
hp_label: .asciiz "HP"
ammo_label: .asciiz "AM"
kill_label: .asciiz "K"
win_label: .asciiz "YOU WIN"
lose_label: .asciiz "YOU DIED"
restart_label: .asciiz "R:RESTART"
intro: .asciiz "MIPS DOOM\nW/S move, A/D turn, Z/C strafe, SPACE fire, M map, R restart, Q quit.\nClear all 5 demons. Connect both MARS display tools.\n"
win_message: .asciiz "All demons cleared! Press R to restart.\n"
lose_message: .asciiz "You died. Press R to restart.\n"
test_ok: .asciiz "SELFTEST PASS: collision, movement, combat, occlusion, AI, restart, rendering.\n"
test_bad: .asciiz "SELFTEST FAILED (test number in test_result).\n"

.text
.globl main
main:
    # Any command-line argument runs the deterministic self-test and exits.
    sw $a0, test_mode
    jal reset_game
    lw $t0, test_mode
    bnez $t0, selftest
    li $v0, 4
    la $a0, intro
    syscall
    jal render
game_loop:
    li $t0, 0xffff0000
    lw $t1, 0($t0)
    andi $t1, $t1, 1
    beqz $t1, timer
    lw $a0, 4($t0)
    jal handle_key
    jal render
timer:
    li $v0, 30
    syscall
    lw $t0, last_tick
    subu $t1, $a0, $t0
    bltu $t1, 350, idle
    sw $a0, last_tick
    sw $zero, flash
    jal update_enemies
    jal render
idle:
    li $a0, 10
    li $v0, 32
    syscall
    j game_loop

reset_game:
    li $t0, 640
    sw $t0, player_x
    sw $t0, player_y
    sw $zero, angle
    sw $zero, dir_y
    sw $zero, kills
    sw $zero, state
    sw $zero, flash
    li $t0, 256
    sw $t0, dir_x
    li $t0, 100
    sw $t0, health
    li $t0, 50
    sw $t0, ammo
    la $t0, spawn_data
    la $t1, enemies
    li $t2, 15
reset_copy:
    lw $t3, 0($t0)
    sw $t3, 0($t1)
    addiu $t0, $t0, 4
    addiu $t1, $t1, 4
    addiu $t2, $t2, -1
    bnez $t2, reset_copy
    li $v0, 30
    syscall
    sw $a0, last_tick
    jr $ra

handle_key:
    addiu $sp, $sp, -8
    sw $ra, 4($sp)
    beq $a0, 113, quit
    beq $a0, 114, key_reset
    beq $a0, 109, key_map
    lw $t0, state
    bnez $t0, key_done
    beq $a0, 32, key_fire
    beq $a0, 97, key_left
    beq $a0, 100, key_right
    beq $a0, 119, key_forward
    beq $a0, 115, key_back
    beq $a0, 122, key_strafe_left
    beq $a0, 99, key_strafe_right
    j key_done
key_reset:
    jal reset_game
    j key_done
key_map:
    lw $t0, show_map
    xori $t0, $t0, 1
    sw $t0, show_map
    j key_done
key_fire:
    jal shoot
    j key_done
key_left:
    lw $t0, angle
    addiu $t0, $t0, -1
    j key_turn
key_right:
    lw $t0, angle
    addiu $t0, $t0, 1
key_turn:
    andi $t0, $t0, 31
    sw $t0, angle
    sll $t1, $t0, 2
    la $t2, cosines
    addu $t1, $t1, $t2
    lw $t3, 0($t1)
    sw $t3, dir_x
    addiu $t0, $t0, -8
    andi $t0, $t0, 31
    sll $t0, $t0, 2
    addu $t0, $t0, $t2
    lw $t3, 0($t0)
    sw $t3, dir_y
    j key_done
key_forward:
    lw $a0, dir_x
    lw $a1, dir_y
    j key_move
key_back:
    lw $a0, dir_x
    lw $a1, dir_y
    subu $a0, $zero, $a0
    subu $a1, $zero, $a1
    j key_move
key_strafe_left:
    lw $a0, dir_y
    lw $a1, dir_x
    subu $a1, $zero, $a1
    j key_move
key_strafe_right:
    lw $a0, dir_y
    lw $a1, dir_x
    subu $a0, $zero, $a0
key_move:
    # Step is 1/4 tile. Collision padding keeps camera away from walls.
    sra $a0, $a0, 2
    sra $a1, $a1, 2
    jal move_player
key_done:
    lw $ra, 4($sp)
    addiu $sp, $sp, 8
    jr $ra
quit:
    li $v0, 10
    syscall

# tile(x Q8, y Q8) -> v0 ASCII tile; out of bounds is solid.
tile:
    bltz $a0, tile_solid
    bltz $a1, tile_solid
    bge $a0, 4096, tile_solid
    bge $a1, 4096, tile_solid
    sra $t0, $a0, 8
    sra $t1, $a1, 8
    sll $t1, $t1, 4
    addu $t0, $t0, $t1
    la $t1, world
    addu $t0, $t0, $t1
    lbu $v0, 0($t0)
    jr $ra
tile_solid:
    li $v0, 49
    jr $ra

# can_stand tests all four corners of a 64x64 collision box.
can_stand:
    addiu $sp, $sp, -16
    sw $ra, 12($sp)
    sw $a0, 0($sp)
    sw $a1, 4($sp)
    addiu $a0, $a0, -32
    addiu $a1, $a1, -32
    jal tile
    bne $v0, 48, stand_done
    lw $a0, 0($sp)
    lw $a1, 4($sp)
    addiu $a0, $a0, 32
    addiu $a1, $a1, -32
    jal tile
    bne $v0, 48, stand_done
    lw $a0, 0($sp)
    lw $a1, 4($sp)
    addiu $a0, $a0, -32
    addiu $a1, $a1, 32
    jal tile
    bne $v0, 48, stand_done
    lw $a0, 0($sp)
    lw $a1, 4($sp)
    addiu $a0, $a0, 32
    addiu $a1, $a1, 32
    jal tile
stand_done:
    lw $ra, 12($sp)
    addiu $sp, $sp, 16
    jr $ra

move_player:
    addiu $sp, $sp, -16
    sw $ra, 12($sp)
    sw $a1, 4($sp)
    lw $t0, player_x
    addu $a0, $a0, $t0
    sw $a0, 0($sp)
    lw $a1, player_y
    jal can_stand
    bne $v0, 48, move_y
    lw $t0, 0($sp)
    sw $t0, player_x
move_y:
    lw $a0, player_x
    lw $a1, player_y
    lw $t0, 4($sp)
    addu $a1, $a1, $t0
    sw $a1, 0($sp)
    jal can_stand
    bne $v0, 48, move_done
    lw $t0, 0($sp)
    sw $t0, player_y
move_done:
    lw $ra, 12($sp)
    addiu $sp, $sp, 16
    jr $ra

# cast_ray(a0,a1 Q8 direction): v0 depth Q8, v1 material, a2 texture U.
# Accumulate Q12 positions: no truncation of shallow ray directions.
cast_ray:
    lw $t0, player_x
    lw $t1, player_y
    sll $t0, $t0, 4
    sll $t1, $t1, 4
    li $t2, 0
    la $t7, world
ray_step:
    addu $t0, $t0, $a0
    addu $t1, $t1, $a1
    addiu $t2, $t2, 1
    sra $t3, $t0, 12
    sra $t4, $t1, 12
    bgeu $t3, 16, ray_boundary
    bgeu $t4, 16, ray_boundary
    sll $t4, $t4, 4
    addu $t3, $t3, $t4
    addu $t3, $t3, $t7
    lbu $v1, 0($t3)
    bne $v1, 48, ray_hit
    blt $t2, 512, ray_step
ray_boundary:
    li $v1, 49
ray_hit:
    sll $v0, $t2, 4
    addu $a2, $t0, $t1
    srl $a2, $a2, 8
    andi $a2, $a2, 15
    jr $ra

# project enemy at a0 pointer -> v0 depth, v1 lateral, both Q8.
project:
    lw $t0, 0($a0)
    lw $t1, 4($a0)
    lw $t2, player_x
    lw $t3, player_y
    subu $t0, $t0, $t2
    subu $t1, $t1, $t3
    lw $t2, dir_x
    lw $t3, dir_y
    mul $t4, $t0, $t2
    mul $t5, $t1, $t3
    addu $v0, $t4, $t5
    sra $v0, $v0, 8
    mul $t4, $t1, $t2
    mul $t5, $t0, $t3
    subu $v1, $t4, $t5
    sra $v1, $v1, 8
    jr $ra

shoot:
    addiu $sp, $sp, -24
    sw $ra, 20($sp)
    sw $s0, 16($sp)
    sw $s1, 12($sp)
    sw $s2, 8($sp)
    sw $s3, 4($sp)
    lw $t0, ammo
    beqz $t0, shoot_done
    addiu $t0, $t0, -1
    sw $t0, ammo
    li $t0, 1
    sw $t0, flash
    lw $a0, dir_x
    lw $a1, dir_y
    jal cast_ray
    move $s2, $v0
    move $s3, $zero
    la $s0, enemies
    li $s1, 5
shoot_loop:
    lw $t0, 8($s0)
    beqz $t0, shoot_next
    move $a0, $s0
    jal project
    blez $v0, shoot_next
    bge $v0, $s2, shoot_next
    abs $t0, $v1
    bgt $t0, 64, shoot_next
    move $s2, $v0
    move $s3, $s0
shoot_next:
    addiu $s0, $s0, 12
    addiu $s1, $s1, -1
    bnez $s1, shoot_loop
    beqz $s3, shoot_done
    lw $t0, 8($s3)
    addiu $t0, $t0, -1
    sw $t0, 8($s3)
    bnez $t0, shoot_done
    lw $t0, kills
    addiu $t0, $t0, 1
    sw $t0, kills
    bne $t0, 5, shoot_done
    li $t0, 1
    sw $t0, state
    li $v0, 4
    la $a0, win_message
    syscall
shoot_done:
    lw $s3, 4($sp)
    lw $s2, 8($sp)
    lw $s1, 12($sp)
    lw $s0, 16($sp)
    lw $ra, 20($sp)
    addiu $sp, $sp, 24
    jr $ra

# Nearby demons pursue independently on each axis. Walls block movement.
update_enemies:
    addiu $sp, $sp, -24
    sw $ra, 20($sp)
    sw $s0, 16($sp)
    sw $s1, 12($sp)
    lw $t0, state
    bnez $t0, ai_done
    la $s0, enemies
    li $s1, 5
ai_loop:
    lw $t0, 8($s0)
    beqz $t0, ai_next
    lw $t0, player_x
    lw $t1, player_y
    lw $t2, 0($s0)
    lw $t3, 4($s0)
    subu $t4, $t0, $t2
    subu $t5, $t1, $t3
    abs $t6, $t4
    abs $t7, $t5
    addu $t6, $t6, $t7
    bgt $t6, 1536, ai_next
    blt $t6, 144, ai_attack
    # Clamp each step to +/-24 to avoid oscillation at the target axis.
    li $t6, 24
    bgt $t4, 24, ai_dx
    move $t6, $t4
    bge $t4, -24, ai_dx
    li $t6, -24
ai_dx:
    addu $a0, $t2, $t6
    move $a1, $t3
    sw $a0, 0($sp)
    sw $t5, 4($sp)
    jal can_stand
    bne $v0, 48, ai_y
    lw $t0, 0($sp)
    sw $t0, 0($s0)
ai_y:
    lw $t5, 4($sp)
    li $t6, 24
    bgt $t5, 24, ai_dy
    move $t6, $t5
    bge $t5, -24, ai_dy
    li $t6, -24
ai_dy:
    lw $a0, 0($s0)
    lw $a1, 4($s0)
    addu $a1, $a1, $t6
    sw $a1, 0($sp)
    jal can_stand
    bne $v0, 48, ai_next
    lw $t0, 0($sp)
    sw $t0, 4($s0)
    j ai_next
ai_attack:
    # Two collision boxes cannot touch through a full 256-unit wall.
    lw $t0, health
    addiu $t0, $t0, -5
    sw $t0, health
    bgtz $t0, ai_next
    sw $zero, health
    li $t0, 2
    sw $t0, state
    li $v0, 4
    la $a0, lose_message
    syscall
    j ai_done
ai_next:
    addiu $s0, $s0, 12
    addiu $s1, $s1, -1
    bnez $s1, ai_loop
ai_done:
    lw $s1, 12($sp)
    lw $s0, 16($sp)
    lw $ra, 20($sp)
    addiu $sp, $sp, 24
    jr $ra

# 128 ray columns, 112 viewport rows. Camera plane is 2/3 of direction.
render:
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
    li $s0, 0
wall_column:
    addiu $t0, $s0, -64
    lw $t1, dir_y
    mul $t1, $t1, $t0
    li $t2, 96
    div $t1, $t2
    mflo $t1
    lw $a0, dir_x
    subu $a0, $a0, $t1
    lw $t1, dir_x
    mul $t1, $t1, $t0
    div $t1, $t2
    mflo $t1
    lw $a1, dir_y
    addu $a1, $a1, $t1
    jal cast_ray
    move $s1, $v0
    move $s7, $a2
    li $t0, 28672
    div $t0, $s1
    mflo $s2                  # full projected wall height
    sra $t0, $s2, 1
    li $s3, 56
    subu $s3, $s3, $t0        # unclipped top
    addu $s4, $s3, $s2        # bottom
    li $s5, 0x887465
    beq $v1, 49, wall_shade
    li $s5, 0x477d78
wall_shade:
    blt $s1, 768, wall_start
    srl $s5, $s5, 1
    li $t1, 0x7f7f7f
    and $s5, $s5, $t1
    blt $s1, 1792, wall_start
    srl $s5, $s5, 1
    and $s5, $s5, $t1
wall_start:
    li $s6, 0
    sll $t0, $s0, 2
    la $t7, framebuffer
    addu $t7, $t7, $t0
    la $t8, pixel_depth
    addu $t8, $t8, $t0
wall_pixel:
    blt $s6, $s3, ceiling_pixel
    bge $s6, $s4, floor_pixel
    subu $t0, $s6, $s3
    sll $t0, $t0, 5
    div $t0, $s2
    mflo $t0
    andi $t1, $t0, 7
    move $t9, $s5
    beqz $t1, mortar_pixel
    srl $t0, $t0, 3
    andi $t0, $t0, 1
    sll $t0, $t0, 3
    addu $t0, $t0, $s7
    andi $t0, $t0, 15
    bnez $t0, write_wall_pixel
mortar_pixel:
    li $t9, 0x242527
    j write_wall_pixel
ceiling_pixel:
    srl $t0, $s6, 3
    li $t9, 0x171923
    li $t1, 0x010101
    mul $t0, $t0, $t1
    addu $t9, $t9, $t0
    j write_wall_pixel
floor_pixel:
    addiu $t0, $s6, -56
    srl $t0, $t0, 2
    li $t1, 0x010101
    mul $t0, $t0, $t1
    li $t9, 0x282322
    addu $t9, $t9, $t0
write_wall_pixel:
    sw $t9, 0($t7)
    sw $s1, 0($t8)
    addiu $t7, $t7, 512
    addiu $t8, $t8, 512
    addiu $s6, $s6, 1
    blt $s6, 112, wall_pixel
    addiu $s0, $s0, 1
    blt $s0, 128, wall_column
    jal draw_enemies
    jal draw_overlay
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

# Per-pixel depth lets sprites overlap correctly without sorting.
draw_enemies:
    addiu $sp, $sp, -48
    sw $ra, 44($sp)
    sw $s0, 40($sp)
    sw $s1, 36($sp)
    sw $s2, 32($sp)
    sw $s3, 28($sp)
    sw $s4, 24($sp)
    sw $s5, 20($sp)
    sw $s6, 16($sp)
    sw $s7, 12($sp)
    la $s0, enemies
    li $s1, 5
sprite_next_enemy:
    lw $t0, 8($s0)
    beqz $t0, sprite_done_enemy
    move $a0, $s0
    jal project
    blt $v0, 48, sprite_done_enemy
    move $s2, $v0
    li $t0, 28672
    div $t0, $s2
    mflo $s3                 # height
    mul $t0, $s3, 2
    li $t1, 3
    div $t0, $t1
    mflo $s4                 # width
    beqz $s4, sprite_done_enemy
    mul $t0, $v1, 96
    div $t0, $s2
    mflo $s5
    addiu $s5, $s5, 64
    sra $t0, $s4, 1
    subu $s5, $s5, $t0       # left
    sra $t0, $s3, 1
    li $s6, 56
    subu $s6, $s6, $t0       # top
    li $s7, 0               # screen y, clipping costs bounded by viewport
sprite_row:
    subu $t0, $s7, $s6
    bltz $t0, sprite_row_next
    bge $t0, $s3, sprite_done_enemy
    mul $t0, $t0, 12
    div $t0, $s3
    mflo $t0
    sll $t0, $t0, 3
    la $t1, demon
    addu $t0, $t0, $t1
    sw $t0, 0($sp)
    li $t2, 0
sprite_col:
    subu $t0, $t2, $s5
    bltz $t0, sprite_col_next
    bge $t0, $s4, sprite_row_next
    sll $t0, $t0, 3
    div $t0, $s4
    mflo $t0
    lw $t1, 0($sp)
    addu $t0, $t0, $t1
    lbu $t0, 0($t0)
    addiu $t0, $t0, -48
    beqz $t0, sprite_col_next
    sll $t1, $s7, 7
    addu $t1, $t1, $t2
    sll $t1, $t1, 2
    la $t3, pixel_depth
    addu $t3, $t3, $t1
    lw $t4, 0($t3)
    bge $s2, $t4, sprite_col_next
    sw $s2, 0($t3)
    sll $t0, $t0, 2
    la $t4, palette
    addu $t0, $t0, $t4
    lw $t0, 0($t0)
    la $t3, framebuffer
    addu $t3, $t3, $t1
    sw $t0, 0($t3)
sprite_col_next:
    addiu $t2, $t2, 1
    blt $t2, 128, sprite_col
sprite_row_next:
    addiu $s7, $s7, 1
    blt $s7, 112, sprite_row
sprite_done_enemy:
    addiu $s0, $s0, 12
    addiu $s1, $s1, -1
    bnez $s1, sprite_next_enemy
    lw $s7, 12($sp)
    lw $s6, 16($sp)
    lw $s5, 20($sp)
    lw $s4, 24($sp)
    lw $s3, 28($sp)
    lw $s2, 32($sp)
    lw $s1, 36($sp)
    lw $s0, 40($sp)
    lw $ra, 44($sp)
    addiu $sp, $sp, 48
    jr $ra

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

# Fixed-size overlay rectangles use a macro to keep presentation readable.
.macro box (%x,%y,%w,%h,%rgb)
    li $a0, %x
    li $a1, %y
    li $a2, %w
    li $a3, %h
    li $t9, %rgb
    jal rect
.end_macro
draw_overlay:
    addiu $sp, $sp, -16
    sw $ra, 12($sp)
    sw $s0, 8($sp)
    sw $s1, 4($sp)
    # Shotgun silhouette, barrel highlights, hand and muzzle flash.
    box (51,96,26,16,0x201e24)
    box (56,84,16,28,0x474650)
    box (59,83,10,26,0x777780)
    box (61,84,6,23,0x36353e)
    box (51,105,9,7,0x9e7259)
    box (70,105,8,7,0x9e7259)
    lw $t0, flash
    beqz $t0, no_flash
    box (61,72,6,11,0xffd05b)
    box (56,76,16,4,0xffa336)
    box (62,75,4,7,0xfff1b0)
no_flash:
    box (60,56,3,1,0xd4d5bf)
    box (66,56,3,1,0xd4d5bf)
    box (64,52,1,3,0xd4d5bf)
    box (64,58,1,3,0xd4d5bf)
    box (0,112,128,16,0x17191e)
    box (0,112,128,1,0xa18a60)
    li $a0, 4
    li $a1, 116
    la $a2, hp_label
    li $t9, 0xe8c9aa
    jal draw_text
    li $a0, 16
    li $a1, 116
    lw $a2, health
    jal draw_number
    li $a0, 47
    li $a1, 116
    la $a2, ammo_label
    li $t9, 0xe8c9aa
    jal draw_text
    li $a0, 59
    li $a1, 116
    lw $a2, ammo
    jal draw_number
    li $a0, 91
    li $a1, 116
    la $a2, kill_label
    li $t9, 0xe8c9aa
    jal draw_text
    li $a0, 99
    li $a1, 116
    lw $a2, kills
    jal draw_number
    box (4,123,34,2,0x39272c)
    li $a0, 4
    li $a1, 123
    lw $t0, health
    li $t1, 3
    div $t0, $t1
    mflo $a2
    li $a3, 2
    li $t9, 0xc34a49
    jal rect
    box (47,123,34,2,0x353124)
    li $a0, 47
    li $a1, 123
    lw $t0, ammo
    mul $t0, $t0, 2
    li $t1, 3
    div $t0, $t1
    mflo $a2
    li $a3, 2
    li $t9, 0xc4a85d
    jal rect
    lw $t0, show_map
    beqz $t0, overlay_state
    li $s0, 0
map_row:
    li $s1, 0
map_col:
    sll $t0, $s0, 4
    addu $t0, $t0, $s1
    la $t1, world
    addu $t0, $t0, $t1
    lbu $t0, 0($t0)
    li $t9, 0x151b22
    beq $t0, 48, map_draw
    li $t9, 0x7b7770
map_draw:
    sll $a0, $s1, 1
    sll $a1, $s0, 1
    addiu $a0, $a0, 3
    addiu $a1, $a1, 3
    li $a2, 2
    li $a3, 2
    jal rect
    addiu $s1, $s1, 1
    blt $s1, 16, map_col
    addiu $s0, $s0, 1
    blt $s0, 16, map_row
    la $s0, enemies
    li $s1, 5
map_enemy:
    lw $t0, 8($s0)
    beqz $t0, map_enemy_next
    lw $a0, 0($s0)
    lw $a1, 4($s0)
    srl $a0, $a0, 7
    srl $a1, $a1, 7
    addiu $a0, $a0, 3
    addiu $a1, $a1, 3
    li $a2, 1
    li $a3, 1
    li $t9, 0xf5574d
    jal rect
map_enemy_next:
    addiu $s0, $s0, 12
    addiu $s1, $s1, -1
    bnez $s1, map_enemy
    lw $a0, player_x
    lw $a1, player_y
    srl $a0, $a0, 7
    srl $a1, $a1, 7
    addiu $a0, $a0, 3
    addiu $a1, $a1, 3
    li $a2, 2
    li $a3, 2
    li $t9, 0x66e4bc
    jal rect
overlay_state:
    lw $s0, state
    beqz $s0, overlay_done
    box (38,40,52,23,0x17191e)
    li $a0, 48
    li $a1, 44
    la $a2, lose_label
    li $t9, 0xf5574d
    bne $s0, 1, overlay_message
    la $a2, win_label
    li $t9, 0x66e4bc
overlay_message:
    jal draw_text
    li $a0, 46
    li $a1, 55
    la $a2, restart_label
    li $t9, 0xe8c9aa
    jal draw_text
overlay_done:
    lw $s1, 4($sp)
    lw $s0, 8($sp)
    lw $ra, 12($sp)
    addiu $sp, $sp, 16
    jr $ra

# Deterministic headless regression checks, using the actual game routines.
# Run: java -jar /Applications/Mars.jar nc ae1 se1 doom.asm pa --test
selftest:
    li $s7, 1
    li $a0, -1
    li $a1, 640
    jal tile
    bne $v0, 49, test_fail
    li $a0, 640
    li $a1, 640
    jal can_stand
    bne $v0, 48, test_fail
    li $s7, 2
    li $a0, 119
    jal handle_key
    lw $t0, player_x
    bne $t0, 704, test_fail
    li $t0, 300
    sw $t0, player_x
    li $a0, -64
    li $a1, 0
    jal move_player
    lw $t0, player_x
    bne $t0, 300, test_fail
    jal reset_game
    li $s7, 3
    jal shoot
    la $t0, enemies
    lw $t1, 8($t0)
    bne $t1, 1, test_fail
    jal shoot
    lw $t0, kills
    bne $t0, 1, test_fail
    lw $t0, ammo
    bne $t0, 48, test_fail
    li $s7, 4
    # Put a demon behind the wall at (7,1); shots must not pass through.
    jal reset_game
    li $t0, 384
    sw $t0, player_y
    la $t0, enemies
    li $t1, 2176
    sw $t1, 0($t0)
    li $t1, 384
    sw $t1, 4($t0)
    jal shoot
    la $t0, enemies
    lw $t1, 8($t0)
    bne $t1, 2, test_fail
    li $s7, 5
    jal reset_game
    jal update_enemies
    la $t0, enemies
    lw $t1, 0($t0)
    bne $t1, 1384, test_fail
    li $t1, 700
    sw $t1, 0($t0)
    jal update_enemies
    lw $t0, health
    bne $t0, 95, test_fail
    li $s7, 6
    li $t0, 5
    sw $t0, health
    jal update_enemies
    lw $t0, state
    bne $t0, 2, test_fail
    li $a0, 119
    jal handle_key
    lw $t0, player_x
    bne $t0, 640, test_fail
    li $s7, 7
    li $a0, 114
    jal handle_key
    lw $t0, health
    bne $t0, 100, test_fail
    lw $t0, state
    bnez $t0, test_fail
    li $s7, 8
    sw $zero, ammo
    jal shoot
    la $t0, enemies
    lw $t1, 8($t0)
    bne $t1, 2, test_fail
    lw $t0, ammo
    bnez $t0, test_fail
    jal reset_game
    li $s7, 9
    # Line up every demon in open space and clear them using actual shots.
    la $s0, enemies
    li $s1, 5
test_lineup:
    li $t0, 1408
    sw $t0, 0($s0)
    li $t0, 640
    sw $t0, 4($s0)
    addiu $s0, $s0, 12
    addiu $s1, $s1, -1
    bnez $s1, test_lineup
    li $s1, 10
test_shots:
    li $a0, 32
    jal handle_key
    addiu $s1, $s1, -1
    bnez $s1, test_shots
    lw $t0, state
    bne $t0, 1, test_fail
    lw $t0, kills
    bne $t0, 5, test_fail
    li $a0, 32
    jal handle_key
    lw $t0, ammo
    bne $t0, 40, test_fail
    jal render
    jal reset_game
    li $s7, 10
    # Render every direction, including sprites behind/beside the camera.
    li $s0, 32
test_turns:
    li $a0, 100
    jal handle_key
    jal render
    addiu $s0, $s0, -1
    bnez $s0, test_turns
    lw $t0, dir_x
    bne $t0, 256, test_fail
    lw $t0, dir_y
    bnez $t0, test_fail
    # Near-wall clipping and close-up sprite clipping.
    li $t0, 300
    sw $t0, player_x
    li $a0, 97
    jal handle_key
    jal render
    jal reset_game
    la $t0, enemies
    li $t1, 704
    sw $t1, 0($t0)
    jal render
    jal reset_game
    jal render
    # Viewport and HUD must both contain rendered pixels.
    la $t0, framebuffer
    lw $t1, 0($t0)
    beqz $t1, test_fail
    lw $t1, 65024($t0)
    beqz $t1, test_fail
    sw $zero, test_result
    li $v0, 4
    la $a0, test_ok
    syscall
    li $a0, 0
    li $v0, 17
    syscall
test_fail:
    sw $s7, test_result
    li $v0, 4
    la $a0, test_bad
    syscall
    move $a0, $s7
    li $v0, 1
    syscall
    move $a0, $s7
    li $v0, 17
    syscall
