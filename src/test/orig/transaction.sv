class Transaction_Feature #(
    config_t cfg
);
  rand
  logic signed [cfg.DATA_WIDTH - 1 : 0]
  inputs [0 : cfg.FEATURE_MAP_WIDTH - 1][0 : cfg.FEATURE_MAP_HEIGHT - 1][0 : cfg.INPUT_NB_CHANNELS-1];

  constraint inputs_sparsity {
    foreach (inputs[i, j, k])
    inputs[i][j][k] dist { // dist sets how likely a random value is created 
    //so in this case 0 has a 50% weigthing, the set [1:(2**DATA_WIDTH)-1] 25% and [-(2**DATA_WIDTH -1):-1] 25%
      0 :/ 50, // TODO: INVESTIGATE SPARSITY!!
      [1 : (2 ** cfg.DATA_WIDTH - 1)] :/ 25,
      [-(2 ** cfg.DATA_WIDTH - 1) : -1] :/ 25
    };
  }
endclass

class Transaction_Kernel #(
    config_t cfg
);
  rand
  logic signed [cfg.DATA_WIDTH - 1 : 0]
  kernel [0:cfg.KERNEL_SIZE - 1][0:cfg.KERNEL_SIZE - 1][0 : cfg.INPUT_NB_CHANNELS - 1][0 : cfg.OUTPUT_NB_CHANNELS - 1];
  constraint kernel_sparsity {
    foreach (kernel[i, j, k, l])
    kernel[i][j][k][l] dist {
      0 :/ 50,
      [1 : (2 ** cfg.DATA_WIDTH - 1)] :/ 25,
      [-(2 ** cfg.DATA_WIDTH - 1) : -1] :/ 25
    };
  }
endclass

class Transaction_Output_Word #(
    config_t cfg
);
  logic signed [                cfg.DATA_WIDTH-1:0] output_data;
  logic        [ $clog2(cfg.FEATURE_MAP_WIDTH)-1:0] output_x;
  logic        [$clog2(cfg.FEATURE_MAP_HEIGHT)-1:0] output_y;
  logic        [$clog2(cfg.OUTPUT_NB_CHANNELS)-1:0] output_ch;
endclass
