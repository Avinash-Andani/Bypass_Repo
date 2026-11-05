`timescale 1ns / 1ps

module system (
    input  wire        clk,             // 40 MHz LabVIEW FPGA Clock (25 ns period)
    input  wire        reset,           // Active-High Reset from LabVIEW
    input  wire [7:0]  digit_sel,       // Live Digit Selector (0..3) from LabVIEW Front Panel
    output reg  [31:0] out_00,          // Verified 2x2 Systolic Array C[0][0] (17)
    output reg  [31:0] out_01,          // Verified 2x2 Systolic Array C[0][1] (23)
    output reg  [31:0] out_10,          // Verified 2x2 Systolic Array C[1][0] (39)
    output reg  [31:0] out_11,          // Verified 2x2 Systolic Array C[1][1] (53)
    output reg  [31:0] hw_cycles,       // Locked Hardware Execution Cycles
    output reg  [31:0] sw_cycles,       // Locked Software Execution Cycles
    output reg  [31:0] predicted_digit, // Recognized Digit Class (0, 1, 2, or 3)
    output wire        led0,            // myRIO Physical LED0 (Digit 0 Detected)
    output wire        led1,            // myRIO Physical LED1 (Digit 1 Detected)
    output wire        led2,            // myRIO Physical LED2 (Digit 2 Detected)
    output wire        led3             // myRIO Physical LED3 (Digit 3 Detected)
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

    // True Synchronous 32-Bit Block RAM (1024 Words = 4KB)
    (* ram_style = "block" *) reg [31:0] memory [0:1023];

    initial begin
        $readmemh("software/firmware.hex", memory);
    end

    wire [9:0] word_addr = mem_addr[11:2];
    wire       is_bram   = (mem_addr[31:12] == 20'h00000);
    wire       is_mmio   = (mem_addr[31:12] == 20'h40000);

    reg [31:0] bram_rdata;

    always @(posedge clk) begin
        if (mem_valid && !mem_ready && is_bram) begin
            if (mem_wstrb[0]) memory[word_addr][7:0]   <= mem_wdata[7:0];
            if (mem_wstrb[1]) memory[word_addr][15:8]  <= mem_wdata[15:8];
            if (mem_wstrb[2]) memory[word_addr][23:16] <= mem_wdata[23:16];
            if (mem_wstrb[3]) memory[word_addr][31:24] <= mem_wdata[31:24];
        end
        bram_rdata <= memory[word_addr];
    end

    wire        coproc_done;
    reg         coproc_clear;
    reg         coproc_start;
    reg         coproc_wr_en;
    reg  [7:0]  a_in_0, a_in_1;
    reg  [7:0]  b_in_0, b_in_1;
    wire [31:0] coproc_out_00, coproc_out_01, coproc_out_10, coproc_out_11;

    coprocessor #(
        .DATA_WIDTH(8),
        .ACC_WIDTH(32),
        .FIFO_DEPTH(16)
    ) coproc (
        .clk    (clk),
        .rst    (reset),
        .clear  (coproc_clear),
        .start  (coproc_start),
        .wr_en  (coproc_wr_en),
        .done   (coproc_done),
        .a_in_0 (a_in_0),
        .a_in_1 (a_in_1),
        .b_in_0 (b_in_0),
        .b_in_1 (b_in_1),
        .out_00 (coproc_out_00),
        .out_01 (coproc_out_01),
        .out_10 (coproc_out_10),
        .out_11 (coproc_out_11)
    );

    reg        hw_counting;
    reg        sw_counting;
    reg [31:0] hw_counter_live;
    reg [31:0] sw_counter_live;
    reg        coproc_done_latched;
    reg        sw_done_latched;
    reg        hw_cycles_locked;
    reg        class_valid;

    // One-hot physical myRIO LED mapping for predicted digit class (0..3)
    assign led0 = class_valid && (predicted_digit[1:0] == 2'd0);
    assign led1 = class_valid && (predicted_digit[1:0] == 2'd1);
    assign led2 = class_valid && (predicted_digit[1:0] == 2'd2);
    assign led3 = class_valid && (predicted_digit[1:0] == 2'd3);

    always @(posedge clk) begin
        if (reset) begin
            mem_ready           <= 1'b0;
            coproc_clear        <= 1'b0;
            coproc_start        <= 1'b0;
            coproc_wr_en        <= 1'b0;
            a_in_0              <= 8'd0;
            a_in_1              <= 8'd0;
            b_in_0              <= 8'd0;
            b_in_1              <= 8'd0;
            out_00              <= 32'd0;
            out_01              <= 32'd0;
            out_10              <= 32'd0;
            out_11              <= 32'd0;
            hw_counting         <= 1'b0;
            sw_counting         <= 1'b0;
            hw_counter_live     <= 32'd0;
            sw_counter_live     <= 32'd0;
            hw_cycles           <= 32'd0;
            sw_cycles           <= 32'd0;
            predicted_digit     <= 32'd0;
            coproc_done_latched <= 1'b0;
            sw_done_latched     <= 1'b0;
            hw_cycles_locked    <= 1'b0;
            class_valid         <= 1'b0;
        end else begin
            coproc_clear <= 1'b0;
            coproc_start <= 1'b0;
            coproc_wr_en <= 1'b0;

            if (mem_valid && !mem_ready) begin
                mem_ready <= 1'b1;
            end else begin
                mem_ready <= 1'b0;
            end

            if (coproc_done) begin
                hw_counting         <= 1'b0;
                coproc_done_latched <= 1'b1;
                if (!hw_cycles_locked) begin
                    hw_cycles        <= hw_counter_live;
                    hw_cycles_locked <= 1'b1;
                end
            end else if (hw_counting) begin
                hw_counter_live <= hw_counter_live + 32'd1;
            end

            if (sw_counting) begin
                sw_counter_live <= sw_counter_live + 32'd1;
            end

            if (mem_valid && !mem_ready && (mem_wstrb != 4'b0000) && is_mmio) begin
                case (mem_addr)
                    32'h4000_0000: begin
                        a_in_0       <= mem_wdata[7:0];
                        b_in_0       <= mem_wdata[15:8];
                        a_in_1       <= mem_wdata[23:16];
                        b_in_1       <= mem_wdata[31:24];
                        coproc_wr_en <= 1'b1;
                    end
                    32'h4000_0004: begin
                        coproc_start        <= mem_wdata[0];
                        hw_counter_live     <= 32'd1;
                        hw_counting         <= 1'b1;
                        coproc_done_latched <= 1'b0;
                    end
                    32'h4000_000C: begin
                        coproc_clear        <= 1'b1;
                        coproc_done_latched <= 1'b0;
                    end
                    32'h4000_0010: begin
                        // Latch verified 2x2 outputs onto top-level LabVIEW buses
                        out_00 <= coproc_out_00;
                        out_01 <= coproc_out_01;
                        out_10 <= coproc_out_10;
                        out_11 <= coproc_out_11;
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
                    default: ;
                endcase
            end
        end
    end

    always @(*) begin
        if (is_bram) begin
            mem_rdata = bram_rdata;
        end else if (is_mmio) begin
            case (mem_addr)
                32'h4000_0008: mem_rdata = {30'd0, sw_done_latched, coproc_done_latched};
                32'h4000_0020: mem_rdata = coproc_out_00;
                32'h4000_0024: mem_rdata = coproc_out_01;
                32'h4000_0028: mem_rdata = coproc_out_10;
                32'h4000_002C: mem_rdata = coproc_out_11;
                32'h4000_0030: mem_rdata = hw_cycles;
                32'h4000_0034: mem_rdata = sw_cycles;
                32'h4000_0038: mem_rdata = {24'd0, digit_sel};
                default:       mem_rdata = 32'd0;
            endcase
        end else begin
            mem_rdata = 32'd0;
        end
    end

endmodule
