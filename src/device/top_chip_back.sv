// Version 2: Big bus
module top_chip #(
    parameter int IO_DATA_WIDTH = 16,
    parameter int ACCUMULATION_WIDTH = 32,
    parameter int EXT_MEM_HEIGHT = 1 << 20,
    parameter int EXT_MEM_WIDTH = ACCUMULATION_WIDTH,
    parameter int FEATURE_MAP_WIDTH = 1024,
    parameter int FEATURE_MAP_HEIGHT = 1024,
    parameter int INPUT_NB_CHANNELS = 64,
    parameter int OUTPUT_NB_CHANNELS = 64
) (
    input logic clk,
    input logic arst_n_in, //asynchronous reset, active low

    //external_memory
    //read port
    output logic unsigned [$clog2(EXT_MEM_HEIGHT)-1:0] ext_mem_read_addr,
    output logic ext_mem_read_en,
    input logic [EXT_MEM_WIDTH-1:0] ext_mem_qout,
    input logic [EXT_MEM_WIDTH-1:0] ext_mem_qout2,
    input logic [EXT_MEM_WIDTH-1:0] ext_mem_qout3,

    //write port
    output logic unsigned [$clog2(EXT_MEM_HEIGHT)-1:0] ext_mem_write_addr,
    output logic [EXT_MEM_WIDTH-1:0] ext_mem_din,
    output logic [EXT_MEM_WIDTH-1:0] ext_mem_din2,
    output logic [EXT_MEM_WIDTH-1:0] ext_mem_din3,

    output logic ext_mem_write_en,

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

    //system data inputs and outputs
    // input logic [IO_DATA_WIDTH-1:0] a_input,
    // input logic [IO_DATA_WIDTH-1:0] b_input,


    inout logic [47:0] io_bus,


    input logic a_valid,
    output logic a_ready,

    input logic b_valid,
    output logic b_ready,

    //output

    //TODO: merge output into io_bus
    output logic signed [16-1:0] out,
    output logic output_valid,

    //TODO: send 3 for each output
    output logic [$clog2(FEATURE_MAP_WIDTH)-1:0 ] output_x,
    output logic [$clog2(FEATURE_MAP_HEIGHT)-1:0] output_y,
    output logic [$clog2(OUTPUT_NB_CHANNELS)-1:0] output_ch,


    input  logic start,
    output logic running
);


  logic write_a;
  logic write_b;

    // Data registers
  `REG(IO_DATA_WIDTH, a);
  `REG(IO_DATA_WIDTH, b);
  assign a_next = io_bus;
  assign b_next = io_bus;
  assign a_we   = write_a;
  assign b_we   = write_b;

//   // Register A1 [15:0]
//   `REG(16, a1);
//   assign a1_next = a_input[15:0]; // Date on next cycle written
//   assign a1_we   = write_a;       // Write enable

//   // Register A2 [31:16]
//   `REG(16, a2);
//   assign a2_next = a_input[31:16]; // Date on next cycle written
//   assign a2_we   = write_a;       // Write enable

//   // Register A3 [47:32]
//   `REG(16, a3);
//   assign a3_next = a_input[47:32]; // Date on next cycle written
//   assign a3_we   = write_a;       // Write enable

//   // Register B1 [15:0]
//   `REG(16, b1);
//   assign b1_next = b_input[15:0]; // Date on next cycle written
//   assign b1_we   = write_b;       // Write enable

//   // Register B2 [31:16]
//   `REG(16, b2);
//   assign b2_next = b_input[31:16]; // Date on next cycle written
//   assign b2_we   = write_b;       // Write enable

