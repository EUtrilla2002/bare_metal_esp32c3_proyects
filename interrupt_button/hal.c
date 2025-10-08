#include "hal.h"
#include <stdint.h>
#include <stdio.h>

void set_irq_handler(void (*fn)(void)) {
  CSR_WRITE(mtvec, (uintptr_t) fn);
}

void gpio_output_enable(int pin, bool enable) {
  GPIO->ENABLE &= ~BIT(pin);
  GPIO->ENABLE |= (enable ? 1U : 0U) << pin;
  // SETBITS(GPIO->ENABLE, BIT(pin), (enable ? BIT(pin) : 0U));
}

void gpio_output(int pin) {
  REG(C3_GPIO)[GPIO_OUT_FUNC + pin] = BIT(9) | 128;  // Simple out, TRM 5.5.3
  gpio_output_enable(pin, 1);
}

void gpio_write(int pin, bool value) {
  GPIO->OUT &= ~BIT(pin);                 // Clear first
  GPIO->OUT |= (value ? 1U : 0U) << pin;  // Then set
}

void gpio_toggle(int pin) {
  GPIO->OUT ^= BIT(pin);
}

void gpio_input(int pin) {
  gpio_output_enable(pin, 0);         // Disable output
  IO_MUX->IO[pin] = BIT(9) | BIT(8);  // Enable pull-up
}

int gpio_read(int pin) {
  return GPIO->IN & BIT(pin) ? 1 : 0;
}



void gpio_clear_interrupt(void *param) {
  uint16_t pin = (uint16_t) (uintptr_t) param;
  //GPIO->STATUS &= ~BIT(pin);
  //printf("clearing pin %d irq\n", pin);
  asm volatile(
    "li t0, 1\n"                // t0 = 1
    "sll t0, t0, %1\n"          // t0 = 1 << pin
    "not t0, t0\n"              // t0 = ~(1 << pin)
    "lw t1, 0(%0)\n"            // t1 = GPIO->STATUS
    "and t1, t1, t0\n"          // t1 = t1 & ~(1 << pin)
    "sw t1, 0(%0)\n"            // GPIO->STATUS = t1
    :                           // No output
    : "r"(&GPIO->STATUS), "r"(pin) // Inputs
    : "t0", "t1"                // Clobbered registers
  );
}
