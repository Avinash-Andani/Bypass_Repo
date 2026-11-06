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

// Live Output Matrix Registers for LabVIEW Front Panel & Intensity Graph
#define MMIO_LIVE_OUT_00     (*(volatile uint32_t*)0x40000020)
#define MMIO_LIVE_OUT_01     (*(volatile uint32_t*)0x40000024)
#define MMIO_LIVE_OUT_10     (*(volatile uint32_t*)0x40000028)
#define MMIO_LIVE_OUT_11     (*(volatile uint32_t*)0x4000002C)
#define MMIO_DIGIT_SELECT    (*(volatile uint32_t*)0x40000038)

// AXI4-Lite DMA Slave Registers (0x5000_0000)
#define DMA_SRC_A_ADDR       (*(volatile uint32_t*)0x50000000)
#define DMA_SRC_B_ADDR       (*(volatile uint32_t*)0x50000004)
#define DMA_DST_C_ADDR       (*(volatile uint32_t*)0x50000008)
#define DMA_CTRL_STATUS      (*(volatile uint32_t*)0x5000000C)

// 4x4 Benchmark Verification Matrices
volatile uint32_t dma_A_packed[4] = {0x01020301, 0x02010402, 0x02030101, 0x03020101};
volatile uint32_t dma_B_packed[4] = {0x02010705, 0x01020806, 0x02030101, 0x03010102};
volatile uint32_t dma_C_out[16];

volatile int32_t sw_A[4][4] = {{1,2,1,1}, {3,4,1,1}, {2,1,3,2}, {1,2,2,3}};
volatile int32_t sw_B[4][4] = {{5,7,1,2}, {6,8,2,1}, {1,1,3,2}, {2,1,1,3}};
volatile int32_t sw_C[4][4];

// Reusable BRAM Tile Buffers for 4x4 DMA Tiled 16x16 Image Inference
volatile uint32_t tile_A_buf[4];
volatile uint32_t tile_B_buf[4];
volatile uint32_t tile_C_buf[16];

// =============================================================================
// 1. TRAINED 16x16 INT8 MODEL WEIGHT / FILTER MATRIX IN BRAM (256 Bytes)
//    Cols 0..3: Class 0 Filter | Cols 4..7: Class 1 Filter
//    Cols 8..11: Class 2 Filter | Cols 12..15: Class 3 Filter
// =============================================================================
static const uint8_t W_model_16x16[16][16] = {
    {8,8,8,8, 0,0,0,0, 0,0,0,0, 0,0,0,0},
    {8,8,8,8, 0,0,0,0, 0,0,0,0, 0,0,0,0},
    {8,8,8,8, 0,0,0,0, 0,0,0,0, 0,0,0,0},
    {0,0,0,0, 0,0,0,0, 8,8,8,8, 0,0,0,0},
    {0,0,0,0, 0,0,0,0, 8,8,8,8, 0,0,0,0},
    {0,0,0,0, 0,0,0,0, 8,8,8,8, 0,0,0,0},
    {0,0,0,0, 8,8,8,8, 0,0,0,0, 0,0,0,0},
    {0,0,0,0, 8,8,8,8, 0,0,0,0, 0,0,0,0},
    {0,0,0,0, 8,8,8,8, 0,0,0,0, 0,0,0,0},
    {0,0,0,0, 8,8,8,8, 0,0,0,0, 0,0,0,0},
    {0,0,0,0, 0,0,0,0, 0,0,0,0, 8,8,8,8},
    {0,0,0,0, 0,0,0,0, 0,0,0,0, 8,8,8,8},
    {0,0,0,0, 0,0,0,0, 0,0,0,0, 8,8,8,8},
    {8,8,8,8, 0,0,0,0, 0,0,0,0, 0,0,0,0},
    {8,8,8,8, 0,0,0,0, 0,0,0,0, 0,0,0,0},
    {8,8,8,8, 0,0,0,0, 0,0,0,0, 0,0,0,0}
};

