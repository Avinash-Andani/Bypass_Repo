#include <stdint.h>

// Coprocessor & Telemetry MMIO Registers (0x4000_0000)
#define MMIO_PACKED_A        (*(volatile uint32_t*)0x40000000)
#define MMIO_PACKED_B_PUSH   (*(volatile uint32_t*)0x40000004)
#define MMIO_COPROC_START    (*(volatile uint32_t*)0x40000008)
#define MMIO_COPROC_STATUS   (*(volatile uint32_t*)0x40000008)
#define MMIO_COPROC_CLEAR    (*(volatile uint32_t*)0x4000000C)
#define MMIO_LATCH_TOP2X2    (*(volatile uint32_t*)0x40000010)
#define MMIO_SW_TIMER_START  (*(volatile uint32_t*)0x40000014)
#define MMIO_SW_TIMER_STOP   (*(volatile uint32_t*)0x40000018)
#define MMIO_PREDICTED_DIGIT (*(volatile uint32_t*)0x4000001C)
#define MMIO_DIGIT_SELECT    (*(volatile uint32_t*)0x40000038)

// AXI4-Lite DMA Slave Registers (0x5000_0000)
#define DMA_SRC_A_ADDR       (*(volatile uint32_t*)0x50000000)
#define DMA_SRC_B_ADDR       (*(volatile uint32_t*)0x50000004)
#define DMA_DST_C_ADDR       (*(volatile uint32_t*)0x50000008)
#define DMA_CTRL_STATUS      (*(volatile uint32_t*)0x5000000C)

// 4x4 Benchmark Matrices in BRAM:
// A = [[1, 2, 1, 1], [3, 4, 1, 1], [2, 1, 3, 2], [1, 2, 2, 3]]
// B = [[5, 7, 1, 2], [6, 8, 2, 1], [1, 1, 3, 2], [2, 1, 1, 3]]
// Packed Column Vectors of A: {A[3][k], A[2][k], A[1][k], A[0][k]} for k = 0..3
volatile uint32_t dma_A_packed[4] = {
    0x01020301, // k=0: {1, 2, 3, 1}
    0x02010402, // k=1: {2, 1, 4, 2}
    0x02030101, // k=2: {2, 3, 1, 1}
    0x03020101  // k=3: {3, 2, 1, 1}
};

// Packed Row Vectors of B: {B[k][3], B[k][2], B[k][1], B[k][0]} for k = 0..3
volatile uint32_t dma_B_packed[4] = {
    0x02010705, // k=0: {2, 1, 7, 5}
    0x01020806, // k=1: {1, 2, 8, 6}
    0x02030101, // k=2: {2, 3, 1, 1}
    0x03010102  // k=3: {3, 1, 1, 2}
};

// Destination BRAM Buffer for DMA 16-Word Hardware Writeback (Golden: 20,25,9,9 / 42,55,15,15 / 23,27,15,17 / 25,28,14,17)
volatile uint32_t dma_C_out[16];

// Software Baseline 4x4 Matrices
volatile int32_t sw_A[4][4] = {{1,2,1,1}, {3,4,1,1}, {2,1,3,2}, {1,2,2,3}};
volatile int32_t sw_B[4][4] = {{5,7,1,2}, {6,8,2,1}, {1,1,3,2}, {2,1,1,3}};
volatile int32_t sw_C[4][4];

// Reusable BRAM Tile Buffers for 4x4 DMA Tiled 8x8 Digit Inference
volatile uint32_t tile_A_buf[4];
volatile uint32_t tile_B_buf[4];
volatile uint32_t tile_C_buf[16];

