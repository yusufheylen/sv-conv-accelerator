//Version 3: Optimal loop ordering
module controller_fsm #(
    parameter int FEATURE_MAP_WIDTH  = 128,
    parameter int FEATURE_MAP_HEIGHT = 128,
    parameter int INPUT_NB_CHANNELS  = 2,
    parameter int OUTPUT_NB_CHANNELS = 16
) (
    input logic clk,
    input logic arst_n_in, //asynchronous reset, active low

    input  logic start,
    output logic running, //seemingly does nothing? Output @interface isn't read / used anywhere
    output logic done,
    output logic chip_drive_enable,

    input logic [1:0] conv_kernel_mode, // Will only do 3x3
    // Currently support 3 sizes:
    // 0: 1x1
    // 1: 3x3
    // 2: 5x5
    input logic [1:0] conv_stride_mode,
    // Currently support 3 modes:
    // 0: step = 1
    // 1: step = 2
    // 2: step = 4

    // Memory control interface 
    output logic memory_array_r_en,
    output logic memory_array_ch0_w_en,
    output logic memory_array_ch1_w_en,

    // Data path control interface & external handshaking communication of a = data and b = kernel
    input  logic data_valid,
    input  logic kernel_valid,

    output logic data_ready,
    output logic kernel_ready,
    
    // WRITE KERNEL REGISTERS ARRAY
    output logic write_regKernel_ky0_ch0, // Row 1 | Chin 0 
    output logic write_regKernel_ky1_ch0, // Row 2 | Chin 0
    output logic write_regKernel_ky2_ch0, // Row 3 | Chin 0
  
    output logic write_regKernel_ky0_ch1, // Row 1 | Chin 1 
    output logic write_regKernel_ky1_ch1, // Row 2 | Chin 1
    output logic write_regKernel_ky2_ch1, // Row 3 | Chin 1

    // Control to enable multiplier output registers 
    output logic write_regMul,

    // Control signal to reset the memory array to zero
    output logic reset_mem_sig, 

    // Coordinates to read from memory array | NB: will give 3x3 outputs from (x,y) -> (x+2,y+2)
    output logic [7:0] memory_array_r_xcoord, output logic [7:0] memory_array_r_ycoord,

    // Coordinates to write to memory array | NB: will write 3 values   from (x,y) -> (x+2,y)
    output logic  [7:0] memory_array_w_xcoord, output logic  [7:0] memory_array_w_ycoord,

    // FIFO control signals 
    output logic write_fifo,
    input  logic fifo_not_full,
    input  logic fifo_not_empty,
    output logic read_fifo,
    
    //Specify which part of inputs to work on
    output logic output_valid,  // signal data to be sent back over bus
    output logic [$clog2(FEATURE_MAP_WIDTH) -1:0] output_x,
    output logic [$clog2(FEATURE_MAP_WIDTH) -1:0] output_y,
    output logic [$clog2(OUTPUT_NB_CHANNELS)-1:0] output_ch
);

  logic [2:0] conv_stride;
  assign conv_stride = 1 << conv_stride_mode; // 1 << 3'b000 || 3'b001 || 3'b010
  logic [2:0] conv_kernel; 
  assign conv_kernel = (conv_kernel_mode << 1) + 1; // possibilities: 3'b001 | 3'b011 | 3'b101  || Will only do 3'b010