//   // Register B3 [47:32]
//   `REG(16, b3);
//   assign b3_next = b_input[47:32]; // Date on next cycle written
//   assign b3_we   = write_b;       // Write enable


  logic mac_valid;
  logic mac_accumulate_internal;
  logic mac_accumulate_with_0;

  logic mac_accumulate_internal_2;
  logic mac_accumulate_with_0_2;
  logic mac_accumulate_internal_3;
  logic mac_accumulate_with_0_3;


  controller_fsm #(
      .LOG2_OF_MEM_HEIGHT($clog2(EXT_MEM_HEIGHT)),
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

      .mem_we(ext_mem_write_en),
      .mem_write_addr(ext_mem_write_addr),
      .mem_re(ext_mem_read_en),
      .mem_read_addr(ext_mem_read_addr),

      .a_valid(a_valid),
      .a_ready(a_ready),
      .b_valid(b_valid),
      .b_ready(b_ready),

      // Connect to FSM Outputs
      .write_a(write_a),
      .write_b(write_b),
      .mac_valid(mac_valid),

      .mac_accumulate_internal(mac_accumulate_internal),
      .mac_accumulate_with_0(mac_accumulate_with_0),
      .mac_accumulate_internal_2(mac_accumulate_internal_2),
      .mac_accumulate_with_0_2(mac_accumulate_with_0_2),
      .mac_accumulate_internal_3(mac_accumulate_internal_3),
      .mac_accumulate_with_0_3(mac_accumulate_with_0_3),

      //TODO: need to specify 3 independent input portion for data and kernel
      // Specifies which part of input is working on

      //TODO:Split outputs at controller fsm
      .output_valid(output_valid),
      .output_x(output_x),
      .output_y(output_y),
      .output_ch(output_ch)
  );

  //TODO: Add internal SRAM FIFO input buffer for data streaming (while compute is busy)
  //TODO: Add internal (?) SRAM FIFO output buffer for data streaming (when input is full) | also store the x/y/out_ch for checking note DOESN'T COUNT FOR COST

  // Assign partial sum 0 to avoid reading uninitialized memory
  logic signed [ACCUMULATION_WIDTH-1:0] mac_partial_sum;
  assign mac_partial_sum = mac_accumulate_with_0 ? 0 : ext_mem_qout;

  // Intermediate Buffer is always buffered by external memory (output memory)
  logic signed [ACCUMULATION_WIDTH-1:0] mac_out;
  assign ext_mem_din = mac_out; // write mac output to external memory as well

  mac #(
      .A_WIDTH(16),
      .B_WIDTH(16),
      .ACCUMULATOR_WIDTH(ACCUMULATION_WIDTH),
      .OUTPUT_WIDTH(ACCUMULATION_WIDTH),
      .OUTPUT_SCALE(0)
  ) mac_unit (
      .clk(clk),
      .arst_n_in(arst_n_in),

      .input_valid(mac_valid),
      .accumulate_internal(mac_accumulate_internal),
      .partial_sum_in(mac_partial_sum),
      .a(a[15:0]), //select which part of a/b to operate on
      .b(b[15:0]),
      .out(mac_out)
  );


// NEW

  // Assign partial sum 0 to avoid reading uninitialized memory
  logic signed [ACCUMULATION_WIDTH-1:0] mac_partial_sum_2;
  assign mac_partial_sum_2 = mac_accumulate_with_0_2 ? 0 : ext_mem_qout2;

  // Intermediate Buffer is always buffered by external memory (output memory)
  logic signed [ACCUMULATION_WIDTH-1:0] mac_out_2;
  assign ext_mem_din2 = mac_out_2;

  // Operates on a2 / b2 
    mac #(
      .A_WIDTH(16),
      .B_WIDTH(16),
      .ACCUMULATOR_WIDTH(ACCUMULATION_WIDTH),
      .OUTPUT_WIDTH(ACCUMULATION_WIDTH),
      .OUTPUT_SCALE(0)
  ) mac_unit_2 (
      .clk(clk),
      .arst_n_in(arst_n_in),

      .input_valid(mac_valid),
      .accumulate_internal(mac_accumulate_internal_2),
      .partial_sum_in(mac_partial_sum_2),
      .a(a[31:16]),
      .b(b[31:16]),
      .out(mac_out_2)
  );


   // Assign partial sum 0 to avoid reading uninitialized memory
  logic signed [ACCUMULATION_WIDTH-1:0] mac_partial_sum_3;
  assign mac_partial_sum_3 = mac_accumulate_with_0_3 ? 0 : ext_mem_qout3;

  // Intermediate Buffer is always buffered by external memory (output memory)
  logic signed [ACCUMULATION_WIDTH-1:0] mac_out_3;
  assign ext_mem_din3 = mac_out_3;

  // Operates on a3 / b3 
    mac #(
      .A_WIDTH(16),
      .B_WIDTH(16),
      .ACCUMULATOR_WIDTH(ACCUMULATION_WIDTH),
      .OUTPUT_WIDTH(ACCUMULATION_WIDTH),
      .OUTPUT_SCALE(0)
  ) mac_unit_3 (
      .clk(clk),
      .arst_n_in(arst_n_in),

      .input_valid(mac_valid),
      .accumulate_internal(mac_accumulate_internal_3),
      .partial_sum_in(mac_partial_sum_3),
      .a(a[47:32]),
      .b(b[47:32]),
      .out(mac_out_3)
  );


  logic signed [ACCUMULATION_WIDTH-1:0] grouped_macs [2:0];
  assign grouped_macs[0] = mac_out;
  assign grouped_macs[1] = mac_out_2;
  assign grouped_macs[2] = mac_out_3;
  
  logic signed [47:0] adder_tree_output;


  // Adder tree to combine final outputs: 
  adder_tree #(
    .ADDEND_WIDTH(ACCUMULATION_WIDTH),
    .OUT_SCALE(0), 
    .OUT_WIDTH(32),
    .NB_ADDENDS(3),
    .NB_LEVELS_IN_PIPELINE_STAGE(10) //NO PIPELINE
  ) add_results (
    .addends(grouped_macs),
    .out(adder_tree_output)
  );
  assign out = adder_tree_output[15:0] ; 


endmodule
