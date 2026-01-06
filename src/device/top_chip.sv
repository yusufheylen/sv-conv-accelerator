// Version 3: Optimal loop ordering
module top_chip #(
    parameter int IO_DATA_WIDTH = 16,
    parameter int ACCUMULATION_WIDTH = 32,
    parameter int FEATURE_MAP_WIDTH = 130,
    parameter int FEATURE_MAP_HEIGHT = 130,
    parameter int INPUT_NB_CHANNELS = 2,
    parameter int OUTPUT_NB_CHANNELS = 16
) (
    input logic clk,
    input logic arst_n_in, //asynchronous reset, active low

    // System Run-time Configuration
    input logic [1:0] conv_kernel_mode,
    // Currently support 3 sizes:
    // 0: 1x1
    // 1: 3x3
    // 2: 5x5
    input logic [1:0] conv_stride_mode,
    // Currently support 3 modes:
    // 0: step = 1
    // 1: step = 2
    // 2: step = 4

    // System data bus
    inout logic [47:0] io_bus,

    //debug
    input logic intf_x,
    input logic intf_y,

    input logic a_valid,
    output logic a_ready,

    input logic b_valid,
    output logic b_ready,

    // Output control signal
    output logic output_valid,

    //TODO: send 3 for each output
    output logic [$clog2(FEATURE_MAP_WIDTH)-1:0 ] output_x,
    output logic [$clog2(FEATURE_MAP_HEIGHT)-1:0] output_y,
    output logic [$clog2(OUTPUT_NB_CHANNELS)-1:0] output_ch,


    input  logic start,
    output logic done, // Signal all done
    output logic running
);
  logic [47:0] io_bus_driver;
  logic chip_drive_enable;

  assign io_bus = chip_drive_enable ? io_bus_driver : 'z;


// -- Kernel weights data registers -- //
  // NOTE: Kernel load order is: for row, for chin 

  // Input Channel 0
  `REG(16, regKernel_kx0_ky0_ch0); `REG(16, regKernel_kx1_ky0_ch0); `REG(16, regKernel_kx2_ky0_ch0); // Row 1
  `REG(16, regKernel_kx0_ky1_ch0); `REG(16, regKernel_kx1_ky1_ch0); `REG(16, regKernel_kx2_ky1_ch0); // Row 2
  `REG(16, regKernel_kx0_ky2_ch0); `REG(16, regKernel_kx1_ky2_ch0); `REG(16, regKernel_kx2_ky2_ch0); // Row 3

  // Input Channel 1
  `REG(16, regKernel_kx0_ky0_ch1); `REG(16, regKernel_kx1_ky0_ch1); `REG(16, regKernel_kx2_ky0_ch1); // Row 1
  `REG(16, regKernel_kx0_ky1_ch1); `REG(16, regKernel_kx1_ky1_ch1); `REG(16, regKernel_kx2_ky1_ch1); // Row 2
  `REG(16, regKernel_kx0_ky2_ch1); `REG(16, regKernel_kx1_ky2_ch1); `REG(16, regKernel_kx2_ky2_ch1); // Row 3

  // Kernel regs control signals | Note: We write a row at a time
  logic write_regKernel_ky0_ch0; // Row 1 | Chin 0 
  logic write_regKernel_ky1_ch0; // Row 2 | Chin 0
  logic write_regKernel_ky2_ch0; // Row 3 | Chin 0
  
  logic write_regKernel_ky0_ch1; // Row 1 | Chin 1 
  logic write_regKernel_ky1_ch1; // Row 2 | Chin 1
  logic write_regKernel_ky2_ch1; // Row 3 | Chin 1

  assign regKernel_kx0_ky0_ch0_we = write_regKernel_ky0_ch0; assign regKernel_kx1_ky0_ch0_we = write_regKernel_ky0_ch0; assign regKernel_kx2_ky0_ch0_we = write_regKernel_ky0_ch0; 
  assign regKernel_kx0_ky1_ch0_we = write_regKernel_ky1_ch0; assign regKernel_kx1_ky1_ch0_we = write_regKernel_ky1_ch0; assign regKernel_kx2_ky1_ch0_we = write_regKernel_ky1_ch0; 
  assign regKernel_kx0_ky2_ch0_we = write_regKernel_ky2_ch0; assign regKernel_kx1_ky2_ch0_we = write_regKernel_ky2_ch0; assign regKernel_kx2_ky2_ch0_we = write_regKernel_ky2_ch0; 

  assign regKernel_kx0_ky0_ch1_we = write_regKernel_ky0_ch1; assign regKernel_kx1_ky0_ch1_we = write_regKernel_ky0_ch1; assign regKernel_kx2_ky0_ch1_we = write_regKernel_ky0_ch1; 
  assign regKernel_kx0_ky1_ch1_we = write_regKernel_ky1_ch1; assign regKernel_kx1_ky1_ch1_we = write_regKernel_ky1_ch1; assign regKernel_kx2_ky1_ch1_we = write_regKernel_ky1_ch1; 
  assign regKernel_kx0_ky2_ch1_we = write_regKernel_ky2_ch1; assign regKernel_kx1_ky2_ch1_we = write_regKernel_ky2_ch1; assign regKernel_kx2_ky2_ch1_we = write_regKernel_ky2_ch1; 

  // Assign correct portion of the data (io_bus)
  assign regKernel_kx0_ky0_ch0_next = io_bus[15:0]; 
  assign regKernel_kx1_ky0_ch0_next = io_bus[31:16]; 
  assign regKernel_kx2_ky0_ch0_next = io_bus[47:32];
  assign regKernel_kx0_ky1_ch0_next = io_bus[15:0]; 
  assign regKernel_kx1_ky1_ch0_next = io_bus[31:16]; 
  assign regKernel_kx2_ky1_ch0_next = io_bus[47:32];
  assign regKernel_kx0_ky2_ch0_next = io_bus[15:0]; 
  assign regKernel_kx1_ky2_ch0_next = io_bus[31:16]; 
  assign regKernel_kx2_ky2_ch0_next = io_bus[47:32];

  assign regKernel_kx0_ky0_ch1_next = io_bus[15:0]; 
  assign regKernel_kx1_ky0_ch1_next = io_bus[31:16]; 
  assign regKernel_kx2_ky0_ch1_next = io_bus[47:32];
  assign regKernel_kx0_ky1_ch1_next = io_bus[15:0]; 
  assign regKernel_kx1_ky1_ch1_next = io_bus[31:16]; 
  assign regKernel_kx2_ky1_ch1_next = io_bus[47:32];
  assign regKernel_kx0_ky2_ch1_next = io_bus[15:0]; 
  assign regKernel_kx1_ky2_ch1_next = io_bus[31:16]; 
  assign regKernel_kx2_ky2_ch1_next = io_bus[47:32];

