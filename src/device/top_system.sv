// Version 3: Optimal loop ordering
module top_system #(
    parameter int IO_DATA_WIDTH = 16, 
    parameter int ACCUMULATION_WIDTH = 32,
    parameter int EXT_MEM_HEIGHT = 1 << 20,
    parameter int EXT_MEM_WIDTH = ACCUMULATION_WIDTH,
    parameter int FEATURE_MAP_WIDTH = 128,
    parameter int FEATURE_MAP_HEIGHT = 128,
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

    // Data bus
    inout wire [47:0] io_bus,
    
    input logic a_valid,
    output logic a_ready,
    input logic b_valid,
    output logic b_ready,

    //debug
    input logic intf_x,
    input logic intf_y,

    // output control    
    output logic output_valid,
    
    output logic [$clog2(FEATURE_MAP_WIDTH)-1:0] output_x,
    output logic [$clog2(FEATURE_MAP_HEIGHT)-1:0] output_y,
    output logic [$clog2(OUTPUT_NB_CHANNELS)-1:0] output_ch,

    input  logic start,
    output logic done,
    output logic running
);

  top_chip #(
      .IO_DATA_WIDTH(IO_DATA_WIDTH),
      .ACCUMULATION_WIDTH(ACCUMULATION_WIDTH),
      .FEATURE_MAP_WIDTH(FEATURE_MAP_WIDTH),
      .FEATURE_MAP_HEIGHT(FEATURE_MAP_HEIGHT),
      .INPUT_NB_CHANNELS(INPUT_NB_CHANNELS),
      .OUTPUT_NB_CHANNELS(OUTPUT_NB_CHANNELS)
  ) top_chip_i (
      .clk(clk),
      .arst_n_in(arst_n_in),

      .conv_kernel_mode(conv_kernel_mode),
      .conv_stride_mode(conv_stride_mode),

      //debug  
      .intf_x(intf_x),  
      .intf_y(intf_y),

      .io_bus(io_bus),  
      .a_valid(a_valid),
      .a_ready(a_ready),

      .b_valid(b_valid),
      .b_ready(b_ready),

      .output_valid(output_valid),

      .output_x(output_x),
      .output_y(output_y),
      .output_ch(output_ch),

      .done(done),
      .start  (start),
      .running(running)
  );


endmodule
