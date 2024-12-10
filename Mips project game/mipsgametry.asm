.globl main

.data
# Configuratie bestandsnamen en berichten
mazeFilename:    .asciiz "input_1.txt"  			                # Bestandsnaam voor doolhof
buffer:          .space  4096               			                # 4096 buffer voor inlezen bestand
victoryMessage:  .asciiz "Je hebt het spel gewonnen! \n"
errorMessage:    .asciiz "Error bij het lezen van doolhofbestand! \n"
# Spel configuratie constanten
amountOfRows:    .word 16  
amountOfColumns: .word 32  

# Kleur definities
wallColor:      .word 0x004286F4    # Blauw voor muur
passageColor:   .word 0x00000000    # Zwart voor gang
playerColor:    .word 0x00FFFF00    # Geel voor speler
exitColor:      .word 0x0000FF00    # Groen voor uitgang

# Speler positie tracking
playerRow:      .word 0
playerCol:      .word 0
exitRow:        .word 0
exitCol:        .word 0

.text
main:
    # Lees doolhof
    jal read_maze

    # Haal initiële speler positie op
    lw $s0, playerRow
    lw $s1, playerCol

game_loop:
    # Wacht op de invoer
    li $v0, 12   # Lees karakter
    syscall

    # Verwerk de invoer
    beq $v0, 122, move_up    # 'z' omhoog
    beq $v0, 115, move_down  # 's' omlaag
    beq $v0, 113, move_left  # 'q' links
    beq $v0, 100, move_right # 'd' rechts
    beq $v0, 120, exit       # 'x' sluit spel

move_up:
    addi $a0, $s0, -1
    move $a1, $s1
    j do_move

move_down:
    addi $a0, $s0, 1
    move $a1, $s1
    j do_move

move_left:
    move $a0, $s0
    addi $a1, $s1, -1
    j do_move

move_right:
    move $a0, $s0
    addi $a1, $s1, 1
    j do_move

do_move:
    move $a2, $a0
    move $a3, $a1
    move $a0, $s0
    move $a1, $s1
    jal move_player

    # Update de playerpositie
    move $s0, $v0
    move $s1, $v1

    # Controleer of uitgang bereikt is
    lw $t0, exitRow
    lw $t1, exitCol
    bne $s0, $t0, game_continue
    bne $s1, $t1, game_continue

    # gewonnen
    la $a0, victoryMessage								# victory message print nog niet
    li $v0, 4
    syscall
    
    j exit

game_continue:
    # de sleep voor 60ms
    li $a0, 60
    li $v0, 32
    syscall

    j game_loop

exit:
    # stop programma
    li $v0, 10
    syscall

read_maze:
    # Bewaar stack frame
    addi $sp, $sp, -16
    sw $ra, 0($sp)
    sw $s0, 4($sp)   
    sw $s1, 8($sp)   
    sw $s2, 12($sp) 

    # Open bestand
    li $v0, 13       
    la $a0, mazeFilename
    li $a1, 0        # Read-only mode
    li $a2, 0        
    syscall
    
    # Controleer of bestand succesvol geopend is
    bltz $v0, file_error
    move $s0, $v0     # Bestandsdescriptor opslaan

# Lees bestand in buffer
    li $v0, 14
    move $a0, $s0
    la $a1, buffer
    li $a2, 8192
    syscall
    bltz $v0, file_error # Check if read operation was successful
    
    # Sluit bestand
    li $v0, 16
    move $a0, $s0
    syscall

    # Verwerk buffer en teken doolhof
    la $s1, buffer   
    li $s2, 0        
    move $t0, $gp    
    li $t4, 0        

process_maze_row:
    lb $t1, ($s1)  
    beqz $t1, maze_done   
    beq $t1, 10, next_row 

    # Bepaal kleur op basis van karakter
    li $t3, 0x00000000  # Standaard zwart (doorgang)
    beq $t1, 119, set_wall_color   # 'w' - muur
    beq $t1, 112, check_path       # 'p' - pad
    beq $t1, 117, check_exit       # 'u' - uitgang 
    beq $t1, 115, check_player     # 's' - player 
    j draw_pixel

set_wall_color: 
    li $t3, 0x004286F4  # Blauwe muurkleur
    j draw_pixel
    
check_path:
    li $t3, 0x00000000  # Standaard zwart (doorgang)
    j draw_pixel
    
check_player:
    sw $s2, playerRow   
    sw $t4, playerCol   
    li $t3, 0x00FFFF00  # Gele spelerkleur
    j draw_pixel

check_exit:
    sw $s2, exitRow     
    sw $t4, exitCol     
    li $t3, 0x0000FF00  # Groene kleur(uitgang)
    j draw_pixel

draw_pixel:
    sw $t3, ($t0)       
    addi $t0, $t0, 4   
    addi $t4, $t4, 1    
    addi $s1, $s1, 1    
    j process_maze_row

next_row:
    addi $s2, $s2, 1    # Volgende rij
    li $t4, 0           # Reset kolom
    addi $s1, $s1, 1    
    j process_maze_row

maze_done:
    # Herstel stack frame
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    addi $sp, $sp, 16
    jr $ra

file_error:
    li $v0, 4
    la $a0, errorMessage
    syscall
    j exit

move_player:
    # $a0 = de huidige rij
    # $a1 = de huidige kolom
    # $a2 = de nieuwe rij
    # $a3 = de nieuwe kolom

    # Bewaar stack frame
    addi $sp, $sp, -16
    sw $ra, 0($sp)
    sw $s0, 4($sp)   # Huidige pixel adres
    sw $s1, 8($sp)   # Nieuwe pixel adres
    sw $s2, 12($sp)  

    # nieuwe positie
    lw $t0, amountOfRows
    lw $t1, amountOfColumns
    bltz $a2, invalid_move   
    bltz $a3, invalid_move   
    bge $a2, $t0, invalid_move  # Rij >= rijen
    bge $a3, $t1, invalid_move  # Kolom >= kolommen

    # huidig pixel adres
    mul $s0, $a0, $t1   
    add $s0, $s0, $a1  
    sll $s0, $s0, 2     
    add $s0, $s0, $gp   

    # nieuw pixel adres
    mul $s1, $a2, $t1   
    add $s1, $s1, $a3   
    sll $s1, $s1, 2    
    add $s1, $s1, $gp  

    # Controleer of nieuwe pixel muur is (blauw)
    lw $t2, ($s1)
    li $t3, 0x004286F4  
    beq $t2, $t3, invalid_move

    # veranderen huidige speler positie
    li $t2, 0x00000000  # Zwart (doorgang)
    sw $t2, ($s0)

    # Teken speler op nieuwe positie
    li $t2, 0x00FFFF00  # Gele spelerkleur
    sw $t2, ($s1)

    # Update speler positie
    move $v0, $a2   # Nieuwe rij
    move $v1, $a3   # Nieuwe kolom
    j move_done

invalid_move:
    # Retour oorspronkelijke positie
    move $v0, $a0
    move $v1, $a1

move_done:
    # Herstel stack frame
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    addi $sp, $sp, 16
    jr $ra
