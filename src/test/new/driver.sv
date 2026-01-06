// Version send 48b at a time 
class Driver #(
    config_t cfg
);

  virtual intf #(cfg) intf_i; // Setup / Connect to Interface

  mailbox #(Transaction_Feature #(cfg)) gen2drv_feature; // Mailbox to get feature data from generator
  mailbox #(Transaction_Kernel #(cfg)) gen2drv_kernel;   // Mailbox to get kerenel data from generator

  // Get Data 
  function new(virtual intf #(cfg) i, mailbox#(Transaction_Feature#(cfg)) g2d_feature,
               mailbox#(Transaction_Kernel#(cfg)) g2d_kernel);
    intf_i = i;
    gen2drv_feature = g2d_feature;
    gen2drv_kernel = g2d_kernel;
  endfunction : new

  task reset;
    $display("[DRV] ----- Reset Started -----");
    //asynchronous start of reset
    intf_i.cb.start <= 0;
    intf_i.cb.conv_kernel_mode <= 0;
    intf_i.cb.conv_stride_mode <= 0;
    intf_i.cb.a_valid <= 0;
    intf_i.cb.b_valid <= 0;
    intf_i.cb.arst_n <= 0;
    repeat (2) @(intf_i.cb);
    intf_i.cb.arst_n <= 1;  //synchronous release of reset
    repeat (2) @(intf_i.cb);
    $display("[DRV] -----  Reset Ended  -----");
  endtask

  task run();
    // Get a transaction with kernel from the Generator
    // Kernel remains same throughput the verification 
    Transaction_Kernel #(cfg) tract_kernel;
    gen2drv_kernel.get(tract_kernel);

    $display("[DRV] -----  Start execution -----");

    forever begin
      time starttime;
      // Get a transaction with feature from the Generator
      Transaction_Feature #(cfg) tract_feature;
      gen2drv_feature.get(tract_feature);
      $display("[DRV] Programming configuration bits");
      intf_i.cb.conv_kernel_mode <= (cfg.KERNEL_SIZE - 1) / 2;
      intf_i.cb.conv_stride_mode <= $clog2(cfg.CONV_STEP);

      $display("[DRV] Giving start signal");
      intf_i.cb.start <= 1;
      starttime = $time();
      @(intf_i.cb);
      intf_i.cb.start <= 0;

      $display("[DRV] ----- Driving a new input feature map -----");
      for (int x = 0; x < cfg.FEATURE_MAP_WIDTH; x = x + cfg.CONV_STEP) begin
        $display("[DRV] %.2f %% of the input is transferred",
                 ((x) * 100.0) / cfg.FEATURE_MAP_WIDTH);
        for (int y = 0; y < cfg.FEATURE_MAP_HEIGHT; y = y + cfg.CONV_STEP) begin //COLOUMNS
          //
          for (int inch = 0; inch < cfg.INPUT_NB_CHANNELS; inch++) begin
            for (int outch = 0; outch < cfg.OUTPUT_NB_CHANNELS; outch++) begin
              /** TODO: 
               *  1. Swap iterations over the channels with the data i.e first iterate over the channels as Kernel is unique then
               *  2. Send kernel data over the bus and save in register 
               *  3. Iterate over the data
               *  4. Send 48bits = one row / coloumn of data for the convolution  
              **/
  
              for (int ky = 0; ky < cfg.KERNEL_SIZE; ky++) begin
                // Send one whole (data) line
                // Data ready
                intf_i.cb.a_valid <= 1; // Signal (a) data is ready to interface 

                //Check if not at top / bottom boundry
                // TODO: Zero boundry on chip
                if( 
                  y+ky-cfg.KERNEL_SIZE/2 >= 0 &&                    //Bottom (top) boundry
                  y+ky-cfg.KERNEL_SIZE/2 < cfg.FEATURE_MAP_HEIGHT   //Top (bottom) boundry 
                ) begin

                 
                  // Check if L is zero
                  if ( x-cfg.KERNEL_SIZE/2 < 0 ) begin
                    //Send 0 for first 16b
                    // TODO: CHECK WHICH IS L AND R (MSB VS LSB)
                    assert (
                      !$isunknown(
                        tract_feature.inputs[y+ky-cfg.KERNEL_SIZE/2][x+2-cfg.KERNEL_SIZE/2][inch]
                    ));
                    intf_i.cb.a_input <= {tract_feature.inputs[y+ky-cfg.KERNEL_SIZE/2 ][x+2-cfg.KERNEL_SIZE/2][inch],tract_feature.inputs[y+ky-cfg.KERNEL_SIZE/2 ][x+1-cfg.KERNEL_SIZE/2][inch], 16'b0}; 
                  // Check if R is zero
                  end else if (                    
                    x+2-cfg.KERNEL_SIZE/2 == cfg.FEATURE_MAP_WIDTH 
                  ) begin
                    assert (
                      !$isunknown(
                        tract_feature.inputs[y+ky-cfg.KERNEL_SIZE/2][x-cfg.KERNEL_SIZE/2][inch]
                    ));
                    //Send 0 for last 16b
                    intf_i.cb.a_input <= {16'b0, tract_feature.inputs[y+ky-cfg.KERNEL_SIZE/2 ][x+1-cfg.KERNEL_SIZE/2][inch], tract_feature.inputs[y+ky-cfg.KERNEL_SIZE/2 ][x-cfg.KERNEL_SIZE/2][inch]};
                  // Else or data is valid
                  end else begin
                    // Send next three values
                    // Sanity check
                    assert (
                      !$isunknown(
                        tract_feature.inputs[y+ky-cfg.KERNEL_SIZE/2][x-cfg.KERNEL_SIZE/2][inch]
                    ));
                    assert (
                      !$isunknown(
                        tract_feature.inputs[y+ky-cfg.KERNEL_SIZE/2][x+1-cfg.KERNEL_SIZE/2][inch]
                    ));
                    assert (
                      !$isunknown(
                        tract_feature.inputs[y+ky-cfg.KERNEL_SIZE/2][x+2-cfg.KERNEL_SIZE/2][inch]
                    ));

                    intf_i.cb.a_input <= {tract_feature.inputs[y+ky-cfg.KERNEL_SIZE/2 ][x+2-cfg.KERNEL_SIZE/2][inch],tract_feature.inputs[y+ky-cfg.KERNEL_SIZE/2 ][x+1-cfg.KERNEL_SIZE/2][inch],tract_feature.inputs[y+ky-cfg.KERNEL_SIZE/2 ][x-cfg.KERNEL_SIZE/2][inch]};
                  end
                // Either at the top / bottom row
                end else begin
                  // Send all 0
                  intf_i.cb.a_input <= 48'b0;  
                end
                @(intf_i.cb iff intf_i.cb.a_ready); //?
                intf_i.cb.a_valid <= 0;

                  //drive one kernel row
                  intf_i.cb.b_valid <= 1;
                  assert (
                    !$isunknown( {tract_kernel.kernel[ky][2][inch][outch],tract_kernel.kernel[ky][1][inch][outch],tract_kernel.kernel[ky][0][inch][outch]})
                  );
                  intf_i.cb.b_input <= {tract_kernel.kernel[ky][2][inch][outch],tract_kernel.kernel[ky][1][inch][outch],tract_kernel.kernel[ky][0][inch][outch]}; // send kernel row data 
                  @(intf_i.cb iff intf_i.cb.b_ready);
                  intf_i.cb.b_valid <= 0;
              end
            end
          end
        end
      end


      $display("\n\n------------------\nLATENCY: input processed in %t\n------------------\n",
               $time() - starttime);

      $display("------------------\nENERGY:  %0d\n------------------\n", tbench_top.energy);

      $display("------------------\nENERGYxLATENCY PRODUCT (/1e9):  %0d\n------------------\n",
               (longint'(tbench_top.energy) * ($time() - starttime)) / 1e9);

      tbench_top.energy = 0;

      $display("\n------------------\nAREA (breakdown see start): %0d\n------------------\n",
               tbench_top.area);

    end
  endtask : run
endclass : Driver
