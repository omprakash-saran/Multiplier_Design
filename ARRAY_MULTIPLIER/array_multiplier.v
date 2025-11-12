`timescale 1ns / 1ps

module array_multiplier(
    input [15:0] A,    
    input [15:0] B,   
    output [31:0] Product    
);

    // 1. Generate partial products (same as before)
    wire [15:0] pp [0:15];
    wire [31:0] p_shifted [0:15];
    
    
    genvar i, j;
    generate
        for (i = 0; i < 16; i = i + 1) begin : pp_gen
            for (j = 0; j < 16; j = j + 1) begin : pp_bits
                assign pp[i][j] = A[j] & B[i];
            end
        end
    endgenerate
    
    // shift the partial products according to the positions
    generate
        for (i = 0; i < 16; i = i + 1) begin : pp_shift_gen
            assign p_shifted[i] = {16'b0, pp[i]} << i;
        end
    endgenerate

    wire [31:0] row_sum [0:15];
    
    assign row_sum[0] = p_shifted[0];
    
    generate
        for (i = 1; i < 16; i = i + 1) begin : adder_chain
            ripple_carry_adder_32bit adder_inst (
                .a(row_sum[i-1]),
                .b(p_shifted[i]),
                .cin(1'b0),
                .sum(row_sum[i]),
                .cout() 
            );
        end
    endgenerate
    
    assign Product = row_sum[15];

endmodule


// 32-bit Ripple Carry Adder
module ripple_carry_adder_32bit (
    input [31:0] a,
    input [31:0] b,
    input cin,
    output [31:0] sum,
    output cout
);
    wire [32:0] carry;
    assign carry[0] = cin;
    
    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin : bit_adder
            full_adder_bit fa (
                .a(a[i]),
                .b(b[i]),
                .cin(carry[i]),
                .s(sum[i]),
                .cout(carry[i+1])
            );
        end
    endgenerate
    
    assign cout = carry[32];
endmodule

// 1-bit Full Adder
module full_adder_bit (
    input a, b, cin,
    output s, cout
);
    assign s = a ^ b ^ cin;
    
    assign cout = (a & b) | (a & cin) | (b & cin);
endmodule