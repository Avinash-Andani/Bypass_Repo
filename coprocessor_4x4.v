`timescale 1ns / 1ps

module coprocessor_4x4 #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32,
    parameter FIFO_DEPTH = 16
)(
    input  wire                  clk,
    input  wire                  rst,
    input  wire                  clear,
    input  wire                  start,
    input  wire                  wr_en,
    output reg                   done,
    input  wire [DATA_WIDTH-1:0] a_in_0, a_in_1, a_in_2, a_in_3,
    input  wire [DATA_WIDTH-1:0] b_in_0, b_in_1, b_in_2, b_in_3,
    output wire [ACC_WIDTH-1:0]  out_00, out_01, out_02, out_03,
    output wire [ACC_WIDTH-1:0]  out_10, out_11, out_12, out_13,
    output wire [ACC_WIDTH-1:0]  out_20, out_21, out_22, out_23,
    output wire [ACC_WIDTH-1:0]  out_30, out_31, out_32, out_33
);

    wire [DATA_WIDTH-1:0] a_w [0:3];
    wire [DATA_WIDTH-1:0] b_w [0:3];
    wire empty_flag;
    reg  rd_en;

    // 4 Row FIFOs for Matrix A
    fifo #(DATA_WIDTH, FIFO_DEPTH) fifo_a0 (.clk(clk), .rst(rst), .clear(clear), .wr_en(wr_en), .rd_en(rd_en), .data_in(a_in_0), .data_out(a_w[0]), .full(), .empty(empty_flag));
    fifo #(DATA_WIDTH, FIFO_DEPTH) fifo_a1 (.clk(clk), .rst(rst), .clear(clear), .wr_en(wr_en), .rd_en(rd_en), .data_in(a_in_1), .data_out(a_w[1]), .full(), .empty());
    fifo #(DATA_WIDTH, FIFO_DEPTH) fifo_a2 (.clk(clk), .rst(rst), .clear(clear), .wr_en(wr_en), .rd_en(rd_en), .data_in(a_in_2), .data_out(a_w[2]), .full(), .empty());
    fifo #(DATA_WIDTH, FIFO_DEPTH) fifo_a3 (.clk(clk), .rst(rst), .clear(clear), .wr_en(wr_en), .rd_en(rd_en), .data_in(a_in_3), .data_out(a_w[3]), .full(), .empty());

    // 4 Column FIFOs for Matrix B
    fifo #(DATA_WIDTH, FIFO_DEPTH) fifo_b0 (.clk(clk), .rst(rst), .clear(clear), .wr_en(wr_en), .rd_en(rd_en), .data_in(b_in_0), .data_out(b_w[0]), .full(), .empty());
    fifo #(DATA_WIDTH, FIFO_DEPTH) fifo_b1 (.clk(clk), .rst(rst), .clear(clear), .wr_en(wr_en), .rd_en(rd_en), .data_in(b_in_1), .data_out(b_w[1]), .full(), .empty());
    fifo #(DATA_WIDTH, FIFO_DEPTH) fifo_b2 (.clk(clk), .rst(rst), .clear(clear), .wr_en(wr_en), .rd_en(rd_en), .data_in(b_in_2), .data_out(b_w[2]), .full(), .empty());
    fifo #(DATA_WIDTH, FIFO_DEPTH) fifo_b3 (.clk(clk), .rst(rst), .clear(clear), .wr_en(wr_en), .rd_en(rd_en), .data_in(b_in_3), .data_out(b_w[3]), .full(), .empty());

    // 4x4 Spatial Systolic Array (16 PEs)
    systolic_4x4 #(DATA_WIDTH, ACC_WIDTH) array4x4 (
        .clk(clk), .rst(rst), .clear(clear),
        .a_in_0(a_w[0]), .a_in_1(a_w[1]), .a_in_2(a_w[2]), .a_in_3(a_w[3]),
        .b_in_0(b_w[0]), .b_in_1(b_w[1]), .b_in_2(b_w[2]), .b_in_3(b_w[3]),
        .mac_00(out_00), .mac_01(out_01), .mac_02(out_02), .mac_03(out_03),
        .mac_10(out_10), .mac_11(out_11), .mac_12(out_12), .mac_13(out_13),
        .mac_20(out_20), .mac_21(out_21), .mac_22(out_22), .mac_23(out_23),
        .mac_30(out_30), .mac_31(out_31), .mac_32(out_32), .mac_33(out_33)
    );

    localparam IDLE = 2'b00, COMPUTE = 2'b01, DONE = 2'b10;
    reg [1:0] state;
    reg [3:0] timer;

    always @(posedge clk or posedge rst) begin
        if (rst || clear) begin
            state <= IDLE;
            rd_en <= 1'b0;
            done  <= 1'b0;
            timer <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start && !empty_flag) begin
                        state <= COMPUTE;
                        rd_en <= 1'b1; // Pop 1st vector on next edge
                        timer <= 4'd0;
                    end
                end

                COMPUTE: begin
                    timer <= timer + 4'd1;
                    // Keep rd_en high for 3 more cycles (4 reads total: k = 0,1,2,3)
                    if (timer == 4'd3)
                        rd_en <= 1'b0;
                    // Last element (k=3) settles in PE[3][3] after 10 compute cycles
                    if (timer == 4'd10) begin
                        state <= DONE;
                        timer <= 4'd0;
                    end
                end

                DONE: begin
                    done  <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
