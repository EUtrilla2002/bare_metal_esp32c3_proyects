// SPDX-FileCopyrightText: 2021-2023 Cesanta Software Limited
// SPDX-License-Identifier: MIT

#include "hal.h"

extern int main(void);
//extern void SystemInit(void);
extern char _sbss, _ebss, _end, _eram;

static char *s_heap_start, *s_heap_end, *s_brk;

void *sbrk(int diff) {
  char *old = s_brk;
  if (&s_brk[diff] > s_heap_end) return NULL;
  s_brk += diff;
  return old;
}

// Mark it weak - allow user to override it
__attribute__((weak)) void SysTick_Handler(void) {
}

// C handlers associated with CPU interrupts, with their arguments
struct irq_data g_irq_data[32];

// Attribute interrupt makes this function to:
// 1. Return with mret instruction
// 2. Save/restore all used registers
__attribute__((interrupt)) void irq_handler(void) {
  unsigned long mcause = CSR_READ(mcause), mepc = CSR_READ(mepc);
  //printf("mcause %lx\n", mcause);
  if ((mcause & BIT(31))) {          // Interrupt
    uint32_t no = mcause << 1 >> 1;  // Interrupt number
    if (no < sizeof(g_irq_data) / sizeof(g_irq_data[0])) {
      struct irq_data *d = &g_irq_data[no];
      if (d->clr) d->clr(d->clr_arg);  // Clear interrupt
      if (d->fn) d->fn(d->arg);        // Call user handler
    }
    // asm_volatile(

    // );
  } else {  // Exception
    CSR_WRITE(mepc, mepc + 4);
  }
}

// Vector table. Point all entries to the irq_handler()
__attribute__((aligned(256))) void irqtab(void) {
  asm(".rept 32");       // 32 entries
  asm("j irq_handler");  // Jump to irq_handler()
  asm(".endr");
}

void Reset_Handler(void) {
  s_heap_start = s_brk = &_end, s_heap_end = &_eram;
  for (char *p = &_sbss; p < &_ebss;) *p++ = '\0';
  CSR_WRITE(mtvec, irqtab);  // Route all interrupts to the irq_handler()
  soc_init();
  main();
  for (;;) (void) 0;
}
