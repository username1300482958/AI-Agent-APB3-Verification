//==============================================================================
// Module Name  : apb_pwm_ctrl
// Description  : AMBA APB3 compliant PWM Controller IP
// Engineer     : Senior Design Engineer
// Company      : Global Fabless Semiconductor Company
//==============================================================================

module apb_pwm_ctrl (
    // APB3 Interface
    input  wire         pclk,           // APB clock
    input  wire         presetn,        // APB reset (active low)
    input  wire         psel,           // APB select
    input  wire         penable,        // APB enable
    input  wire         pwrite,         // APB write enable
    input  wire [31:0]  paddr,          // APB address
    input  wire [31:0]  pwdata,         // APB write data
    output reg  [31:0]  prdata,         // APB read data
    output wire         pready,         // APB ready (always ready)
    
    // PWM Output
    output reg          pwm_out         // PWM output signal
);

    //==========================================================================
    // Register Map Definition
    //==========================================================================
    localparam ADDR_CTRL   = 32'h0000_0000;  // Control Register
    localparam ADDR_PERIOD = 32'h0000_0004;  // Period Register
    localparam ADDR_DUTY   = 32'h0000_0008;  // Duty Cycle Register
    
    //==========================================================================
    // Internal Registers
    //==========================================================================
    reg         ctrl_enable;        // Enable bit from CTRL register
    reg [31:0]  period_reg;         // Period value
    reg [31:0]  duty_reg;           // Duty cycle value
    reg [31:0]  pwm_counter;        // PWM counter for timing
    
    //==========================================================================
    // APB Interface - Always Ready
    //==========================================================================
    assign pready = 1'b1;  // This design is always ready
    
    //==========================================================================
    // APB Write Logic
    //==========================================================================
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            ctrl_enable <= 1'b0;
            period_reg  <= 32'h0000_0000;
            duty_reg    <= 32'h0000_0000;
        end else begin
            // APB Write Transaction: psel && penable && pwrite
            if (psel && penable && pwrite) begin
                case (paddr)
                    ADDR_CTRL: begin
                        ctrl_enable <= pwdata[0];  // bit 0: enable
                    end
                    ADDR_PERIOD: begin
                        period_reg <= pwdata;
                    end
                    ADDR_DUTY: begin
                        duty_reg <= pwdata;
                    end
                    default: begin
                        // Invalid address - no action
                    end
                endcase
            end
        end
    end
    
    //==========================================================================
    // APB Read Logic
    //==========================================================================
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            prdata <= 32'h0000_0000;
        end else begin
            // APB Read Transaction: psel && !pwrite
            if (psel && !pwrite) begin
                case (paddr)
                    ADDR_CTRL: begin
                        prdata <= {31'h0, ctrl_enable};  // Return enable bit
                    end
                    ADDR_PERIOD: begin
                        prdata <= period_reg;
                    end
                    ADDR_DUTY: begin
                        prdata <= duty_reg;
                    end
                    default: begin
                        prdata <= 32'h0000_0000;  // Invalid address returns 0
                    end
                endcase
            end else begin
                prdata <= 32'h0000_0000;
            end
        end
    end
    
    //==========================================================================
    // PWM Generation Logic
    //==========================================================================
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            pwm_counter <= 32'h0000_0000;
            pwm_out     <= 1'b0;
        end else begin
            if (ctrl_enable && (period_reg > 0)) begin
                // Increment counter
                if (pwm_counter >= period_reg - 1) begin
                    pwm_counter <= 32'h0000_0000;
                end else begin
                    pwm_counter <= pwm_counter + 1;
                end
                
                // Generate PWM output
                if (pwm_counter < duty_reg) begin
                    pwm_out <= 1'b1;
                end else begin
                    pwm_out <= 1'b0;
                end
            end else begin
                // Disabled or invalid period
                pwm_counter <= 32'h0000_0000;
                pwm_out     <= 1'b0;
            end
        end
    end

endmodule
