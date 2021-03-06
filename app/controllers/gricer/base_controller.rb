module Gricer
  # This is the base controller which is used by Gricer's basic statistics controllers
  #
  # You can use this to make your own statistics controllers from a scaffold.
  class BaseController < ::ApplicationController
    before_filter :guess_from_thru
    helper BaseHelper

    layout ::Gricer.config.admin_layout unless ::Gricer.config.admin_layout.nil?

    # This action generates a JSON for a process statistics.
    def process_stats
      @items = basic_collection

      handle_special_fields

      data = {
        alternatives: [
          {
            type: 'spread',
            uri: url_for(action: "spread_stats", field: params[:field], filters: params[:filters], only_path: true)
          },
          {
            type: 'process'
          }
        ],
        from: @stat_from.to_time.utc.to_i * 1000,
        thru: @stat_thru.to_time.utc.to_i * 1000,
        step: @stat_step.to_i * 1000,
        data: @items.stat(params[:field], @stat_from, @stat_thru, @stat_step)
      }

      if further_details.keys.include? params[:field]
        filters = (params[:filters] || {})
        filters[params[:field]] = '%{self}'

        data[:detail_uri] = url_for(action: "process_stats", field: further_details[params[:field]], filters: filters, only_path: true)
      end

      render json: data
    end

    # This action generates a JSON for a spread statistics.
    def spread_stats
      @items = basic_collection.between_dates(@stat_from, @stat_thru)

      handle_special_fields

      data = {
        alternatives: [
          {
            type: 'spread'
          },
          {
            type: 'process',
            uri: url_for(action: "process_stats", field: params[:field], filters: params[:filters], only_path: true)
          }
        ],
        from: @stat_from.to_time.utc.to_i * 1000,
        thru: @stat_thru.to_time.utc.to_i * 1000,
        total: @items.count(),
        data: @items.count_by(params[:field])
      }

      if further_details.keys.include? params[:field]
        filters = (params[:filters] || {})
        filters[params[:field]] = '%{self}'

        data[:detail_uri] = url_for(action: "spread_stats", field: further_details[params[:field]], filters: filters, only_path: true)
      end

      render json: data
    end

    private
    # @abstract
    # Define which is the basic collection to be processed by the controller.
    # This value has to be overwritten to use the process_stats or spread_stats actions.
    def basic_collection
      raise 'basic_collection must be defined'
    end

    # Define how to handle special fields
    def handle_special_fields
      if params[:filters]
        params[:filters].each do |filter_attr, filter_value|
          @items = @items.filter_by(filter_attr, filter_value)
        end
      end
    end

    # Define how to handle further details
    def further_details
      {}
    end

    # Guess for which time range to display statistics
    def guess_from_thru
      begin
        @stat_thru = Time.parse(params[:thru]).to_date
      rescue
      end

      begin
        @stat_from = Time.parse(params[:from]).to_date
      rescue
      end

      if @stat_from.nil?
        if @stat_thru.nil?
          @stat_thru = Time.now.localtime.to_date - 1.day
        end
        @stat_from = @stat_thru - 1.week + 1.day
      else
        if @stat_thru.nil?
          @stat_thru = @stat_from + 1.week - 1.day
        end
      end

      @stat_step = 1.day

      duration = @stat_thru - @stat_from

      if duration < 90
        @stat_step = 12.hours
      end

      if duration < 30
        @stat_step = 6.hour
      end

      if duration < 10
        @stat_step = 1.hour
      end

      #if @stat_thru - @stat_from > 12.month
      #  @stat_step = 4.week
      #end
    end
  end
end