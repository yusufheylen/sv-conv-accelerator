// //This is a simple testbench only for CONV, not in object-oriented style

// module tbench_top;

//   localparam int IO_DATA_WIDTH = 16;
//   localparam int ACCUMULATION_WIDTH = 32;
//   localparam int EXT_MEM_HEIGHT = 1 << 20;
//   localparam int EXT_MEM_WIDTH = ACCUMULATION_WIDTH;
//   localparam int FEATURE_MAP_WIDTH = 128;
//   localparam int FEATURE_MAP_HEIGHT = 128;
//   localparam int INPUT_NB_CHANNELS = 2;
//   localparam int OUTPUT_NB_CHANNELS = 16;
//   localparam int KERNEL_SIZE = 3;

//   logic clk = 0;
//   always #0.5ns clk = ~clk;
//   logic arst_n;
//   initial begin
//     #1ns;
//     arst_n = 0;
//     #2ns;
//     @(posedge clk);
//     #0.1ns;
//     arst_n = 1;
//   end


//   logic [IO_DATA_WIDTH-1:0] a_input, b_input;
//   logic a_valid, b_valid, a_ready, b_ready;

//   logic signed [IO_DATA_WIDTH-1:0] output_data;
//   logic output_valid;
//   logic [$clog2(FEATURE_MAP_WIDTH)-1:0] output_x;
//   logic [$clog2(FEATURE_MAP_HEIGHT)-1:0] output_y;
//   logic [$clog2(OUTPUT_NB_CHANNELS)-1:0] output_ch;

//   logic start;
//   top_system #(
//       .IO_DATA_WIDTH(IO_DATA_WIDTH),
//       .ACCUMULATION_WIDTH(ACCUMULATION_WIDTH),
//       .EXT_MEM_HEIGHT(EXT_MEM_HEIGHT),
//       .EXT_MEM_WIDTH(EXT_MEM_WIDTH),
//       .FEATURE_MAP_WIDTH(FEATURE_MAP_WIDTH),
//       .FEATURE_MAP_HEIGHT(FEATURE_MAP_HEIGHT),
//       .INPUT_NB_CHANNELS(INPUT_NB_CHANNELS),
//       .OUTPUT_NB_CHANNELS(OUTPUT_NB_CHANNELS),
//       .KERNEL_SIZE(KERNEL_SIZE)
//   ) dut (
//       .clk(clk),
//       .arst_n_in(arst_n),
//       .conv_mode(1'b0),  // this testbench is an example and works only for conv
//       .a_input(a_input),
//       .b_input(b_input),
//       .a_valid(a_valid),
//       .b_valid(b_valid),
//       .a_ready(a_ready),
//       .b_ready(b_ready),

//       .out(output_data),
//       .output_valid(output_valid),
//       .output_x(output_x),
//       .output_y(output_y),
//       .output_ch(output_ch),

//       .start  (start),
//       .running(running)
//   );


//   logic signed [IO_DATA_WIDTH-1:0] inputs [0:FEATURE_MAP_HEIGHT-1][0:FEATURE_MAP_HEIGHT-1][0:INPUT_NB_CHANNELS-1];
//   logic signed [IO_DATA_WIDTH-1:0] kernel [0:KERNEL_SIZE-1][0:KERNEL_SIZE-1][0:INPUT_NB_CHANNELS-1][0:OUTPUT_NB_CHANNELS-1];
//   ;
//   logic signed [IO_DATA_WIDTH-1:0] outputs [0:FEATURE_MAP_HEIGHT-1][0:FEATURE_MAP_HEIGHT-1][0:OUTPUT_NB_CHANNELS-1];
//   logic output_tested[0:FEATURE_MAP_HEIGHT-1][0:FEATURE_MAP_HEIGHT-1][0:OUTPUT_NB_CHANNELS-1];

//   //mark all outputs as not tested (received) yet
//   initial begin
//     std::randomize(inputs);
//     std::randomize(kernel);
//     for (int x = 0; x < FEATURE_MAP_WIDTH; x++) begin
//       for (int y = 0; y < FEATURE_MAP_HEIGHT; y++) begin
//         for (int outch = 0; outch < OUTPUT_NB_CHANNELS; outch++) begin
//           output_tested[y][x][outch] = 0;
//         end
//       end
//     end
//   end

