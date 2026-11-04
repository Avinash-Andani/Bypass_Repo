module coprocessor #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32,
    parameter FIFO_DEPTH = 16
)(
    input clk,
    input rst,
    input start,
    input wr_en,
    output reg done,

    input [DATA_WIDTH-1:0] a_in_0, a_in_1,
    input [DATA_WIDTH-1:0] b_in_0, b_in_1,

    output [ACC_WIDTH-1:0] out_00, out_01,
    output [ACC_WIDTH-1:0] out_10, out_11
);

    wire [DATA_WIDTH-1:0] a_wires[0:1];
    wire [DATA_WIDTH-1:0] b_wires[0:1];
    wire empty_flag;
    reg rd_en;

    fifo #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(FIFO_DEPTH)) fifo_a0 (.clk(clk), .rst(rst), .wr_en(wr_en), .rd_en(rd_en), .data_in(a_in_0), .data_out(a_wires[0]), .empty(empty_flag));
    fifo #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(FIFO_DEPTH)) fifo_a1 (.clk(clk), .rst(rst), .wr_en(wr_en), .rd_en(rd_en), .data_in(a_in_1), .data_out(a_wires[1]), .empty());
    fifo #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(FIFO_DEPTH)) fifo_b0 (.clk(clk), .rst(rst), .wr_en(wr_en), .rd_en(rd_en), .data_in(b_in_0), .data_out(b_wires[0]), .empty());
    fifo #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(FIFO_DEPTH)) fifo_b1 (.clk(clk), .rst(rst), .wr_en(wr_en), .rd_en(rd_en), .data_in(b_in_1), .data_out(b_wires[1]), .empty());

    systolic_2x2 #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) array (
        .clk(clk), .rst(rst),
        .a_in_0(a_wires[0]), .a_in_1(a_wires[1]),
        .b_in_0(b_wires[0]), .b_in_1(b_wires[1]),
        .mac_00(out_00), .mac_01(out_01),
        .mac_10(out_10), .mac_11(out_11)
    );

    parameter IDLE = 2'b00, COMPUTE = 2'b01, DONE = 2'b10;
    reg [1:0] state;
    reg [3:0] timer;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            rd_en <= 0;
            done  <= 0;
            timer <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start && !empty_flag) begin
                        state <= COMPUTE;
                        rd_en <= 1; 
                        timer <= 0;
                    end
                end

                COMPUTE: begin
                    timer <= timer + 1;
                    if (timer == 1) rd_en <= 0; 
                    if (timer == 6) begin
                        state <= DONE;
                        timer <= 0;
                    end
                end

                DONE: begin
                    done  <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule