### Main function

.global main
.type main, @function 

#----Variables
.equ LED_GPIO, 2
.equ BUTTON_GPIO, 9
.equ PRIORITY, 1
# Memory positions
.equ INTERRUPT_BASE, 0x600C2000
.equ GPIO_BASE, 0x60004000

.section .rodata
# Mensajes para cpu_alloc_interrupt
msg: .string "gpio_set_irq_handler\n"
msg_mstatus:
    .string  "mstatus = 0x%08x\n"

msg_pri_addr:   .string "DEBUG: CPU_INT_PRI_n address = %p\n"
msg_pri_after:  .string "DEBUG: CPU_INT_PRI_n valor despues de escribir = 0x%08lX\n"

msg_reg_after:
    .string "INTERRUPT_CORE0_CPU_INT_ENABLE_REG escrito en %p: 0x%08X\n"
msg_addr:
    .string "GPIO_PIN_9_REG escrito en %p: 0x%08X\n"
msg_allocated:
    .string "allocated escrito en %p: 0x%08X\n"
msg_cpu_enable:
    .string "CPU_INT_ENABLE_REG escrito en %p: 0x%08X\n"
msg_cpu_pri:
    .string "CPU_INT_PRI escrito en %p: 0x%08X\n"
msg2:
    .string "IRQ handler setup: prioridad %d, IRQ asignada %d\n"

# Mensajes para gpio_set_irq_handler
msg_irq_info:
    .string "IRQ handler setup: pin=%d, fn=%p, arg=%p, irq=%d\n"
msg_fn:
    .string "g_irq_data.fn = %p\n"
msg_arg:
    .string "g_irq_data.arg = %p\n"
msg_clr:
    .string "g_irq_data.clr = %p\n"
msg_clr_arg:
    .string "g_irq_data.clr_arg = %p\n"
msg_reg:
    .string "Registro INT_STATUS: 0x%08X\n"
msg_reg2:
    .string "Registro GPIO_PIN%d_REG: 0x%08X\n"


.data

allocated:
    .word 0 # Think about it as a vector with 31 positions available from 0x00000000 to 0x7FFFFFFE
.text
#----------Set interruption
cpu_alloc_interrupt:
    mv s3, a0
    li t0, 31
    li s4 ,1
    bge s4, t0, fail       # Loop for 31
    # Load if it is allocated
    la t1, allocated
    lw t2, 0(t1)
    # Load mask  BIT(no) = 1 << s4
    li t3, 1
    sll t3, t3, s4
    # Is this position occupied??
    and t4, t2, t3 # allocated & BIT(no)
    bnez t4, next          # si está ocupado → probar siguiente
    # Position not occupied --> Check in allocated
    or t2, t2, t3
    sw t2, 0(t1)
    #----Habilitate interruption in CPU in NTERRUPT_CORE0_CPU_INT_ENABLE_REG
    li t5, INTERRUPT_BASE 
    addi t6, t5, 0x104 #NTERRUPT_CORE0_CPU_INT_ENABLE_REG
    lw t0, 0(t6)
    or t0, t0, t3
    sw t0, 0(t6)
    fence
    #---------DEBUG
    # Guardar ra en la pila
    addi sp, sp, -8
    sw ra, 0(sp)

    # Preparar parámetros para printf
    lw t1, 0(t6)          # leer valor del registro
    la a0, msg_reg_after   # string
    mv a1, t6             # dirección del registro
    mv a2, t1             # valor leído
    call printf

    # Restaurar ra de la pila
    lw ra, 0(sp)
    addi sp, sp, 8
    #----Configure Interrupt priority
    addi t6, t5, 0x118 #INTERRUPT_CORE0_CPU_INT_PRI_1_REG, we will start from here
    mv t0, s1             # t0 = IRQ number
    addi t0, t0, -1       # t0 = no - 1
    slli t0, t0, 2        # t0 * 4 bytes
    add t6, t6, t0        # t6 = dirección de CPU_INT_PRI_no
    #------DEBUG
    # Guardar ra en la pila para printf
    addi sp, sp, -8
    sw ra, 0(sp)

    # DEBUG: imprimir dirección del registro de prioridad
    la a0, msg_pri_addr
    mv a1, t6
    call printf

    # Escribir prioridad
    sw s3, 0(t6)                  # prioridad en a0
    fence

    # DEBUG: leer y verificar valor escrito
    lw t1, 0(t6)
    la a0, msg_pri_after
    mv a1, s4
    call printf

    # Restaurar ra de la pila
    lw ra, 0(sp)
    addi sp, sp, 8

    # Devolver IRQ asignado
    mv a0, s4

    j done

next:
    addi s4, s4, 1 #Move towards the next position
    j cpu_alloc_interrupt

fail: #Return -1 and go to "done"
    li a0, -1
    j done 

done:
    addi sp, sp, -8
    sw ra, 0(sp)
    la a0, msg2
    mv a1, s3
    mv a2, s4
    call printf
    lw ra, 0(sp)
    addi sp, sp, 8
    mv a0, s4
    ret   

