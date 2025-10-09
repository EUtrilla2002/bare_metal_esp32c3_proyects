    ### MAIN PROGRAM ###
.data
systimer_tick:
    .word 0
allocated:
    .word 0  
msg_tick:
    .string "tick\n"


.section .text

    .equ BUTTON_PIN, 9
    .equ LED_PIN, 2
    .equ INTERRUPT_BASE, 0x600c2000
    .equ GPIO_BASE, 0x60004000
    .equ SYSTIMER_BASE, 0x60023000

    .global main
#---Interrupts
cpu_alloc_interrupt:
    #Save all save registers, just in case
    addi sp, sp, -12
    sw s0, 0(sp)
    sw s1, 4(sp)
    sw s2, 8(sp)

    #Save argument
    mv s0,a0 #PRIORITY (1-15)

    la t0, allocated     # t0 = &allocated
    lw t1, 0(t0)         # t1 = allocated
    #Start loop conditions
    li t2, 1             # t2 = 1, usaremos como BIT(1)
    li t3, 1             # t3 = no = 1 (inicio del bucle)
loop_bits:
    li t5, 31
    bge t3, t5, no_free # si no >= 31, terminar con 0

    sll t4, t2, t3      # t4 = 1 << t3
    and t5, t1, t4      # t5 = allocated & (1 << t3)
    bne t5, zero, next  # si está usado, ir al siguiente

    # si no está usado, marcarlo
    or t1, t1, t4       # allocated |= (1 << t3)
    sw t1, 0(t0)

    # (1) Enable CPU interruptions REG(C3_INTERRUPT)[0x104 / 4] |= BIT(no); 
    li t5, INTERRUPT_BASE
    addi t5, t5, 0x104 # INTERRUPT_CORE0_CPU_INT_ENABLE_REG
    lw t0, 0(t5)
    li t1, 1
    sll t1, t1, t3 #BIT(no)
    or t0, t0, t1
    sw t0, 0(t5)

    # (2) Assign priority REG(C3_INTERRUPT)[0x118 / 4 + no - 1] = prio;  // CPU_INT_PRI_N
    li t5, INTERRUPT_BASE
    addi t5, t5, 0x118 #INTERRUPT_CORE0_CPU_INT_PRI_n_REG  
    addi t1, t3, -1
    slli t1, t1, 2
    add t5, t5, t1
    sw s0, 0(t5)

    # #(3) Print if it's allocated
    # la a0,allocated_msg
    # mv a1,t3
    # mv a2, s0

    # call printf

    mv a0, t3            # devolver número asignado
    j done

next:
    addi t3, t3, 1       # no++
    j loop_bits

no_free:
    li a0, -1             # ningún bit libre

done:
    # Restaurar registros
    lw s0, 0(sp)
    lw s1, 4(sp)
    lw s2, 8(sp)
    addi sp, sp, 12
    ret

systimer_init:
    # Arguments: a0 = period
    mv s0, a0 
    # (1) Configure timer
    # SYSTIMER->TARGET0_CONF = BIT(30) | 16000; Set period
    li t0, SYSTIMER_BASE
    addi t0, t0, 0x034 #SYSTIMER_TARGET0_CONF_REG
    li t1, 1
    sll t1, t1, 30 #Bit(30)
    or t1, t1, s0  # t1 = BIT(30) | 16000
    sw t1, 0(t0)
    # SYSTIMER->COMP0_LOAD = BIT(0); Reload period
    li t0, SYSTIMER_BASE
    addi t0, t0, 0x050
    li t1, 1
    sll t1, t1, 0 # t1 = BIT(0)
    sw t1, 0(t0)
    # SYSTIMER->CONF |= BIT(24);                 // Enable comparator 0
    li t0, SYSTIMER_BASE
    addi t0, t0, 0x000  #SYSTIMER_CONF_REG
    lw t1, 0(t0)
    li t2, 1
    slli t3, t2, 24  # t3 = BIT(24)
    or t1, t1, t3  # BIT(24) | 0
    sw t1, 0(t0)
    # SYSTIMER->INT_ENA |= 7U enable triggers in all targets
    li t0, SYSTIMER_BASE
    addi t0, t0, 0x064 # t0 = SYSTIMER_INT_ENA_REG
    lw t1, 0(t0)
    li t2, 7 # 7 (111) activate all targets
    or t1, t1, t2 # SYSTIMER->INT_ENA |= 7U;
    sw t1, 0(t0)
    # (2)Allocate interrupt in CPU with priority 1
    li a0, 1          # prioridad
    call cpu_alloc_interrupt
    mv s1, a0         # Save IRQ assigned
    # (3) Save ISR in g_irq_data
    la t0, g_irq_data
    slli t1, s1, 4 # t1 = no * 16 (4 campos x 4 bytes)
    add t0, t0, t1
    la t2, timer_handler
    sw t2, 0(t0)
    la t2, systimer_clear_interrupt
    sw t2, 8(t0)
    # (4) Map systimer IRQ to CPU
    li t0, INTERRUPT_BASE
    addi t0, t0, 0x94
    lw t1, 0(t0)
    mv t2, s1 #no
    sw t2, 0(t0)

    jr ra

##---ISR---
timer_handler:
    lw t0, systimer_tick
    addi t0, t0, 1

    addi sp, sp, -4      # Reserva espacio en la pila
    sw ra, 0(sp)         # Guarda ra

    la a0, msg_tick      # a0 = dirección del string
    call printf          # llama a printf("tick\n")

    lw ra, 0(sp)         # Restaura ra
    addi sp, sp, 4       # Libera espacio de la pila

    jr ra

systimer_clear_interrupt:
   li t0, SYSTIMER_BASE
   addi t0, t0, 0x06C # 
   lw t1, 0(t0)
   li t2, 7
   sw t2, 0(t0)  
   jr ra 

main: 
    li a0, 16000
    jal ra, systimer_init

loop:
    j loop
