############## GPIO manipulation functions ######
#------Variables
.equ GPIO_BASE, 0x60004000
#------GPIO input operations
.global gpio_input_read
gpio_input_read:
    li t0,GPIO_BASE + 0x003C #GPIO_IN_REG
    lw t1,0(t0)
    srl t1, t1, a0 #GPIO_IN_REG >> BUTTON_GPIO
    andi t1, t1, 1 #Take the input position
    mv a0, t1
    jr ra


#------GPIO output operations
.global gpio_output_low
gpio_output_low:
    li t0, GPIO_BASE + 0x000C #GPIO_OUT_W1TC_REG
    li t1, 1
    sll t1, t1, a0       # 1 << OUTPUT_GPIO
    sw t1, 0(t0)         # Write on the register
    jr ra

.global gpio_output_high
gpio_output_high:
    li t0, GPIO_BASE + 0x0008 #GPIO_OUT_W1TS_REG
    li t1, 1
    sll t1, t1, a0       # 1 << OUTPUT_GPIO
    sw t1, 0(t0)         # Write on the register
    jr ra
#------GPIO initialization
.global gpio_input
gpio_input:
    # Configurar GPIO 4 como entrada
    li t0, GPIO_BASE + 0x24   # GPIO_ENABLE_W1TC_REG
    li t1, 1
    sll t1, t1, a0    # 1 << INPUT_GPIO
    sw t1, 0(t0)        
    jr ra
.global  gpio_output    
gpio_output:
    li t0, GPIO_BASE + 0x20   # GPIO_ENABLE_W1TS_REG
    li t1, 1
    sll t1, t1, a0       # 1 << OUTPUT_GPIO
    sw t1, 0(t0)        
    jr ra    
