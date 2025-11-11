`timescale 1ns / 1ps

module wallace_tb;
    
    
    localparam CLK_PERIOD = 4.5;
    
    
    reg clk;
    reg rst_n;
    reg [15:0] test_a;
    reg [15:0] test_b;
    
    wire [31:0] test_p;
    wire test_done;
    reg [31:0] expected_p; 

    // --- Queues to store expected values for pipelined test ---
    reg [15:0] a_queue [0:25];
    reg [15:0] b_queue [0:25];
    reg [31:0] expected_p_queue [0:25];
    integer i;
    
    
    wallace_multi uut (
        .clk(clk),
        .rst(rst_n),  
        .a(test_a),
        .b(test_b),
        .p(test_p),
        .done(test_done)
    );
    
    
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk; 
    end
  
    initial begin 
        $display("Testbench Starting...");
        rst_n  = 0; 
        test_a = 0;
        test_b = 0;
        expected_p = 0;
        
        for (i = 0; i < 26; i = i + 1) begin
            a_queue[i] = 0;
            b_queue[i] = 0;
            expected_p_queue[i] = 0;
        end
        
        #(2 * CLK_PERIOD) rst_n = 1; 
        
        //  some hardcoded edge cases for testing 
        @(posedge clk); 
        a_queue[1] = 16'd10;    b_queue[1] = 16'd20;
        expected_p_queue[1] = 32'd200;
        test_a = a_queue[1];    test_b = b_queue[1];
        
        @(posedge clk);
        a_queue[2] = 16'd1234;  b_queue[2] = 16'd0;
        expected_p_queue[2] = 32'd0;
        test_a = a_queue[2];    test_b = b_queue[2];

        @(posedge clk); 
        expected_p_queue[3] = 32'd0;
        test_a = a_queue[3];    test_b = b_queue[3];
        
        @(posedge clk); 
        a_queue[4] = 16'd65535; b_queue[4] = 16'd1;
        expected_p_queue[4] = 32'd65535;
        test_a = a_queue[4];    test_b = b_queue[4];

        @(posedge clk); 
        a_queue[5] = 16'd255;   b_queue[5] = 16'd255;
        expected_p_queue[5] = 32'd65025;
        test_a = a_queue[5];    test_b = b_queue[5];

        
        
        $monitor("Cycle %0d: [Done: %b] In: %6d * %6d | Out: %10d | Expected: %10d",
                 i, test_done, test_a, test_b, test_p, expected_p_queue[i-6]);

        for (i = 6; i <= 20; i = i + 1) begin
            @(posedge clk); 
            
            // check the output for inout before 5 clock as my latency is 5 stage cycle then output will appear after the 5 clocks
            expected_p = expected_p_queue[i-5];
            if (test_done && test_p !== expected_p_queue[i-6]) begin
                $display("ERROR @ Cycle %0d: MISMATCH! Expected %d, Got %d", i, expected_p, test_p);
            end
                
            a_queue[i] = $random;
            b_queue[i] = $random;
            expected_p_queue[i] = $unsigned(a_queue[i]) * $unsigned(b_queue[i]);
            test_a = a_queue[i];
            test_b = b_queue[i];
        end
        
        $monitoroff; 
        test_a = 0;
        test_b = 0;
        
        // check for the remainig 5 output in pipeline stages
        for (i = 21; i <= 25; i = i + 1) begin
            @(posedge clk);
            
            expected_p = expected_p_queue[i-5];
            if (test_done && test_p === expected_p)
                $display("Cycle %0d: [PASS]   In: %6d * %6d | Out: %10d | Expected: %10d", 
                         i, a_queue[i-5], b_queue[i-5], test_p, expected_p_queue[i-6]);
            else
                $display("Cycle %0d: [FAIL]   In: %6d * %6d | Out: %10d | Expected: %10d", 
                         i, a_queue[i-5], b_queue[i-5], test_p, expected_p_queue[i-6]);
        end
        
        @(posedge clk);
        $display("Testbench completed.");
        $stop;
    end

endmodule