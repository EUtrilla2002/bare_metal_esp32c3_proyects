###------------INTERRUPT STRUCTURE--------------


# IRQ vector (what to do for every IRQ)
    .section .bss
    .align 4
    .global g_irq_data
g_irq_data:
    .skip 32*16      # 32 elementos * 16 bytes
# How this structure works:
#   fn (offset 0): User-defined handler function
#   arg (offset 4): Arguments needed
#   clr pointer (offset 8): Interrupt clearance function
#   clr_arg pointer (offset 12) : Arguments for interrupt clearence functions 
.section .data
    msg: .string "Entered handler"
## Custom trap vector table (Redirects every interrupt to the interrupt handler)
.section .iram0.text   # sección ejecutable en RAM
.global irqtab
.balign 256            # garantiza dirección múltiplo 256 bytes
irqtab:
    .rept 32
        j irq_handler
    .endr

.global irq_handler
.type irq_handler, @function

# (Function) Interruption handler: When an interrupt is detected, checks what IRQ play    
irq_handler:
    addi sp, sp, -32         # reservar stack
    sw ra, 28(sp)
    sw t0, 24(sp)
    sw t1, 20(sp)
    sw t2, 16(sp)
    sw t3, 12(sp)
    sw t4, 8(sp)
    sw t5, 4(sp)
    sw t6, 0(sp)

    la a0, msg
    call printf

    csrr t0, mcause          # Mcause
    csrr t1, mepc            # mepc

    li t2, 0x80000000        # BIT(31)
    and t3, t0, t2
    beqz t3, exception       # If interrupt  == 0 --> Exception 

    # mcause & 0x7FFFFFFF: checks if the interrupt is between the 31 interrupts range
    li t2, 1
    sll t2, t2, 31
    not t2, t2               # t2 = 0x7FFFFFFF
    and t0, t0, t2           # t0 = mcause & 0x7FFFFFFF
    mv t4, t0                # no = t0
    li t5, 32
    bge t4, t5, end_handler # if no > 32 -- > Not an interrupt

    # If its an interruption in the range, checkout the ISR it must execute
    la t6, g_irq_data
    mv t2, t4        # t2 = no
    slli t2, t2, 4   # t2 = no * 16 (sizeof(struct irq_data))
    add t6, t6, t2   # dirección de g_irq_data[no]

    # Call CRL to clear that the interrupt is pending
    lw t2, 8(t6)             # clr pointer (offset 8)
    beqz t2, skip_clr
    lw a0, 12(t6)            # clr_arg (offset 12)
    jalr t2                  # call clr(clr_arg)

skip_clr:
    # Llamar a fn si existe
    lw t2, 0(t6)             # fn pointer (offset 0)
    beqz t2, end_handler
    lw a0, 4(t6)             # arg (offset 4)
    jalr t2                  # call fn(arg) (THE ISR)

    j end_handler
# Exception Handler
exception:
    addi t1, t1, 4           # mepc += 4
    csrw mepc, t1

end_handler:
    lw ra, 28(sp)
    lw t0, 24(sp)
    lw t1, 20(sp)
    lw t2, 16(sp)
    lw t3, 12(sp)
    lw t4, 8(sp)
    lw t5, 4(sp)
    lw t6, 0(sp)
    addi sp, sp, 32
    mret

