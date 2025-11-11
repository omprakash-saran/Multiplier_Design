`timescale 1ns / 1ps
 
 // 32-bit Carry-Save Adder (3:2 Compressor)
module csa_32bit (
    input [31:0] a,
    input [31:0] b, 
    input [31:0] c,
    output [31:0] sum,
    output [31:0] carry
);
    assign sum = a ^ b ^ c;
    assign carry = ((a & b) | (a & c) | (b & c)) << 1;
endmodule

 // 4:2 Compressor using 3:2 compressor
module comp_4to2_32bit (
    input [31:0] w,
    input [31:0] x, 
    input [31:0] y,
    input [31:0] z,
    output [31:0] sum,
    output [31:0] carry );
   
    wire [31:0] sum1, carry1;
    wire [31:0] sum2, carry2;
    
    csa_32bit csa1 (.a(w), .b(x), .c(y), .sum(sum1), .carry(carry1));
    csa_32bit csa2 (.a(sum1), .b(z), .c(carry1), .sum(sum2), .carry(carry2));
    
    assign sum = sum2;
    assign carry = carry2;
endmodule

// wallace multiplier :- using 5 stage pipe-lining and 4:2 compressor to reduce levels while compression
module wallace_multi (
    input clk,                   
    input rst,                  
    input [15:0] a,             
    input [15:0] b,             
    output reg [31:0] p,         
    output reg done              
);
    
    reg [15:0] a_reg, b_reg;
    reg stage1_valid;
    
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            a_reg <= 0;
            b_reg <= 0;
            stage1_valid <= 0;
        end 
        else begin
            a_reg <= a;
            b_reg <= b;
            stage1_valid <= 1;
        end
    end
    
    
    // <------ STAGE 1 : generate 16 partial products --------->
     
    wire [31:0] pp [0:15];
    reg [31:0] pp_reg [0:15];
    
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : pp_gen_loop
            wire [15:0] product_term = a_reg & {16{b_reg[i]}};
            assign pp[i] = product_term << i;
        end
    endgenerate
    
    reg stage2_valid;
    integer j; 
    
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            for (j = 0; j < 16; j = j + 1) begin
                pp_reg[j] <= 32'b0;
            end
            stage2_valid <= 0;
        end else begin
            for (j = 0; j < 16; j = j + 1) begin
                pp_reg[j] <= pp[j];
            end
            stage2_valid <= stage1_valid;
        end
    end

    //<------- STAGE 2: using 4 (4 :2) compressor to reduce 16 vectors rows into 8 ------>
    
    wire [31:0] sum1_0, carry1_0, sum1_1, carry1_1;
    wire [31:0] sum1_2, carry1_2, sum1_3, carry1_3;

    // use the 4 (4:2) compressor
    comp_4to2_32bit comp_stage2_0 (.w(pp_reg[0]), .x(pp_reg[1]), .y(pp_reg[2]), .z(pp_reg[3]), .sum(sum1_0), .carry(carry1_0));
    comp_4to2_32bit comp_stage2_1 (.w(pp_reg[4]), .x(pp_reg[5]), .y(pp_reg[6]), .z(pp_reg[7]), .sum(sum1_1), .carry(carry1_1));
    comp_4to2_32bit comp_stage2_2 (.w(pp_reg[8]), .x(pp_reg[9]), .y(pp_reg[10]), .z(pp_reg[11]), .sum(sum1_2), .carry(carry1_2));
    comp_4to2_32bit comp_stage2_3 (.w(pp_reg[12]), .x(pp_reg[13]), .y(pp_reg[14]), .z(pp_reg[15]), .sum(sum1_3), .carry(carry1_3));

    reg [31:0] sum1_0_reg, sum1_1_reg, sum1_2_reg, sum1_3_reg;
    reg [31:0] carry1_0_reg, carry1_1_reg, carry1_2_reg, carry1_3_reg;
    reg stage3_valid;
    
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            sum1_0_reg <= 0; sum1_1_reg <= 0; sum1_2_reg <= 0; sum1_3_reg <= 0;
            carry1_0_reg <= 0; carry1_1_reg <= 0; carry1_2_reg <= 0; carry1_3_reg <= 0;
            stage3_valid <= 0;
        end else begin
            sum1_0_reg <= sum1_0; sum1_1_reg <= sum1_1; sum1_2_reg <= sum1_2; sum1_3_reg <= sum1_3;
            carry1_0_reg <= carry1_0; carry1_1_reg <= carry1_1; carry1_2_reg <= carry1_2; carry1_3_reg <= carry1_3;
            stage3_valid <= stage2_valid;
        end
    end

    // <------- STAGE 3: use 2 (4:2) compressor to reduce 8 vector rows into 4
    
    wire [31:0] sum2_0, carry2_0, sum2_1, carry2_1;
    
    comp_4to2_32bit comp_stage3_0 (.w(sum1_0_reg), .x(sum1_1_reg), .y(sum1_2_reg), .z(sum1_3_reg), .sum(sum2_0), .carry(carry2_0));
    comp_4to2_32bit comp_stage3_1 (.w(carry1_0_reg), .x(carry1_1_reg), .y(carry1_2_reg), .z(carry1_3_reg), .sum(sum2_1), .carry(carry2_1));
    
    reg [31:0] sum2_0_reg, sum2_1_reg;
    reg [31:0] carry2_0_reg, carry2_1_reg;
    reg stage4_valid;
    
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            sum2_0_reg <= 0; sum2_1_reg <= 0;
            carry2_0_reg <= 0; carry2_1_reg <= 0; 
            stage4_valid <= 0;
        end else begin
            sum2_0_reg <= sum2_0; sum2_1_reg <= sum2_1;
            carry2_0_reg <= carry2_0; carry2_1_reg <= carry2_1;
            stage4_valid <= stage3_valid;
        end
    end

    //<------ STAGE 4: use the 4:2 compressor to reduce the last 4 vector rows into 2
    
    wire [31:0] final_sum, final_carry;
    
    comp_4to2_32bit comp_stage4_0 (.w(sum2_0_reg), .x(sum2_1_reg), .y(carry2_0_reg), .z(carry2_1_reg), .sum(final_sum), .carry(final_carry));
    
    
    reg stage5_valid;
    reg [31:0] final_sum_reg, final_carry_reg;
    
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            final_sum_reg <= 0; final_carry_reg <= 0;
            stage5_valid <= 0;
        end else begin
            final_sum_reg <= final_sum; final_carry_reg <= final_carry;
            stage5_valid <= stage4_valid;
        end
    end
    
    
    //<------- STAGE 5 : FINAL SUM USING CLA ------->
    
    wire [31:0] final_product;
    wire final_cout;
    

    cla_32bit_O_log_n final_cla (
        .x(final_sum_reg),
        .y(final_carry_reg),
        .cin(1'b0),
        .s(final_product),
        .cout(final_cout)
    );
    
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            p <= 0;
            done <= 0;
        end else begin
            p <= final_product;
            done <= stage5_valid;
        end
    end

endmodule

//<------------------- Pipeline is end ------------> 
//below is module of cla 32 bit adder used in 5th stage of pipeling to add the final sum and final carry

module cla_32bit_O_log_n (
    input [31:0] x,
    input [31:0] y,
    input cin,
    output [31:0] s,
    output cout);
    
    wire [7:0] P_g, G_g;
    wire [8:0] C_block;
    assign C_block[0] = cin;
    
    genvar i;
    generate
    // divide the 32 bit into 8 block each with 4-bit data 
        for (i = 0; i < 8; i = i + 1) begin : block_gen
            cla_4bit_block cla_block (
                .x(x[4*i + 3 : 4*i]),
                .y(y[4*i + 3 : 4*i]),
                .cin(C_block[i]),
                .s(s[4*i + 3 : 4*i]),
                .P_g(P_g[i]),
                .G_g(G_g[i])
            );
            
            assign C_block[i+1] = G_g[i] | (P_g[i] & C_block[i]);
        end
    endgenerate
    
    assign cout = C_block[8];
endmodule

module cla_4bit_block (
    input [3:0] x, y,
    input cin,
    output [3:0] s,
    output P_g, G_g
);
    wire [3:0] p, g;
    wire [4:0] c;
    assign p = x ^ y;
    assign g = x & y;
    assign c[0] = cin;
    assign c[1] = g[0] | (p[0] & c[0]);
    assign c[2] = g[1] | (p[1] & c[1]);
    assign c[3] = g[2] | (p[2] & c[2]);
    assign c[4] = g[3] | (p[3] & c[3]);
    assign s = p ^ c[3:0];
    assign P_g = p[0] & p[1] & p[2] & p[3];
    assign G_g = g[3] | (p[3] & g[2]) | (p[3] & p[2] & g[1]) | (p[3] & p[2] & p[1] & g[0]);
endmodule
