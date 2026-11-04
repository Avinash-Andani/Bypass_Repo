#include <stdint.h>

// Memory-Mapped I/O Register Definitions
#define MMIO_FIFO_PUSH      (*(volatile uint32_t*)0x40000000)
#define MMIO_COPROC_START   (*(volatile uint32_t*)0x40000004)
#define MMIO_COPROC_STATUS  (*(volatile uint32_t*)0x40000008)
#define MMIO_HW_TIMER_START (*(volatile uint32_t*)0x40000010)
#define MMIO_SW_TIMER_START (*(volatile uint32_t*)0x40000014)
#define MMIO_SW_TIMER_STOP  (*(volatile uint32_t*)0x40000018)

// Global Matrices for Software Baseline (Volatile prevents compiler constant-folding)
volatile int32_t A[2][2] = {{1, 2}, {3, 4}};
volatile int32_t B[2][2] = {{5, 6}, {7, 8}};
volatile int32_t sw_result[2][2];

// Naked Bootloader Placed at 0x0000_0000 via .text.init
void __attribute__((naked, section(".text.init"))) _start(void) {
    asm volatile (
        "li sp, 0x00000FF0\n\t"
        "j main\n\t"
    );
}

int main(void) {
    // =========================================================================
    // PHASE A: Hardware Systolic Array Benchmark
    // =========================================================================
    MMIO_HW_TIMER_START = 1;

    // Push 32-bit packed vectors: {b_in_1, a_in_1, b_in_0, a_in_0}
    MMIO_FIFO_PUSH = 0x08040602;
    MMIO_FIFO_PUSH = 0x07030501;

    // Trigger Systolic Array FSM
    MMIO_COPROC_START = 1;

    // Wait for Hardware Completion Flag (Bit 0 of 0x40000008)
    while ((MMIO_COPROC_STATUS & 0x01) == 0);

    // =========================================================================
    // PHASE B: Software O(N^3) RISC-V CPU Baseline Benchmark
    // =========================================================================
    MMIO_SW_TIMER_START = 1;

    for (int i = 0; i < 2; i++) {
        for (int j = 0; j < 2; j++) {
            int32_t acc = 0;
            for (int k = 0; k < 2; k++) {
                acc += A[i][k] * B[k][j];
            }
            sw_result[i][j] = acc;
        }
    }

    MMIO_SW_TIMER_STOP = 1;

    // Park CPU cleanly after both benchmarks are locked into hardware registers
    while (1) {
        asm volatile ("nop");
    }

    return 0;
}
