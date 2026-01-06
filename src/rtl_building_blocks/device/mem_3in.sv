// Takes three inputs and one address -> writes to subsequent addresses (i.e. 0,1,2)
//a simple pseudo-2 port memory (can read and write simultaneously)
//Feel free to write a single port memory (inout data, either write or read every cycle) to decrease your bandwidth
module mem_3in #(
  parameter int WIDTH = 16,
  parameter int HEIGHT = 1,
  parameter bit USED_AS_EXTERNAL_MEM// for area, bandwidth and energy estimation
  )
  (
  input logic clk,

  //read port (0 cycle: there is no clock edge between changing the read_addr and the output)
  input logic unsigned[$clog2(HEIGHT)-1:0] read_addr,
  input logic read_en,

  // Three outputs:
  output logic[WIDTH-1:0] qout,
  output logic[WIDTH-1:0] qout_2,
  output logic[WIDTH-1:0] qout_3,

  //write port (data is written on the rising clock edge)
  input logic unsigned[$clog2(HEIGHT)-1:0] write_addr,
  
  // Three inputs: 
  input logic [WIDTH-1:0] din,
  input logic [WIDTH-1:0] din_2,
  input logic [WIDTH-1:0] din_3,

  input logic write_en
  );


  //storage
  logic [WIDTH-1:0] data [HEIGHT];

  always @ (posedge clk) begin
    if (write_en) begin
        data[write_addr]   <= din;
        data[write_addr+1] <= din_2;
        data[write_addr+2] <= din_3;
    end
  end

  assign qout   = read_en ? data[read_addr]   :'x ;
  assign qout_2 = read_en ? data[read_addr+1] :'x ;
  assign qout_3 = read_en ? data[read_addr+2] :'x ;

  `ifndef TARGET_SYNTHESIS
  //area logging
  initial begin
    #0;
    if(!USED_AS_EXTERNAL_MEM) begin
      if (HEIGHT<128) begin
        tbench_top.area += 17*WIDTH*HEIGHT;
        $display("%m added %d to area", 17*WIDTH*HEIGHT);
      end else begin
        tbench_top.area += 1*WIDTH*HEIGHT;
        $display("%m added %d to area", 1*WIDTH*HEIGHT);
      end
    end
  end

  //energy logging:
  always @(posedge clk) begin
    if(read_en)
      tbench_top.energy += 3*WIDTH*(USED_AS_EXTERNAL_MEM?1:0.1);
  end
  always @(posedge clk) begin
    if(write_en) //NB: if only read/write disable the other! 
      tbench_top.energy += 3*WIDTH*(USED_AS_EXTERNAL_MEM?1:0.1);
  end
  `endif
endmodule
