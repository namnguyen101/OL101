`ifndef UCIE_RDI_SIMPLE_MONITOR_SVH
`define UCIE_RDI_SIMPLE_MONITOR_SVH

`ifndef UCIE_RDI_SIMPLE_ACTIVE_VALUE
`define UCIE_RDI_SIMPLE_ACTIVE_VALUE 4'h1
`endif

class ucie_rdi_simple_monitor extends uvm_monitor;
  `uvm_component_utils(ucie_rdi_simple_monitor)

  svt_ucie_d2d_vif rdi_vif;
  ucie_rdi_simple_side_e side;
  uvm_analysis_port #(ucie_rdi_simple_item) ap;

  bit [3:0] active_state_value = `UCIE_RDI_SIMPLE_ACTIVE_VALUE;
  bit       active_seen;
  bit       log_each_item = 1'b0;

  function new(string name = "ucie_rdi_simple_monitor", uvm_component parent = null);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    string side_name;

    super.build_phase(phase);

    if (!uvm_config_db#(svt_ucie_d2d_vif)::get(this, "", "rdi_vif", rdi_vif))
      `uvm_fatal("RDI_SIMPLE_MON", "rdi_vif must be set for ucie_rdi_simple_monitor")

    if (!uvm_config_db#(ucie_rdi_simple_side_e)::get(this, "", "side", side)) begin
      if (uvm_config_db#(string)::get(this, "", "side_name", side_name)) begin
        if (side_name == "US")
          side = UCIE_RDI_SIMPLE_US;
        else if (side_name == "DS")
          side = UCIE_RDI_SIMPLE_DS;
        else
          `uvm_fatal("RDI_SIMPLE_MON", $sformatf("Unsupported side_name '%s'", side_name))
      end else begin
        `uvm_fatal("RDI_SIMPLE_MON", "side must be set to UCIE_RDI_SIMPLE_US or UCIE_RDI_SIMPLE_DS")
      end
    end

    void'(uvm_config_db#(bit [3:0])::get(this, "", "active_state_value", active_state_value));
    void'(uvm_config_db#(bit)::get(this, "", "log_each_item", log_each_item));
  endfunction

  task run_phase(uvm_phase phase);
    `uvm_info("RDI_SIMPLE_MON",
              $sformatf("%s monitor started active_state_value=0x%0h",
                        side_to_string(), active_state_value),
              UVM_LOW)

    forever begin
      @(posedge rdi_vif.lclk);

      if (rdi_vif.reset) begin
        active_seen = 1'b0;
        continue;
      end

      if (!is_active()) begin
        active_seen = 1'b0;
        continue;
      end

      if (!active_seen) begin
        active_seen = 1'b1;
        `uvm_info("RDI_SIMPLE_MON",
                  $sformatf("%s RDI ACTIVE observed state=0x%0h inband=%0b",
                            side_to_string(), rdi_vif.pl_state_sts,
                            rdi_vif.pl_inband_pres),
                  UVM_LOW)
      end

      sample_mainband();
    end
  endtask

  function bit is_active();
    return ((rdi_vif.pl_state_sts == active_state_value) &&
            (rdi_vif.pl_inband_pres == 1'b1));
  endfunction

  task sample_mainband();
    ucie_rdi_simple_item item;

    if (rdi_vif.lp_valid && rdi_vif.lp_irdy && rdi_vif.pl_trdy) begin
      item = make_item(UCIE_RDI_SIMPLE_MAINBAND_TX);
      item.data = rdi_vif.lp_data;
      ap.write(item);
      log_item(item);
    end

    if (rdi_vif.pl_valid) begin
      item = make_item(UCIE_RDI_SIMPLE_MAINBAND_RX);
      item.data = rdi_vif.pl_data;
      ap.write(item);
      log_item(item);
    end
  endtask

  function ucie_rdi_simple_item make_item(ucie_rdi_simple_kind_e kind);
    ucie_rdi_simple_item item;

    item = ucie_rdi_simple_item::type_id::create("rdi_item");
    item.side = side;
    item.kind = kind;
    item.sample_time = $time;

    item.pl_state_sts = rdi_vif.pl_state_sts;
    item.pl_inband_pres = rdi_vif.pl_inband_pres;

    return item;
  endfunction

  function string side_to_string();
    case (side)
      UCIE_RDI_SIMPLE_US: return "US";
      UCIE_RDI_SIMPLE_DS: return "DS";
      default:            return "UNKNOWN";
    endcase
  endfunction

  function void log_item(ucie_rdi_simple_item item);
    if (log_each_item) begin
      `uvm_info("RDI_SIMPLE_MON",
                $sformatf("%s captured %s", side_to_string(),
                          item.convert2string()),
                UVM_MEDIUM)
    end
  endfunction
endclass

`endif
