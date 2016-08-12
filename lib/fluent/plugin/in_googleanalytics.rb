require 'fluent/input'

class Fluent::GoogleAnalyticsInput < Fluent::Input
  Fluent::Plugin.register_input("googleanalytics", self)

  # To support log_level option implemented by Fluentd v0.10.43
  unless method_defined?(:log)
    define_method("log") { $log }
  end

  # Define `router` method of v0.12 to support v0.10 or earlier
  unless method_defined?(:router)
    define_method("router") { Fluent::Engine }
  end

  # A profile id, in the format 'ga:XXXX'
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#ids
  config :id, :validate => :string, :required => true
  # In the format YYYY-MM-DD, or relative by using today, yesterday, or the NdaysAgo pattern
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#startDate
  config :start_date, :validate => :string, :default => 'yesterday'
  # In the format YYYY-MM-DD, or relative by using today, yesterday, or the NdaysAgo pattern
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#endDate
  config :end_date, :validate => :string, :default => 'yesterday'
  # The aggregated statistics for user activity to your site, such as clicks or pageviews.
  # Maximum of 10 metrics for any query
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#metrics
  # For a full list of metrics, see the documentation
  # https://developers.google.com/analytics/devguides/reporting/core/dimsmets
  config :metrics, :validate => :string, :required => true
  # Breaks down metrics by common criteria; for example, by ga:browser or ga:city
  # Maximum of 7 dimensions in any query
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#dimensions
  # For a full list of dimensions, see the documentation
  # https://developers.google.com/analytics/devguides/reporting/core/dimsmets
  config :dimensions, :validate => :string, :default => nil
  # Used to restrict the data returned from your request
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#filters
  config :filters, :validate => :string, :default => nil
  # A list of metrics and dimensions indicating the sorting order and sorting direction for the returned data
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#sort
  config :sort, :validate => :string, :default => nil
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#segment
  config :segment, :validate => :string, :default => nil
  # Valid values are DEFAULT, FASTER, HIGHER_PRECISION
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#samplingLevel
  config :sampling_level, :validate => :string, :default => nil
  # This is the result to start with, beginning at 1
  # You probably don't need to change this but it has been included here for completeness
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#startIndex
  config :start_index, :validate => :number, :default => 1
  # This is the number of results in a page. This plugin will start at
  # @start_index and keep pulling pages of data until it has all results.
  # You probably don't need to change this but it has been included here for completeness
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#maxResults
  config :max_results, :validate => :number, :default => 10000
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#include-empty-rows
  config :include_empty_rows, :validate => :boolean, :default => true

  # The service name to connect to. Should not change unless Google changes something
  config :service_name, :validate => :string, :default => 'analytics'
  # The version of the API to use.
  config :api_version, :validate => :string, :default => 'v3'

  # This will store the query in the resulting logstash event
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#data_response
  config :store_query, :validate => :boolean, :default => true
  # This will store the profile information in the resulting logstash event
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#data_response
  config :store_profile, :validate => :boolean, :default => true

  # Set how frequently messages should be sent.
  #
  # The default, `1`, means send a message every second.
  config :interval, :validate => :number, :default => 60

  def initialize
    super
    require "googleauth"
    require "google/apis/analytics_v3"
  end

  def configure(conf)
    super

    Analytics = Google::Apis::AnalyticsV3
  end

  def start
    super

    @running = true
    @updated = Time.now
    @watcher = Thread.new(&method(:watch))
    @monitor = Thread.new(&method(:monitor))
    @mutex   = Mutex.new
  end

  def shutdown
    super
    @running = false
    @watcher.terminate
    @monitor.terminate
    @watcher.join
    @monitor.join
  end

  private

  # if watcher thread was not update timestamp in recent @interval * 2 sec., restarting it.
  def monitor
    log.debug "googleanalytics: monitor thread starting"
    while @running
      sleep @interval / 2
      @mutex.synchronize do
        log.debug "googleanalytics: last updated at #{@updated}"
        now = Time.now
        if @updated < now - @interval * 2
          log.warn "googleanalytics: watcher thread is not working after #{@updated}. Restarting..."
          @watcher.kill
          @updated = now
          @watcher = Thread.new(&method(:watch))
        end
      end
    end
  end

  def watch
    if @delayed_start
      delay = rand() * @interval
      log.debug "googleanalytics: delay at start #{delay} sec"
      sleep delay
    end

    @analytics = Analytics::AnalyticsService.new
    @analytics.authorization = Google::Auth.get_application_default(Analytics::AUTH_ANALYTICS)

    output

    started = Time.now
    while @running
      now = Time.now
      sleep 1
      if now - started >= @interval
        output
        started = now
        @mutex.synchronize do
          @updated = Time.now
        end
      end
    end
  end

  def output
    results = @analytics.get_ga_data(@id,
                                   @start_date,
                                   @end_date,
                                   @metrics,
                                   dimensions: @dimensions,
                                   sort: @sort)
    if results.rows.first
      column_headers = results.column_headers.map { |h| h.name }
      results.rows.each do |r|
        ga_record = {}
        column_headers.zip(r).each do |head,data|
          if head == "ga:date"
            ga_time = Time.parse(data)
          else
            ga_record[head] = data
          end
        end
        router.emit("googleanalytics", ga_time, ga_record)
      end
    else
      log.warn("googleanalytics: results empty")
    end

  end
end
