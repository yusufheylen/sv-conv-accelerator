class Monitor #(
    config_t cfg
);
  virtual intf #(cfg) intf_i;
  mailbox #(Transaction_Output_Word #(cfg)) mon2chk;

  function new(virtual intf #(cfg) intf_i, mailbox#(Transaction_Output_Word#(cfg)) m2c);
    this.intf_i = intf_i;
    mon2chk = m2c;
  endfunction : new

  task run;
    @(intf_i.cb iff intf_i.arst_n);
    forever begin
      Transaction_Output_Word #(cfg) tract_output;
      tract_output = new();
      @(intf_i.cb iff intf_i.cb.output_valid);

      // ? IS THIS CORRECT?? 
      tract_output.output_data = intf_i.cb.io_bus[15:0];
      tract_output.output_x    = intf_i.cb.output_x;
      tract_output.output_y    = intf_i.cb.output_y;
      tract_output.output_ch   = intf_i.cb.output_ch;
      mon2chk.put(tract_output);
      
      tract_output.output_data = intf_i.cb.io_bus[31:16];
      tract_output.output_x    = intf_i.cb.output_x;
      tract_output.output_y    = intf_i.cb.output_y+1;
      tract_output.output_ch   = intf_i.cb.output_ch;
      mon2chk.put(tract_output);

      tract_output.output_data = intf_i.cb.io_bus[47:32];
      tract_output.output_x    = intf_i.cb.output_x;
      tract_output.output_y    = intf_i.cb.output_y+2;
      tract_output.output_ch   = intf_i.cb.output_ch;
      mon2chk.put(tract_output);

    end
  endtask

endclass : Monitor