// ----------------------------------- //
// -------- Multiplier Array  -------- //
  
  // Output wires 
  logic signed [47:0] mul_array_ch0 [0:2]; // e.g. [15:0][0] = kx0, ky0
  logic signed [47:0] mul_array_ch1 [0:2];  

  // Input kernel wires
  logic signed [47:0] kernel_ch0 [0:2];

  assign kernel_ch0[0][15:0]   = regKernel_kx0_ky0_ch0; 
  assign kernel_ch0[0][31:16]  = regKernel_kx1_ky0_ch0; 
  assign kernel_ch0[0][47:32]  = regKernel_kx2_ky0_ch0;

  assign kernel_ch0[1][15:0]   = regKernel_kx0_ky1_ch0; 
  assign kernel_ch0[1][31:16]  = regKernel_kx1_ky1_ch0; 
  assign kernel_ch0[1][47:32]  = regKernel_kx2_ky1_ch0;

  assign kernel_ch0[2][15:0]   = regKernel_kx0_ky2_ch0; 
  assign kernel_ch0[2][31:16]  = regKernel_kx1_ky2_ch0; 
  assign kernel_ch0[2][47:32]  = regKernel_kx2_ky2_ch0;

  logic signed [47:0] kernel_ch1 [0:2];

  assign kernel_ch1[0][15:0]   = regKernel_kx0_ky0_ch1; 
  assign kernel_ch1[0][31:16]  = regKernel_kx1_ky0_ch1; 
  assign kernel_ch1[0][47:32]  = regKernel_kx2_ky0_ch1;

  assign kernel_ch1[1][15:0]   = regKernel_kx0_ky1_ch1; 
  assign kernel_ch1[1][31:16]  = regKernel_kx1_ky1_ch1; 
  assign kernel_ch1[1][47:32]  = regKernel_kx2_ky1_ch1;

  assign kernel_ch1[2][15:0]   = regKernel_kx0_ky2_ch1; 
  assign kernel_ch1[2][31:16]  = regKernel_kx1_ky2_ch1; 
  assign kernel_ch1[2][47:32]  = regKernel_kx2_ky2_ch1;


  // Memory output lines is input to mul array
  logic signed [47:0] memory_array_ch0_out [0:2];
  logic signed [47:0] memory_array_ch1_out [0:2];

  multiplier_array #(.OUT_SCALE(16)) muls_ch0 (.kernel(kernel_ch0), .data(memory_array_ch0_out), .product(mul_array_ch0) );     // Kernel 0 (Input Channel 0)
  multiplier_array #(.OUT_SCALE(16)) muls_ch1 (.kernel(kernel_ch1), .data(memory_array_ch1_out), .product(mul_array_ch1) );     // Kernel 1 (Input Channel 1)

  // Multiplier Output Pipeline registers 
  
  // Input Channel 0
  `REG(16, regMul_kx0_ky0_ch0); `REG(16, regMul_kx1_ky0_ch0); `REG(16, regMul_kx2_ky0_ch0); // Row 1
  `REG(16, regMul_kx0_ky1_ch0); `REG(16, regMul_kx1_ky1_ch0); `REG(16, regMul_kx2_ky1_ch0); // Row 2
  `REG(16, regMul_kx0_ky2_ch0); `REG(16, regMul_kx1_ky2_ch0); `REG(16, regMul_kx2_ky2_ch0); // Row 3

  // Input Channel 1
  `REG(16, regMul_kx0_ky0_ch1); `REG(16, regMul_kx1_ky0_ch1); `REG(16, regMul_kx2_ky0_ch1); // Row 1
  `REG(16, regMul_kx0_ky1_ch1); `REG(16, regMul_kx1_ky1_ch1); `REG(16, regMul_kx2_ky1_ch1); // Row 2
  `REG(16, regMul_kx0_ky2_ch1); `REG(16, regMul_kx1_ky2_ch1); `REG(16, regMul_kx2_ky2_ch1); // Row 3

  logic write_regMul; // All written together in parallel

  assign regMul_kx0_ky0_ch0_we = write_regMul; assign regMul_kx1_ky0_ch0_we = write_regMul; assign regMul_kx2_ky0_ch0_we = write_regMul;  // Mul Out Row 1 Chin 0
  assign regMul_kx0_ky1_ch0_we = write_regMul; assign regMul_kx1_ky1_ch0_we = write_regMul; assign regMul_kx2_ky1_ch0_we = write_regMul;  // Mul Out Row 2 Chin 0
  assign regMul_kx0_ky2_ch0_we = write_regMul; assign regMul_kx1_ky2_ch0_we = write_regMul; assign regMul_kx2_ky2_ch0_we = write_regMul;  // Mul Out Row 3 Chin 0

  assign regMul_kx0_ky0_ch1_we = write_regMul; assign regMul_kx1_ky0_ch1_we = write_regMul; assign regMul_kx2_ky0_ch1_we = write_regMul;  // Mul Out Row 1 Chin 1
  assign regMul_kx0_ky1_ch1_we = write_regMul; assign regMul_kx1_ky1_ch1_we = write_regMul; assign regMul_kx2_ky1_ch1_we = write_regMul;  // Mul Out Row 2 Chin 1
  assign regMul_kx0_ky2_ch1_we = write_regMul; assign regMul_kx1_ky2_ch1_we = write_regMul; assign regMul_kx2_ky2_ch1_we = write_regMul;  // Mul Out Row 3 Chin 1

  // Assign output of multiplier array
  assign regMul_kx0_ky0_ch0_next = mul_array_ch0[0][15:0]; 
  assign regMul_kx1_ky0_ch0_next = mul_array_ch0[0][31:16]; 
  assign regMul_kx2_ky0_ch0_next = mul_array_ch0[0][47:32];

  assign regMul_kx0_ky1_ch0_next = mul_array_ch0[1][15:0]; 
  assign regMul_kx1_ky1_ch0_next = mul_array_ch0[1][31:16]; 
  assign regMul_kx2_ky1_ch0_next = mul_array_ch0[1][47:32];

  assign regMul_kx0_ky2_ch0_next = mul_array_ch0[2][15:0]; 
  assign regMul_kx1_ky2_ch0_next = mul_array_ch0[2][31:16]; 
  assign regMul_kx2_ky2_ch0_next = mul_array_ch0[2][47:32];

  assign regMul_kx0_ky0_ch1_next = mul_array_ch1[0][15:0]; 
  assign regMul_kx1_ky0_ch1_next = mul_array_ch1[0][31:16]; 
  assign regMul_kx2_ky0_ch1_next = mul_array_ch1[0][47:32];

  assign regMul_kx0_ky1_ch1_next = mul_array_ch1[1][15:0]; 
  assign regMul_kx1_ky1_ch1_next = mul_array_ch1[1][31:16]; 
  assign regMul_kx2_ky1_ch1_next = mul_array_ch1[1][47:32];

  assign regMul_kx0_ky2_ch1_next = mul_array_ch1[2][15:0]; 
  assign regMul_kx1_ky2_ch1_next = mul_array_ch1[2][31:16]; 
  assign regMul_kx2_ky2_ch1_next = mul_array_ch1[2][47:32];


