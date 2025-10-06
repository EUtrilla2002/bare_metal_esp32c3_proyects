// SPDX-FileCopyrightText: 2021-2023 Cesanta Software Limited
// SPDX-License-Identifier: MIT

//#include "hal.h"
#include <stddef.h>

extern int main(void);

#define CSR_WRITE(reg, val) ({ asm volatile("csrw " #reg ", %0" ::"rK"(val)); })

// Memory
extern char _sbss, _ebss, _end, _eram;
static char *s_heap_start, *s_heap_end, *s_brk;
// Interrupts
extern void irqtab(void);        // tabla de vectores

void *sbrk(int diff) {
  char *old = s_brk;
  if (&s_brk[diff] > s_heap_end) return NULL;
  s_brk += diff;
  return old;
}

void Reset_Handler(void) {
  s_heap_start = s_brk = &_end, s_heap_end = &_eram;
  for (char *p = &_sbss; p < &_ebss;) *p++ = '\0';
  CSR_WRITE(mtvec, irqtab);  // Route all interrupts to the irq_handler()
  main();
  for (;;) (void) 0;
}
