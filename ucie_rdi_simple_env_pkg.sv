`ifndef UCIE_RDI_SIMPLE_ENV_PKG_SV
`define UCIE_RDI_SIMPLE_ENV_PKG_SV

package ucie_rdi_simple_env_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import ucie_rdi_simple_agent_pkg::*;
  import ucie_rdi_simple_scb_pkg::*;

  `include "ucie_rdi_simple_monitor.sv"

  class ucie_rdi_simple_svt_env extends uvm_env;
    `uvm_component_utils(ucie_rdi_simple_svt_env)

    svt_ucie_d2d_vif us_rdi_vif;
    svt_ucie_d2d_vif ds_rdi_vif;
    ucie_rdi_simple_sequencer sequencer;
    ucie_rdi_simple_driver driver;
    ucie_rdi_simple_monitor us_mon;
    ucie_rdi_simple_monitor ds_mon;
    ucie_rdi_simple_scb scb;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(svt_ucie_d2d_vif)::get(this, "", "ucie_us_rdi_vif", us_rdi_vif))
        `uvm_fatal("RDI_SIMPLE_ENV", "Missing ucie_us_rdi_vif")
      if (!uvm_config_db#(svt_ucie_d2d_vif)::get(this, "", "ucie_ds_rdi_vif", ds_rdi_vif))
        `uvm_fatal("RDI_SIMPLE_ENV", "Missing ucie_ds_rdi_vif")

      sequencer = ucie_rdi_simple_sequencer::type_id::create("sequencer", this);
      driver = ucie_rdi_simple_driver::type_id::create("driver", this);
      us_mon = ucie_rdi_simple_monitor::type_id::create("us_mon", this);
      ds_mon = ucie_rdi_simple_monitor::type_id::create("ds_mon", this);
      scb = ucie_rdi_simple_scb::type_id::create("scb", this);

      uvm_config_db#(svt_ucie_d2d_vif)::set(this, "driver", "rdi_vif", us_rdi_vif);
      uvm_config_db#(svt_ucie_d2d_vif)::set(this, "us_mon", "rdi_vif", us_rdi_vif);
      uvm_config_db#(svt_ucie_d2d_vif)::set(this, "ds_mon", "rdi_vif", ds_rdi_vif);
      uvm_config_db#(ucie_rdi_simple_side_e)::set(this, "us_mon", "side", UCIE_RDI_SIMPLE_US);
      uvm_config_db#(ucie_rdi_simple_side_e)::set(this, "ds_mon", "side", UCIE_RDI_SIMPLE_DS);
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      driver.seq_item_port.connect(sequencer.seq_item_export);
      us_mon.ap.connect(scb.us_export);
      ds_mon.ap.connect(scb.ds_export);
    endfunction
  endclass
endpackage

`endif
