#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require_relative 'test_helper'

module Yast
  Yast.import 'ServicesManagerTarget'
  Yast.import 'ServicesManager'
  Yast.import 'Installation'
  Yast.import 'Arch'
  Yast.import 'Pkg'

  extend Yast::I18n
  Yast::textdomain "services-manager"

  TARGETS = {
    "multi-user"=>{
      :enabled=>true, :loaded=>true, :active=>true, :description=>"Multi-User System"
    },
    "emergency"=>{
      :enabled=>false, :loaded=>true, :active=>false, :description=>"Emergency Mode"
    },
    "graphical"=>{
      :enabled=>false, :loaded=>true, :active=>false, :description=>"Graphical Interface"
    },
    "rescue"=>{
      :enabled=>false, :loaded=>true, :active=>false, :description=>"Rescue Mode"
    }
  }

  describe ServicesManager do
    before(:each) do
      log.info "--- test ---"
      allow(Yast::ServicesManagerService).to receive(:services).and_return({})
      allow(Yast::ServicesManagerTarget).to receive(:targets).and_return(TARGETS)
    end

    describe ".errors" do
      it "delegates errors to ServiceManagerService" do
        allow(Yast::ServicesManagerService).to receive(:errors).and_return(["Error msg"])
        expect(Yast::ServicesManager.errors).to eq ["Error msg"]
      end
    end

    describe "#export" do
      let(:services) { { enabled: ["cups"], disabled: ["nfsserver"] } }

      before do
        allow(Yast::ServicesManagerService).to receive(:export).and_return(services)
        allow(Yast::ServicesManagerTarget).to receive(:export).and_return("graphical")
      end

      it "exports systemd target and services" do
        expect(Yast::ServicesManager.export).to eq({
          "default_target" => "graphical",
          "services" => services
        })
      end
    end

    describe "#import" do
      context "when using AutoYast profile written in SLE 11 format" do
        it "imports data for systemd target and services" do
          data = {
            'default' => '3',
            'services' => [
              {
                'service_name' => 'sa',
                'service_status' => 'enable',
                'service_start' => '3',
              },
              {
                'service_name' => 'sb',
                'service_status' => 'enable',
                'service_start' => '3',
              },
              {
                'service_name' => 'YaST2-Second-Stage',
                'service_status' => 'enable',
                'service_start' => '3',
              },
              {
                'service_name' => 'YaST2-Firstboot',
                'service_status' => 'enable',
                'service_start' => '3',
              },
              {
                'service_name' => 'sc',
                'service_status' => 'disable',
                'service_start' => '3',
              },
            ]
          }

          expect(ServicesManagerService).to receive(:exists?).with(/^s[abc]$/).at_least(:once).and_return(true)
          expect(ServicesManagerService).to receive(:set_start_mode)
            .with(/^s[ab]$/, :on_boot).twice.and_return(true)
          expect(ServicesManagerService).to receive(:set_start_mode)
            .with("sc", :manual).and_return(true)

          expect(ServicesManagerService).to receive(:import).and_call_original
          expect(ServicesManagerTarget).to receive(:import).and_call_original
          expect(ServicesManager.import(data)).to eq(true)
        end

        it "imports data for systemd target runlevel 3" do
          data = {
            'default' => '3'
          }

          expect(ServicesManagerTarget).to receive(:import).and_call_original
          expect(ServicesManager.import(data)).to eq(true)
          expect(ServicesManagerTarget.default_target).to eq("multi-user")
        end

        it "imports data for systemd target runlevel 5" do
          data = {
            'default' => '5'
          }

          expect(ServicesManagerTarget).to receive(:import).and_call_original
          expect(ServicesManager.import(data)).to eq(true)
          expect(ServicesManagerTarget.default_target).to eq("graphical")
        end
      end

      context "when using AutoYast profile written in pre-SLE 12 format" do
        it "imports data for systemd target and services" do
          data = {
            'default_target' => 'multi-user',
            'services'       => ['x', 'y', 'z']
          }

          expect(ServicesManagerService).to receive(:exists?).with(/^[xyz]$/).at_least(:once).and_return(true)

          expect(ServicesManagerService).to receive(:import).and_call_original
          expect(ServicesManagerTarget).to receive(:import).and_call_original
          expect(ServicesManager.import(data)).to eq(true)
        end

        it "imports data for systemd target multi-user" do
          data = {
            'default_target' => 'multi-user',
          }

          expect(ServicesManagerTarget).to receive(:import).and_call_original
          expect(ServicesManager.import(data)).to eq(true)
          expect(ServicesManagerTarget.default_target).to eq("multi-user")
        end

        it "imports data for systemd target graphical" do
          data = {
            'default_target' => 'graphical',
          }

          expect(ServicesManagerTarget).to receive(:import).and_call_original
          expect(ServicesManager.import(data)).to eq(true)
          expect(ServicesManagerTarget.default_target).to eq("graphical")
        end
      end

      context "when using AutoYast profile without any default_target entry" do
        it "setting to multi-user if X11 is not available" do
          expect(Installation).to receive(:x11_setup_needed).and_return(false)
          expect(ServicesManagerTarget).to receive(:import).and_call_original
          expect(ServicesManager.import({})).to eq(true)
          expect(ServicesManagerTarget.default_target).to eq("multi-user")
        end

        it "setting to graphical if X11 is available" do
          expect(Installation).to receive(:x11_setup_needed).and_return(true)
          expect(Arch).to receive(:x11_setup_needed).and_return(true)
          expect(Pkg).to receive(:IsSelected).with("xdm").and_return(true)
          expect(ServicesManagerTarget).to receive(:import).and_call_original
          expect(ServicesManager.import({})).to eq(true)
          expect(ServicesManagerTarget.default_target).to eq("graphical")
        end
      end

      context "when configuration hasn't been cloned/modified" do
        it "returns information that it hasn't been configured yet" do
          expect(ServicesManager).to receive(:modified?).and_return(false)
          expect(ServicesManager.auto_summary).to eq(Yast::_("Not configured yet."))
        end
      end

      context "when configuration has been cloned/modified" do
        it "returns HTML-formatted autoyast summary with HTML-escaped values" do
          expect(ServicesManager).to receive(:modified?).and_return(true)
          expect(ServicesManagerTarget).to receive(:export).and_return("multi-head-graphical-hydra")
          expect(ServicesManagerService).to receive(:export).and_return({
            "enable" => ["service-1", "service-<br>-2", "service-<b>name</b>-3"],
            "disable" => ["service-4", "service-<br>-5", "service-<b>name</b>-6"],
          })

          summary = ServicesManager.auto_summary
          ["multi-head-graphical-hydra", "service-[14]", "service-&lt;br&gt;-[25]", "service-&lt;b&gt;name&lt;/b&gt;-[36]"].each do |item|
            expect(summary).to match(/#{item}/)
          end
        end
      end
    end

    describe "#read" do
      it "reads services and targets" do
        expect(Yast::ServicesManagerService).to receive(:read)
        expect(Yast::ServicesManagerTarget).to receive(:read)
        subject.read
      end

      it "returns nil" do
        allow(Yast::ServicesManagerService).to receive(:read)
        allow(Yast::ServicesManagerTarget).to receive(:read)
        expect(subject.read).to eq(nil)
      end
    end

    describe "#reset" do
      it "reads services and targets" do
        expect(Yast::ServicesManagerService).to receive(:reset)
        expect(Yast::ServicesManagerTarget).to receive(:reset)
        subject.reset
      end

      it "returns nil" do
        allow(Yast::ServicesManagerService).to receive(:reset)
        allow(Yast::ServicesManagerTarget).to receive(:reset)
        expect(subject.reset).to eq(nil)
      end
    end

    describe "#changes_summary" do
      before do
        allow(Yast::ServicesManagerTarget).to receive(:changes_summary).and_return(target_changes)
        allow(Yast::ServicesManagerService).to receive(:changes_summary).and_return(services_changes)
      end

      let(:target_changes) { "target changes" }
      let(:services_changes) { "services changes" }

      it "contains the summary of changes for the default target" do
        expect(subject.changes_summary).to include(target_changes)
      end

      it "contains the summary of changes for the services" do
        expect(subject.changes_summary).to include(services_changes)
      end

      context "when there are no changes" do
        let(:target_changes) { "" }
        let(:services_changes) { "" }

        it "returns an empty text" do
          expect(subject.changes_summary).to be_empty
        end
      end
    end
  end

  context "Global public API" do
    it "has available methods for both target and services" do
      public_methods = [ :save, :read, :reset, :modified ]
      public_methods.each do |method|
        expect(ServicesManagerService).to receive(method)
        expect(ServicesManagerTarget).to receive(method)
        ServicesManager.__send__(method)
      end

      expect(ServicesManagerService).to receive(:modified=).with(true)
      expect(ServicesManagerTarget).to receive(:modified=).with(true)
      ServicesManager.__send__(:modify)
    end
  end
end