// ----------------------------------- //
// ----------- Adder Tree  ----------- //

  logic signed [15:0] grouped_muls [0:17];      // All 18 Multiplication outputs
  assign grouped_muls[0]  = regMul_kx0_ky0_ch0;
  assign grouped_muls[1]  = regMul_kx1_ky0_ch0;
  assign grouped_muls[2]  = regMul_kx2_ky0_ch0;
  assign grouped_muls[3]  = regMul_kx0_ky1_ch0;
  assign grouped_muls[4]  = regMul_kx1_ky1_ch0;
  assign grouped_muls[5]  = regMul_kx2_ky1_ch0;
  assign grouped_muls[6]  = regMul_kx0_ky2_ch0;
  assign grouped_muls[7]  = regMul_kx1_ky2_ch0;
  assign grouped_muls[8]  = regMul_kx2_ky2_ch0;
  assign grouped_muls[9]  = regMul_kx0_ky0_ch1;
  assign grouped_muls[10] = regMul_kx1_ky0_ch1;
  assign grouped_muls[11] = regMul_kx2_ky0_ch1;
  assign grouped_muls[12] = regMul_kx0_ky1_ch1;
  assign grouped_muls[13] = regMul_kx1_ky1_ch1;
  assign grouped_muls[14] = regMul_kx2_ky1_ch1;
  assign grouped_muls[15] = regMul_kx0_ky2_ch1;
  assign grouped_muls[16] = regMul_kx1_ky2_ch1;
  assign grouped_muls[17] = regMul_kx2_ky2_ch1;

  logic signed [15:0] adder_tree_output;

  // Adder tree to combine final outputs: 
  adder_tree #(
    .ADDEND_WIDTH(16),
    .OUT_SCALE(0), 
    .OUT_WIDTH(16),
    .NB_ADDENDS(18),
    .NB_LEVELS_IN_PIPELINE_STAGE(1) // Pipeline after each level, there should be 4 (excl. input stage)
  ) add_results (
    .clk(clk),
    .arst_n_in(arst_n_in),
    .addends(grouped_muls),
    .out(adder_tree_output)
  );

