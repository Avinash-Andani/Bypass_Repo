module systolic_2x2 #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
)(
    input clk,
    input rst,
    input [DATA_WIDTH-1:0] a_in_0, a_in_1,  
    input [DATA_WIDTH-1:0] b_in_0, b_in_1,  
    output [ACC_WIDTH-1:0] mac_00, mac_01, mac_10, mac_11 
);

    wire [DATA_WIDTH-1:0] a_00_to_01, a_10_to_11;
    wire [DATA_WIDTH-1:0] b_00_to_10, b_01_to_11;
    wire [DATA_WIDTH-1:0] trash_a0, trash_a1, trash_b0, trash_b1;

    pe #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) pe00 (
        .clk(clk), .rst(rst),
        .a_in(a_in_0), .b_in(b_in_0),
        .a_out(a_00_to_01), .b_out(b_00_to_10),
        .mac_out(mac_00)
    );

    pe #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) pe01 (
        .clk(clk), .rst(rst),
        .a_in(a_00_to_01), .b_in(b_in_1), 
        .a_out(trash_a0), .b_out(b_01_to_11),
        .mac_out(mac_01)
    );

    pe #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) pe10 (
        .clk(clk), .rst(rst),
        .a_in(a_in_1), .b_in(b_00_to_10), 
        .a_out(a_10_to_11), .b_out(trash_b0),
        .mac_out(mac_10)
    );

    pe #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) pe11 (
        .clk(clk), .rst(rst),
        .a_in(a_10_to_11), .b_in(b_01_to_11),
        .a_out(trash_a1), .b_out(trash_b1),
        .mac_out(mac_11)
    );

endmodule