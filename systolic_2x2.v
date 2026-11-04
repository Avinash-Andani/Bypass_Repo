`timescale 1ns / 1ps

module systolic_2x2 #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
)(
    input  wire                  clk,
    input  wire                  rst,
    input  wire [DATA_WIDTH-1:0] a_in_0,
    input  wire [DATA_WIDTH-1:0] a_in_1,
    input  wire [DATA_WIDTH-1:0] b_in_0,
    input  wire [DATA_WIDTH-1:0] b_in_1,
    output wire [ACC_WIDTH-1:0]  mac_00,
    output wire [ACC_WIDTH-1:0]  mac_01,
    output wire [ACC_WIDTH-1:0]  mac_10,
    output wire [ACC_WIDTH-1:0]  mac_11
);

    // 1-Cycle Systolic Boundary Skew Registers for Row 1 (a_in_1) and Col 1 (b_in_1)
    reg [DATA_WIDTH-1:0] a_in_1_skew;
    reg [DATA_WIDTH-1:0] b_in_1_skew;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            a_in_1_skew <= 0;
            b_in_1_skew <= 0;
        end else begin
            a_in_1_skew <= a_in_1;
            b_in_1_skew <= b_in_1;
        end
    end

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
        .a_in(a_00_to_01), .b_in(b_in_1_skew),
        .a_out(trash_a0), .b_out(b_01_to_11),
        .mac_out(mac_01)
    );

    pe #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) pe10 (
        .clk(clk), .rst(rst),
        .a_in(a_in_1_skew), .b_in(b_00_to_10),
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