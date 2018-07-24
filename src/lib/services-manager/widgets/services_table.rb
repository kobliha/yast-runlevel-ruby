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

require "yast"

Yast.import "UI"
Yast.import "ServicesManager"

module Y2ServicesManager
  module Widgets
    class ServicesTable
      include Yast
      include Yast::I18n
      include Yast::UIShortcuts

      extend Yast::I18n

      # Systemd states and substates might change. Use the following script to check
      # whether new states are not considered yet:
      #
      # https://github.com/yast/yast-services-manager/blob/systemd_states_check/devel/systemd_status_check.rb
      TRANSLATIONS = {
        service_state: {
          "activating"   => N_("Activating"),
          "active"       => N_("Active"),
          "deactivating" => N_("Deactivating"),
          "failed"       => N_("Failed"),
          "inactive"     => N_("Inactive"),
          "reloading"    => N_("Reloading")
        },
        service_substate: {
          "auto-restart"  => N_("Auto-restart"),
          "dead"          => N_("Dead"),
          "exited"        => N_("Exited"),
          "failed"        => N_("Failed"),
          "final-sigkill" => N_("Final-sigkill"),
          "final-sigterm" => N_("Final-sigterm"),
          "reload"        => N_("Reload"),
          "running"       => N_("Running"),
          "start"         => N_("Start"),
          "start-post"    => N_("Start-post"),
          "start-pre"     => N_("Start-pre"),
          "stop"          => N_("Stop"),
          "stop-post"     => N_("Stop-post"),
          "stop-sigabrt"  => N_("Stop-sigabrt"),
          "stop-sigkill"  => N_("Stop-sigkill"),
          "stop-sigterm"  => N_("Stop-sigterm")
        }
      }
      private_constant :TRANSLATIONS

      # Constructor
      #
      # @example
      #   ServicesTable.new(services_names: ["tftp", "cups"])
      #
      # @param id [Symbol] widget id
      # @param services_names [Array<String>] name of services to show
      def initialize(id: DEFAULT_ID, services_names: [])
        textdomain 'services-manager'

        @id = id
        @services_names = services_names
      end

      # @return [Yast::Term]
      def widget
        @table ||= Table(id, Opt(:immediate), header, items)
      end

      # Sets focus on the table
      def focus
        UI.SetFocus(id)
      end

      # Refreshes the content of the table
      #
      # The table will refresh its content with the given services names. In case that
      # no services names are given, it will show the same services again.
      #
      # @param services_names [Array<String>, nil]
      def refresh(services_names: nil)
        @services_names = services_names if services_names

        UI.ChangeWidget(id, :Items, items)
        focus
      end

      # Refreshes the row of a specific service
      #
      # @param service_name [String]
      def refresh_row(service_name)
        refresh_start_mode_value(service_name)
        refresh_state_value(service_name)
        focus
      end

      # Name of the service of the currently selected row
      #
      # @return [String]
      def selected_service_name
        UI.QueryWidget(id, :CurrentItem)
      end

      # Service object of the currently selected row
      #
      # @return [Yast2::SystemService, nil] nil if the service is not found
      def selected_service
        ServicesManagerService.find(selected_service_name)
      end

    private

      DEFAULT_ID = :services_table
      private_constant :DEFAULT_ID

      # @return [Array<String>] services shown in the table
      attr_reader :services_names

      # Table widget id
      #
      # @return [Yast::Term]
      def id
        Id(@id)
      end

      # Table header
      #
      # @return [Yast::Term]
      def header
        Header(
          *columns.map { |c| send("#{c}_title") }
        )
      end

      # Content of the table
      #
      # @return [Array<Yast::Term>]
      def items
        services_names.sort_by { |s| s.downcase }.map { |s| Item(*values_for(s)) }
      end

      # Values to show in the table for a specific service
      #
      # @param service_name [String]
      # @return [Array<Yast::Term, String>]
      def values_for(service_name)
        [row_id(service_name)] + columns.map { |c| send("#{c}_value", service_name) }
      end

      # Columns to show in the table
      #
      # @return [Array<Symbol>]
      def columns
        [:name, :start_mode, :state, :description]
      end

      # Title for name column
      #
      # @return [String]
      def name_title
        _('Service')
      end

      # Title for start_mode column
      #
      # @return [String]
      def start_mode_title
        _('Start')
      end

      # Title for state column
      #
      # @return [String]
      def state_title
        _('State')
      end

      # Title for description column
      #
      # @return [String]
      def description_title
        _('Description')
      end

      # Id for a table row of a service
      #
      # @param service_name [String]
      # @return [Yast::Term]
      def row_id(service_name)
        Id(service_name)
      end

      # Value for the name column of a service
      #
      # @param service_name [String]
      # @return [String]
      def name_value(service_name)
        max_width = max_column_width(:name)
        return service_name if service_name.size < max_width

        service_name[0..(max_width - 3)] + "..."
      end

      # Value for the start_mode column of a service
      #
      # @param service_name [String]
      # @return [String]
      def start_mode_value(service_name)
        ServicesManagerService.start_mode_to_human_for(service_name)
      end

      # Value for the state column of a service
      #
      # @param service_name [String]
      # @return [String]
      def state_value(service_name)
        state = TRANSLATIONS[:service_state][service_state(service_name)]
        substate = TRANSLATIONS[:service_substate][service_substate(service_name)]

        return _(state) unless substate

        format(_("%{state} (%{substate})"), state: _(state), substate: _(substate))
      end

      # Value for the description column of a service
      #
      # @param service_name [String]
      # @return [String]
      def description_value(service_name)
        ServicesManagerService.description(service_name) || ""
      end

      # State of a service
      #
      # @param service_name [String]
      # @return [String]
      def service_state(service_name)
        ServicesManagerService.state(service_name) || ""
      end

      # Substate of a service
      #
      # @param service_name [String]
      # @return [String]
      def service_substate(service_name)
        ServicesManagerService.substate(service_name) || ""
      end

      # Updates the value for the start_mode column of a service
      #
      # @param service_name [String]
      def refresh_start_mode_value(service_name)
        UI.ChangeWidget(id, Cell(service_name, 1), start_mode_value(service_name))
      end

      # Updates the value for the state column of a service
      #
      # @param service_name [String]
      def refresh_state_value(service_name)
        active_changed = ServicesManagerService.find(service_name).changed_value?(:active)
        will_be_active = ServicesManagerService.active?(service_name)

        state = if active_changed
          will_be_active ? _('Active (will start)') : _('Inactive (will stop)')
        else
          state_value(service_name)
        end

        UI.ChangeWidget(id, Cell(service_name, 2), state)
      end

      # Max width of a column
      #
      # In general there is no limitation for any column. Only name column has
      # a limited width.
      #
      # @param column [Symbol]
      # @return [Integer]
      def max_column_width(column)
        return nil if column != :name

        # use 60 for other elements in table we want to display, see bsc#993826
        display_width - 60
      end

      # @return [Integer]
      def display_width
        UI.GetDisplayInfo["Width"] || 80
      end
    end
  end
end