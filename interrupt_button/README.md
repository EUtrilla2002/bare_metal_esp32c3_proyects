# Interrupts

Pequeño tutorial para aprender y entender como poner interrupciones GPIO

1. **Asignar el puerto GPIO a la interrupción con un nivel de prioridad:**

En este paso, recorremos en bucle una variable auxiliar que aloja qué interrupciones están cogidas.

En nuestro “mock” no tenemos ninguna interrupción alojada y no permitimos que dos interrupciones tengan el mismo ID de interrupción, para más comodidad.

Lo comprobamos haciendo una máscara entre esa lista de interrupciones puestas y la posición del bucle.

```
.data
allocated_msg:
    .string  "Allocated CPU IRQ %d, prio %u\n"  
.text
next:
    addi t3, t3, 1       # no++
    j loop_bits

no_free:
    li a0, -1             # ningún bit libre
 
cpu_alloc_intr:   
la t0, allocated     # t0 = &allocated
    lw t1, 0(t0)         # t1 = allocated
    #Start loop conditions
    li t2, 1             # t2 = 1, usaremos como BIT(1)
    li t3, 1             # t3 = no = 1 (inicio del bucle)
loop_bits:
    li t5, 31
    bge t3, t5, no_free # no >= 31, no interruption ID free
#  start loop
    sll t4, t2, t3      # t4 = BIT(no)
    and t5, t1, t4      # allocated & (1 << t3) 
    bne t5, zero, next  # si está usado (=/0), ir al siguiente
    # si no está usado, marcarlo
    or t1, t1, t4       # allocated |= (1 << t3)
    sw t1, 0(t0)

```

Una vez encontrada esa posición libre, lo indicamos en el vector,habilitamos las interrupciones dentro de la placa y asignamos la prioridad de la posición de interrupción escogida en memoria.

Aquí tocamos los registros

* INTERRUPT_CORE0_CPU_INT_ENABLE_REG  (para habilitar la interrupción)

```
 # (1) Enable CPU interruptions 
    li t5, INTERRUPT_BASE
    addi t5, t5, 0x104 # offset INTERRUPT_CORE0_CPU_INT_ENABLE_REG
    lw t0, 0(t5)
    li t1, 1
    sll t1, t1, t3 #BIT(no)
    or t0, t0, t1
    sw t0, 0(t5)

```

* INTERRUPT_CORE0_CPU_INT_PRI_n_REG (para indicar la prioridad de la interrupción)

```
    # (2) Assign priority
    li t5, INTERRUPT_BASE
    addi t5, t5, 0x118 #INTERRUPT_CORE0_CPU_INT_PRI_0_REG
    addi t1, t3, -1
    slli t1, t1, 2 #For GPIO 2
    add t5, t5, t1 #INTERRUPT_CORE0_CPU_INT_PRI_2_REG
    sw s0, 0(t5)

```

2. **Guardar en el vector de alojamiento de ISRs la información sobre cómo queremos que reaccione nuestra introducción.**

En las placas Expressif no almacenan todo dentro del vector de interrupciones, sino que tienen en memoria otra tabla (una lista de estructuras) para almacenar los ISR de cada interrupción, que en ese caso llamamos  “g_irq_data” ,con tantas posiciones como interrupciones que se pueden alojar y estructurados de la siguiente forma (mostrado en C para entenderse mejor):

```
struct irq_data {
    void (*fn)(void *); // ISR a ejecutar.
    void *arg; // Argumentos que necesita la ISR
    void (*clr)(void *); //Función de limpieza después del registro
    void *clr_arg; // Argumentos que emplea la función de registro (por defecto, el pin a limpiar)
};

```

Cada elemento del struct ocupa 4 bytes, por lo tanto en ensamblador tendremos que desplazarnos hasta la lista correspondiente (en este caso,tantas posiciones como interrupciones haya) y luego ir accediendo a cada elemento saltando de 4 a 4 bytes

Aquí se muestra un ejemplo

