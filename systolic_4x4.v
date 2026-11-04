module systolic_4x4 #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
)(
    input clk,
    input rst,
    
    // 4 inputs on the Left side
    input [DATA_WIDTH-1:0] a_in_0, a_in_1, a_in_2, a_in_3,
    // 4 inputs on the Top side
    input [DATA_WIDTH-1:0] b_in_0, b_in_1, b_in_2, b_in_3,
    
    // 16 final accumulator answers
    output [ACC_WIDTH-1:0] mac_00, mac_01, mac_02, mac_03,
    output [ACC_WIDTH-1:0] mac_10, mac_11, mac_12, mac_13,
    output [ACC_WIDTH-1:0] mac_20, mac_21, mac_22, mac_23,
    output [ACC_WIDTH-1:0] mac_30, mac_31, mac_32, mac_33
);

    // Horizontal cascading wires (Row propagation)
    wire [DATA_WIDTH-1:0] a_00_to_01, a_01_to_02, a_02_to_03, trash_a0;
    wire [DATA_WIDTH-1:0] a_10_to_11, a_11_to_12, a_12_to_13, trash_a1;
    wire [DATA_WIDTH-1:0] a_20_to_21, a_21_to_22, a_22_to_23, trash_a2;
    wire [DATA_WIDTH-1:0] a_30_to_31, a_31_to_32, a_32_to_33, trash_a3;

    // Vertical cascading wires (Column propagation)
    wire [DATA_WIDTH-1:0] b_00_to_10, b_10_to_20, b_20_to_30, trash_b0;
    wire [DATA_WIDTH-1:0] b_01_to_11, b_11_to_21, b_21_to_31, trash_b1;
    wire [DATA_WIDTH-1:0] b_02_to_12, b_12_to_22, b_22_to_32, trash_b2;
    wire [DATA_WIDTH-1:0] b_03_to_13, b_13_to_23, b_23_to_33, trash_b3;

    // --- ROW 0 ---
    pe #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) pe00 (.clk(clk), .rst(rst), .a_in(a_in_0),     .b_in(b_in_0),     .a_out(a_00_to_01), .b_out(b_00_to_10), .mac_out(mac_00));
    pe #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) pe01 (.clk(clk), .rst(rst), .a_in(a_00_to_01), .b_in(b_in_1),     .a_out(a_01_to_02), .b_out(b_01_to_11), .mac_out(mac_01));
    pe #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) pe02 (.clk(clk), .rst(rst), .a_in(a_01_to_02), .b_in(b_in_2),     .a_out(a_02_to_03), .b_out(b_02_to_12), .mac_out(mac_02));
    pe #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) pe03 (.clk(clk), .rst(rst), .a_in(a_02_to_03), .b_in(b_in_3),     .a_out(trash_a0),   .b_out(b_03_to_13), .mac_out(mac_03));

    // --- ROW 1 ---
    pe #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) pe10 (.clk(clk), .rst(rst), .a_in(a_in_1),     .b_in(b_00_to_10), .a_out(a_10_to_11), .b_out(b_10_to_20), .mac_out(mac_10));
    pe #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) pe11 (.clk(clk), .rst(rst), .a_in(a_10_to_11), .b_in(b_01_to_11), .a_out(a_11_to_12), .b_out(b_11_to_21), .mac_out(mac_11));
    pe #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) pe12 (.clk(clk), .rst(rst), .a_in(a_11_to_12), .b_in(b_02_to_12), .a_out(a_12_to_13), .b_out(b_12_to_22), .mac_out(mac_12));
    pe #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) pe13 (.clk(clk), .rst(rst), .a_in(a_12_to_13), .b_in(b_03_to_13), .a_out(trash_a1),   .b_out(b_13_to_23), .mac_out(mac_13));

    // --- ROW 2 ---
    pe #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) pe20 (.clk(clk), .rst(rst), .a_in(a_in_2),     .b_in(b_10_to_20), .a_out(a_20_to_21), .b_out(b_20_to_30), .mac_out(mac_20));
    pe #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) pe21 (.clk(clk), .rst(rst), .a_in(a_20_to_21), .b_in(b_11_to_21), .a_out(a_21_to_22), .b_out(b_21_to_31), .mac_out(mac_21));
    pe #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) pe22 (.clk(clk), .rst(rst), .a_in(a_21_to_22), .b_in(b_12_to_22), .a_out(a_22_to_23), .b_out(b_22_to_32), .mac_out(mac_22));
    pe #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) pe23 (.clk(clk), .rst(rst), .a_in(a_22_to_23), .b_in(b_13_to_23), .a_out(trash_a2),   .b_out(b_23_to_33), .mac_out(mac_23));

    // --- ROW 3 ---
    pe #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) pe30 (.clk(clk), .rst(rst), .a_in(a_in_3),     .b_in(b_20_to_30), .a_out(a_30_to_31), .b_out(trash_b0),   .mac_out(mac_30));
    pe #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) pe31 (.clk(clk), .rst(rst), .a_in(a_30_to_31), .b_in(b_21_to_31), .a_out(a_31_to_32), .b_out(trash_b1),   .mac_out(mac_31));
    pe #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) pe32 (.clk(clk), .rst(rst), .a_in(a_31_to_32), .b_in(b_22_to_32), .a_out(a_32_to_33), .b_out(trash_b2),   .mac_out(mac_32));
    pe #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) pe33 (.clk(clk), .rst(rst), .a_in(a_32_to_33), .b_in(b_23_to_33), .a_out(trash_a3),   .b_out(trash_b3),   .mac_out(mac_33));

endmodule