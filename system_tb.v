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

    // Top-level debug aliases for GTKWave
    wire        hw_counting  = uut.hw_counting;
    wire        sw_counting  = uut.sw_counting;
    wire        coproc_wr_en = uut.coproc_wr_en;
    wire        coproc_start = uut.coproc_start;
    wire        coproc_done  = uut.coproc_done;

    always #12.5 clk = ~clk;

    initial begin
        $dumpfile("phase2_benchmark.vcd");
        $dumpvars(0, system_tb);

        clk       = 1'b0;
        reset     = 1'b1;
        digit_sel = 8'd0;
        #100;
        reset     = 1'b0;

        // 1. Wait for Digit 0 inference to complete (class_valid == 1)
        wait (uut.class_valid == 1'b1);
        #2000;
        $display("\n=======================================================");
        $display("   NI myRIO-1900 (Zynq-7010 @ 40 MHz) BENCHMARK REPORT ");
        $display("=======================================================");
        $display("1. Hardcoded 2x2 Systolic Array Outputs (Golden: 17, 23, 39, 53):");
        $display("   out_00 : %0d | out_01 : %0d | out_10 : %0d | out_11 : %0d", out_00, out_01, out_10, out_11);
        $display("-------------------------------------------------------");
        $display("2. Deterministic 40 MHz Cycle Telemetry (1 Cycle = 25 ns):");
        $display("   Hardware Execution : %0d cycles (%0d ns)", hw_cycles, hw_cycles * 25);
        $display("   Software Execution : %0d cycles (%0d ns)", sw_cycles, sw_cycles * 25);
        $display("   Measured Speedup   : %0.2fX Faster in Hardware", $itor(sw_cycles) / $itor(hw_cycles));
        $display("-------------------------------------------------------");
        $display("3. Live 8x8 Tiled Edge-AI Digit Sensing (64 2x2 Tiles/Image):");
        $display("   [Input digit_sel = %0d] -> Predicted Digit = %0d | LEDs [3:0] = %b%b%b%b",
                 digit_sel, predicted_digit, led3, led2, led1, led0);

        // 2. Switch to Digit 1
        digit_sel = 8'd1;
        wait (predicted_digit == 32'd1);
        #2000;
        $display("   [Input digit_sel = %0d] -> Predicted Digit = %0d | LEDs [3:0] = %b%b%b%b",
                 digit_sel, predicted_digit, led3, led2, led1, led0);

        // 3. Switch to Digit 2
        digit_sel = 8'd2;
        wait (predicted_digit == 32'd2);
        #2000;
        $display("   [Input digit_sel = %0d] -> Predicted Digit = %0d | LEDs [3:0] = %b%b%b%b",
                 digit_sel, predicted_digit, led3, led2, led1, led0);

        // 4. Switch to Digit 3
        digit_sel = 8'd3;
        wait (predicted_digit == 32'd3);
        #2000;
        $display("   [Input digit_sel = %0d] -> Predicted Digit = %0d | LEDs [3:0] = %b%b%b%b",
                 digit_sel, predicted_digit, led3, led2, led1, led0);
        $display("=======================================================\n");
        $finish;
    end

endmodule
