require 'helper'

class GoogleAnalyticsInputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  ### for GA
  CONFIG_GA = %[
    tag googleanalytics
    id 51309237
    dimensions %w(ga:date)
    metrics %w(ga:sessions ga:percentNewSessions ga:newUsers ga:bounceRate ga:avgSessionDuration ga:pageviewsPerSession)
    sort %w(ga:date)
  ]

  def create_driver_ga(conf = CONFIG_GA)
    Fluent::Test::InputTestDriver.new(Fluent::GoogleAnalyticsInput).configure(conf)
  end

  def test_configure_ga
    d = create_driver_ga
    assert_equal 'googleanalytics', d.instance.tag
    assert_equal '51309237' , d.instance.id
    assert_equal '%w(ga:date)', d.instance.dimensions
    assert_equal '%w(ga:sessions ga:percentNewSessions ga:newUsers ga:bounceRate ga:avgSessionDuration ga:pageviewsPerSession)', d.instance.metrics
    assert_equal '%w(ga:date)', d.instance.sort
  end

end