//   //when done, check if all outputs are received
//   initial begin
//     wait (running);
//     wait (!running);
//     repeat (10) @(posedge clk);

//     for (int x = 0; x < FEATURE_MAP_WIDTH; x++) begin
//       for (int y = 0; y < FEATURE_MAP_HEIGHT; y++) begin
//         for (int outch = 0; outch < OUTPUT_NB_CHANNELS; outch++) begin
//           if (!output_tested[y][x][outch]) begin
//             $display("NOT TESTED@: %0d, %0d, %0d", y, x, outch);
//           end
//         end
//       end
//     end
//     $finish();
//   end

//   //check all received outputs, and mark them as received
//   initial begin
//     wait (!arst_n);
//     @(posedge clk iff arst_n);
//     forever begin
//       logic signed [IO_DATA_WIDTH] expected, actual;
//       @(posedge clk iff output_valid);
//       output_tested[output_y][output_x][output_ch] = 1;
//       expected = 0;

//       //software calculation of expected output
//       for (int inch = 0; inch < INPUT_NB_CHANNELS; inch++) begin
//         for (int kx = 0; kx < KERNEL_SIZE; kx++) begin
//           for (int ky = 0; ky < KERNEL_SIZE; ky++) begin
//             logic signed [IO_DATA_WIDTH-1:0] feature;
//             logic signed [IO_DATA_WIDTH-1:0] weight;
//             logic signed [ACCUMULATION_WIDTH-1:0] prod;

//             if( output_x+kx-KERNEL_SIZE/2 >= 0 && output_x+kx-KERNEL_SIZE/2 < FEATURE_MAP_WIDTH
//               &&output_y+ky-KERNEL_SIZE/2 >= 0 && output_y+ky-KERNEL_SIZE/2 < FEATURE_MAP_HEIGHT)
//               feature = inputs[output_y+ky-KERNEL_SIZE/2][output_x+kx-KERNEL_SIZE/2][inch];
//             else feature = 0;

//             weight = kernel[ky][kx][inch][output_ch];
//             prod = weight * feature;
//             expected = expected + prod;
//           end
//         end
//       end

//       actual = output_data;
//       if (expected === output_data) begin
//         $display("OK    @: %0d, %0d, %0d", output_y, output_x, output_ch);
//       end else begin
//         $display("NOT OK@: %0d, %0d, %0d: real %0d (%0x; %0b) != %0d (%0x; %0b) expected", output_y,
//                  output_x, output_ch, actual, actual, actual, expected, expected, expected);
//         $stop();
//       end
//     end
//   end

//   //hardware driving
//   initial begin
//     start   <= 0;
//     a_valid <= 0;
//     b_valid <= 0;
//     wait (!arst_n);
//     @(posedge clk iff arst_n);
//     start <= 1;
//     @(posedge clk);
//     start <= 0;
//     //loops matching order of controller_fsm
//     for (int x = 0; x < FEATURE_MAP_WIDTH; x++) begin
//       $display("%0d/%0d", x, FEATURE_MAP_WIDTH);
//       for (int y = 0; y < FEATURE_MAP_HEIGHT; y++) begin
//         for (int inch = 0; inch < OUTPUT_NB_CHANNELS; inch++) begin
//           for (int outch = 0; outch < OUTPUT_NB_CHANNELS; outch++) begin
//             for (int ky = 0; ky < KERNEL_SIZE; ky++) begin
//               for (int kx = 0; kx < KERNEL_SIZE; kx++) begin
//                 //drive a
//                 a_valid <= 1;
//                 if( x+kx-KERNEL_SIZE/2 >= 0 && x+kx-KERNEL_SIZE/2 < FEATURE_MAP_WIDTH
//                   &&y+ky-KERNEL_SIZE/2 >= 0 && y+ky-KERNEL_SIZE/2 < FEATURE_MAP_HEIGHT)
//                   a_input <= inputs[y+ky-KERNEL_SIZE/2][x+kx-KERNEL_SIZE/2][inch];
//                 else a_input <= 0;
//                 @(posedge clk iff a_ready);
//                 a_valid <= 0;

//                 //drive b
//                 b_valid <= 1;
//                 b_input <= kernel[ky][kx][inch][outch];
//                 @(posedge clk iff b_ready);
//                 b_valid <= 0;
//               end
//             end
//           end
//         end
//       end
//     end
//   end




// endmodule
