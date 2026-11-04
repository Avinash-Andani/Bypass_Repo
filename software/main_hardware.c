#include <stdint.h>

#define OUT_START      (*(volatile uint32_t*)0x40000010)
#define HW_MATRIX_DATA (*(volatile uint32_t*)0x40000000)
#define HW_START_CMD   (*(volatile uint32_t*)0x40000004)

void __attribute__((naked)) _start() {
    asm volatile("li sp, 0x00000FF0"); 
    asm volatile("j main");
}

int main() {
    // Start the Verilog stopwatch
    OUT_START = 1; 

    // Pack and send the matrix data into the FIFOs
    HW_MATRIX_DATA = 0x08040602; 
    HW_MATRIX_DATA = 0x07030501; 
    
    // Trigger the Systolic Array Start Wire
    HW_START_CMD = 1; 
    
    // Halt the CPU and let the hardware take over
    while(1); 
    return 0;
}