.extern g_irq_data  
gpio_set_irq_handler:
    mv s0, a0       # s0 = pin
    mv s1, a1       # s1 = fn
    mv s2, a2       # s2 = arg
    #--------Set interruption with some priority (ej: 1)
    li a0, PRIORITY
    call cpu_alloc_interrupt
    mv s3,a0
    # -----------------------------------------Debug
    # la a0, msg_irq_info
    # mv a1, s0       # pin
    # mv a2, s1       # fn
    # mv a3, s2       # arg
    # mv a4, s3       # irq asignado
    # call printf
    #--------Allocate in interrupt vector table
    # Access to the vector position
    la t5, g_irq_data      # base de g_irq_data
    slli t6, s3, 4         # t6 = no * 16
    add t5, t5, t6         # t5 = &g_irq_data[no]
    # Write in the irq_data
    la t3, gpio_clear_interrupt
    sw s1, 0(t5)     # fn
    sw s2, 4(t5)     # arg
    sw t3, 8(t5)     # clr
    sw s0, 12(t5)    # clr_arg
    #-----------------------DEBUG
    # lw t0, 0(t5)   # fn
    # la a0, msg_fn
    # mv a1, t0
    # call printf

    # lw t0, 4(t5)   # arg
    # la a0, msg_arg
    # mv a1, t0
    # call printf

    # lw t0, 8(t5)   # clr
    # la a0, msg_clr
    # mv a1, t0
    # call printf

    # lw t0, 12(t5)  # clr_arg
    # la a0, msg_clr_arg
    # mv a1, t0
    # call printf
    # Enable interruption for GPIO 
    li t0, INTERRUPT_BASE + 0xF8
    lw t1, 0(t0)           # lectura volatile
    li t2, 1
    slli t2, t2, 16        # BIT(16)
    or t1, t1, t2
    sw t1, 0(t0)           # escritura volatile
    fence                  # asegurar propagación

    #----------DEBUG: imprimir valor
    # addi sp, sp, -24       # 8 bytes por t1, a1, ra
    # sw t1, 0(sp)
    # sw a1, 8(sp)
    # sw ra, 16(sp)

    # lw t1, 0(t0)
    # la a0, msg_reg
    # mv a1, t1
    # call printf

    # lw t1, 0(sp)
    # lw a1, 8(sp)
    # lw ra, 16(sp)
    # addi sp, sp, 24

    # Enable pin intr
    la t0, GPIO_BASE
    li t1, 0x74
    add t0, t0, t1         # base PIN0_REG
    slli t1, s0, 2         # pin*4
    add t0, t0, t1         # &GPIO_PIN<pin>_REG

    lw t2, 0(t0)           # lectura volatile
    li t3, 3
    slli t3, t3, 7          # 3 << 7
    li t4, 1
    slli t4, t4, 13         # BIT(13)
    or t2, t2, t3
    or t2, t2, t4
    sw t2, 0(t0)            # escritura volatile
    fence                   # asegurar propagación

    #--------DEBUG: imprimir dirección y valor final
    # addi sp, sp, -24   # Reservar espacio: 8 bytes por t0, t2 y a1
    # sw t0, 0(sp)
    # sw t2, 8(sp)
    # sw a1, 16(sp)

    # # Preparar parámetros para printf
    # mv a2, t2
    # mv a1, t0
    # la a0, msg_addr
    # call printf

    # # Restaurar registros de la pila
    # lw t0, 0(sp)
    # lw t2, 8(sp)
    # lw a1, 16(sp)
    # addi sp, sp, 24    # liberar espacio de la pila

    # Map GPIO IRQ to CPU
    li t0, INTERRUPT_BASE + 0x40
    sw s3, 0(t0)           # número de IRQ asignado
    fence                  # asegurar propagación
    #---------DEBUG Interrupt enabled in CPU
    # addi sp, sp, -8
    # sw ra, 0(sp)

    # csrr a1, mstatus

    # la a0, msg_mstatus
    # call printf

    # lw ra, 0(sp)
    # addi sp, sp, 8
    # Retornar
   
    
    ret


#----Clean interrupts
gpio_clear_interrupt:
    li t0,GPIO_BASE + 0x44  #GPIO_STATUS_REG
    lw t1, 0(t0)              #read status
    li t2, 1
    sll t2, t2, a0            # t1 = 1 << pin
    not t2,t2                 #~BIT(pin)
    and t1, t1 ,t2            # STATUS & ~BIT(pin): D
    sw t1, 0(t0)              # Cleans the pin
    jr ra                     
    
#------ISR---
button_handler:
    la a0, msg
    call printf
    jr ra
.button_not_pressed:
    li a0, LED_GPIO
    call gpio_output_low
    jr ra 



.extern  gpio_output
.extern  gpio_input 
.extern gpio_output_high 
.extern gpio_input_read
loop:
    li t0, 0x6001f0fc   # TIMG0_WDT_FEED_REG
    li t1, 1             # valor de "feed"
    sw t1, 0(t0)         # alimentar watchdog

    j loop
main:
    # Initiate GPIO
    li a0, LED_GPIO
    call gpio_output  # Put LED as output
    li a0, BUTTON_GPIO
    call gpio_input # Put button as input
    # INTERRUPTION SETUP
    li a0, BUTTON_GPIO
    la a1, button_handler
    li a2, BUTTON_GPIO
    call  gpio_set_irq_handler
    j loop