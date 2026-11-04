#include <stdint.h>

#define OUT_START (*(volatile uint32_t*)0x40000010)
#define OUT_DONE  (*(volatile uint32_t*)0x40000014)

int A[2][2] = {{1, 2}, {3, 4}};
int B[2][2] = {{5, 6}, {7, 8}};
volatile int sw_result[2][2];

void __attribute__((naked)) _start() {
    asm volatile("li sp, 0x00000FF0"); 
    asm volatile("j main");
}

int main() {
    OUT_START = 1; 

    // Standard nested loops (This forces the CPU to waste cycles on branching)
    for(int i = 0; i < 2; i++) {
        for(int j = 0; j < 2; j++) {
            sw_result[i][j] = 0;
            for(int k = 0; k < 2; k++) {
                sw_result[i][j] += A[i][k] * B[k][j];
            }
        }
    }
    
    OUT_DONE = 1; 
    
    while(1); 
    return 0;
}