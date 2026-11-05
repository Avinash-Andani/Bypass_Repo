#include <stdint.h>

// Memory-Mapped I/O Register Definitions
#define MMIO_FIFO_PUSH       (*(volatile uint32_t*)0x40000000)
#define MMIO_COPROC_START    (*(volatile uint32_t*)0x40000004)
#define MMIO_COPROC_STATUS   (*(volatile uint32_t*)0x40000008)
#define MMIO_COPROC_CLEAR    (*(volatile uint32_t*)0x4000000C)
#define MMIO_LATCH_2X2       (*(volatile uint32_t*)0x40000010)
#define MMIO_SW_TIMER_START  (*(volatile uint32_t*)0x40000014)
#define MMIO_SW_TIMER_STOP   (*(volatile uint32_t*)0x40000018)
#define MMIO_PREDICTED_DIGIT (*(volatile uint32_t*)0x4000001C)

#define MMIO_OUT_00          (*(volatile uint32_t*)0x40000020)
#define MMIO_OUT_01          (*(volatile uint32_t*)0x40000024)
#define MMIO_OUT_10          (*(volatile uint32_t*)0x40000028)
#define MMIO_OUT_11          (*(volatile uint32_t*)0x4000002C)
#define MMIO_DIGIT_SELECT    (*(volatile uint32_t*)0x40000038)

// Software Baseline 2x2 Matrices
volatile int32_t A[2][2] = {{1, 2}, {3, 4}};
volatile int32_t B[2][2] = {{5, 7}, {6, 8}};
volatile int32_t sw_result[2][2];

// 4 Test Digit Images (8x8 INT8 = 256 Bytes total in BRAM)
static const uint8_t digits[4][8][8] = {
    // Digit 0: Hollow Ring (Strong outer columns 0 & 7)
    {
        { 0, 10, 10, 10, 10, 10, 10,  0},
        {10,  0,  0,  0,  0,  0,  0, 10},
        {10,  0,  0,  0,  0,  0,  0, 10},
        {10,  0,  0,  0,  0,  0,  0, 10},
        {10,  0,  0,  0,  0,  0,  0, 10},
        {10,  0,  0,  0,  0,  0,  0, 10},
        {10,  0,  0,  0,  0,  0,  0, 10},
        { 0, 10, 10, 10, 10, 10, 10,  0}
    },
    // Digit 1: Central Vertical Spine (Strong center columns 3 & 4)
    {
        { 0,  0,  0, 10, 10,  0,  0,  0},
        { 0,  0, 10, 10, 10,  0,  0,  0},
        { 0,  0,  0, 10, 10,  0,  0,  0},
        { 0,  0,  0, 10, 10,  0,  0,  0},
        { 0,  0,  0, 10, 10,  0,  0,  0},
        { 0,  0,  0, 10, 10,  0,  0,  0},
        { 0,  0,  0, 10, 10,  0,  0,  0},
        { 0,  0, 10, 10, 10, 10,  0,  0}
    },
    // Digit 2: Left-Swept Diagonal & Base (Strong columns 1 & 2)
    {
        { 0, 10, 10, 10, 10,  0,  0,  0},
        { 0, 10, 10,  0,  0, 10,  0,  0},
        { 0,  0, 10, 10,  0,  0,  0,  0},
        { 0, 10, 10,  0,  0,  0,  0,  0},
        { 0, 10, 10,  0,  0,  0,  0,  0},
        { 0, 10, 10,  0,  0,  0,  0,  0},
        { 0, 10, 10,  0,  0,  0,  0,  0},
        { 0, 10, 10, 10, 10,  0,  0,  0}
    },
    // Digit 3: Right-Edge Spine & Three Bars (Strong columns 5 & 6)
    {
        { 0,  0,  0, 10, 10, 10, 10,  0},
        { 0,  0,  0,  0,  0, 10, 10,  0},
        { 0,  0,  0,  0,  0, 10, 10,  0},
        { 0,  0,  0, 10, 10, 10, 10,  0},
        { 0,  0,  0,  0,  0, 10, 10,  0},
        { 0,  0,  0,  0,  0, 10, 10,  0},
        { 0,  0,  0,  0,  0, 10, 10,  0},
        { 0,  0,  0, 10, 10, 10, 10,  0}
    }
};