// 4 Test Digit Images (8x8 INT8 = 256 Bytes)
static const uint8_t digits[4][8][8] = {
    { // Digit 0: Hollow Ring (Strong cols 0 & 7)
        { 0, 10, 10, 10, 10, 10, 10,  0},
        {10,  0,  0,  0,  0,  0,  0, 10},
        {10,  0,  0,  0,  0,  0,  0, 10},
        {10,  0,  0,  0,  0,  0,  0, 10},
        {10,  0,  0,  0,  0,  0,  0, 10},
        {10,  0,  0,  0,  0,  0,  0, 10},
        {10,  0,  0,  0,  0,  0,  0, 10},
        { 0, 10, 10, 10, 10, 10, 10,  0}
    },
    { // Digit 1: Central Vertical Spine (Strong cols 3 & 4)
        { 0,  0,  0, 10, 10,  0,  0,  0},
        { 0,  0, 10, 10, 10,  0,  0,  0},
        { 0,  0,  0, 10, 10,  0,  0,  0},
        { 0,  0,  0, 10, 10,  0,  0,  0},
        { 0,  0,  0, 10, 10,  0,  0,  0},
        { 0,  0,  0, 10, 10,  0,  0,  0},
        { 0,  0,  0, 10, 10,  0,  0,  0},
        { 0,  0, 10, 10, 10, 10,  0,  0}
    },
    { // Digit 2: Left-Swept Diagonal & Base (Strong cols 1 & 2)
        { 0, 10, 10, 10, 10,  0,  0,  0},
        { 0, 10, 10,  0,  0, 10,  0,  0},
        { 0,  0, 10, 10,  0,  0,  0,  0},
        { 0, 10, 10,  0,  0,  0,  0,  0},
        { 0, 10, 10,  0,  0,  0,  0,  0},
        { 0, 10, 10,  0,  0,  0,  0,  0},
        { 0, 10, 10,  0,  0,  0,  0,  0},
        { 0, 10, 10, 10, 10,  0,  0,  0}
    },
    { // Digit 3: Right-Edge Spine (Strong cols 5 & 6)
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

// Trained Quantized INT8 Weight Matrix (8x8 = 64 Bytes)
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

static inline uint32_t pack4(uint8_t x0, uint8_t x1, uint8_t x2, uint8_t x3) {
    return ((uint32_t)x3 << 24) | ((uint32_t)x2 << 16) | ((uint32_t)x1 << 8) | (uint32_t)x0;
}

int main(void) {
    // =========================================================================
    // PHASE A: 4x4 CPU-MMIO Benchmark (Exposes CPU Data-Feeding Bottleneck)
    // =========================================================================
    MMIO_COPROC_CLEAR = 0x03; // Clear accumulators + Start MMIO Cycle Counter
    for (int k = 0; k < 4; k++) {
        MMIO_PACKED_A      = dma_A_packed[k];
        MMIO_PACKED_B_PUSH = dma_B_packed[k];
    }
    MMIO_COPROC_START = 1;
    while ((MMIO_COPROC_STATUS & 0x01) == 0);

    // =========================================================================
    // PHASE B: 4x4 AXI4-Lite DMA Burst Benchmark (Autonomous Read + Compute + Writeback)
    // =========================================================================
    DMA_SRC_A_ADDR  = (uint32_t)dma_A_packed;
    DMA_SRC_B_ADDR  = (uint32_t)dma_B_packed;
    DMA_DST_C_ADDR  = (uint32_t)dma_C_out;
    DMA_CTRL_STATUS = 0x07; // Bit 0=Start, Bit 1=Writeback 16 words, Bit 2=Clear Accumulators
    while ((DMA_CTRL_STATUS & 0x01) == 0);

    // Latch top-left 2x2 block (20, 25, 42, 55) onto LabVIEW Front Panel pins
    MMIO_LATCH_TOP2X2 = 1;

    // =========================================================================
    // PHASE C: 4x4 Software O(N^3) CPU Baseline Benchmark (64 MACs in Software)
    // =========================================================================
    MMIO_SW_TIMER_START = 1;
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
            int32_t acc = 0;
            for (int k = 0; k < 4; k++) {
                acc += sw_A[i][k] * sw_B[k][j];
            }
            sw_C[i][j] = acc;
        }
    }
    MMIO_SW_TIMER_STOP = 1;

    // =========================================================================
    // PHASE D: Live 8x8 Tiled Digit Sensing via 8 Autonomous 4x4 DMA Bursts
    // =========================================================================
    DMA_SRC_A_ADDR = (uint32_t)tile_A_buf;
    DMA_SRC_B_ADDR = (uint32_t)tile_B_buf;
    DMA_DST_C_ADDR = (uint32_t)tile_C_buf;

    uint32_t last_sel = 0xFFFFFFFF;

    while (1) {
        uint32_t sel = MMIO_DIGIT_SELECT & 0x03;
        if (sel != last_sel) {
            last_sel = sel;
            uint32_t class_scores[4] = {0, 0, 0, 0};

            // Partition 8x8 Image x 8x8 Weights into 8 4x4 Hardware DMA Tiles
            for (int i = 0; i < 8; i += 4) {
                for (int j = 0; j < 8; j += 4) {
                    for (int k = 0; k < 8; k += 4) {
                        for (int step = 0; step < 4; step++) {
                            tile_A_buf[step] = pack4(
                                digits[sel][i+0][k+step],
                                digits[sel][i+1][k+step],
                                digits[sel][i+2][k+step],
                                digits[sel][i+3][k+step]
                            );
                            tile_B_buf[step] = pack4(
                                W_model[k+step][j+0],
                                W_model[k+step][j+1],
                                W_model[k+step][j+2],
                                W_model[k+step][j+3]
                            );
                        }
                        // On k==0: Clear accumulators & burst (0x05). On k==4: Accumulate & Writeback 16 words (0x03).
                        DMA_CTRL_STATUS = (k == 0) ? 0x05 : 0x03;
                        while ((DMA_CTRL_STATUS & 0x01) == 0);
                    }

                    // Pool the 16 DMA-written output words in tile_C_buf[0..15] into class_scores
                    uint32_t col_pair_0 = 0;
                    uint32_t col_pair_1 = 0;
                    for (int r = 0; r < 4; r++) {
                        col_pair_0 += tile_C_buf[r*4 + 0] + tile_C_buf[r*4 + 1];
                        col_pair_1 += tile_C_buf[r*4 + 2] + tile_C_buf[r*4 + 3];
                    }
                    class_scores[(j >> 1) + 0] += col_pair_0;
                    class_scores[(j >> 1) + 1] += col_pair_1;
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

            MMIO_PREDICTED_DIGIT = best_digit;
        }
    }

    return 0;
}
