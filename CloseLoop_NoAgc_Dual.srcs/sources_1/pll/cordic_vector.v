`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/05/12 11:15:21
// Design Name: 
// Module Name: cordic_vector
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: CORDIC algorithm in vector mode for phase and amplitude calculation
//              Serial implementation (one iteration per clock)
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module cordic_vector #(
    parameter ITER = 16         // Number of iterations (16 for better accuracy)
) (
    input               clk,
    input               start,          // Start signal for calculation
    input               rst_n,
    input signed [15:0] x_in,           // Input vector X (16-bit signed)
    input signed [15:0] y_in,           // Input vector Y
    output reg signed [15:0] phase_out, // Phase (-32768~+32767 maps to -pi~+pi)
    output  [15:0]      amp_out,        // Amplitude (0~65535)
    output reg          done            // Calculation complete flag
);

// State machine definition
localparam IDLE         = 2'b00;
localparam PRE_CA       = 2'b01;
localparam CALC         = 2'b10;
localparam DONE         = 2'b11;

reg [1:0] state = IDLE;
reg [4:0] iter_count = 0;  // Iteration counter (0-16)

reg signed [33:0] amp_temp;
assign amp_out = {amp_temp[33], amp_temp[30:16]};

// Pre-calculated arctan(2^-i) angle table (Q2.14 format)   
// pi <=> 2(real) <=> 2^15(Q2.14)
// pi/4 <=> 0.5(real) <=> 2^13(Q2.14)
// First 16 values for higher precision
reg [15:0] atan_table [0:15];
initial begin
    atan_table[0]  = 16'h2000; // atan(2^0)  = 45.000 deg = 0.7854 rad
    atan_table[1]  = 16'h12E4; // atan(2^-1) = 26.565 deg = 0.4636 rad
    atan_table[2]  = 16'h09FB; // atan(2^-2) = 14.036 deg = 0.2450 rad
    atan_table[3]  = 16'h0511; // atan(2^-3) = 7.125  deg = 0.1244 rad
    atan_table[4]  = 16'h028B; // atan(2^-4) = 3.576  deg = 0.0624 rad
    atan_table[5]  = 16'h0145; // atan(2^-5) = 1.790  deg = 0.0312 rad
    atan_table[6]  = 16'h00A2; // atan(2^-6) = 0.895  deg = 0.0156 rad
    atan_table[7]  = 16'h0051; // atan(2^-7) = 0.448  deg = 0.0078 rad
    atan_table[8]  = 16'h0028; // atan(2^-8) = 0.224  deg = 0.0039 rad
    atan_table[9]  = 16'h0014; // atan(2^-9) = 0.112  deg = 0.0020 rad
    atan_table[10] = 16'h000A; // atan(2^-10)= 0.056  deg = 0.0010 rad
    atan_table[11] = 16'h0005; // atan(2^-11)= 0.028  deg = 0.0005 rad
    atan_table[12] = 16'h0003; // atan(2^-12)= 0.014  deg = 0.0002 rad
    atan_table[13] = 16'h0001; // atan(2^-13)= 0.007  deg = 0.0001 rad
    atan_table[14] = 16'h0001; // atan(2^-14)= 0.003  deg = 0.0001 rad
    atan_table[15] = 16'h0000; // atan(2^-15)= 0.002  deg = 0.0000 rad
end

// Working registers
reg signed [17:0] x_curr;  // Current X value (extended by 2 bits to prevent overflow)
reg signed [17:0] y_curr;  // Current Y value
reg signed [15:0] z_curr;  // Current accumulated angle (Q2.14)

// CORDIC gain compensation factor (K approx= 0.607)
localparam [15:0] CORDIC_GAIN = 16'h9B74;  // 0.607 in Q0.16 format

// Serial CORDIC implementation
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        iter_count <= 0;
        x_curr <= 18'd0;
        y_curr <= 18'd0;
        z_curr <= 16'd0;
        phase_out <= 16'd0;
        // amp_out <= 16'd0;
        done <= 0;
        amp_temp <= 34'd0;

    end else begin
        case (state)
            IDLE: begin
                done <= 0;
                if (start) begin
                    // Initialize calculation
                    if((x_in[14:0]==15'b0)&&(y_in[14:0]==15'b0)) begin
                        x_curr <= 18'd0;
                        z_curr <= 16'd0;
                        state <= DONE;
                    end
                    else begin
                        x_curr <= {x_in[15], x_in[15], x_in};  // Sign extend to 18 bits
                        y_curr <= {y_in[15], y_in[15], y_in};
                        z_curr <= 16'd0;
                        iter_count <= 0;
                        state <= PRE_CA;
                    end
                end
            end
            
            PRE_CA: begin
                //Perform pre-rotate 180deg
                if(x_curr[17]) begin
                    x_curr <= -x_curr;
                    y_curr <= -y_curr;
                    z_curr <= 16'h8000;  //pi = 16'h8000 in Q2.14
                end
                state <= CALC;
            end

            CALC: begin
                // Perform one CORDIC iteration per clock cycle
                if (y_curr[17]) begin  // y is negative, rotate counter-clockwise
                    x_curr <= x_curr - (y_curr >>> iter_count);
                    y_curr <= y_curr + (x_curr >>> iter_count);
                    z_curr <= z_curr - atan_table[iter_count];
                end else begin         // y is positive, rotate clockwise
                    x_curr <= x_curr + (y_curr >>> iter_count);
                    y_curr <= y_curr - (x_curr >>> iter_count);
                    z_curr <= z_curr + atan_table[iter_count];
                end
                
                // Increment iteration counter
                iter_count <= iter_count + 1;
                
                // Check if all iterations are complete
                if (iter_count == ITER-1) begin
                    state <= DONE;
                end
            end
            
            DONE: begin
                // Calculate final outputs
                phase_out <= z_curr;
                // Apply CORDIC gain compensation (K approx= 0.607)
                amp_temp <= x_curr * CORDIC_GAIN;

                done <= 1;
                state <= IDLE;
            end
        endcase
    end
end

endmodule