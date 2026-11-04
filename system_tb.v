`timescale 1ns / 1ps

module system_tb;

    reg         clk;
    reg         reset;
    wire [31:0] out_00, out_01, out_10, out_11;
    wire [31:0] hw_cycles, sw_cycles;
    wire        led0, led1;

    // Instantiate Top-Level SoC
    system uut (
        .clk       (clk),
        .reset     (reset),
        .out_00    (out_00),
        .out_01    (out_01),
        .out_10    (out_10),
        .out_11    (out_11),
        .hw_cycles (hw_cycles),
        .sw_cycles (sw_cycles),
        .led0      (led0),
        .led1      (led1)
    );

    // Expose key internal signals at top-level so they appear directly in GTKWave
    wire        hw_counting  = uut.hw_counting;
    wire        sw_counting  = uut.sw_counting;
    wire        coproc_wr_en = uut.coproc_wr_en;
    wire        coproc_start = uut.coproc_start;
    wire        coproc_done  = uut.coproc_done;
    wire [31:0] mem_addr     = uut.mem_addr;

    // 40 MHz Clock (25 ns period -> toggle every 12.5 ns)
    always #12.5 clk = ~clk;

    initial begin
        $dumpfile("phase2_benchmark.vcd");
        $dumpvars(0, system_tb);

        clk   = 1'b0;
        reset = 1'b1;
        #100;
        reset = 1'b0;

        // Wait for both HW (led0) and SW (led1) benchmarks to finish
        wait (led0 == 1'b1 && led1 == 1'b1);

        // Hold for 5,000 ns (5 us) so sw_cycles and led1 are wide and clear in GTKWave!
        #5000;

        $display("\n=======================================================");
        $display("   NI myRIO-1900 (Zynq-7010 @ 40 MHz) BENCHMARK REPORT ");
        $display("=======================================================");
        $display("Systolic Array Outputs (Golden: 17, 23, 39, 53):");
        $display("  out_00 : %0d (0x%02h)", out_00, out_00);
        $display("  out_01 : %0d (0x%02h)", out_01, out_01);
        $display("  out_10 : %0d (0x%02h)", out_10, out_10);
        $display("  out_11 : %0d (0x%02h)", out_11, out_11);
        $display("-------------------------------------------------------");
        $display("Deterministic Cycle Telemetry (1 Cycle = 25 ns):");
        $display("  Hardware Execution : %0d cycles (%0d ns)", hw_cycles, hw_cycles * 25);
        $display("  Software Execution : %0d cycles (%0d ns)", sw_cycles, sw_cycles * 25);
        if (hw_cycles > 0)
            $display("  Measured Speedup   : %0.2fX Faster in Hardware", $itor(sw_cycles) / $itor(hw_cycles));
        $display("=======================================================\n");
        $finish;
    end

endmodule