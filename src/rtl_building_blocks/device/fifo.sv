// Asymmetric FIFO writes in 16 bits and reads out 48 bits per cycle. Energy logging done accordingly 
module fifo #(
  parameter int WIDTH = 16,
  parameter int DEPTH = 128,
  parameter bit USE_AS_EXTERNAL_FIFO = 1
  )
  (
    input  logic                      clk,
    input  logic                      arst_n_in, //asynchronous reset, active low
    //write port
    input  logic [WIDTH-1:0]          din,
    input  logic                      input_valid, // write enable
    output logic                      input_ready, // not fifo full

    output logic [3*WIDTH-1:0]        qout,         // NB: THE FIFO READS OUT 3 VALUES OF 16 BITS AT A TIME BUT ONLY WRITES IN 1 16b
    output logic                      output_valid, // not empty
    input  logic                      output_ready  // read enable
  );
  localparam int LOG2_OF_DEPTH = $clog2(DEPTH);
  
  logic write_effective;
  assign write_effective = input_valid && input_ready;


  // Address to write to
  `REG(LOG2_OF_DEPTH+1, write_addr); // 8 bit reg
  assign write_addr_we = write_effective;
  assign write_addr_next = write_addr + 1; 

  logic read_effective;
  assign read_effective = output_valid && output_ready;

  // Address to read from 
  `REG(LOG2_OF_DEPTH+1, read_addr); // 8 bit reg
  assign read_addr_we = read_effective;
  assign read_addr_next = read_addr + 3;

  //if write_addr - read_addr = 2**LOG2_OF_DEPTH = depth, then the fifo is full
  //if write_addr = read_addr, the fifo is empty
  logic [LOG2_OF_DEPTH+1-1:0] write_addr_limit; // 7 bit reg!?
  assign write_addr_limit = read_addr + (1 << LOG2_OF_DEPTH); // Read Address + 128
  assign input_ready = write_addr != write_addr_limit;
  assign output_valid = read_addr != write_addr;


  //storage
  logic [WIDTH-1:0] data [DEPTH];

  logic read_en;
  logic write_en;

  assign write_en = write_effective;
  assign read_en  =  read_effective; 
  always @ (posedge clk) begin
    if (write_en) begin
        data[write_addr] <= din;
    end
  end

  assign qout[15:0]  = read_en ? data[read_addr  ] :'x ;
  assign qout[31:16] = read_en ? data[read_addr+1] :'x ;
  assign qout[47:32] = read_en ? data[read_addr+2] :'x ;

  `ifndef TARGET_SYNTHESIS
  //area logging
  initial begin
    #0;
    if(!USE_AS_EXTERNAL_FIFO) begin
      if (DEPTH<128) begin
        tbench_top.area += 17*WIDTH*DEPTH;
        $display("%m added %d to area", 17*WIDTH*DEPTH);
      end else begin
        tbench_top.area += 1*WIDTH*DEPTH;
        $display("%m added %d to area", 1*WIDTH*DEPTH);
      end
    end
  end

  //energy logging:
  always @(posedge clk) begin
    if(read_en)
      tbench_top.energy += 3*WIDTH*(USE_AS_EXTERNAL_FIFO?1:0.1); // NOTE: x3 AS WE READ OUT 3 VALUES AT A TIME!!! 
  end
  always @(posedge clk) begin
    if(write_en) //NB: if only read/write disable the other! 
      tbench_top.energy += WIDTH*(USE_AS_EXTERNAL_FIFO?1:0.1);
  end
  `endif

endmodule
