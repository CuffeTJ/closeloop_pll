`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/05/12 11:12:30
// Design Name: 
// Module Name: sine_lut
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Sine/cosine lookup table with quarter-wave symmetry (BRAM-friendly)
// 
// Dependencies: sine_table.mem
// 
// Revision:
// Revision 0.01 - File Created
// Revision 1.00 - Modified for BRAM inference by adding a pipeline stage.
// Revision 1.01 - Added lut_st/lut_done control signals. Restored original cosine logic.
// Additional Comments:
// - Assert lut_st for one clock cycle to start the lookup.
// - lut_done will be asserted two clock cycles after lut_st, indicating valid output.
// 
//////////////////////////////////////////////////////////////////////////////////

module sine_lut (
    input                 clk,          // System clock
    input                 lut_st,       // Start lookup (pulse for one cycle)
    
    input [15:0]          phase_sin,    // Phase for sine (sampled on lut_st)
    input [15:0]          phase_cos,    // Phase for cosine (sampled on lut_st)
    input [15:0]          phase_shift,  // Phase for sine-shift (sampled on lut_st)
    
    output reg            lut_done,     // Lookup done, output data is valid
    output reg [15:0]     sin_out,      // Sine output (16-bit signed)
    output reg [15:0]     cos_out,      // Cosine output (16-bit signed)
    output reg [15:0]     shift_out     // Sine-phase-shifted output (16-bit signed)
);

// Sine lookup table - only stores 1/4 cycle (0-90 degrees)
// Uses Block RAM for efficient implementation
(* ram_style = "block" *) reg [15:0] sin_table [0:16383];

// Initialize sine table from external file
initial begin
    $readmemh("sine_table.mem", sin_table);
end

// Internal registers for pipeline stage 1
reg [1:0]   sin_quadrant_reg;
reg [13:0]  sin_addr_reg;
reg [1:0]   cos_quadrant_reg;
reg [13:0]  cos_addr_reg;
reg [1:0]   shift_quadrant_reg;
reg [13:0]  shift_addr_reg;

// Pipeline register to track the valid signal through the pipeline
reg stage1_valid;

// Control Signal Pipeline: Generate lut_done two cycles after lut_st
always @(posedge clk) begin
    stage1_valid <= lut_st;
    lut_done     <= stage1_valid;
end

// Stage 1: Sample inputs, calculate address, and register them.
// This stage executes only when lut_st is high.
always @(posedge clk) begin
    if (lut_st) begin
        // Sine address generation
        sin_quadrant_reg <= phase_sin[15:14];
        sin_addr_reg     <= (phase_sin[15:14] == 2'b00 || phase_sin[15:14] == 2'b10) ? 
                            phase_sin[13:0] : ~phase_sin[13:0];

        // Cosine address generation
        cos_quadrant_reg <= phase_cos[15:14];
        cos_addr_reg     <= (phase_cos[15:14] == 2'b00 || phase_cos[15:14] == 2'b10) ? 
                            phase_cos[13:0] : ~phase_cos[13:0];
                            
        // Sine-Shifted address generation
        shift_quadrant_reg <= phase_shift[15:14];
        shift_addr_reg     <= (phase_shift[15:14] == 2'b00 || phase_shift[15:14] == 2'b10) ? 
                              phase_shift[13:0] : ~phase_shift[13:0];
    end
end

// Stage 2: Perform synchronous BRAM read and apply quadrant logic.
// This stage executes when the data from stage 1 is valid.
always @(posedge clk) begin
    if (stage1_valid) begin
        // Sine lookup with quadrant handling using registered address
        case (sin_quadrant_reg)
            2'b00: sin_out <=  sin_table[sin_addr_reg];
            2'b01: sin_out <=  sin_table[sin_addr_reg];
            2'b10: sin_out <= -sin_table[sin_addr_reg];
            2'b11: sin_out <= -sin_table[sin_addr_reg];
        endcase
        
        // Cosine lookup with quadrant handling (restored to original logic)
        case (cos_quadrant_reg)
            2'b00: cos_out <=  sin_table[cos_addr_reg];
            2'b01: cos_out <=  sin_table[cos_addr_reg];
            2'b10: cos_out <= -sin_table[cos_addr_reg];
            2'b11: cos_out <= -sin_table[cos_addr_reg];
        endcase
        
        // Sine-Shifted lookup with quadrant handling
        case (shift_quadrant_reg)
            2'b00: shift_out <=  sin_table[shift_addr_reg];
            2'b01: shift_out <=  sin_table[shift_addr_reg];
            2'b10: shift_out <= -sin_table[shift_addr_reg];
            2'b11: shift_out <= -sin_table[shift_addr_reg];
        endcase
    end
end

endmodule