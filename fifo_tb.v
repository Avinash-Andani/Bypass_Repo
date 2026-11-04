`timescale 1ns / 1ps

module fifo_tb;
    reg clk, rst;
    reg wr_en, rd_en;
    reg [7:0] data_in;
    
    wire [7:0] data_out;
    wire full, empty;

    // Instantiate the FIFO
    fifo UUT (
        .clk(clk), .rst(rst),
        .wr_en(wr_en), .rd_en(rd_en), .data_in(data_in),
        .data_out(data_out), .full(full), .empty(empty)
    );

    always #5 clk = ~clk; // 10ns clock

    initial begin
        $dumpfile("fifo_wave.vcd");
        $dumpvars(0, fifo_tb);

        // 1. Reset
        clk = 0; rst = 1; wr_en = 0; rd_en = 0; data_in = 0;
        #10 rst = 0;

        // 2. CPU rapidly writes 3 numbers (e.g., 10, 20, 30)
        #10 wr_en = 1; data_in = 8'd10;
        #10 wr_en = 1; data_in = 8'd20;
        #10 wr_en = 1; data_in = 8'd30;
        
        // 3. CPU stops writing
        #10 wr_en = 0; data_in = 0;
        #20; // Wait a bit

        // 4. Systolic Array slowly reads the 3 numbers out
        #10 rd_en = 1;
        #10 rd_en = 1;
        #10 rd_en = 1;
        
        // 5. Array stops reading
        #10 rd_en = 0;
        
        #20 $finish;
    end
endmodule