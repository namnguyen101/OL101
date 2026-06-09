`ifndef UCIE_RDI_SIMPLE_MONITOR_B_SV
`define UCIE_RDI_SIMPLE_MONITOR_B_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
import ucie_phy_pkg::*;
import ucie_rdi_simple_scb_pkg::*;

class ucie_rdi_simple_monitor_b extends uvm_component;
  `uvm_component_utils(ucie_rdi_simple_monitor_b)

  virtual svt_ucie_d2d_if rdi_vif;
  uvm_analysis_port #(ucie_rdi_simple_flit) ap;
  bit active_seen;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual svt_ucie_d2d_if)::get(this, "", "rdi_vif", rdi_vif)) begin
      `uvm_fatal("RDI_SIMPLE_MON_B", "Missing rdi_vif for monitor B")
    end
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      @(posedge rdi_vif.lclk);
      if (rdi_vif.reset) begin
        active_seen = 1'b0;
      end else begin
        if ((rdi_vif.pl_state_sts == RDI_ACTIVE) && rdi_vif.pl_inband_pres) begin
          active_seen = 1'b1;
        end
        sample_tx();
        sample_rx();
      end
    end
  endtask

  task sample_tx();
    ucie_rdi_simple_flit item;
    if (active_seen && (rdi_vif.pl_state_sts == RDI_ACTIVE) &&
        rdi_vif.lp_valid && rdi_vif.lp_irdy && rdi_vif.pl_trdy) begin
      item = make_flit(UCIE_RDI_SIMPLE_TX);
      item.data = rdi_vif.lp_data;
      item.user = 16'h0;
      item.sop  = 1'b1;
      item.eop  = 1'b1;
      ap.write(item);
    end
  endtask

  task sample_rx();
    ucie_rdi_simple_flit item;
    if (active_seen && (rdi_vif.pl_state_sts == RDI_ACTIVE) && rdi_vif.pl_valid) begin
      item = make_flit(UCIE_RDI_SIMPLE_RX);
      item.data = rdi_vif.pl_data;
      item.user = 16'h0;
      item.sop  = 1'b1;
      item.eop  = 1'b1;
      ap.write(item);
    end
  endtask

  function ucie_rdi_simple_flit make_flit(ucie_rdi_simple_dir_e dir);
    ucie_rdi_simple_flit item;
    item = ucie_rdi_simple_flit::type_id::create("item");
    item.side = UCIE_RDI_SIMPLE_SIDE_B;
    item.dir = dir;
    item.sample_time = $time;
    item.pl_state_sts = rdi_vif.pl_state_sts;
    item.pl_link_cfg = rdi_vif.pl_link_cfg;
    item.pl_speed_mode = rdi_vif.pl_speed_mode;
    return item;
  endfunction
endclass

`endif
