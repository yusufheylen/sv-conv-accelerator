interface intf #(
    config_t cfg
) (
    input logic clk
);
  logic arst_n;

  /*#############################
  WHEN ADJUSTING THIS INTERFACE, ADJUST THE ENERGY ADDITIONS AT THE BOTTOM ACCORDINGLY!
  ################################*/

  // input interface
  logic [1:0] conv_kernel_mode;
  logic [1:0] conv_stride_mode;
  
  logic x_driver;
  logic y_driver;

  logic a_valid;
  logic a_ready;

  logic b_valid;
  logic b_ready;

  // output interface

  logic [$clog2(cfg.FEATURE_MAP_WIDTH)-1:0 ] output_x;
  logic [$clog2(cfg.FEATURE_MAP_HEIGHT)-1:0] output_y;
  logic [$clog2(cfg.OUTPUT_NB_CHANNELS)-1:0] output_ch;

  // Control wire to signal to driver that done (for Latency calcs)
  logic done; 

  // Dual i/o data bus
  wire [47:0] io_bus;

  // Control wire to signal to switch to Receive mode from chip
  logic output_valid;

  logic start;
  logic running;

  default clocking cb @(posedge clk);
    default input #0.01 output #0.01;

    output conv_kernel_mode;
    output conv_stride_mode;
    output arst_n;

    inout io_bus;

    output start;
    input running; //changed from input

    output x_driver;
    output y_driver;

    output a_valid;
    input  a_ready;

    output b_valid;
    input  b_ready;

    input output_valid;
    input done;

    input output_x;
    input output_y;
    input output_ch;


    
  endclocking

  modport tb(clocking cb);  // testbench's view of the interface

  //TODO: DOUBLE CHECK THIS IS CORRECT 

  always @(posedge clk) begin
    if (a_valid && a_ready) begin
      tbench_top.energy += 1 * 48;//(cfg.DATA_WIDTH);
    end
  end
  always @(posedge clk) begin
    if (b_valid && b_ready) begin
      tbench_top.energy += 1 * 48;//(cfg.DATA_WIDTH);
    end
  end
  always @(posedge clk) begin
    if (output_valid && 1) begin  //no ready here, set to 1
      tbench_top.energy += 1 * 48;//(cfg.DATA_WIDTH);
    end
  end


endinterface