// =============================================================================
// 2. PREBUILT 4-IMAGE 16x16 INT8 TEST BANK IN BRAM (4 x 256 = 1,024 Bytes)
//    (Can be replaced with any 4 user images via convert_images_to_c.py)
// =============================================================================
static const uint8_t test_images[4][16][16] = {
    // Test Image 0 (digit_sel = 0): Outer Perimeter Ring / Class 0 Pattern
    {
        {10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10},
        {10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10},
        {10,10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,10,10},
        {10,10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,10,10},
        {10,10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,10,10},
        {10,10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,10,10},
        {10,10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,10,10},
        {10,10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,10,10},
        {10,10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,10,10},
        {10,10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,10,10},
        {10,10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,10,10},
        {10,10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,10,10},
        {10,10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,10,10},
        {10,10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,10,10},
        {10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10},
        {10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10}
    },
    // Test Image 1 (digit_sel = 1): Central Vertical Core / Class 1 Pattern
    {
        { 0, 0, 0, 0, 0, 0,12,12,12,12, 0, 0, 0, 0, 0, 0},
        { 0, 0, 0, 0, 0, 0,12,12,12,12, 0, 0, 0, 0, 0, 0},
        { 0, 0, 0, 0, 0, 0,12,12,12,12, 0, 0, 0, 0, 0, 0},
        { 0, 0, 0, 0, 0, 0,12,12,12,12, 0, 0, 0, 0, 0, 0},
        { 0, 0, 0, 0, 0, 0,12,12,12,12, 0, 0, 0, 0, 0, 0},
        { 0, 0, 0, 0, 0, 0,12,12,12,12, 0, 0, 0, 0, 0, 0},
        { 0, 0, 0, 0, 0,12,12,12,12,12,12, 0, 0, 0, 0, 0},
        { 0, 0, 0, 0, 0,12,12,12,12,12,12, 0, 0, 0, 0, 0},
        { 0, 0, 0, 0, 0,12,12,12,12,12,12, 0, 0, 0, 0, 0},
        { 0, 0, 0, 0, 0,12,12,12,12,12,12, 0, 0, 0, 0, 0},
        { 0, 0, 0, 0, 0, 0,12,12,12,12, 0, 0, 0, 0, 0, 0},
        { 0, 0, 0, 0, 0, 0,12,12,12,12, 0, 0, 0, 0, 0, 0},
        { 0, 0, 0, 0, 0, 0,12,12,12,12, 0, 0, 0, 0, 0, 0},
        { 0, 0, 0, 0, 0, 0,12,12,12,12, 0, 0, 0, 0, 0, 0},
        { 0, 0, 0, 0, 0, 0,12,12,12,12, 0, 0, 0, 0, 0, 0},
        { 0, 0, 0, 0, 0, 0,12,12,12,12, 0, 0, 0, 0, 0, 0}
    },
    // Test Image 2 (digit_sel = 2): Upper-Left Diagonal Band / Class 2 Pattern
    {
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        { 0, 0,12,12,12,12, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        { 0, 0,12,12,12,12,12,12,12,12,12,12, 0, 0, 0, 0},
        { 0, 0,12,12,12,12,12,12,12,12,12,12, 0, 0, 0, 0},
        { 0, 0,12,12,12,12,12,12,12,12,12,12, 0, 0, 0, 0},
        { 0, 0, 0, 0,12,12,12,12, 0, 0, 0, 0, 0, 0, 0, 0},
        { 0, 0, 0, 0,12,12, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
    },
    // Test Image 3 (digit_sel = 3): Lower-Right Quadrant & Trace / Class 3 Pattern
    {
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,12,12,12,12, 0, 0},
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,12,12,12,12, 0, 0},
        { 0, 0, 0, 0,12,12,12,12,12,12,12,12,12,12,12,12},
        { 0, 0, 0, 0,12,12,12,12,12,12,12,12,12,12,12,12},
        { 0, 0, 0, 0,12,12,12,12,12,12,12,12,12,12,12,12},
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,12,12,12,12, 0, 0},
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
    }
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
    // PHASE A & B: Core 4x4 MMIO & AXI4-Lite DMA Cycle Benchmark
    // =========================================================================
    MMIO_COPROC_CLEAR = 0x03;
    for (int k = 0; k < 4; k++) {
        MMIO_PACKED_A      = dma_A_packed[k];
        MMIO_PACKED_B_PUSH = dma_B_packed[k];
    }
    MMIO_COPROC_START = 1;
    while ((MMIO_COPROC_STATUS & 0x01) == 0);

    DMA_SRC_A_ADDR  = (uint32_t)dma_A_packed;
    DMA_SRC_B_ADDR  = (uint32_t)dma_B_packed;
    DMA_DST_C_ADDR  = (uint32_t)dma_C_out;
    DMA_CTRL_STATUS = 0x07;
    while ((DMA_CTRL_STATUS & 0x01) == 0);

    MMIO_LATCH_TOP2X2 = 1;

    // =========================================================================
    // PHASE C: 4x4 Software O(N^3) CPU Baseline Benchmark
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
    // PHASE D: Live 16x16 Prebuilt Image x 16x16 Model Matrix Multiplication
    //          (64 Autonomous 4x4 AXI4-Lite DMA Bursts per Selected Image)
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

            // Multiply 16x16 Image[sel] x 16x16 W_model using 4x4 Hardware DMA Tiles
            for (int i = 0; i < 16; i += 4) {
                for (int j = 0; j < 16; j += 4) {
                    for (int k = 0; k < 16; k += 4) {
                        for (int step = 0; step < 4; step++) {
                            tile_A_buf[step] = pack4(
                                test_images[sel][i+0][k+step],
                                test_images[sel][i+1][k+step],
                                test_images[sel][i+2][k+step],
                                test_images[sel][i+3][k+step]
                            );
                            tile_B_buf[step] = pack4(
                                W_model_16x16[k+step][j+0],
                                W_model_16x16[k+step][j+1],
                                W_model_16x16[k+step][j+2],
                                W_model_16x16[k+step][j+3]
                            );
                        }
                        // k==0: Clear & burst (0x05). k==12: Accumulate & Writeback 16 words (0x03). Otherwise: Accumulate (0x01).
                        if (k == 0)
                            DMA_CTRL_STATUS = 0x05;
                        else if (k == 12)
                            DMA_CTRL_STATUS = 0x03;
                        else
                            DMA_CTRL_STATUS = 0x01;

                        while ((DMA_CTRL_STATUS & 0x01) == 0);
                    }

                    // Pool the 16 32-bit hardware MAC outputs of C[i:i+4, j:j+4] into class quadrant (j / 4)
                    uint32_t tile_energy = 0;
                    for (int idx = 0; idx < 16; idx++) {
                        tile_energy += tile_C_buf[idx];
                    }
                    class_scores[j >> 2] += tile_energy;
                }
            }

            // Stream the 4 Spatial Feature Matrix Quadrants to LabVIEW Front Panel & Intensity Graph!
            // (For digit_sel == 0, out_00 has max energy; for digit_sel == 1, out_01; for 2, out_10; for 3, out_11)
            MMIO_LIVE_OUT_00 = class_scores[0];
            MMIO_LIVE_OUT_01 = class_scores[1];
            MMIO_LIVE_OUT_10 = class_scores[2];
            MMIO_LIVE_OUT_11 = class_scores[3];

            // Argmax Classification across the 4 Output Matrix Quadrants
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
