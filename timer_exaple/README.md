# Timer Interrupts

Pequeño tutorial para aprender y entender como poner interrupciones SYSTIMER

1. **Definir el ISR**

En este caso, el ISR es sumamente sencillo: ¿qué es lo que queremos que pase cada vez que se ejecuta una interrupción?

Para este caso sencillo, lo que vamos a hacer es contabilizar cuántos milisegundos han pasado desde que inicializamos el timer.

```
timer_handler:
    la t0, systimer_tick
    lw t1, 0(t0)
    addi t1, t1, 1
    sw t1, 0(t0)
    jr ra

```


2. **Inicializar el timer**

Lo primero de todo es establecer en nuestro timer la frecuencia que va a seguir y permitir que este produzca interrupciones.

```
    li t0, SYSTIMER_BASE
    addi t0, t0, 0x034 #SYSTIMER_TARGET0_CONF_REG
    li t1, 1
    sll t1, t1, 30 #Bit(30)
    or t1, t1, s0  # t1 = BIT(30) | 16000
    sw t1, 0(t0)
```

- Arrancamos el contador a cero

```
    li t0, SYSTIMER_BASE
    addi t0, t0, 0x050
    li t1, 1
    sll t1, t1, 0 # t1 = BIT(0)
    sw t1, 0(t0)
```

- Activamos el comparador.

```
    li t0, SYSTIMER_BASE
    addi t0, t0, 0x000  #SYSTIMER_CONF_REG
    lw t1, 0(t0)
    li t2, 1
    slli t3, t2, 24  # t3 = BIT(24)
    or t1, t1, t3  # BIT(24) | 0
    sw t1, 0(t0)

```

- Habilitamos las interrupciones del timer

  ```
      li t0, SYSTIMER_BASE
      addi t0, t0, 0x064 # t0 = SYSTIMER_INT_ENA_REG
      lw t1, 0(t0)
      li t2, 7 # 7 (111) activate all targets
      or t1, t1, t2 # SYSTIMER->INT_ENA |= 7U;
      sw t1, 0(t0)
  ```
- Asignamos el ISR a la interrupción

  ```
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

  ```
  - ISR de limpieza:

    ```
    systimer_clear_interrupt:
       li t0, SYSTIMER_BASE
       addi t0, t0, 0x06C # SYSTIMER_TARGET0_INT_CLR
       lw t1, 0(t0)
       li t2, 7
       sw t2, 0(t0)  
       jr ra 

    ```
- Mapeamos el IRQ del Systimer a la CPU

  ```
      li t0, INTERRUPT_BASE
      addi t0, t0, 0x94
      lw t1, 0(t0)
      mv t2, s1 #no
      sw t2, 0(t0)

  ```
  3. Interactuar con ese timer creado

     ```
     .data
        msg_tick:
         .string "Hi!!! \n"
     .text
     print_function:
         addi sp, sp,-4
         sw ra,0(sp)
         la a0, msg_tick
         call printf
         li t0, 0                # t0 = 0
         la t1, systimer_tick    # t1 = &systimer_tick
         sw t0, 0(t1)            # systimer_tick = 0
         lw ra,0(sp)
         addi sp, sp,4
         jr ra

     log_task:
         lw t0, systimer_tick
         li t1, 1000 #1 s
         bge t0,t1, print_function
         j log_task

     main: 
         li a0, 16000
         jal ra, systimer_init
         j log_task

     loop:
         j loop

     ```
