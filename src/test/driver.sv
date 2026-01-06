// Version: Optimal loop ordering
class Driver #(
    config_t cfg
);

  virtual intf #(cfg) intf_i; // Setup / Connect to Interface

  localparam int x_step = cfg.CONV_STEP == 4 ? 4 : 3; // If conv stride is 4 then we skip an entire column, else we will send the next column regardless | Note +3 as we send three column elements at a time
  localparam int y_step = cfg.CONV_STEP == 4 ? 4 : 3; // If conv stride is 4 then we skip an entire row,    else we will send the next row regardles
  // TODO: CHECK THIS ^^

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
      for (int outch = 0; outch < cfg.OUTPUT_NB_CHANNELS; outch++) begin
        $display("[DRV] ----- Driving kernel data for output channel %d -----", outch);
        // First send Kernel Data as is stationary here: 
        intf_i.cb.b_valid <= 1; // Signal kernel data ready to send
        for (int ky = 0; ky < cfg.KERNEL_SIZE; ky++) begin
          for (int inch = 0; inch < cfg.INPUT_NB_CHANNELS; inch++) begin
          // Assert kernel data is valid: 
            assert (
              !$isunknown({
                  tract_kernel.kernel[ky][2][inch][outch],
                  tract_kernel.kernel[ky][1][inch][outch],
                  tract_kernel.kernel[ky][0][inch][outch]
              })
            ) else $fatal("[DRV] Kernel data invalid!");
            intf_i.cb.io_bus  <= {
              tract_kernel.kernel[ky][2][inch][outch],
              tract_kernel.kernel[ky][1][inch][outch],
              tract_kernel.kernel[ky][0][inch][outch]
            };
            @(intf_i.cb iff intf_i.cb.b_ready); // Wait for ACK
            intf_i.cb.b_valid <= 0;
          end
        end

        $display("[DRV] ----- Kernel data for output channel %d loaded! -----", outch);
        for (int x = 0; x < 129 ; x = x + x_step) begin
          $display("[DRV] %.2f %% of the input is transferred",
                 ((x) * 100.0) / 130);
          // Block if IO_bus is sending output data back | TODO: might have to be at end 
          for (int y = -1; y < 130; y = y + y_step ) begin 
            for (int ky = 0; ky < 3; ky = ky +1 ) begin
              for (int inch = 0; inch < 2; inch++) begin
                intf_i.cb.a_valid <= 1; // Signal data is ready to interface 
                if(y+ky > 128)
                  break;
                $display("[DRV] Sending ch = %d, (x= %d +2, y = %d)", inch, x, y+ky);
                //Check if not at top / bottom boundary

                intf_i.cb.x_driver <= x;
                intf_i.cb.y_driver <= y+ky;
                if( y+ky == -1 || y+ky == 128 ) begin
                  // At top or bottom boundary 
                  intf_i.cb.io_bus  <= 48'b0;  
                end 
                  // Check if Left element (L) is zero
                else if ( x-1 == -1 ) begin
                    //Send 0 for first 16b
                    intf_i.cb.io_bus  <= {tract_feature.inputs[y+ky][x+1][inch],tract_feature.inputs[y+ky][x][inch], 16'b0}; 
                  // Check if R is zero
                end else if ( x+2 == 128 ) begin
                    //Send 0 for last 16b
                    intf_i.cb.io_bus  <= {16'b0, tract_feature.inputs[y+ky][x+1][inch], tract_feature.inputs[y+ky][x][inch]};
                  // Else not near boundaries
                end else begin
                    // Send data 
                    intf_i.cb.io_bus  <= {tract_feature.inputs[y+ky][x+2][inch],tract_feature.inputs[y+ky][x+1][inch],tract_feature.inputs[y+ky][x][inch]};
                end
              end // end inch
              @(intf_i.cb iff intf_i.cb.a_ready); // Wait till ACK
              intf_i.cb.a_valid <= 0; 
            end   // end ky
          end     // end y
        end       // end x

        // Wait till has read out for current channel out 
        intf_i.cb.io_bus  <= 'z;
        wait(intf_i.cb.b_ready);
      end         // end outch

      @(intf_i.cb iff intf_i.cb.done); // Wait for pipeline to finish before giving latency results
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