// Trained Quantized INT8 Weight Matrix (8x8 = 64 Bytes in BRAM)
// Cols 0..1: Class 0 Filter | Cols 2..3: Class 1 Filter | Cols 4..5: Class 2 Filter | Cols 6..7: Class 3 Filter
static const uint8_t W_model[8][8] = {
    {10, 10,  0,  0,  0,  0,  0,  0},
    { 0,  0,  0,  0, 10, 10,  0,  0},
    { 0,  0,  0,  0, 10, 10,  0,  0},
    { 0,  0, 10, 10,  0,  0,  0,  0},
    { 0,  0, 10, 10,  0,  0,  0,  0},
    { 0,  0,  0,  0,  0,  0, 10, 10},
    { 0,  0,  0,  0,  0,  0, 10, 10},
    {10, 10,  0,  0,  0,  0,  0,  0}
};

void __attribute__((naked, section(".text.init"))) _start(void) {
    asm volatile (
        "li sp, 0x00000FF0\n\t"
        "j main\n\t"
    );
}

static inline uint32_t pack_tile_step(uint8_t a0, uint8_t b0, uint8_t a1, uint8_t b1) {
    return ((uint32_t)b1 << 24) | ((uint32_t)a1 << 16) | ((uint32_t)b0 << 8) | (uint32_t)a0;
}

int main(void) {
    // =========================================================================
    // PHASE A: Hardcoded 2x2 Systolic Hardware Benchmark (Locks 17, 23, 39, 53)
    // =========================================================================
    MMIO_COPROC_CLEAR = 1;
    MMIO_FIFO_PUSH    = 0x08040602;
    MMIO_FIFO_PUSH    = 0x07030501;
    MMIO_COPROC_START = 1;

    while ((MMIO_COPROC_STATUS & 0x01) == 0);
    MMIO_LATCH_2X2 = 1; // Locks out_00..11 (17, 23, 39, 53) onto LabVIEW Front Panel

    // =========================================================================
    // PHASE B: Software O(N^3) CPU Baseline Benchmark (Locks sw_cycles)
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

    // =========================================================================
    // PHASE C: Live 8x8 Tiled Digit Sensing Loop (64 2x2 Hardware Tile Calls)
    // =========================================================================
    uint32_t last_sel = 0xFFFFFFFF;

    while (1) {
        uint32_t sel = MMIO_DIGIT_SELECT & 0x03;
        if (sel != last_sel) {
            last_sel = sel;
            uint32_t class_scores[4] = {0, 0, 0, 0};

            // Partition 8x8 Image x 8x8 Weights into 2x2 Hardware Systolic Tiles
            for (int i = 0; i < 8; i += 2) {
                for (int j = 0; j < 8; j += 2) {
                    // Clear PE accumulators once per 2x2 output block C[i:i+2, j:j+2]
                    MMIO_COPROC_CLEAR = 1;

                    // Accumulate across k = 0, 2, 4, 6 inside the 2x2 systolic array
                    for (int k = 0; k < 8; k += 2) {
                        uint32_t step1 = pack_tile_step(
                            digits[sel][i][k+1],   W_model[k+1][j],
                            digits[sel][i+1][k+1], W_model[k+1][j+1]
                        );
                        uint32_t step2 = pack_tile_step(
                            digits[sel][i][k],     W_model[k][j],
                            digits[sel][i+1][k],   W_model[k][j+1]
                        );
                        MMIO_FIFO_PUSH    = step1;
                        MMIO_FIFO_PUSH    = step2;
                        MMIO_COPROC_START = 1;
                        while ((MMIO_COPROC_STATUS & 0x01) == 0);
                    }

                    // Pool the 2x2 hardware accumulator outputs into the class score (c = j / 2)
                    uint32_t block_sum = MMIO_OUT_00 + MMIO_OUT_01 + MMIO_OUT_10 + MMIO_OUT_11;
                    class_scores[j >> 1] += block_sum;
                }
            }

            // Argmax Classification across Classes 0, 1, 2, 3
            uint32_t best_digit = 0;
            uint32_t max_score  = class_scores[0];
            for (uint32_t c = 1; c < 4; c++) {
                if (class_scores[c] > max_score) {
                    max_score  = class_scores[c];
                    best_digit = c;
                }
            }

            // Output recognized digit to LabVIEW & Physical myRIO LED0..LED3
            MMIO_PREDICTED_DIGIT = best_digit;
        }
    }

    return 0;
}