```
  # (2)Save pin interrupt
    la t0, g_irq_data 
    la s1, isr_function #ISR definida
    la t2, gpio_clear_interrupt # t2 = gpio_clear_interrupt
    #---- Recorremos la lista
    slli t1, s3, 4    # t1 = no * 16
    add t0, t0, t1    # t0 = &g_irq_data[no]
    #---- Almacenamos en el struct
    sw s1, 0(t0)     # *(t0 + 0) = isr
    sw s2, 4(t0)     # *(t0 + 4) = arg 
    sw t2, 8(t0)     # *(t0 + 8) = gpio_clear_interrupt
    sw s0, 12(t0)    # *(t0 + 12) = pin (s0)

```

Pero ¿Qué es eso de “limpiar la interrupción"?

Si recordamos antes, uno de los valores de una interrupción es si está pending. Por ello,cuando se ha terminado la interrupción y para volver a la ejecución normal, tenemos que escribir en GPIO que todas las interrupciones que pudieran estar encendidas ya han terminado. Esto se hace de la siguiente forma:

```
gpio_clear_interrupt:
    # a0 = pin
    li t0, GPIO_BASE
    addi t0, t0, 0x44 #GPIO_STATUS_REG
    lw t1, 0(t0)
    li t2, 1
    sll t2, t2, a0   # BIT(pin)
    not t0, t0      # ~BIT(pin)
    and t1, t1, t0  #t1 & ~(1 << pin) Clear pin
    sw t1, 0(t0)
    ret

```

Una vez establecida la rutina de interrupción, debemos asignar las características de la interrupción al GPIO asignado.

En nuestro caso,cuando lleguemos al registro de memoria del pin que queremos, debemos tocar los apartados de memoria GPIO_PINn_INT_ENA (para habilitar esta interrupción) y GPIO_PINn_INT_TYPE (establecer el tipo de interrupción que queremos, como se ha hablado anteriormente)

Vemos que INT_TYPE tiene 3 bits, y es para indicar el tipo, que son estos reflejados en la página 184 del manual.

| Tipo de interrupción             | Valor   |
| --------------------------------- | ------- |
| Deshabilitada                     | 0 (000) |
| Flanco ascendente (rising edge)   | 1 (001) |
| Flanco descendente (falling edge) | 2 (010) |
| Cualquier flanco                  | 3 (011) |
| Nivel bajo                        | 4 (100) |
| Nivel alto                        | 5 (101) |

Y por otro lado GPIO_PINn_INT_ENA es solo un bit, para indicar que está activada esa interrupción.

Por ello, antes de escribir en el registro, hacemos los cálculos y escribimos las características que queremos de golpe.

En este caso de ejemplo, buscamos indicar que la interrupción que queremos va a aceptar los dos flancos (ya que es para notar si un botón sube o baja) , por ello salen las siguientes operaciones:

```
   li t3, 3         # t3 = 3
    slli t3, t3, 7   # t3 = 3 << 7 = 0x180 activar INT_TYPE con el valor 3
    li t4, 1         # t4 = 1
    slli t4, t4, 13  # t4 = 1 << 13 = 0x2000 activar GPIO_PINn_INT_ENA
    or t3, t3, t4    # t3 = t3 | t4 = 0x180 | 0x2000 = 0x2180

```

Luego la operación completa sería la siguiente

```
 # (3) Set characteristics for the interrupt; 
    li t0, GPIO_BASE
    addi t0, t0, 0x74
    slli t1, s0, 2        #t1 = pin(2) * 4
    add t0, t0, t1     #t0 =  GPIO_PIN2_REG
    lw t2, 0(t0)
    li t3, 3         # t3 = 3
    slli t3, t3, 7   # t3 = 3 << 7 = 0x180
    li t4, 1         # t4 = 1
    slli t4, t4, 13  # t4 = 1 << 13 = 0x2000
    or t3, t3, t4    # t3 = t3 | t4 = 0x180 | 0x2000 = 0x2180
    or t2, t2, t3 
    sw t2, 0(t0)

```

Y, por último, mapeamos la rutina de interrupción GPIO a CPU mediante el registro GPIO_INTERRUPT_PRO_MAP_REG añadiendo el numerosos de interrupción que se le ha asignado.

```
    li t0, INTERRUPT_BASE
    addi t0, t0, 0x40 #GPIO_INTERRUPT_PRO_MAP_REG
    sw s3, 0(t0)

```
