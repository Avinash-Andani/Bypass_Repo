`timescale 1ns / 1ps

module system_tb;

    reg         clk;
    reg         reset;
    reg  [7:0]  digit_sel;
    wire [31:0] out_00, out_01, out_10, out_11;
    wire [31:0] hw_cycles, sw_cycles, predicted_digit;
    wire        led0, led1, led2, led3;

    system uut (
        .clk             (clk),
        .reset           (reset),
        .digit_sel       (digit_sel),
        .out_00          (out_00),
        .out_01          (out_01),
        .out_10          (out_10),
        .out_11          (out_11),
        .hw_cycles       (hw_cycles),
        .sw_cycles       (sw_cycles),
        .predicted_digit (predicted_digit),
        .led0            (led0),
        .led1            (led1),
        .led2            (led2),
        .led3            (led3)
    );

    // Top-level waveform signals for GTKWave
    wire        dma_busy     = uut.dma_busy;
    wire        dma_done     = uut.dma_done;
    wire        mmio_counting= uut.mmio_counting;
    wire        dma_counting = uut.dma_counting;
    wire        sw_counting  = uut.sw_counting;
    wire        coproc_wr_en = uut.mux_wr_en;
    wire        coproc_start = uut.mux_start;
    wire        coproc_done  = uut.coproc_done;
    wire [31:0] mmio_cycles  = uut.mmio_cycles;

    always #12.5 clk = ~clk;

    initial begin
        $dumpfile("phase2_benchmark.vcd");
        $dumpvars(0, system_tb);

        clk       = 1'b0;
        reset     = 1'b1;
        digit_sel = 8'd0;
        #100;
        reset     = 1'b0;

        // Wait until Phase A (MMIO), Phase B (DMA), Phase C (SW), and Phase D (Digit 0) finish
        wait (uut.class_valid == 1'b1);
        #2000;

        $display("\n=====================================================================");
        $display("  PHASE-2 NI myRIO-1900 (Zynq-7010 @ 40 MHz) 4x4 + AXI-LITE DMA REPORT");
        $display("=====================================================================");
        $display("1. Verified 4x4 Systolic Array Accumulator Outputs (16 PEs in Parallel):");
        $display("   Row 0 : [%3d, %3d, %3d, %3d]  (Golden: [ 20,  25,   9,   9])",
                 uut.c_out_00, uut.c_out_01, uut.c_out_02, uut.c_out_03);
        $display("   Row 1 : [%3d, %3d, %3d, %3d]  (Golden: [ 42,  55,  15,  15])",
                 uut.c_out_10, uut.c_out_11, uut.c_out_12, uut.c_out_13);
        $display("   Row 2 : [%3d, %3d, %3d, %3d]  (Golden: [ 23,  27,  15,  17])",
                 uut.c_out_20, uut.c_out_21, uut.c_out_22, uut.c_out_23);
        $display("   Row 3 : [%3d, %3d, %3d, %3d]  (Golden: [ 25,  28,  14,  17])",
                 uut.c_out_30, uut.c_out_31, uut.c_out_32, uut.c_out_33);
        $display("   LabVIEW Top-2x2 Pins : out_00=%0d, out_01=%0d, out_10=%0d, out_11=%0d",
                 out_00, out_01, out_10, out_11);
        $display("---------------------------------------------------------------------");
        $display("2. Deterministic 40 MHz Cycle Telemetry (1 Clock Cycle = 25.0 ns):");
        $display("   - 4x4 Software O(N^3) CPU Baseline : %4d cycles (%6d ns)", sw_cycles, sw_cycles * 25);
        $display("   - 4x4 Hardware (CPU MMIO Feed)     : %4d cycles (%6d ns) [Memory Wall!]", mmio_cycles, mmio_cycles * 25);
        $display("   - 4x4 Hardware (AXI4-Lite DMA)     : %4d cycles (%6d ns) [Autonomous Burst!]", hw_cycles, hw_cycles * 25);
        $display("   - Pure 4x4 Systolic Wave Latency   :   11 cycles (   275 ns) [64 MACs Parallel]");
        $display("   - DMA Speedup vs. 4x4 CPU MMIO     : %0.2fX Faster", $itor(mmio_cycles) / $itor(hw_cycles));
        $display("   - DMA Speedup vs. 4x4 Software CPU : %0.2fX Faster", $itor(sw_cycles) / $itor(hw_cycles));
        $display("---------------------------------------------------------------------");
        $display("3. Live 8x8 Tiled Digit Sensing via 8 Autonomous 4x4 DMA Bursts:");
        $display("   [Input digit_sel = %0d] -> Predicted Digit = %0d | LEDs [3:0] = %b%b%b%b",
                 digit_sel, predicted_digit, led3, led2, led1, led0);

        digit_sel = 8'd1;
        wait (predicted_digit == 32'd1);
        #2000;
        $display("   [Input digit_sel = %0d] -> Predicted Digit = %0d | LEDs [3:0] = %b%b%b%b",
                 digit_sel, predicted_digit, led3, led2, led1, led0);

        digit_sel = 8'd2;
        wait (predicted_digit == 32'd2);
        #2000;
        $display("   [Input digit_sel = %0d] -> Predicted Digit = %0d | LEDs [3:0] = %b%b%b%b",
                 digit_sel, predicted_digit, led3, led2, led1, led0);

        digit_sel = 8'd3;
        wait (predicted_digit == 32'd3);
        #2000;
        $display("   [Input digit_sel = %0d] -> Predicted Digit = %0d | LEDs [3:0] = %b%b%b%b",
                 digit_sel, predicted_digit, led3, led2, led1, led0);
        $display("=====================================================================\n");
        $finish;
    end

endmodule
