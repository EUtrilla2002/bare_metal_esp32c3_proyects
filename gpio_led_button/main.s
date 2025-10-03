### Function 1: Led lights interact with button

.global main
.type main, @function 

#----Variables
.equ LED_GPIO, 2
.equ BUTTON_GPIO, 4


.extern  gpio_output
.extern  gpio_input 
.extern gpio_output_high 
.extern gpio_input_read

loop:
    li a0, BUTTON_GPIO
    call gpio_input_read
    beq a0, x0, .button_not_pressed
    # Button pressed
    li a0, LED_GPIO
    call gpio_output_high #Light up led
    j loop
.button_not_pressed:
    li a0, LED_GPIO
    call gpio_output_low
    j loop    

main:
    # Initiate GPIO
    li a0, LED_GPIO
    call gpio_output  # Put LED as output
    li a0, BUTTON_GPIO
    call gpio_input # Put button as input
    j loop