`timescale 1ns / 1ps

module coprocessor_tb;
    reg clk, rst, start, wr_en;
    reg [7:0] a0, a1, b0, b1;
    wire done;
    wire [31:0] out_00, out_01, out_10, out_11;

    // Instantiate the complete Coprocessor
    coprocessor UUT (
        .clk(clk), .rst(rst), .start(start), .wr_en(wr_en), .done(done),
        .a_in_0(a0), .a_in_1(a1), .b_in_0(b0), .b_in_1(b1),
        .out_00(out_00), .out_01(out_01), .out_10(out_10), .out_11(out_11)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("coprocessor_wave.vcd");
        $dumpvars(0, coprocessor_tb);

        // 1. Reset
        clk = 0; rst = 1; start = 0; wr_en = 0;
        a0=0; a1=0; b0=0; b1=0;
        #10 rst = 0;

        // 2. CPU writes staggered data to FIFOs
        #10 wr_en = 1; a0=2; b0=2; a1=0; b1=0;
        #10 wr_en = 1; a0=3; b0=3; a1=4; b1=4;
        #10 wr_en = 0; a0=0; b0=0; a1=0; b1=0; // Stop writing

        // 3. CPU tells Coprocessor to Start!
        #10 start = 1;
        #10 start = 0;

        // 4. Wait for the 'done' flag
        wait(done == 1);
        
        // Let it run for just a few more nanoseconds so we can see the answer
        #20 $finish; 
    end
endmodule