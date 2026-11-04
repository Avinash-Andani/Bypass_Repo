`timescale 1ns / 1ps
module pe_tb;
    reg clk, rst;
    reg [7:0] a_in, b_in;
    wire [7:0] a_out, b_out;
    wire [31:0] mac_out;
    pe UUT (.clk(clk),.rst(rst),.a_in(a_in),.b_in(b_in),.a_out(a_out),.b_out(b_out),.mac_out(mac_out));
    // Generate a clock (10ns period)
    always #5 clk = ~clk;
    initial 
    begin
        // Setup GTKWave output
        $dumpfile("pe_wave.vcd");
        $dumpvars(0, pe_tb);

        // 1. Reset the system
        clk = 0; rst = 1; a_in = 0; b_in = 0;
        #10 rst = 0;

        // 2. Feed it Data: 2 x 3
        #10 a_in = 2; b_in = 3;
        
        // 3. Feed it Data: 4 x 5
        #10 a_in = 4; b_in = 5;

        // 4. Feed it Zeros (to let the pipeline flush)
        #10 a_in = 0; b_in = 0;

        // 5. Wait and finish
        #30 $finish;
    end
endmodule