// ----------------------------------- //
// --- Input data SRAM Grid Mems   --- //
  
  logic memory_array_r_en;
  logic memory_array_ch0_w_en;
  logic memory_array_ch1_w_en;

  // Coordinates to Read from (driven by FSM) | NB: will give 3x3 outputs from (x,y) -> (x+2,y+2) | Channels read same elements 
  logic [7:0] memory_array_r_xcoord; logic [7:0] memory_array_r_ycoord; 

  // Coordinates to write to (driven by FSM)  | NB: will write 3 values   from (x,y) -> (x+2,y)   | Channels writes to same elements but on alternating cycles
  logic [7:0] memory_array_w_xcoord; logic [7:0] memory_array_w_ycoord;          
  
  logic reset_mem_sig;

 // Channel In 0 data
  memory_array #( 
    .MEM_WIDTH(16),
    .DIM_Y(130),
    .DIM_X(66),
    .USED_AS_EXTERNAL_MEM(0)
  ) memory_array_ch0 (
    .clk(clk),
    .arst_n_in(arst_n_in),

    .mem_rst(reset_mem_sig),

    .write_en(memory_array_ch0_w_en),
    .din(io_bus),
    .x_write(memory_array_w_xcoord),
    .y_write(memory_array_w_ycoord),
    
    .read_en(memory_array_r_en),
    .x_read(memory_array_r_xcoord),
    .y_read(memory_array_r_ycoord),

    .output_grid(memory_array_ch0_out)

  );

 // Channel In 1 data
  memory_array #( 
    .MEM_WIDTH(16),
    .DIM_Y(130),
    .DIM_X(66),
    .USED_AS_EXTERNAL_MEM(0)
  ) memory_array_ch1 (
    .clk(clk),
    .arst_n_in(arst_n_in),

    .mem_rst(reset_mem_sig),

    .write_en(memory_array_ch1_w_en),
    .din(io_bus),
    .x_write(memory_array_w_xcoord),
    .y_write(memory_array_w_ycoord),
    
    .read_en(memory_array_r_en),
    .x_read(memory_array_r_xcoord),
    .y_read(memory_array_r_ycoord),

    .output_grid(memory_array_ch1_out)

  );

