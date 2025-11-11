`timescale 1ns / 1ps

module array_tb;

    reg [15:0] test_A;
    reg [15:0] test_B;
    
    wire [31:0] test_Product;
    
    reg [31:0] expected_Product;

    integer i;

    array_multi uut (
        .A(test_A),
        .B(test_B),
        .Product(test_Product)
    );
    
    initial begin
        $display("Starting Array Multiplier Random Test (20 Cases)");
        $display("Status |   A (Input)  |   B (Input)  |   Got (Output)   |    Expected    ");
        $display("-------|--------------|--------------|------------------|------------------");

        for (i = 0; i < 20; i = i + 1) begin
            test_A = $random;
            test_B = $random;
            
            expected_Product = test_A * test_B;
            
            #10; 
            
            if (test_Product === expected_Product) begin
                $display(" PASS  | %12d | %12d | %16d | %16d", 
                         test_A, test_B, test_Product, expected_Product);
            end else begin
                $display(" FAIL  | %12d | %12d | %16d | %16d", 
                         test_A, test_B, test_Product, expected_Product);
            end
        end
        
        $stop;
    end

endmodule