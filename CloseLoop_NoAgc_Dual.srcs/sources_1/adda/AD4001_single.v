module ad4001_driver_single (
    // System Signals
    input           clk_fs,
    input           reset_n,

    // ADC Interface
    output          adc_cnv,
    output          adc_sck,
    input           adc_sdo,

    // Data Output
    output [15:0]   conversion_data,
    output          data_ready
);

    // =================================================================================
    // Parameters
    // =================================================================================
    parameter SAMPLING_RATE_SPS = 1_000_000;
    localparam F_CLK_HZ = 100_000_000;
    localparam TCYC_CLOCKS = (F_CLK_HZ / SAMPLING_RATE_SPS) - 1;
    localparam TCONV_CLOCKS = 350/ 10; // tCONV = 350ns, clk_fs period = 10ns
    localparam DATA_READ_CLOCKS = 16;

    // =================================================================================
    // State Machine Definition
    // =================================================================================
    localparam S_INIT_START    = 3'd0;
    localparam S_IDLE          = 3'd1;
    localparam S_CONVERT_START = 3'd2;
    localparam S_WAIT_CONV     = 3'd3;
    localparam S_READ_DATA     = 3'd4;
    localparam S_WAIT_TCYC     = 3'd5;

    // =================================================================================
    // Internal Registers
    // =================================================================================
    reg [2:0]  state_reg;
    reg [15:0] tcyc_counter_reg;
    reg [5:0]  bit_counter_reg;
    reg [15:0] sdo_shift_reg;

    reg adc_cnv_reg;
    reg adc_sck_reg;
    reg [15:0] conversion_data_reg;
    reg data_ready_reg;

    // =================================================================================
    // Single-Process State Machine (Sequential Logic)
    // =================================================================================
    always @(posedge clk_fs or negedge reset_n) begin
        if (!reset_n) begin
            // Reset state: assign deterministic initial values
            state_reg           <= S_INIT_START;
            tcyc_counter_reg    <= 16'd0;
            bit_counter_reg     <= 6'd0;
            sdo_shift_reg       <= 16'd0;
            adc_cnv_reg         <= 1'b1;
            adc_sck_reg         <= 1'b0;
            conversion_data_reg <= 16'd0;
            data_ready_reg      <= 1'b0;
        end 
        else begin
            // Default assignment to create a single-cycle pulse for data_ready
            //data_ready_reg <= 1'b0;

            case (state_reg)
                // --- State: Initialization ---
                S_INIT_START: begin
                    adc_cnv_reg         <= 1'b0;
                    adc_sck_reg         <= 1'b0;
                    bit_counter_reg     <= 0;
                    state_reg           <= S_IDLE;
                end

                // --- State: Idle ---
                S_IDLE: begin
                    // This state is transitional, immediately moving to start the next conversion.
                    // It can be useful for alignment with other modules if needed.
                    state_reg <= S_CONVERT_START;
                end

                // --- State: Start Conversion ---
                S_CONVERT_START: begin
                    adc_cnv_reg         <= 1'b1; // Start conversion with a rising edge on CNV
                    tcyc_counter_reg    <= 0;
                    state_reg           <= S_WAIT_CONV;
                end

                // --- State: Wait for tCONV ---
                S_WAIT_CONV: begin
                    tcyc_counter_reg <= tcyc_counter_reg + 1;
                    if (tcyc_counter_reg == (TCONV_CLOCKS - 4)) begin
                        adc_cnv_reg     <= 1'b0; // Bring CNV low before reading
                    end
                    else if (tcyc_counter_reg == TCONV_CLOCKS) begin
                        bit_counter_reg <= 0;
                        sdo_shift_reg   <= 0;
                        state_reg       <= S_READ_DATA;
                    end
                end

                // --- State: Read Data ---
                S_READ_DATA: begin
                    tcyc_counter_reg <= tcyc_counter_reg + 1;
                    adc_sck_reg      <= ~adc_sck_reg; // Generate SCK clock
                    
                    // Sample data on the falling edge of SCK (when adc_sck_reg is 1)
                    if (adc_sck_reg == 1'b1) begin
                        sdo_shift_reg   <= {sdo_shift_reg[14:0], adc_sdo};
                        bit_counter_reg <= bit_counter_reg + 1;
                    end

                    if (bit_counter_reg == DATA_READ_CLOCKS) begin
                        adc_sck_reg         <= 1'b0;
                        conversion_data_reg <= sdo_shift_reg;
                        data_ready_reg      <= 1'b1; // Assert data_ready for one cycle
                        state_reg           <= S_WAIT_TCYC;
                    end
                end

                // --- State: Wait for Cycle End ---
                S_WAIT_TCYC: begin
                    tcyc_counter_reg <= tcyc_counter_reg + 1;
                    if (tcyc_counter_reg >= TCYC_CLOCKS - 1) begin
                        state_reg <= S_CONVERT_START; // Start next conversion cycle
                        data_ready_reg <= 1'b0;
                    end
                end

                default: begin
                    state_reg <= S_INIT_START;
                end
            endcase
        end
    end

    // =================================================================================
    // Output Assignments
    // =================================================================================
    assign adc_cnv         = adc_cnv_reg;
    assign adc_sck         = adc_sck_reg;
    assign conversion_data = conversion_data_reg;
    assign data_ready      = data_ready_reg;


endmodule
