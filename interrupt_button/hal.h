
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>


#define BIT(x) ((uint32_t) 1U << (x))
#define REG(x) ((volatile uint32_t *) (x))
#define SETBITS(R, CLEARMASK, SETMASK) (R) = ((R) & ~(CLEARMASK)) | (SETMASK)

#define C3_GPIO 0x60004000
#define C3_IO_MUX 0x60009000
#define C3_INTERRUPT 0x600c2000
#define C3_RTCCNTL 0x60008000
#define C3_TIMERGROUP0 0x6001F000
#define C3_TIMERGROUP1 0x60020000

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

static inline void wdt_disable(void) {
  REG(C3_RTCCNTL)[42] = 0x50d83aa1;  // Disable write protection
  // REG(C3_RTCCNTL)[36] &= BIT(31);    // Disable RTC WDT
  REG(C3_RTCCNTL)[36] = 0;  // Disable RTC WDT
  REG(C3_RTCCNTL)[35] = 0;  // Disable

  // bootloader_super_wdt_auto_feed()
  REG(C3_RTCCNTL)[44] = 0x8F1D312A;
  REG(C3_RTCCNTL)[43] |= BIT(31);
  REG(C3_RTCCNTL)[45] = 0;

  // REG(C3_TIMERGROUP0)[63] &= ~BIT(9);  // TIMG_REGCLK -> disable TIMG_WDT_CLK
  REG(C3_TIMERGROUP0 + 0x48)[0] = 0;  // Disable TG0 WDT
  REG(C3_TIMERGROUP1 + 0x48)[0] = 0;  // Disable TG1 WDT
}

static inline void soc_init(void) {
  // Init clock. TRM 6.2.4.1
  // REG(C3_SYSTEM)[2] &= ~3U;
  // REG(C3_SYSTEM)[2] |= BIT(0) | BIT(2);
  // REG(C3_SYSTEM)[22] = BIT(19) | (40U << 12) | BIT(10);
  // REG(C3_RTCCNTL)[47] = 0; // RTC_APB_FREQ_REG -> freq >> 12
  //((void (*)(int)) 0x40000588)(160);  // ets_update_cpu_frequency(160)
  wdt_disable();

#if 0
  // Configure system clock timer, TRM 8.3.1, 8.9
  REG(C3_TIMERGROUP0)[1] = REG(C3_TIMERGROUP0)[2] = 0UL;  // Reset LO and HI
  REG(C3_TIMERGROUP0)[8] = 0;                             // Trigger reload
  REG(C3_TIMERGROUP0)[0] = (83U << 13) | BIT(12) | BIT(29) | BIT(30) | BIT(31);
#endif
}

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