// ----------------------------------- //
// -- Output data SRAM FIFO Buffer  -- //

  logic write_fifo; 
  logic fifo_not_full;
  logic fifo_not_empty;
  logic read_fifo;

  fifo #(
    .WIDTH(16), 
    .DEPTH(5440), //5440
    .USE_AS_EXTERNAL_FIFO(0) //0
  ) output_buffer (
    .clk(clk),
    .arst_n_in(arst_n_in),

    .din(adder_tree_output),
    .input_valid(write_fifo),
    .input_ready(fifo_not_full),

    .qout(io_bus_driver),
    .output_valid(fifo_not_empty),
    .output_ready(read_fifo)
  );

// ----------------------------------- //
// --------- FSM Controller --------- //
  controller_fsm #(
      .FEATURE_MAP_WIDTH (FEATURE_MAP_WIDTH),
      .FEATURE_MAP_HEIGHT(FEATURE_MAP_HEIGHT),
      .INPUT_NB_CHANNELS (INPUT_NB_CHANNELS),
      .OUTPUT_NB_CHANNELS(OUTPUT_NB_CHANNELS)
  ) controller (
      .clk(clk),
      .arst_n_in(arst_n_in),
      .start(start),
      .running(running),
      .conv_kernel_mode(conv_kernel_mode),
      .conv_stride_mode(conv_stride_mode),

      //Handshaking signals  
      .data_valid(a_valid),
      .kernel_valid(b_valid),
      .data_ready(a_ready),
      .kernel_ready(b_ready),
      .chip_drive_enable(chip_drive_enable),

      // Kernel Register signals 
      .write_regKernel_ky0_ch0(write_regKernel_ky0_ch0), // Row 1 | Chin 0 
      .write_regKernel_ky1_ch0(write_regKernel_ky1_ch0), // Row 2 | Chin 0
      .write_regKernel_ky2_ch0(write_regKernel_ky2_ch0), // Row 3 | Chin 0
  
      .write_regKernel_ky0_ch1(write_regKernel_ky0_ch1), // Row 1 | Chin 1
      .write_regKernel_ky1_ch1(write_regKernel_ky1_ch1), // Row 2 | Chin 1
      .write_regKernel_ky2_ch1(write_regKernel_ky2_ch1), // Row 3 | Chin 1

      // Memory Array signals 
      .memory_array_r_en(memory_array_r_en),
      .memory_array_ch0_w_en(memory_array_ch0_w_en),
      .memory_array_ch1_w_en(memory_array_ch1_w_en),

      .reset_mem_sig(reset_mem_sig), 

      .memory_array_r_xcoord(memory_array_r_xcoord),
      .memory_array_r_ycoord(memory_array_r_ycoord),
      .memory_array_w_xcoord(memory_array_w_xcoord),
      .memory_array_w_ycoord(memory_array_w_ycoord),

      // Output buffer signals
      .write_fifo(write_fifo),
      .fifo_not_full(fifo_not_full),
      .fifo_not_empty(fifo_not_empty),
      .read_fifo(read_fifo),

      .output_valid(output_valid),
      .output_x(output_x),
      .output_y(output_y),
      .output_ch(output_ch)
  );
// ----------------------------------- //
endmodule