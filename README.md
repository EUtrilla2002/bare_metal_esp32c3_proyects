# Collection of trys and falls in ESP32c3 programming using their registers

Thanks to online recouses from THA: https://tha.de/homes/hhoegl/home/es2/Elektor-Bare-Metal/

And https://github.com/cpq/bare-metal-programming-guide

# In order to build this firmware:
- Install docker
- Install esputil from https://github.com/cpq/esputil

Use any ESP32-C3 board, for example ESP32-C3-DevKITM-1.
Attach LED to pin 2. Then,

```sh
$ export PORT=/dev/SERIAL_PORT
$ make flash monitor
...
tick:  1001, CPU 160 MHz
tick:  2001, CPU 160 MHz
tick:  3001, CPU 160 MHz
...
```


<div align="center">
  <img width="192" height="200" alt="image" src="https://media.tenor.com/2hKngpUf2vEAAAAj/jevil-deltarune.gif" />
</div>
