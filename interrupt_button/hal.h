
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>


#define BIT(x) ((uint32_t) 1U << (x))
#define REG(x) ((volatile uint32_t *) (x))
#define SETBITS(R, CLEARMASK, SETMASK) (R) = ((R) & ~(CLEARMASK)) | (SETMASK)

#define C3_GPIO 0x60004000
#define C3_IO_MUX 0x60009000
#define C3_INTERRUPT 0x600c2000

#define CSR_WRITE(reg, val) ({ asm volatile("csrw " #reg ", %0" ::"rK"(val)); })
#define CSR_READ(reg)                          \
  ({                                           \
    unsigned long v_;                          \
    asm volatile("csrr %0, " #reg : "=r"(v_)); \
    v_;                                        \
  })
#define CSR_SETBITS(reg, cm, sm) CSR_WRITE(reg, (CSR_READ(reg) & ~(cm)) | (sm))

enum { GPIO_OUT_EN = 8, GPIO_OUT_FUNC = 341, GPIO_IN_FUNC = 85 };

struct gpio {  // 5.14 (incomplete)
  volatile uint32_t BT_SELECT, OUT, OUT_W1TS, OUT_W1TC, RESERVED0[4], ENABLE, ENABLE_W1TS,
      ENABLE_W1TC, RESERVED1[3], STRAP, IN, RESERVED2[1], STATUS, STATUS_W1TS, STATUS_W1TC,
      RESERVED3[3], PCPU_INT, PCPU_NMI_INT,
      // TODO(cpq): complete next
      STATUS_NEXT, PIN[22], FUNC_IN[128], FUNC_OUT[22], DATE, CLOCK_GATE;
};
#define GPIO ((struct gpio *) C3_GPIO)


struct irq_data {
    void (*fn)(void *);
    void *arg;
    void (*clr)(void *);
    void *clr_arg;
};
// struct irq_data g_irq_data[32];
struct io_mux {  // 5.14 (incomplete)
  volatile uint32_t PIN_CTRL, IO[22];
};
extern struct irq_data g_irq_data[32];
#define IO_MUX ((struct io_mux *) C3_IO_MUX)

extern int cpu_alloc_interrupt(uint8_t prio);

/* Versiones externas para ASM */
extern void gpio_input(int pin);
extern void gpio_output(int pin);
extern int gpio_read(int pin);
void gpio_set_irq_handler(uint16_t pin, void (*fn)(void *), void *arg);
