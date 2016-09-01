# fluent-plugin-googleanalytics, a plugin for [Fluentd](http://fluentd.org)

## Overview

***Google Analytics*** input plugin.

Get metrics from Google Analytics to fluentd.

* Get metrics from Google API.
  * Interval is 300(default. config=interval) seconds
  * Fetch datapoints in recent (interval * 10) seconds, and emit the latest datapoint to Fluentd data stream.

## Configuration

```config
<source>
  @type googleanalytics
  id 'ga:GOOGLE_ANALYTICS_PROFILE_ID'
  start_date START_DATETIME
  end_date END_DATETIME
  dimensions 'ga:<metric>,'
  metrics 'ga:<metric>,ga:<metric>,...' #https://developers.google.com/analytics/devguides/reporting/core/v3/reference#metrics
  sort 'ga:<metric>'
</source>
```

## Setup Google Analytics API access

To make sure this plug-in is able to get data from Google Analytics some steps need to be taken.

Use the following steps:
1. Create a service account in the Google API console (https://console.developers.google.com/iam-admin/serviceaccounts/) and copy the Service account ID (an emailaddress)
2. Create a service account key and download the JSON file (Not the P12 version) using the Google API console (https://console.developers.google.com/apis/credentials)
3. Put the JSON file on the system where you run fluentd or td-agent
4. Create an environment variable which points to the JSON file. (export GOOGLE_APPLICATION_CREDENTIALS=<path-to-JSONfile>)
5. Add the Service account ID to the Google Analytics profile with read permissions

## config: id

A profile id, in the format 'ga:XXXX'. Please make sure that the Service account ID created in the setup section has access to this profile.
https://developers.google.com/analytics/devguides/reporting/core/v3/reference#ids

## config: start_date

In the format YYYY-MM-DD, or relative by using today, yesterday, or the daysAgo pattern
https://developers.google.com/analytics/devguides/reporting/core/v3/reference#startDate

## config: end_date

In the format YYYY-MM-DD, or relative by using today, yesterday, or the NdaysAgo pattern
https://developers.google.com/analytics/devguides/reporting/core/v3/reference#endDate

## config: metrics

The aggregated statistics for user activity to your site, such as clicks or pageviews.
Maximum of 10 metrics for any query
https://developers.google.com/analytics/devguides/reporting/core/v3/reference#metrics
For a full list of metrics, see the documentation
https://developers.google.com/analytics/devguides/reporting/core/dimsmets

## config: dimensions

Breaks down metrics by common criteria; for example, by ga:browser or ga:city
Maximum of 7 dimensions in any query
https://developers.google.com/analytics/devguides/reporting/core/v3/reference#dimensions
For a full list of dimensions, see the documentation
https://developers.google.com/analytics/devguides/reporting/core/dimsmets

## config: sort

A list of metrics and dimensions indicating the sorting order and sorting direction for the returned data
https://developers.google.com/analytics/devguides/reporting/core/v3/reference#sort

## config: interval

Set how frequently data should be retrieved. The default, `1`, means send a message every second.

## Other config options

As you can see in the code more options are available but they are not implemented yet. They will be in future versions.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
