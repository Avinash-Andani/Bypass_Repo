module pe #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
)(
    input clk,
    input rst,
    input [DATA_WIDTH-1:0] a_in,     
    input [DATA_WIDTH-1:0] b_in,      
    output reg [DATA_WIDTH-1:0] a_out,    
    output reg [DATA_WIDTH-1:0] b_out,    
    output reg [ACC_WIDTH-1:0] mac_out 
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            a_out   <= 0;
            b_out   <= 0;
            mac_out <= 0;
        end else begin
            a_out   <= a_in;                      
            b_out   <= b_in;                      
            mac_out <= mac_out + (a_in * b_in);   
        end
    end
endmodule