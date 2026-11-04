`timescale 1ns / 1ps
module systolic_2x2_tb;
    reg clk, rst;
    reg [7:0] a_in_0, a_in_1;
    reg [7:0] b_in_0, b_in_1;

    wire [31:0] mac_00, mac_01, mac_10, mac_11;

    // Instantiate the 2x2 Array
    systolic_2x2 UUT (
        .clk(clk), .rst(rst),
        .a_in_0(a_in_0), .a_in_1(a_in_1),
        .b_in_0(b_in_0), .b_in_1(b_in_1),
        .mac_00(mac_00), .mac_01(mac_01), .mac_10(mac_10), .mac_11(mac_11)
    );

    always #5 clk = ~clk; // 10ns clock period

    initial begin
        $dumpfile("array_wave.vcd");
        $dumpvars(0, systolic_2x2_tb);

        // 1. Reset everything
        clk = 0; rst = 1; 
        a_in_0 = 0; a_in_1 = 0; 
        b_in_0 = 0; b_in_1 = 0;
        #10 rst = 0;

        // 2. Cycle 1: Feed Top-Left PE
        #10 a_in_0 = 2; b_in_0 = 2; 
            a_in_1 = 0; b_in_1 = 0;

        // 3. Cycle 2: Feed Bottom-Left and Top-Right, keep feeding Top-Left
        #10 a_in_0 = 3; b_in_0 = 3; 
            a_in_1 = 4; b_in_1 = 4;

        // 4. Cycle 3: Flush with zeros to let the data cascade through
        #10 a_in_0 = 0; b_in_0 = 0;
            a_in_1 = 0; b_in_1 = 0;

        // 5. Wait for the final math to finish
        #40 $finish;
    end
endmodule