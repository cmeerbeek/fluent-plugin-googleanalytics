# fluent-plugin-googleanalytics, a plugin for [Fluentd](http://fluentd.org)

## Overview

***Google Analytics*** input plugin.

This plugin is simple.
Get metrics from Google Analytics to fluentd.

* Get metrics from Google API.
  * Interval is 300(default. config=interval) seconds
  * Fetch datapoints in recent (interval * 10) seconds, and emit the latest datapoint to Fluentd data stream.

## Configuration

```config
<source>
  type cloudwatch
  tag cloudwatch
  aws_key_id  YOUR_AWS_KEY_ID
  aws_sec_key YOUR_AWS_SECRET_KEY
  cw_endpoint ENDPOINT

  namespace        [namespace]
  statistics       [statistics] (default: Average)
  metric_name      [metric name]
  dimensions_name  [dimensions_name]
  dimensions_value [dimensions value]
  period           [period] (default: 300)
  interval         [interval] (default: 300)
  delayed_start    [bool] (default: false)
  emit_zero        [bool] (default: false)
</source>
```

### GET RDS Metric

```config
<source>
  type cloudwatch
  tag  cloudwatch
  aws_key_id  YOUR_AWS_KEY_ID
  aws_sec_key YOUR_AWS_SECRET_KEY
  cw_endpoint monitoring.ap-northeast-1.amazonaws.com

  namespace AWS/RDS
  metric_name CPUUtilization,FreeStorageSpace,DiskQueueDepth,FreeableMemory,SwapUsage,ReadIOPS,ReadLatency,ReadThroughput,WriteIOPS,WriteLatency,WriteThroughput
  dimensions_name DBInstanceIdentifier
  dimensions_value rds01
</source>

<match cloudwatch>
  type copy
 <store>
  type file
  path /var/log/td-agent/test
 </store>
</match>

```

#### output data format

```
2013-02-24T13:40:00+09:00       cloudwatch      {"CPUUtilization":2.0}
2013-02-24T13:40:00+09:00       cloudwatch      {"FreeStorageSpace":104080723968.0}
2013-02-24T13:39:00+09:00       cloudwatch      {"DiskQueueDepth":0.002000233360558732}
2013-02-24T13:40:00+09:00       cloudwatch      {"FreeableMemory":6047948800.0}
2013-02-24T13:40:00+09:00       cloudwatch      {"SwapUsage":0.0}
2013-02-24T13:40:00+09:00       cloudwatch      {"ReadIOPS":0.4832769510223807}
2013-02-24T13:40:00+09:00       cloudwatch      {"ReadLatency":0.0}
2013-02-24T13:39:00+09:00       cloudwatch      {"ReadThroughput":0.0}
2013-02-24T13:40:00+09:00       cloudwatch      {"WriteIOPS":5.116069791857616}
2013-02-24T13:40:00+09:00       cloudwatch      {"WriteLatency":0.004106280193236715}
2013-02-24T13:39:00+09:00       cloudwatch      {"WriteThroughput":54074.40992132284}
```

## config: Complex metric_name

`metric_name` format is allowed as below.
- `MetricName`
- `MetricName:Statstics`

For example, this configuration fetches "Sum of RequestCount" and "Average of Latancy".

```
  metric_name RequestCount,Latency:Average
  statistics Sum
```

## config: delayed_start

When config `delayed_start` is set true, plugin startup will be delayed in random seconds(0 ~ interval).

## config: offset

unit: seconds.

flunet-plugin-cloudwatch gets metrics between now and `period` &times; 10 sec ago, and pick a latest value from that.

But the latest metric is insufficient for `statistics Sum`.

If `offset` is specified, fluent-plugin-cloudwatch gets metrics between `offset` sec ago and older.

## config: emit_zero

If `emit_zero` is true and cloudwatch datapoint is empty, fluent-plugin-cloudwatch emits 0 instead of warn log "datapoint is empty".

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
