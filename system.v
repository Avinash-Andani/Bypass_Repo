`timescale 1ns / 1ps

module system (
    input  wire        clk,             // 40 MHz LabVIEW FPGA Clock (25 ns period)
    input  wire        reset,           // Active-High Reset from LabVIEW
    input  wire [7:0]  digit_sel,       // Live Image Selector (0..3) from LabVIEW Front Panel
    output reg  [31:0] out_00,          // Live Output Matrix Quadrant [0,0] / Verified C[0,0]
    output reg  [31:0] out_01,          // Live Output Matrix Quadrant [0,1] / Verified C[0,1]
    output reg  [31:0] out_10,          // Live Output Matrix Quadrant [1,0] / Verified C[1,0]
    output reg  [31:0] out_11,          // Live Output Matrix Quadrant [1,1] / Verified C[1,1]
    output reg  [31:0] hw_cycles,       // Locked Phase-2 4x4 AXI-Lite DMA Execution Cycles
    output reg  [31:0] sw_cycles,       // Locked Phase-2 4x4 Software Execution Cycles
    output reg  [31:0] predicted_digit, // Recognized Image Class (0, 1, 2, or 3)
    output wire        led0,            // myRIO Physical LED0 (Image Class 0)
    output wire        led1,            // myRIO Physical LED1 (Image Class 1)
    output wire        led2,            // myRIO Physical LED2 (Image Class 2)
    output wire        led3             // myRIO Physical LED3 (Image Class 3)
);

    wire        mem_valid;
    reg         mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wstrb;
    reg  [31:0] mem_rdata;

    picorv32 #(
        .ENABLE_MUL(1),
        .COMPRESSED_ISA(1),
        .ENABLE_FAST_MUL(0)
    ) cpu (
        .clk       (clk),
        .resetn    (~reset),
        .mem_valid (mem_valid),
        .mem_ready (mem_ready),
        .mem_addr  (mem_addr),
        .mem_wdata (mem_wdata),
        .mem_wstrb (mem_wstrb),
        .mem_rdata (mem_rdata)
    );

    wire        dma_busy;
    wire        dma_done;
    wire [9:0]  dma_bram_addr;
    wire        dma_bram_wen;
    wire [31:0] dma_bram_wdata;
    reg  [31:0] bram_rdata;

    wire [9:0]  cpu_word_addr = mem_addr[11:2];
    wire        is_bram       = (mem_addr[31:12] == 20'h00000);
    wire        is_mmio       = (mem_addr[31:12] == 20'h40000);
    wire        is_dma_cfg    = (mem_addr[31:12] == 20'h50000);

    wire [9:0]  arb_bram_addr  = dma_busy ? dma_bram_addr  : cpu_word_addr;
    wire [3:0]  arb_bram_wstrb = dma_busy ? {4{dma_bram_wen}} : ((mem_valid && !mem_ready && is_bram) ? mem_wstrb : 4'b0000);
    wire [31:0] arb_bram_wdata = dma_busy ? dma_bram_wdata : mem_wdata;

    (* ram_style = "block" *) reg [31:0] memory [0:1023];

    initial begin
        $readmemh("software/firmware.hex", memory);
    end

    always @(posedge clk) begin
        if (arb_bram_wstrb[0]) memory[arb_bram_addr][7:0]   <= arb_bram_wdata[7:0];
        if (arb_bram_wstrb[1]) memory[arb_bram_addr][15:8]  <= arb_bram_wdata[15:8];
        if (arb_bram_wstrb[2]) memory[arb_bram_addr][23:16] <= arb_bram_wdata[23:16];
        if (arb_bram_wstrb[3]) memory[arb_bram_addr][31:24] <= arb_bram_wdata[31:24];
        bram_rdata <= memory[arb_bram_addr];
    end

    wire        coproc_done;
    reg         cpu_coproc_clear;
    reg         cpu_coproc_start;
    reg         cpu_coproc_wr_en;
    reg  [31:0] cpu_a_packed;
    reg  [31:0] cpu_b_packed;

    wire        dma_coproc_clear;
    wire        dma_coproc_wr_en;
    wire        dma_coproc_start;
    wire [31:0] dma_a_packed;
    wire [31:0] dma_b_packed;

    wire        mux_clear = dma_busy ? dma_coproc_clear : cpu_coproc_clear;
    wire        mux_wr_en = dma_busy ? dma_coproc_wr_en : cpu_coproc_wr_en;
    wire        mux_start = dma_busy ? dma_coproc_start : cpu_coproc_start;
    wire [31:0] mux_a     = dma_busy ? dma_a_packed     : cpu_a_packed;
    wire [31:0] mux_b     = dma_busy ? dma_b_packed     : cpu_b_packed;

    wire [31:0] c_out_00, c_out_01, c_out_02, c_out_03;
    wire [31:0] c_out_10, c_out_11, c_out_12, c_out_13;
    wire [31:0] c_out_20, c_out_21, c_out_22, c_out_23;
    wire [31:0] c_out_30, c_out_31, c_out_32, c_out_33;

    coprocessor_4x4 #(
        .DATA_WIDTH(8),
        .ACC_WIDTH(32),
        .FIFO_DEPTH(16)
    ) coproc (
        .clk    (clk),
        .rst    (reset),
        .clear  (mux_clear),
        .start  (mux_start),
        .wr_en  (mux_wr_en),
        .done   (coproc_done),
        .a_in_0 (mux_a[7:0]),   .a_in_1 (mux_a[15:8]),  .a_in_2 (mux_a[23:16]), .a_in_3 (mux_a[31:24]),
        .b_in_0 (mux_b[7:0]),   .b_in_1 (mux_b[15:8]),  .b_in_2 (mux_b[23:16]), .b_in_3 (mux_b[31:24]),
        .out_00 (c_out_00),     .out_01 (c_out_01),     .out_02 (c_out_02),     .out_03 (c_out_03),
        .out_10 (c_out_10),     .out_11 (c_out_11),     .out_12 (c_out_12),     .out_13 (c_out_13),
        .out_20 (c_out_20),     .out_21 (c_out_21),     .out_22 (c_out_22),     .out_23 (c_out_23),
        .out_30 (c_out_30),     .out_31 (c_out_31),     .out_32 (c_out_32),     .out_33 (c_out_33)
    );

    wire        s_axi_wen = (mem_valid && !mem_ready && (mem_wstrb != 4'b0000) && is_dma_cfg);
    wire [31:0] dma_cfg_rdata;

    dma_controller dma_inst (
        .clk              (clk),
        .rst              (reset),
        .s_axi_wen        (s_axi_wen),
        .s_axi_addr       (mem_addr[3:0]),
        .s_axi_wdata      (mem_wdata),
        .s_axi_rdata      (dma_cfg_rdata),
        .dma_busy         (dma_busy),
        .dma_done         (dma_done),
        .dma_bram_addr    (dma_bram_addr),
        .dma_bram_wen     (dma_bram_wen),
        .dma_bram_wdata   (dma_bram_wdata),
        .dma_bram_rdata   (bram_rdata),
        .dma_coproc_clear (dma_coproc_clear),
        .dma_coproc_wr_en (dma_coproc_wr_en),
        .dma_coproc_start (dma_coproc_start),
        .dma_a_packed     (dma_a_packed),
        .dma_b_packed     (dma_b_packed),
        .coproc_done      (coproc_done),
        .out_00(c_out_00), .out_01(c_out_01), .out_02(c_out_02), .out_03(c_out_03),
        .out_10(c_out_10), .out_11(c_out_11), .out_12(c_out_12), .out_13(c_out_13),
        .out_20(c_out_20), .out_21(c_out_21), .out_22(c_out_22), .out_23(c_out_23),
        .out_30(c_out_30), .out_31(c_out_31), .out_32(c_out_32), .out_33(c_out_33)
    );

    reg        mmio_counting;
    reg        dma_counting;
    reg        sw_counting;
    reg [31:0] mmio_counter_live;
    reg [31:0] dma_counter_live;
    reg [31:0] sw_counter_live;
    reg [31:0] mmio_cycles;
    reg        mmio_cycles_locked;
    reg        dma_cycles_locked;
    reg        coproc_done_latched;
    reg        sw_done_latched;
    reg        class_valid;

    assign led0 = class_valid && (predicted_digit[1:0] == 2'd0);
    assign led1 = class_valid && (predicted_digit[1:0] == 2'd1);
    assign led2 = class_valid && (predicted_digit[1:0] == 2'd2);
    assign led3 = class_valid && (predicted_digit[1:0] == 2'd3);

    always @(posedge clk) begin
        if (reset) begin
            mem_ready           <= 1'b0;
            cpu_coproc_clear    <= 1'b0;
            cpu_coproc_start    <= 1'b0;
            cpu_coproc_wr_en    <= 1'b0;
            cpu_a_packed        <= 32'd0;
            cpu_b_packed        <= 32'd0;
            out_00              <= 32'd0;
            out_01              <= 32'd0;
            out_10              <= 32'd0;
            out_11              <= 32'd0;
            mmio_counting       <= 1'b0;
            dma_counting        <= 1'b0;
            sw_counting         <= 1'b0;
            mmio_counter_live   <= 32'd0;
            dma_counter_live    <= 32'd0;
            sw_counter_live     <= 32'd0;
            mmio_cycles         <= 32'd0;
            hw_cycles           <= 32'd0;
            sw_cycles           <= 32'd0;
            predicted_digit     <= 32'd0;
            mmio_cycles_locked  <= 1'b0;
            dma_cycles_locked   <= 1'b0;
            coproc_done_latched <= 1'b0;
            sw_done_latched     <= 1'b0;
            class_valid         <= 1'b0;
        end else begin
            cpu_coproc_clear <= 1'b0;
            cpu_coproc_start <= 1'b0;
            cpu_coproc_wr_en <= 1'b0;

            if (mem_valid && !mem_ready && !(is_bram && dma_busy)) begin
                mem_ready <= 1'b1;
            end else begin
                mem_ready <= 1'b0;
            end

            if (mmio_counting) begin
                if (coproc_done) begin
                    mmio_counting       <= 1'b0;
                    coproc_done_latched <= 1'b1;
                    if (!mmio_cycles_locked) begin
                        mmio_cycles        <= mmio_counter_live;
                        mmio_cycles_locked <= 1'b1;
                    end
                end else begin
                    mmio_counter_live <= mmio_counter_live + 32'd1;
                end
            end else if (coproc_done) begin
                coproc_done_latched <= 1'b1;
            end

            if (s_axi_wen && (mem_addr[3:0] == 4'hC) && mem_wdata[0]) begin
                dma_counter_live <= 32'd1;
                dma_counting     <= 1'b1;
            end else if (dma_counting) begin
                if (coproc_done) begin
                    dma_counting <= 1'b0;
                    if (!dma_cycles_locked) begin
                        hw_cycles         <= dma_counter_live;
                        dma_cycles_locked <= 1'b1;
                    end
                end else begin
                    dma_counter_live <= dma_counter_live + 32'd1;
                end
            end

            if (sw_counting) begin
                sw_counter_live <= sw_counter_live + 32'd1;
            end

            if (mem_valid && !mem_ready && (mem_wstrb != 4'b0000) && is_mmio) begin
                case (mem_addr)
                    32'h4000_0000: cpu_a_packed <= mem_wdata;
                    32'h4000_0004: begin
                        cpu_b_packed     <= mem_wdata;
                        cpu_coproc_wr_en <= 1'b1;
                    end
                    32'h4000_0008: begin
                        cpu_coproc_start    <= mem_wdata[0];
                        coproc_done_latched <= 1'b0;
                    end
                    32'h4000_000C: begin
                        cpu_coproc_clear    <= 1'b1;
                        coproc_done_latched <= 1'b0;
                        if (mem_wdata[1]) begin
                            mmio_counter_live <= 32'd1;
                            mmio_counting     <= 1'b1;
                        end
                    end
                    32'h4000_0010: begin
                        out_00 <= c_out_00;
                        out_01 <= c_out_01;
                        out_10 <= c_out_10;
                        out_11 <= c_out_11;
                    end
                    32'h4000_0014: begin
                        sw_counter_live <= 32'd1;
                        sw_counting     <= 1'b1;
                        sw_done_latched <= 1'b0;
                    end
                    32'h4000_0018: begin
                        sw_counting     <= 1'b0;
                        sw_cycles       <= sw_counter_live;
                        sw_done_latched <= 1'b1;
                    end
                    32'h4000_001C: begin
                        predicted_digit <= mem_wdata;
                        class_valid     <= 1'b1;
                    end
                    // Live Output Matrix Streaming Registers for LabVIEW Intensity Graph
                    32'h4000_0020: out_00 <= mem_wdata;
                    32'h4000_0024: out_01 <= mem_wdata;
                    32'h4000_0028: out_10 <= mem_wdata;
                    32'h4000_002C: out_11 <= mem_wdata;
                    default: ;
                endcase
            end
        end
    end

    always @(*) begin
        if (is_bram) begin
            mem_rdata = bram_rdata;
        end else if (is_dma_cfg) begin
            mem_rdata = dma_cfg_rdata;
        end else if (is_mmio) begin
            case (mem_addr)
                32'h4000_0008: mem_rdata = {29'd0, dma_done, sw_done_latched, coproc_done_latched};
                32'h4000_0020: mem_rdata = c_out_00;
                32'h4000_0024: mem_rdata = c_out_01;
                32'h4000_0028: mem_rdata = c_out_10;
                32'h4000_002C: mem_rdata = c_out_11;
                32'h4000_0030: mem_rdata = hw_cycles;
                32'h4000_0034: mem_rdata = sw_cycles;
                32'h4000_0038: mem_rdata = {24'd0, digit_sel};
                32'h4000_003C: mem_rdata = mmio_cycles;
                default:       mem_rdata = 32'd0;
            endcase
        end else begin
            mem_rdata = 32'd0;
        end
    end

endmodule
