
typedef struct {
  int DATA_WIDTH         = 16;
  int ACCUMULATION_WIDTH = 32;
  int EXT_MEM_HEIGHT     = 1 << 20;
  int EXT_MEM_WIDTH      = 32;
  int FEATURE_MAP_WIDTH  = 128;
  int FEATURE_MAP_HEIGHT = 128;
  int INPUT_NB_CHANNELS  = 2;
  int OUTPUT_NB_CHANNELS = 16;
  int KERNEL_SIZE        = 3;
  int CONV_STEP          = 1; //VARIABLE
} config_t;
