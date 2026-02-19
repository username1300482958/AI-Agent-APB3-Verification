//==============================================================================
// Module Name  : tb_apb_pwm_ctrl
// Description  : Self-Checking Testbench for APB PWM Controller
// Engineer     : Senior Design Engineer
// Company      : Global Fabless Semiconductor Company
//==============================================================================

`timescale 1ns/1ps

module tb_apb_pwm_ctrl;

    //==========================================================================
    // Testbench Signals
    //==========================================================================
    reg         pclk;
    reg         presetn;
    reg         psel;
    reg         penable;
    reg         pwrite;
    reg  [31:0] paddr;
    reg  [31:0] pwdata;
    wire [31:0] prdata;
    wire        pready;
    wire        pwm_out;
    
    // Test control variables
    integer     error_count;
    integer     test_count;
    reg  [31:0] read_data;
    integer     i;
    integer     high_count, low_count;
    
    //==========================================================================
    // DUT Instantiation
    //==========================================================================
    apb_pwm_ctrl u_apb_pwm_ctrl (
        .pclk       (pclk),
        .presetn    (presetn),
        .psel       (psel),
        .penable    (penable),
        .pwrite     (pwrite),
        .paddr      (paddr),
        .pwdata     (pwdata),
        .prdata     (prdata),
        .pready     (pready),
        .pwm_out    (pwm_out)
    );
    
    //==========================================================================
    // Clock Generation (10ns period = 100MHz)
    //==========================================================================
    initial begin
        pclk = 0;
        forever #5 pclk = ~pclk;
    end
    
    //==========================================================================
    // APB Write Task
    //==========================================================================
    task apb_write;
        input [31:0] addr;
        input [31:0] data;
        begin
            @(posedge pclk);
            psel    = 1'b1;
            penable = 1'b0;
            pwrite  = 1'b1;
            paddr   = addr;
            pwdata  = data;
            
            @(posedge pclk);
            penable = 1'b1;
            
            @(posedge pclk);
            psel    = 1'b0;
            penable = 1'b0;
            pwrite  = 1'b0;
            
            $display("[TIME=%0t] APB WRITE: Addr=0x%08h, Data=0x%08h", $time, addr, data);
        end
    endtask
    
    //==========================================================================
    // APB Read Task
    //==========================================================================
    task apb_read;
        input  [31:0] addr;
        output [31:0] data;
        begin
            @(posedge pclk);
            psel    = 1'b1;
            penable = 1'b0;
            pwrite  = 1'b0;
            paddr   = addr;
            
            @(posedge pclk);
            penable = 1'b1;
            
            @(posedge pclk);
            data    = prdata;
            psel    = 1'b0;
            penable = 1'b0;
            
            $display("[TIME=%0t] APB READ: Addr=0x%08h, Data=0x%08h", $time, addr, data);
        end
    endtask
    
    //==========================================================================
    // Check Task
    //==========================================================================
    task check_result;
        input [31:0] expected;
        input [31:0] actual;
        input [200*8:1] test_name;
        begin
            test_count = test_count + 1;
            if (expected === actual) begin
                $display("[PASS] Test #%0d: %0s (Expected: 0x%08h, Got: 0x%08h)", 
                         test_count, test_name, expected, actual);
            end else begin
                $display("[FAIL] Test #%0d: %0s (Expected: 0x%08h, Got: 0x%08h)", 
                         test_count, test_name, expected, actual);
                error_count = error_count + 1;
            end
        end
    endtask
    
    //==========================================================================
    // PWM Duty Cycle Check Task
    //==========================================================================
    task check_pwm_duty;
        input [31:0] period;
        input [31:0] duty;
        input [200*8:1] test_name;
        integer local_high, local_low;
        begin
            local_high = 0;
            local_low = 0;
            
            // Wait for counter to reset to ensure we start from beginning
            wait(u_apb_pwm_ctrl.pwm_counter == 0);
            @(posedge pclk);
            
            // Count high and low cycles over one complete period
            for (i = 0; i < period; i = i + 1) begin
                @(posedge pclk);
                if (pwm_out == 1'b1)
                    local_high = local_high + 1;
                else
                    local_low = local_low + 1;
            end
            
            test_count = test_count + 1;
            $display("[INFO] PWM Analysis: HIGH cycles=%0d, LOW cycles=%0d, Total=%0d", 
                     local_high, local_low, local_high + local_low);
            
            if (local_high == duty) begin
                $display("[PASS] Test #%0d: %0s (Expected Duty=%0d, Got=%0d)", 
                         test_count, test_name, duty, local_high);
            end else begin
                $display("[FAIL] Test #%0d: %0s (Expected Duty=%0d, Got=%0d)", 
                         test_count, test_name, duty, local_high);
                error_count = error_count + 1;
            end
        end
    endtask
    
    //==========================================================================
    // Main Test Sequence
    //==========================================================================
    initial begin
        // Initialize
        error_count = 0;
        test_count  = 0;
        
        psel    = 0;
        penable = 0;
        pwrite  = 0;
        paddr   = 0;
        pwdata  = 0;
        presetn = 0;
        
        $display("==============================================================================");
        $display("  APB PWM Controller Verification");
        $display("  Engineer: Senior Design Engineer");
        $display("==============================================================================");
        $display("");
        
        // Reset sequence
        $display("[INFO] Applying Reset...");
        repeat(10) @(posedge pclk);
        presetn = 1;
        repeat(5) @(posedge pclk);
        $display("[INFO] Reset Released");
        $display("");
        
        //======================================================================
        // Test 1: Register Write/Read Test
        //======================================================================
        $display("----------------------------------------------------------------------");
        $display("TEST 1: APB Register Write/Read Verification");
        $display("----------------------------------------------------------------------");
        
        // Write to CTRL register
        apb_write(32'h0000_0000, 32'h0000_0001);
        
        // Read back CTRL register
        apb_read(32'h0000_0000, read_data);
        check_result(32'h0000_0001, read_data, "CTRL Register Write/Read");
        
        // Write to PERIOD register
        apb_write(32'h0000_0004, 32'h0000_0064);  // Period = 100
        
        // Read back PERIOD register
        apb_read(32'h0000_0004, read_data);
        check_result(32'h0000_0064, read_data, "PERIOD Register Write/Read");
        
        // Write to DUTY register
        apb_write(32'h0000_0008, 32'h0000_0032);  // Duty = 50
        
        // Read back DUTY register
        apb_read(32'h0000_0008, read_data);
        check_result(32'h0000_0032, read_data, "DUTY Register Write/Read");
        
        $display("");
        
        //======================================================================
        // Test 2: PWM Output Verification (Disabled State)
        //======================================================================
        $display("----------------------------------------------------------------------");
        $display("TEST 2: PWM Output when Disabled");
        $display("----------------------------------------------------------------------");
        
        // Disable PWM
        apb_write(32'h0000_0000, 32'h0000_0000);
        
        // Wait and check PWM output should be 0
        repeat(10) @(posedge pclk);
        check_result(1'b0, pwm_out, "PWM Output Disabled");
        
        $display("");
        
        //======================================================================
        // Test 3: PWM Output Verification (Enabled, 50% Duty Cycle)
        //======================================================================
        $display("----------------------------------------------------------------------");
        $display("TEST 3: PWM Output with 50 percent Duty Cycle");
        $display("----------------------------------------------------------------------");
        
        // Configure PWM: Period=100, Duty=50 (50% duty cycle)
        apb_write(32'h0000_0004, 32'h0000_0064);  // Period = 100
        apb_write(32'h0000_0008, 32'h0000_0032);  // Duty = 50
        apb_write(32'h0000_0000, 32'h0000_0001);  // Enable
        
        // Check PWM duty cycle
        check_pwm_duty(100, 50, "PWM 50 percent Duty Cycle");
        
        $display("");
        
        //======================================================================
        // Test 4: PWM Output Verification (25% Duty Cycle)
        //======================================================================
        $display("----------------------------------------------------------------------");
        $display("TEST 4: PWM Output with 25 percent Duty Cycle");
        $display("----------------------------------------------------------------------");
        
        // Reconfigure PWM: Period=100, Duty=25 (25% duty cycle)
        apb_write(32'h0000_0008, 32'h0000_0019);  // Duty = 25
        
        // Check PWM duty cycle
        check_pwm_duty(100, 25, "PWM 25 percent Duty Cycle");
        
        $display("");
        
        //======================================================================
        // Test 5: PWM Output Verification (75% Duty Cycle)
        //======================================================================
        $display("----------------------------------------------------------------------");
        $display("TEST 5: PWM Output with 75 percent Duty Cycle");
        $display("----------------------------------------------------------------------");
        
        // Reconfigure PWM: Period=100, Duty=75 (75% duty cycle)
        apb_write(32'h0000_0008, 32'h0000_004B);  // Duty = 75
        
        // Check PWM duty cycle
        check_pwm_duty(100, 75, "PWM 75 percent Duty Cycle");
        
        $display("");
        
        //======================================================================
        // Test 6: PWM Different Period Test (Period=50, Duty=30)
        //======================================================================
        $display("----------------------------------------------------------------------");
        $display("TEST 6: PWM with Different Period (Period=50, Duty=30)");
        $display("----------------------------------------------------------------------");
        
        // Reconfigure PWM: Period=50, Duty=30
        apb_write(32'h0000_0004, 32'h0000_0032);  // Period = 50
        apb_write(32'h0000_0008, 32'h0000_001E);  // Duty = 30
        
        // Check PWM duty cycle
        check_pwm_duty(50, 30, "PWM Period=50, Duty=30");
        
        $display("");
        
        //======================================================================
        // Test 7: Enable/Disable Toggle Test
        //======================================================================
        $display("----------------------------------------------------------------------");
        $display("TEST 7: Enable/Disable Toggle Test");
        $display("----------------------------------------------------------------------");
        
        // Disable PWM
        apb_write(32'h0000_0000, 32'h0000_0000);
        repeat(5) @(posedge pclk);
        check_result(1'b0, pwm_out, "PWM Disabled State");
        
        // Re-enable PWM
        apb_write(32'h0000_0000, 32'h0000_0001);
        repeat(10) @(posedge pclk);
        $display("[INFO] PWM Re-enabled");
        
        // Verify it works after re-enable
        check_pwm_duty(50, 30, "PWM After Re-enable");
        
        $display("");
        
        //======================================================================
        // Test 8: Edge Case - Duty = 0 (Always Low)
        //======================================================================
        $display("----------------------------------------------------------------------");
        $display("TEST 8: Edge Case - Duty = 0 (Always Low)");
        $display("----------------------------------------------------------------------");
        
        apb_write(32'h0000_0008, 32'h0000_0000);  // Duty = 0
        
        check_pwm_duty(50, 0, "PWM Duty=0 (Always Low)");
        
        $display("");
        
        //======================================================================
        // Test 9: Edge Case - Duty = Period (Always High)
        //======================================================================
        $display("----------------------------------------------------------------------");
        $display("TEST 9: Edge Case - Duty = Period (Always High)");
        $display("----------------------------------------------------------------------");
        
        apb_write(32'h0000_0008, 32'h0000_0032);  // Duty = 50 (same as period)
        
        check_pwm_duty(50, 50, "PWM Duty=Period (Always High)");
        
        $display("");
        
        //======================================================================
        // Final Report
        //======================================================================
        $display("==============================================================================");
        $display("  VERIFICATION SUMMARY");
        $display("==============================================================================");
        $display("  Total Tests Run    : %0d", test_count);
        $display("  Tests Passed       : %0d", test_count - error_count);
        $display("  Tests Failed       : %0d", error_count);
        $display("------------------------------------------------------------------------------");
        if (error_count == 0) begin
            $display("  STATUS: *** ALL TESTS PASSED *** ");
            $display("  ");
            $display("  CONGRATULATIONS! The APB PWM Controller IP is fully verified.");
            $display("  All APB transactions and PWM waveforms are working correctly.");
        end else begin
            $display("  STATUS: *** VERIFICATION FAILED ***");
            $display("  Please review the failure logs above.");
        end
        $display("==============================================================================");
        $display("");
        
        // Finish simulation
        repeat(10) @(posedge pclk);
        $finish;
    end
    
    //==========================================================================
    // Timeout Watchdog
    //==========================================================================
    initial begin
        #2000000;  // 2ms timeout
        $display("ERROR: Simulation timeout!");
        $finish;
    end
    
    //==========================================================================
    // Waveform Dump (VCD format)
    //==========================================================================
    initial begin
        $dumpfile("apb_pwm_ctrl.vcd");
        $dumpvars(0, tb_apb_pwm_ctrl);
    end

endmodule