// --- Kernel Register Load Counter --- //
  logic reset_regKernel;

  `REG(3, kernel_counter);
  assign kernel_counter_next = reset_regKernel ? 0 : kernel_counter + 1;
  always @(*) begin
    // defaults all zero
    write_regKernel_ky0_ch0 = 0; // Row 1 | Chin 0 
    write_regKernel_ky1_ch0 = 0; // Row 2 | Chin 0
    write_regKernel_ky2_ch0 = 0; // Row 3 | Chin 0
  
    write_regKernel_ky0_ch1 = 0; // Row 1 | Chin 1 
    write_regKernel_ky1_ch1 = 0; // Row 2 | Chin 1
    write_regKernel_ky2_ch1 = 0; // Row 3 | Chin 1
    case(kernel_counter)
      3'b000 : begin
        write_regKernel_ky0_ch0 = 1 && !reset_regKernel; 
      end 
      3'b001 : begin
        write_regKernel_ky1_ch0 = 1 && !reset_regKernel;
      end 
      3'b010 : begin
        write_regKernel_ky2_ch0 = 1 && !reset_regKernel;
      end
      3'b011 : begin
        write_regKernel_ky0_ch1 = 1 && !reset_regKernel;
      end
      3'b100 : begin
        write_regKernel_ky1_ch1 = 1 && !reset_regKernel;
      end
      3'b101 : begin
        write_regKernel_ky2_ch1 = 1 && !reset_regKernel;
      end
      default : begin
        //do nothing
      end
    endcase
  end 
// ------------------------------------ //
// --------- Load Data Logic  --------- //

  //loop data counters (see register.sv for macro)
  `REG(4, ch_out); // THIS IS THE SAME FOR READING AND WRITING !!! 
  `REG(8, x);     //2^8 = 256 values (only valid 0-129)
  `REG(8, y); 
  `REG(2, ky);
  `REG(1, ch_in);

    // Checks if loaded last element per dim
  logic  last_ch_out, last_x, last_y, last_ky, last_ch_in;

  assign last_ch_out = ch_out == OUTPUT_NB_CHANNELS - 1;
  assign last_x   = x     >= FEATURE_MAP_WIDTH  - conv_stride;  
  assign last_y   = y + 2 >= FEATURE_MAP_HEIGHT - conv_stride; 
  assign last_ky  = ky == 2; 
  assign last_ch_in = ch_in == INPUT_NB_CHANNELS - 1;

  // Load data counter logic (i.e. write location)
  assign x_next =      (last_x    ) ? 0 : (conv_stride == 4) ? x + 4 : x + 3 ;
  assign y_next =      (last_y    ) ? 0 : (conv_stride == 4) ? y + 4 : y + 3; // see driver.sv 
  assign ky_next =     (last_ky   ) ? 0 : ky + 1; 
  assign ch_in_next =  (last_ch_in) ? 0 : ch_in + 1;


  /*
  Data load order:
  for ch_out
    # Kernel
    for ky
      for chin
    # Data
    for x
      for y    
        for ch_in
          body
  */
  //Registers to be written depending on loop order
  logic load_valid; 

  assign ch_in_we   = load_valid;                                  
  assign ky_we      = load_valid && last_ch_in;                     
  assign y_we       = load_valid && last_ch_in && last_ky;
  assign x_we       = load_valid && last_ch_in && last_ky && last_y;                              

  assign memory_array_w_xcoord = x; 
  assign memory_array_w_ycoord = y + ky;

  // Set which memory array to be written
  assign memory_array_ch0_w_en = !ch_in && load_valid;  
  assign memory_array_ch1_w_en =  ch_in && load_valid;

  // Check if done with writing in data for this output channel 
  `REG(1, all_loaded);
  assign all_loaded_next = last_x;


  // Binary logic to see if at final loop iter for given loop ordering | Used in FSM state logic
  logic  last_overall;
  assign last_overall =  last_ch_in && last_ky && last_y && last_x && last_ch_out;
// ------------------------------------ //
// --------- Mul control logic -------- //
  // Logic to keep track of convolution kernel location

  logic last_y_mul;
  logic last_x_mul; 
  logic reset_mul_regs;
  logic mul_valid;

  `REG(8, x_mul);     //2^8 = 256 values (only valid 0-129)
  `REG(8, y_mul); 
  assign x_mul_next = reset_mul_regs ? 0 : x_mul + {5'b0, conv_stride};
  assign y_mul_next = reset_mul_regs ? 0 : y_mul + {5'b0, conv_stride}; 

  assign y_mul_we   = mul_valid; 
  assign x_mul_we   = last_y_mul && mul_valid;

  assign last_y_mul = y_mul + 2 + conv_stride >= FEATURE_MAP_HEIGHT; // +2 is to take into account that using 3x3 kernel 
  assign last_x_mul = x_mul + 2 + conv_stride >= FEATURE_MAP_WIDTH;

  assign memory_array_r_xcoord = x_mul;
  assign memory_array_r_ycoord = y_mul;
// ------------------------------------ //
// ------- Readout control Logic ------ //
  // Output data counters
  logic output_x_we;
  logic output_y_we;
  logic reset_output_regs; 
  logic readout_valid;
  logic output_x_din;
  logic output_y_din;

  logic out_x; 
  logic out_y; 

  assign output_x = out_x;
  assign output_y = out_y;

  assign output_valid = readout_valid;
  assign last_x_out    = output_x >= FEATURE_MAP_WIDTH  / conv_stride - 1;  
  assign last_y_out    = output_y >= FEATURE_MAP_HEIGHT / conv_stride - 1; 

  assign output_y_din = (last_y_out || reset_output_regs) ? 7'b0 : last_y_out + 3; // see driver.sv 


  always_comb begin
    if (reset_output_regs) begin
      output_x_din = 7'b0;
    end
    else if (last_y_out) begin 
      output_x_din = output_x  + 1;
    end
    else begin
      output_x_din = output_x;
    end
  end 
  // ! ASSUMPTION THAT WE WILL HAVE LOADED ALL THE DATA BEFORE WE START WRITING BACK, I.E. THAT WE WILL NEVER GO BACK TO CONV_LOAD STATE !

  assign output_x_we =  readout_valid || reset_output_regs;  //
  assign output_y_we =  readout_valid || reset_output_regs;

  // X location register for Monitor 
  register #(
      .WIDTH($clog2(FEATURE_MAP_WIDTH)) 
  ) output_x_r (
      .clk(clk),
      .arst_n_in(arst_n_in),
      .din(output_x_din), // the (x,y) location for a specific input-output feature map
      .qout(out_x),
      .we(output_x_we) 
  );

  // Y location register for Monitor
  register #(
      .WIDTH($clog2(FEATURE_MAP_HEIGHT))
  ) output_y_r (
      .clk(clk),
      .arst_n_in(arst_n_in),
      .din(output_y_din),
      .qout(out_y),
      .we(output_y_we) 
  );

  // Channel Output Register for Monitor 
  register #(
      .WIDTH($clog2(OUTPUT_NB_CHANNELS))
  ) output_ch_r (
      .clk(clk),
      .arst_n_in(arst_n_in),
      .din(ch_out),
      .qout(output_ch),
      .we(ch_out_we) 
  );

// ------------------------------------ //
// --------- FSM state counters ------- //

  // Counter for pre-loading some data into the memory 
  logic reset_preload_cycles;

  `REG(12, preload_cycles);
  assign preload_cycles_next = reset_preload_cycles ? 0 : preload_cycles + 1; 
  
  // Counter for filling up adder pipeline | 5 cycles 
  logic resetPipe_count;

  `REG(3, regPipe_count);
  assign regPipe_count_next = resetPipe_count ? 0 : regPipe_count + 1;

  assign chip_drive_enable = readout_valid;

// ------------------------------------ //
// ---------- FSM State Logic  -------- //

  /** FSM Control Signals:
   *  1.  kernel_counter_we     - Enable to update the kernel register counter                                       | Internal
   *  2.  reset_regKernel       - Reset kernel register counter 
   *  2.  load_valid            - When loading data this is set to one to begin counting location                    | Internal
   *  3.  last_overall          - Use to check if need to move to DONE || IDLE state                                 | Internal, state switching     
   *  4.  readout_valid         - When storing and in when loading kernel to reset output counters                   | Internal 
   *  5.  mul_valid             - Enable when doing convolution (FILL_PIPELINE / CONV_PLUS_LOAD / CONV_PLUS_READOUT) | Internal
   *  6.  regPipe_count_we      - Enable when starting convolution but waiting for adder pipeline to fill            | Internal 
   *  7.  resetPipe_count       - Reset the adder pipeline counter                                                   | Internal 
   *  7.  reset_preload_cycles  - Set high to reset the preload reg to 0                                             | Internal
   *  8.  preload_cycles_we     - Set high to enable preload reg counting                                            | Internal 
   *  9.  all_loaded_we         - Enable to store if all data has been loaded for a given ch_out                     | Internal     
   *  10. reset_output_regs     - Reset the output register counters                                                 | Internal  
   *  11. reset_mul_regs        - Reset multiplier location registers                                                | Internal    
   *  10. write_regMul          - Control signal to enable multiplier output registers                               | Output 
   *  11. reset_mem_sig         - Control signal to reset memory array values to 0                                   | Output 
   *  12. memory_array_r_en     - Control signal to allow reading from memory (for mul)                              | Output 
   *  13. write_fifo            - Control signal to allow writing to output buffer (fifo)                            | Output
   *  14. read_fifo             - Control signal to allow reading from output buffer                                 | Output 
   *  15. data_ready            - Chip ready to receive more data (ack)                                              | Output 
   *  16. kernel_ready          - Chip ready to receive more kernel weights (ack)                                    | Output 
   *  17. running               - Chip is busy                                                                       | Output
   *  18. fifo_not_full         - Input signal if fifo is not full                                                   | Input, state switching 
   *  19. fifo_not_empty        - Input signal if fifo not empty                                                     | Input, state switching  
   *  20. data_valid            - Data ready to be loaded into memory cells (syn)                                    | Input, state switching
   *  21. kernel_valid          - Kernel weights ready to be loaded into kernel registers (syn)                      | Input, state switching  
   *  22. start                 - Signal to chip to do work                                                          | Input, state switching 
  **/

  typedef enum {
    IDLE,               // Wait for start and reset everything 
    LOAD_KERNEL,        // Grab all the kernel data
    LOAD_DATA,          // Preload some data 
    FILL_PIPELINE,      // Fill the pipeline with some data before we can do writing to output fifo buffer 
    CONV_PLUS_LOAD,     // Convolve and load in more data 
    CONV_PLUS_READOUT,  // Continue to convolve while sending data back to output 
    READOUT_REST,       // Read out remaining data 
    DONE              
  } fsm_state_e;

  fsm_state_e current_state;
  fsm_state_e next_state;
  always @(posedge clk or negedge arst_n_in) begin
    if (arst_n_in == 0) begin
      current_state <= IDLE;
    end else begin
      current_state <= next_state;
    end
  end

  assign ch_out_next = (next_state == IDLE) ? 0 : ch_out + 1;                         // ! ! ! state logic outside
  assign ch_out_we  =  (current_state == READOUT_REST) && (next_state == LOAD_KERNEL); // ! ! ! state logic outside  


  always_comb begin
    //defaults: applicable if not overwritten below
    kernel_counter_we     = 0;
    reset_regKernel       = 0;
    load_valid            = 0;
    readout_valid         = 0;
    mul_valid             = 0;
    regPipe_count_we      = 0;
    resetPipe_count       = 0;
    reset_preload_cycles  = 0;
    preload_cycles_we     = 0;
    all_loaded_we         = 0;
    reset_output_regs     = 0;
    reset_mul_regs        = 0;
    write_regMul          = 0;
    reset_mem_sig         = 0;
    memory_array_r_en     = 0;
    write_fifo            = 0;
    read_fifo             = 0;
    data_ready            = 0;
    kernel_ready          = 0;
    running               = 1;
    case (current_state)
      IDLE: begin
        kernel_counter_we     = 1; 
        reset_regKernel       = 1; // Reset counter to zero
        running               = 0;
      end
      LOAD_KERNEL: begin
        kernel_counter_we     = 1; // Update Kernel counter
        regPipe_count_we      = 1; // Reset pipeline filling counter
        resetPipe_count       = 1; // ^ 
        all_loaded_we         = 1; // Reset flag
        reset_mul_regs        = 1; // Reset multiplier location registers 
        reset_preload_cycles  = 1; // Reset preloading counter   
        preload_cycles_we     = 1; // ^
        reset_mem_sig         = 1; // Reset memory array 
        kernel_ready          = 1; // Read kernel data  
      end
      LOAD_DATA: begin
        load_valid            = 1; // Read in data
        all_loaded_we         = 1; // Flag 
        preload_cycles_we     = 1; // Update loading counter  
        data_ready            = 1; // Feed data
      end
      FILL_PIPELINE: begin 
        load_valid            = 1; // Keep Reading in data
        mul_valid             = 1; // Start convolving ky loading counter (%d) is out of bounds!
        regPipe_count_we      = 1; // Update pipeline filling register 
        all_loaded_we         = 1; // Flag
        write_regMul          = 1; // Enable conv pipeline 
        memory_array_r_en     = 1; // Allow reading from memory grid
        data_ready            = 1; // Keep reading data
      end 
      CONV_PLUS_LOAD: begin 
        load_valid            = 1; // Keep Reading in data
        mul_valid             = 1; // Continue convolving 
        all_loaded_we         = 1; // Flag 
        write_regMul          = 1; // Enable conv pipeline 
        memory_array_r_en     = 1; // Allow reading from memory grid
        write_fifo            = 1; // Allow writing to fifo output buffer
        data_ready            = 1; // Keep reading data
        reset_output_regs     = 1; // Reset output register counters
      end
      CONV_PLUS_READOUT: begin
        load_valid            = 0; // ! ASSUMING ALL DATA LOADED IN ! 
        all_loaded_we         = 0; // Hold Flag 
        readout_valid         = 1; // Begin writing out on bus
        mul_valid             = 1; // Continue convolving 
        write_regMul          = 1; // ^
        memory_array_r_en     = 1; // Allow reading from memory grid
        write_fifo            = 1; // Continue convolving and writing to fifo 
        read_fifo             = 1; // Read out from fifo 
      end
      READOUT_REST : begin
        kernel_counter_we     = 1; // Enable to reset to zero 
        readout_valid         = 1; // Continue reading out onto bus 
        read_fifo             = 1; // Read last elements in buffer 
        reset_regKernel       = 1; // Reset counter to zero
      end
      default: begin
        // do nothing
        running = 0;
      end
    endcase
  end

  always_comb begin
    case (current_state)
      IDLE: begin
        next_state = start ? LOAD_KERNEL : IDLE; 
      end
      LOAD_KERNEL: begin
        next_state = (kernel_counter == 3'b101) ? LOAD_DATA : LOAD_KERNEL;  
      end
      LOAD_DATA: begin
        next_state = (preload_cycles < 1322) ? LOAD_DATA : FILL_PIPELINE;
      end
      FILL_PIPELINE: begin 
        next_state = (regPipe_count < 5) ? FILL_PIPELINE : CONV_PLUS_LOAD;
      end 
      CONV_PLUS_LOAD: begin 
        next_state = all_loaded_next ? CONV_PLUS_READOUT : CONV_PLUS_LOAD; // !! error if fifo becomes full before this
      end
      CONV_PLUS_READOUT: begin
        next_state = (last_y_mul && last_x_mul) ? READOUT_REST : CONV_PLUS_READOUT;
      end
      READOUT_REST : begin
        next_state = (last_y_out && last_x_out) ? LOAD_KERNEL : READOUT_REST;
      end
      default: begin

      end
    endcase
  end 
// ------------------------------------ //
// ------------ Assertions ------------ //
  // always @(posedge clk) begin
  //   assert(all_loaded == 0 && !fifo_not_full) else $fatal("[FSM] FATAL ERROR - Fifo is Full & Not all data is loaded!");

  //   assert(ky <= 2) else $fatal("[FSM] ky loading counter (%d) is out of bounds!" ,ky);
  //   assert(x < 130) else $fatal("[FSM]  x loading counter (%d) is out of bounds!" , x);
  //   assert(y < 130) else $fatal("[FSM]  y loading counter (%d) is out of bounds!" , y);
  // end
// ------------------------------------ //
endmodule
