require "fluent/input"
require "googleauth"
require "google/apis/analyticsreporting_v4"

class Fluent::GoogleAnalyticsInput < Fluent::Input
  Fluent::Plugin.register_input("googleanalytics", self)
  Analyticsreporting = Google::Apis::AnalyticsreportingV4

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
  config_param :id, :validate => :string, :required => true
  # In the format YYYY-MM-DD, or relative by using today, yesterday, or the NdaysAgo pattern
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#startDate
  config_param :start_date, :validate => :string, :default => 'today'
  # In the format YYYY-MM-DD, or relative by using today, yesterday, or the NdaysAgo pattern
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#endDate
  config_param :end_date, :validate => :string, :default => 'today'
  # The aggregated statistics for user activity to your site, such as clicks or pageviews.
  # Maximum of 10 metrics for any query
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#metrics
  # For a full list of metrics, see the documentation
  # https://developers.google.com/analytics/devguides/reporting/core/dimsmets
  config_param :metrics, :validate => :string, :required => true
  # Breaks down metrics by common criteria; for example, by ga:browser or ga:city
  # Maximum of 7 dimensions in any query
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#dimensions
  # For a full list of dimensions, see the documentation
  # https://developers.google.com/analytics/devguides/reporting/core/dimsmets
  config_param :dimensions, :validate => :string, :default => nil
  # Used to restrict the data returned from your request
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#filters
  config_param :filters, :validate => :string, :default => nil
  # A list of metrics and dimensions indicating the sorting order and sorting direction for the returned data
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#sort
  config_param :sort, :validate => :string, :default => nil
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#segment
  config_param :segment, :validate => :string, :default => nil
  # Valid values are DEFAULT, FASTER, HIGHER_PRECISION
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#samplingLevel
  config_param :sampling_level, :validate => :string, :default => nil
  # This is the result to start with, beginning at 1
  # You probably don't need to change this but it has been included here for completeness
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#startIndex
  config_param :start_index, :validate => :number, :default => 1
  # This is the number of results in a page. This plugin will start at
  # @start_index and keep pulling pages of data until it has all results.
  # You probably don't need to change this but it has been included here for completeness
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#maxResults
  config_param :max_results, :validate => :number, :default => 10000
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#include-empty-rows
  config_param :include_empty_rows, :validate => :boolean, :default => true

  # The service name to connect to. Should not change unless Google changes something
  config_param :service_name, :validate => :string, :default => 'analytics'
  # The version of the API to use.
  config_param :api_version, :validate => :string, :default => 'v3'

  # This will store the query in the resulting logstash event
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#data_response
  config_param :store_query, :validate => :boolean, :default => true
  # This will store the profile information in the resulting logstash event
  # https://developers.google.com/analytics/devguides/reporting/core/v3/reference#data_response
  config_param :store_profile, :validate => :boolean, :default => true

  # Set how frequently messages should be sent.
  #
  # The default, `1`, means send a message every second.
  config_param :interval, :validate => :number, :default => 60

  def initialize
    super
  end

  def configure(conf)
    super

    @dims = conf['dimensions']
    log.debug "googleanalytics: dimension is #{@dims.split(",")[0]}"

    log.debug "googleanalytics: initiate analytics objects"
    @analytics = Analyticsreporting::AnalyticsReportingService.new
    @analytics.authorization = Google::Auth.get_application_default(Analyticsreporting::AUTH_ANALYTICS)
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
        now = Time.now
        number = @updated < now - @interval * 2
        log.debug "googleanalytics: last updated at #{@updated} with number #{number}"
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
    begin
      log.debug "googleanalytics: try to get the data"
      request = Google::Apis::AnalyticsreportingV4::GetReportsRequest.new
      request.report_requests = build_report_request(@id, @start_date, @end_date, metrics.split(","), @dims.split(","))

      result = @analytics.batch_get_reports(request)

      report = result.to_h[:reports].first
      log.debug "googleanalytics: total: #{report[:data][:row_count]} rows."

      if !report[:data].has_key?(:rows)
        raise "googleanalytics: result doesn't contain rows."
      end

      if report[:data][:rows].empty?
        raise "googleanalytics: result has 0 rows."
      end

      dimensions = report[:column_header][:dimensions]
      metrics = report[:column_header][:metric_header][:metric_header_entries].map{|m| m[:name]}
      report[:data][:rows].each do |row|
        dim = dimensions.zip(row[:dimensions]).to_h
        met = metrics.zip(row[:metrics].first[:values]).to_h
        ga_record = dim.merge(met)

        now = DateTime.now
        if @dims.split(",")[0] == 'ga:hour'
          timestring = DateTime.new(now.year, now.month, now.day, dim['ga:hour'].to_i, 00, 00, now.offset)
        else @dims.split(",")[0] == 'ga:day'
          timestring = DateTime.new(now.year, now.month, dim['ga:day'].to_i, 00, 00, 00, now.offset)
        end
        ga_time = timestring.to_time.to_i
        ga_record['@timestamp'] = timestring.strftime("%FT%T%:z")

        log.debug "googleanalytics: #{ga_record}"
        router.emit("googleanalytics", ga_time, ga_record)
      end

    rescue => err
      log.fatal("googleanalytics: caught exception; exiting")
      log.fatal(err)
    end
  end

  def build_report_request(view_id, start_date, end_date, metrics, dimensions, page_token = nil)
    query = {
      view_id: view_id,
      dimensions: dimensions.map{|d| {name: d}},
      metrics: metrics.map{|m| {expression: m}},
      include_empty_rows: true,
      #page_size: preview? ? 10 : 10000,
    }

    if start_date || end_date
      query[:date_ranges] = [{
        start_date: start_date,
        end_date: end_date,
      }]
    end

    if page_token
      query[:page_token] = page_token
    end

    log.debug "googleanalytics: query is #{query}"

    [query]
  end
end
