`timescale 1ns / 1ps

module dma_controller (
    input  wire        clk,
    input  wire        rst,

    // AXI4-Lite / MMIO Slave Configuration Interface (0x5000_0000 - 0x5000_000C)
    input  wire        s_axi_wen,
    input  wire [3:0]  s_axi_addr,     // Word offset: 0x0=SRC_A, 0x4=SRC_B, 0x8=DST_C, 0xC=CTRL
    input  wire [31:0] s_axi_wdata,
    output reg  [31:0] s_axi_rdata,

    // Master BRAM Burst Interface (Connected to 2-Master Bus Arbiter in system.v)
    output wire        dma_busy,
    output reg         dma_done,
    output reg  [9:0]  dma_bram_addr,  // 10-bit word address into 1024-word BRAM
    output reg         dma_bram_wen,
    output reg  [31:0] dma_bram_wdata,
    input  wire [31:0] dma_bram_rdata,

    // Direct Hardware Stream Interface to 4x4 Coprocessor
    output reg         dma_coproc_clear,
    output reg         dma_coproc_wr_en,
    output reg         dma_coproc_start,
    output reg  [31:0] dma_a_packed,
    output reg  [31:0] dma_b_packed,
    input  wire        coproc_done,

    // 16 Accumulator Inputs from 4x4 Coprocessor for Direct BRAM Writeback
    input  wire [31:0] out_00, out_01, out_02, out_03,
    input  wire [31:0] out_10, out_11, out_12, out_13,
    input  wire [31:0] out_20, out_21, out_22, out_23,
    input  wire [31:0] out_30, out_31, out_32, out_33
);

    reg [31:0] reg_src_a;
    reg [31:0] reg_src_b;
    reg [31:0] reg_dst_c;
    reg        reg_wb_en;

    localparam S_IDLE        = 3'd0,
               S_READ_A_REQ  = 3'd1,
               S_READ_B_REQ  = 3'd2,
               S_PUSH_LAST   = 3'd3,
               S_WAIT_COPROC = 3'd4,
               S_WRITEBACK   = 3'd5,
               S_FINISH      = 3'd6;

    reg [2:0] state;
    reg [3:0] beat_cnt;

    assign dma_busy = (state != S_IDLE);

    // Multiplex the 16 32-bit outputs during DMA Writeback burst
    reg [31:0] wb_mux_data;
    always @(*) begin
        case (beat_cnt)
            4'd0:  wb_mux_data = out_00;
            4'd1:  wb_mux_data = out_01;
            4'd2:  wb_mux_data = out_02;
            4'd3:  wb_mux_data = out_03;
            4'd4:  wb_mux_data = out_10;
            4'd5:  wb_mux_data = out_11;
            4'd6:  wb_mux_data = out_12;
            4'd7:  wb_mux_data = out_13;
            4'd8:  wb_mux_data = out_20;
            4'd9:  wb_mux_data = out_21;
            4'd10: wb_mux_data = out_22;
            4'd11: wb_mux_data = out_23;
            4'd12: wb_mux_data = out_30;
            4'd13: wb_mux_data = out_31;
            4'd14: wb_mux_data = out_32;
            4'd15: wb_mux_data = out_33;
            default: wb_mux_data = 32'd0;
        endcase
    end

    always @(*) begin
        case (s_axi_addr)
            4'h0: s_axi_rdata = reg_src_a;
            4'h4: s_axi_rdata = reg_src_b;
            4'h8: s_axi_rdata = reg_dst_c;
            4'hC: s_axi_rdata = {30'd0, dma_busy, dma_done};
            default: s_axi_rdata = 32'd0;
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            reg_src_a        <= 32'd0;
            reg_src_b        <= 32'd0;
            reg_dst_c        <= 32'd0;
            reg_wb_en        <= 1'b0;
            state            <= S_IDLE;
            beat_cnt         <= 4'd0;
            dma_done         <= 1'b0;
            dma_bram_addr    <= 10'd0;
            dma_bram_wen     <= 1'b0;
            dma_bram_wdata   <= 32'd0;
            dma_coproc_clear <= 1'b0;
            dma_coproc_wr_en <= 1'b0;
            dma_coproc_start <= 1'b0;
            dma_a_packed     <= 32'd0;
            dma_b_packed     <= 32'd0;
        end else begin
            dma_coproc_clear <= 1'b0;
            dma_coproc_wr_en <= 1'b0;
            dma_coproc_start <= 1'b0;
            dma_bram_wen     <= 1'b0;

            // Slave Register Writes from CPU
            if (s_axi_wen && state == S_IDLE) begin
                case (s_axi_addr)
                    4'h0: reg_src_a <= s_axi_wdata;
                    4'h4: reg_src_b <= s_axi_wdata;
                    4'h8: reg_dst_c <= s_axi_wdata;
                    4'hC: begin
                        // Bit 0: Start DMA | Bit 1: Writeback 16 outputs to BRAM | Bit 2: Clear Accumulators
                        if (s_axi_wdata[0]) begin
                            dma_done         <= 1'b0;
                            reg_wb_en        <= s_axi_wdata[1];
                            dma_coproc_clear <= s_axi_wdata[2];
                            beat_cnt         <= 4'd0;
                            dma_bram_addr    <= reg_src_a[11:2];
                            state            <= S_READ_A_REQ;
                        end
                    end
                    default: ;
                endcase
            end

            // Autonomous Hardware DMA State Machine
            case (state)
                S_IDLE: begin
                    // Wait for CPU trigger on 0x5000_000C
                end

                S_READ_A_REQ: begin
                    // Cycle after reg_src_a[beat_cnt] was presented: issue reg_src_b[beat_cnt]
                    // If beat_cnt > 0, dma_bram_rdata currently holds B[beat_cnt-1]
                    if (beat_cnt > 4'd0) begin
                        dma_b_packed     <= dma_bram_rdata;
                        dma_coproc_wr_en <= 1'b1;
                    end
                    dma_bram_addr <= reg_src_b[11:2] + {6'd0, beat_cnt};
                    state         <= S_READ_B_REQ;
                end

                S_READ_B_REQ: begin
                    // dma_bram_rdata now holds A[beat_cnt]
                    dma_a_packed <= dma_bram_rdata;
                    if (beat_cnt == 4'd3) begin
                        state <= S_PUSH_LAST;
                    end else begin
                        beat_cnt      <= beat_cnt + 4'd1;
                        dma_bram_addr <= reg_src_a[11:2] + {6'd0, beat_cnt + 4'd1};
                        state         <= S_READ_A_REQ;
                    end
                end

                S_PUSH_LAST: begin
                    // dma_bram_rdata now holds B[3] -> push final beat & fire systolic array!
                    dma_b_packed     <= dma_bram_rdata;
                    dma_coproc_wr_en <= 1'b1;
                    dma_coproc_start <= 1'b1;
                    state            <= S_WAIT_COPROC;
                end

                S_WAIT_COPROC: begin
                    if (coproc_done) begin
                        if (reg_wb_en) begin
                            beat_cnt <= 4'd0;
                            state    <= S_WRITEBACK;
                        end else begin
                            state    <= S_FINISH;
                        end
                    end
                end

                S_WRITEBACK: begin
                    dma_bram_addr  <= reg_dst_c[11:2] + {6'd0, beat_cnt};
                    dma_bram_wdata <= wb_mux_data;
                    dma_bram_wen   <= 1'b1;
                    if (beat_cnt == 4'd15) begin
                        state <= S_FINISH;
                    end else begin
                        beat_cnt <= beat_cnt + 4'd1;
                    end
                end

                S_FINISH: begin
                    dma_done <= 1'b1;
                    state    <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
