/**
 * Memory array module represents a 2D grid of r/w memory elements. Each location stores data of size DATA_WIDTH.
 * The module expects to write 3 location units at a time, and reads out 9 location units at a time. 
 * Memory Calculations are done using the memory.sv module. 
**/
module memory_array #(
  parameter int MEM_WIDTH = 16,         // #bits per memory unit
  parameter int DIM_Y     = 128,        // i.e. HEIGHT
  parameter int DIM_X     = 66,         // i.e. WIDTH
  parameter bit USED_AS_EXTERNAL_MEM = 0// for area, bandwidth and energy estimation
  )
  (
  input logic clk,
  input logic arst_n_in,

  input logic write_en,
  input logic [47:0]  din,      // Data to write (i.e. three locations ) | Expects {(x+2,y);(x+1,y);(x,y)} i.e. MSB 16b is x+2 and LSB 16b is x

  input logic [7:0] x_write,    // Valid x coordinates will be 0 -> 127  | Will write to all of (x_write, x_write  +1, x_write +2) %63
  input logic [7:0] y_write,    // Valid y coordinates will be 0 -> 127 

  input logic mem_rst, 

  input logic read_en,

  input logic [7:0] x_read, // Can read simultaneously (for Pipelining)
  input logic [7:0] y_read, // Will read out a 3x3 with the top left corner being (x_read,y_read)

  output logic signed[47:0] output_grid[0:2] // Ouput is a grid of locations (x,y) -> (x+2,y+2) | Note that x is located on each 16b, this is done for the multiplier array 
);

  // TODO: RESET 

  //storage
  logic [MEM_WIDTH-1:0] data [0:DIM_Y-1][0:DIM_X-1]; // row x col 

  // Write on rising edge  
  always @ (posedge clk, negedge arst_n_in) begin
    if (arst_n_in) begin 
      foreach(data[i])
        foreach(data[i][j])
          data[i][j] <= '0;
    end
    else if (write_en) begin
        // Write three locations (adjacent columns)
        data[y_write][x_write%63] <= din[15:0]; data[y_write][(x_write+1)%63] <= din[31:16]; data[y_write][(x_write+2)%63] <= din[47:32]; 
    end else if (mem_rst) begin
      foreach(data[i])
        foreach(data[i][j])
          data[i][j] <= '0; 
    end
  end

  // Read instantaneously - elements (x,y) -> (x+2, y+2)
  assign output_grid[0][15:0]   = read_en ? data[x_read%63][y_read      ] : 'x;
  assign output_grid[0][31:16]  = read_en ? data[(x_read+1)%63][y_read  ] : 'x;
  assign output_grid[0][47:32]  = read_en ? data[(x_read+2)%63][y_read  ] : 'x;

  assign output_grid[1][15:0]   = read_en ? data[x_read%63][y_read+1    ] : 'x;
  assign output_grid[1][31:16]  = read_en ? data[(x_read+1)%63][y_read+1] : 'x;
  assign output_grid[1][47:32]  = read_en ? data[(x_read+2)%63][y_read+1] : 'x;

  assign output_grid[2][15:0]   = read_en ? data[x_read%63][y_read+2    ]   : 'x;
  assign output_grid[2][31:16]  = read_en ? data[(x_read+1)%63][y_read+2] : 'x;
  assign output_grid[2][47:32]  = read_en ? data[(x_read+2)%63][y_read+2] : 'x;

  `ifndef TARGET_SYNTHESIS
  initial begin
    #0;
    //area logging | NOTE: This has been adjusted accordingly 
    if(!USED_AS_EXTERNAL_MEM) begin
      if (DIM_Y<128) begin
        tbench_top.area += 17*MEM_WIDTH*DIM_X*DIM_Y;
        $display("%m added %d to area", 17*MEM_WIDTH*DIM_X*DIM_Y); // factor*bits*x_width*y_width
      end else begin
        tbench_top.area += 1*MEM_WIDTH*DIM_X*DIM_Y;
        $display("%m added %d to area", 1*MEM_WIDTH*DIM_X*DIM_Y); // factor*bits*x_width*y_width
      end
    end
  end

  //energy logging | NOTE: These values have been adjusted accordingly 
  always @(posedge clk) begin
    if(read_en)
      tbench_top.energy += 9*MEM_WIDTH*(USED_AS_EXTERNAL_MEM?1:0.1);    // Reads 9 at a time
  end
  always @(posedge clk) begin
    if(write_en) 
      tbench_top.energy += 3*MEM_WIDTH*(USED_AS_EXTERNAL_MEM?1:0.1);    // Writes 3 at a time
  end
  `endif

endmodule
