module fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH = 16    
) (
    input clk,
    input rst,
    input wr_en,            
    input rd_en,            
    input [DATA_WIDTH-1:0] data_in,
    
    output reg [DATA_WIDTH-1:0] data_out,
    output full,            
    output empty            
);

    reg [DATA_WIDTH-1:0] memory [0:DEPTH-1];
    
    reg [3:0] wr_ptr;
    reg [3:0] rd_ptr;
    reg [4:0] count;        

    assign empty = (count == 0);
    assign full  = (count == DEPTH);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wr_ptr   <= 0;
            rd_ptr   <= 0;
            count    <= 0;
            data_out <= 0;
        end else begin
            if (wr_en && !full) begin
                memory[wr_ptr] <= data_in;
                wr_ptr <= wr_ptr + 1;
            end

            if (rd_en && !empty) begin
                data_out <= memory[rd_ptr];
                rd_ptr <= rd_ptr + 1;
            end
            else begin
                data_out <= 0;
            end
            
            if (wr_en && !full && (!rd_en || empty)) 
                count <= count + 1;
            else if (rd_en && !empty && (!wr_en || full)) 
                count <= count - 1;
        end
    end
endmodule