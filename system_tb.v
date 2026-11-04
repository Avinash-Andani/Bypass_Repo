`timescale 1ns / 1ps

module system_tb;

    reg         clk;
    reg         reset;
    wire [31:0] out_00, out_01, out_10, out_11;
    wire [31:0] hw_cycles, sw_cycles;
    wire        led0, led1;

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

    always #12.5 clk = ~clk;

    initial begin
        $dumpfile("phase2_benchmark.vcd");
        $dumpvars(0, system_tb);

        clk   = 1'b0;
        reset = 1'b1;
        #100;
        reset = 1'b0;

        wait (led0 == 1'b1 && led1 == 1'b1);
        #100;

        $display("\n=======================================================");
        $display("   NI myRIO-1900 (Zynq-7010 @ 40 MHz) BENCHMARK REPORT ");
        $display("=======================================================");
        $display("Systolic Array Outputs:");
        $display("  out_00 : %0d", out_00);
        $display("  out_01 : %0d", out_01);
        $display("  out_10 : %0d", out_10);
        $display("  out_11 : %0d", out_11);
        $display("-------------------------------------------------------");
        $display("Deterministic Cycle Telemetry (1 Cycle = 25 ns):");
        $display("  Hardware Execution : %0d cycles (%0d ns)", hw_cycles, hw_cycles * 25);
        $display("  Software Execution : %0d cycles (%0d ns)", sw_cycles, sw_cycles * 25);
        if (hw_cycles > 0)
            $display("  Measured Speedup   : %0.2fX", $itor(sw_cycles) / $itor(hw_cycles));
        $display("=======================================================\n");
        $finish;
    end

endmodule