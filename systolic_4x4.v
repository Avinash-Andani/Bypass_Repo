`timescale 1ns / 1ps

module systolic_4x4 #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
)(
    input  wire                  clk,
    input  wire                  rst,
    input  wire                  clear,
    input  wire [DATA_WIDTH-1:0] a_in_0, a_in_1, a_in_2, a_in_3,
    input  wire [DATA_WIDTH-1:0] b_in_0, b_in_1, b_in_2, b_in_3,
    output wire [ACC_WIDTH-1:0]  mac_00, mac_01, mac_02, mac_03,
    output wire [ACC_WIDTH-1:0]  mac_10, mac_11, mac_12, mac_13,
    output wire [ACC_WIDTH-1:0]  mac_20, mac_21, mac_22, mac_23,
    output wire [ACC_WIDTH-1:0]  mac_30, mac_31, mac_32, mac_33
);

    // Stair-step boundary skew registers: Row/Col 1 = 1 cycle, Row/Col 2 = 2 cycles, Row/Col 3 = 3 cycles
    reg [DATA_WIDTH-1:0] a1_d1;
    reg [DATA_WIDTH-1:0] a2_d1, a2_d2;
    reg [DATA_WIDTH-1:0] a3_d1, a3_d2, a3_d3;

    reg [DATA_WIDTH-1:0] b1_d1;
    reg [DATA_WIDTH-1:0] b2_d1, b2_d2;
    reg [DATA_WIDTH-1:0] b3_d1, b3_d2, b3_d3;

    always @(posedge clk or posedge rst) begin
        if (rst || clear) begin
            a1_d1 <= 0;
            a2_d1 <= 0; a2_d2 <= 0;
            a3_d1 <= 0; a3_d2 <= 0; a3_d3 <= 0;
            b1_d1 <= 0;
            b2_d1 <= 0; b2_d2 <= 0;
            b3_d1 <= 0; b3_d2 <= 0; b3_d3 <= 0;
        end else begin
            a1_d1 <= a_in_1;
            a2_d1 <= a_in_2; a2_d2 <= a2_d1;
            a3_d1 <= a_in_3; a3_d2 <= a3_d1; a3_d3 <= a3_d2;

            b1_d1 <= b_in_1;
            b2_d1 <= b_in_2; b2_d2 <= b2_d1;
            b3_d1 <= b_in_3; b3_d2 <= b3_d1; b3_d3 <= b3_d2;
        end
    end

    wire [DATA_WIDTH-1:0] a_h [0:3][0:3];
    wire [DATA_WIDTH-1:0] b_v [0:3][0:3];

    // Row 0 PEs
    pe #(DATA_WIDTH, ACC_WIDTH) pe00 (.clk(clk), .rst(rst), .clear(clear), .a_in(a_in_0),   .b_in(b_in_0),   .a_out(a_h[0][0]), .b_out(b_v[0][0]), .mac_out(mac_00));
    pe #(DATA_WIDTH, ACC_WIDTH) pe01 (.clk(clk), .rst(rst), .clear(clear), .a_in(a_h[0][0]), .b_in(b1_d1),    .a_out(a_h[0][1]), .b_out(b_v[0][1]), .mac_out(mac_01));
    pe #(DATA_WIDTH, ACC_WIDTH) pe02 (.clk(clk), .rst(rst), .clear(clear), .a_in(a_h[0][1]), .b_in(b2_d2),    .a_out(a_h[0][2]), .b_out(b_v[0][2]), .mac_out(mac_02));
    pe #(DATA_WIDTH, ACC_WIDTH) pe03 (.clk(clk), .rst(rst), .clear(clear), .a_in(a_h[0][2]), .b_in(b3_d3),    .a_out(a_h[0][3]), .b_out(b_v[0][3]), .mac_out(mac_03));

    // Row 1 PEs
    pe #(DATA_WIDTH, ACC_WIDTH) pe10 (.clk(clk), .rst(rst), .clear(clear), .a_in(a1_d1),    .b_in(b_v[0][0]), .a_out(a_h[1][0]), .b_out(b_v[1][0]), .mac_out(mac_10));
    pe #(DATA_WIDTH, ACC_WIDTH) pe11 (.clk(clk), .rst(rst), .clear(clear), .a_in(a_h[1][0]), .b_in(b_v[0][1]), .a_out(a_h[1][1]), .b_out(b_v[1][1]), .mac_out(mac_11));
    pe #(DATA_WIDTH, ACC_WIDTH) pe12 (.clk(clk), .rst(rst), .clear(clear), .a_in(a_h[1][1]), .b_in(b_v[0][2]), .a_out(a_h[1][2]), .b_out(b_v[1][2]), .mac_out(mac_12));
    pe #(DATA_WIDTH, ACC_WIDTH) pe13 (.clk(clk), .rst(rst), .clear(clear), .a_in(a_h[1][2]), .b_in(b_v[0][3]), .a_out(a_h[1][3]), .b_out(b_v[1][3]), .mac_out(mac_13));

    // Row 2 PEs
    pe #(DATA_WIDTH, ACC_WIDTH) pe20 (.clk(clk), .rst(rst), .clear(clear), .a_in(a2_d2),    .b_in(b_v[1][0]), .a_out(a_h[2][0]), .b_out(b_v[2][0]), .mac_out(mac_20));
    pe #(DATA_WIDTH, ACC_WIDTH) pe21 (.clk(clk), .rst(rst), .clear(clear), .a_in(a_h[2][0]), .b_in(b_v[1][1]), .a_out(a_h[2][1]), .b_out(b_v[2][1]), .mac_out(mac_21));
    pe #(DATA_WIDTH, ACC_WIDTH) pe22 (.clk(clk), .rst(rst), .clear(clear), .a_in(a_h[2][1]), .b_in(b_v[1][2]), .a_out(a_h[2][2]), .b_out(b_v[2][2]), .mac_out(mac_22));
    pe #(DATA_WIDTH, ACC_WIDTH) pe23 (.clk(clk), .rst(rst), .clear(clear), .a_in(a_h[2][2]), .b_in(b_v[1][3]), .a_out(a_h[2][3]), .b_out(b_v[2][3]), .mac_out(mac_23));

    // Row 3 PEs
    pe #(DATA_WIDTH, ACC_WIDTH) pe30 (.clk(clk), .rst(rst), .clear(clear), .a_in(a3_d3),    .b_in(b_v[2][0]), .a_out(a_h[3][0]), .b_out(b_v[3][0]), .mac_out(mac_30));
    pe #(DATA_WIDTH, ACC_WIDTH) pe31 (.clk(clk), .rst(rst), .clear(clear), .a_in(a_h[3][0]), .b_in(b_v[2][1]), .a_out(a_h[3][1]), .b_out(b_v[3][1]), .mac_out(mac_31));
    pe #(DATA_WIDTH, ACC_WIDTH) pe32 (.clk(clk), .rst(rst), .clear(clear), .a_in(a_h[3][1]), .b_in(b_v[2][2]), .a_out(a_h[3][2]), .b_out(b_v[3][2]), .mac_out(mac_32));
    pe #(DATA_WIDTH, ACC_WIDTH) pe33 (.clk(clk), .rst(rst), .clear(clear), .a_in(a_h[3][2]), .b_in(b_v[2][3]), .a_out(a_h[3][3]), .b_out(b_v[3][3]), .mac_out(mac_33));

endmodule
