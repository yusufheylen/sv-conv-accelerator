for (int ky = 0; ky < cfg.KERNEL_SIZE; ky++) begin

  // Send one whole (data) line

  // Data ready

  intf_i.cb.a_valid <= 1; // Signal (a) data is ready to interface 



  // Check if not at top / bottom boundary

  if (y + ky - cfg.KERNEL_SIZE / 2 >= 0 && 
      y + ky - cfg.KERNEL_SIZE / 2 < cfg.FEATURE_MAP_HEIGHT
      ) begin

    // Check if L is zero

    if (x - cfg.KERNEL_SIZE / 2 < 0) begin

      // Send 0 for first 16b

      if (x + 2 - cfg.KERNEL_SIZE / 2 < cfg.FEATURE_MAP_WIDTH) begin

        assert (
          !$isunknown(
            tract_feature.inputs[y + ky - cfg.KERNEL_SIZE / 2][x + 2 - cfg.KERNEL_SIZE / 2][inch]
            ));

      end

      if (x + 1 - cfg.KERNEL_SIZE / 2 < cfg.FEATURE_MAP_WIDTH) begin

        assert (!$isunknown(tract_feature.inputs[y + ky - cfg.KERNEL_SIZE / 2][x + 1 - cfg.KERNEL_SIZE / 2][inch]));

      end

      intf_i.cb.a_input <= {tract_feature.inputs[y + ky - cfg.KERNEL_SIZE / 2][x + 2 - cfg.KERNEL_SIZE / 2][inch], tract_feature.inputs[y + ky - cfg.KERNEL_SIZE / 2][x + 1 - cfg.KERNEL_SIZE / 2][inch], 16'b0};

    // Check if R is zero

    end else if (x + 2 - cfg.KERNEL_SIZE / 2 == cfg.FEATURE_MAP_WIDTH) begin

      assert (!$isunknown(tract_feature.inputs[y + ky - cfg.KERNEL_SIZE / 2][x - cfg.KERNEL_SIZE / 2][inch]));

      intf_i.cb.a_input <= {16'b0, tract_feature.inputs[y + ky - cfg.KERNEL_SIZE / 2][x + 1 - cfg.KERNEL_SIZE / 2][inch], tract_feature.inputs[y + ky - cfg.KERNEL_SIZE / 2][x - cfg.KERNEL_SIZE / 2][inch]};

    // Else or data is valid

    end else begin

      // Send next three values

      // Sanity check

      if (x - cfg.KERNEL_SIZE / 2 >= 0 && x + 1 - cfg.KERNEL_SIZE / 2 < cfg.FEATURE_MAP_WIDTH && x + 2 - cfg.KERNEL_SIZE / 2 < cfg.FEATURE_MAP_WIDTH) begin

        assert (!$isunknown(tract_feature.inputs[y + ky - cfg.KERNEL_SIZE / 2][x - cfg.KERNEL_SIZE / 2][inch]));

        assert (!$isunknown(tract_feature.inputs[y + ky - cfg.KERNEL_SIZE / 2][x + 1 - cfg.KERNEL_SIZE / 2][inch]));

        assert (!$isunknown(tract_feature.inputs[y + ky - cfg.KERNEL_SIZE / 2][x + 2 - cfg.KERNEL_SIZE / 2][inch]));

      end

      intf_i.cb.a_input <= {tract_feature.inputs[y + ky - cfg.KERNEL_SIZE / 2][x + 2 - cfg.KERNEL_SIZE / 2][inch], tract_feature.inputs[y + ky - cfg.KERNEL_SIZE / 2][x + 1 - cfg.KERNEL_SIZE / 2][inch], tract_feature.inputs[y + ky - cfg.KERNEL_SIZE / 2][x - cfg.KERNEL_SIZE / 2][inch]};

    end

  // Either at the top / bottom row

  end else begin

    // Send all 0

    intf_i.cb.a_input <= 48'b0;  

  end

  @(intf_i.cb iff intf_i.cb.a_ready); //?

  intf_i.cb.a_valid <= 0;



  // Drive one kernel row

  intf_i.cb.b_valid <= 1;

  assert (!$isunknown({tract_kernel.kernel[ky][2][inch][outch], tract_kernel.kernel[ky][1][inch][outch], tract_kernel.kernel[ky][0][inch][outch]}));

  intf_i.cb.b_input <= {tract_kernel.kernel[ky][2][inch][outch], tract_kernel.kernel[ky][1][inch][outch], tract_kernel.kernel[ky][0][inch][outch]}; // send kernel row data 

  @(intf_i.cb iff intf_i.cb.b_ready);

  intf_i.cb.b_valid <= 0;

end

