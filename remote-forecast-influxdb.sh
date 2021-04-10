#!/bin/bash

# Debug

debug=$WEATHERFLOW_COLLECTOR_DEBUG

# InfluxDB Endpoint

collector_type=$WEATHERFLOW_COLLECTOR_COLLECTOR_TYPE
influxdb_password=$WEATHERFLOW_COLLECTOR_INFLUXDB_PASSWORD
influxdb_url=$WEATHERFLOW_COLLECTOR_INFLUXDB_URL
influxdb_username=$WEATHERFLOW_COLLECTOR_INFLUXDB_USERNAME
remote_collector_station_id=$WEATHERFLOW_COLLECTOR_REMOTE_COLLECTOR_STATION_ID
remote_collector_token=$WEATHERFLOW_COLLECTOR_REMOTE_COLLECTOR_TOKEN
station_id=$WEATHERFLOW_COLLECTOR_REMOTE_COLLECTOR_STATION_ID

if [ "$debug" == "true" ]
then

#
# Print Environmental Variables
#

echo "$WEATHERFLOW_COLLECTOR_COLLECTOR_TYPE"
echo "$WEATHERFLOW_COLLECTOR_BACKEND_TYPE"
echo "$WEATHERFLOW_COLLECTOR_DEBUG"
echo "$WEATHERFLOW_COLLECTOR_INFLUXDB_PASSWORD"
echo "$WEATHERFLOW_COLLECTOR_INFLUXDB_URL"
echo "$WEATHERFLOW_COLLECTOR_INFLUXDB_USERNAME"
echo "$WEATHERFLOW_COLLECTOR_REMOTE_COLLECTOR_DEVICE_ID"
echo "$WEATHERFLOW_COLLECTOR_REMOTE_COLLECTOR_STATION_ID"
echo "$WEATHERFLOW_COLLECTOR_REMOTE_COLLECTOR_TOKEN"

else

#
# Print Environmental Variables
#

echo "$WEATHERFLOW_COLLECTOR_COLLECTOR_TYPE"
echo "$WEATHERFLOW_COLLECTOR_BACKEND_TYPE"
echo "$WEATHERFLOW_COLLECTOR_REMOTE_COLLECTOR_DEVICE_ID"
echo "$WEATHERFLOW_COLLECTOR_REMOTE_COLLECTOR_STATION_ID"

fi

# Curl Command

if [ "$debug" == "true" ]
then

curl=(  )

else

curl=( --silent --output /dev/null --show-error --fail )

fi

#
# Start Reading in STDIN
#

## Fetch some meta information about our Tempest

if [ "$debug" == "true" ]
then

station_details=$(curl -w "\n" -X GET --header "Accept: application/json" "https://swd.weatherflow.com/swd/rest/observations/station/${remote_collector_station_id}?token=${remote_collector_token}")

else

station_details=$(curl --silent --show-error --fail -w "\n" -X GET --header "Accept: application/json" "https://swd.weatherflow.com/swd/rest/observations/station/${remote_collector_station_id}?token=${remote_collector_token}")

fi

elevation=$(echo "${station_details}" | jq -r .elevation)
latitude=$(echo "${station_details}" | jq -r .latitude)
longitude=$(echo "${station_details}" | jq -r .longitude)
public_name=$(echo "${station_details}" | jq -r .public_name)
station_id=$(echo "${station_details}" | jq -r .station_id)
station_name=$(echo "${station_details}" | jq -r .station_name)
timezone=$(echo "${station_details}" | jq -r .timezone)

## Escape Spaces

## Spaces

public_name=$(echo "${public_name}" | sed 's/ /\\ /g')
station_name=$(echo "${station_name}" | sed 's/ /\\ /g')

## Commas

public_name=$(echo "${public_name}" | sed 's/,/\\,/g')
station_name=$(echo "${station_name}" | sed 's/,/\\,/g')

## Equal Signs

public_name=$(echo "${public_name}" | sed 's/=/\\=/g')
station_name=$(echo "${station_name}" | sed 's/=/\\=/g')

if [ "$debug" == "true" ]
then

echo "elevation=${elevation}"
echo "latitude=${latitude}"
echo "longitude=${longitude}"
echo "public_name=${public_name}"
echo "station_id=${station_id}"
echo "station_name=${station_name}"
echo "timezone=${timezone}"

fi


while read -r line; do

if [ "$debug" == "true" ]
then

echo ""
echo "${line}"
echo ""

fi

## Current Conditions

conditions=$(echo "${line}" |jq -r ".current_conditions.conditions")
icon=$(echo "${line}" |jq -r ".current_conditions.icon")

if [ "$debug" == "true" ]
then

#
# Print Metrics
#

echo "conditions ${conditions}"
echo "icon ${icon}"

fi

## Send Data To InfluxDB

curl "${curl[@]}" -i -XPOST "${influxdb_url}" -u "${influxdb_username}":"${influxdb_password}" --data-binary "
weatherflow_forecast_current,collector_type=${collector_type},elevation=${elevation},latitude=${latitude},longitude=${longitude},public_name=${public_name},station_id=${station_id},station_name=${station_name},timezone=${timezone} conditions=\"${conditions}\"
weatherflow_forecast_current,collector_type=${collector_type},elevation=${elevation},latitude=${latitude},longitude=${longitude},public_name=${public_name},station_id=${station_id},station_name=${station_name},timezone=${timezone} icon=\"${icon}\""

## Daily Forecast

## Start Timer

daily_start=$(date +%s%N)

#
# Start "threading"
#

N=4

for day in {0..9}; do

(

air_temp_high=$(echo "${line}" |jq -r ".forecast.daily | .[$day].air_temp_high")
air_temp_low=$(echo "${line}" |jq -r ".forecast.daily | .[$day].air_temp_low")
conditions=$(echo "${line}" |jq -r ".forecast.daily | .[$day].conditions")
day_num=$(echo "${line}" |jq -r ".forecast.daily | .[$day].day_num")
day_start_local=$(echo "${line}" |jq -r ".forecast.daily | .[$day].day_start_local")
icon=$(echo "${line}" |jq -r ".forecast.daily | .[$day].icon")
month_num=$(echo "${line}" |jq -r ".forecast.daily | .[$day].month_num")
precip_probability=$(echo "${line}" |jq -r ".forecast.daily | .[$day].precip_probability")
sunrise=$(echo "${line}" |jq -r ".forecast.daily | .[$day].sunrise")
sunset=$(echo "${line}" |jq -r ".forecast.daily | .[$day].sunset")

## Add 86399 seconds to provide end of day data points if viewing graphs after midnight

day_start_local=$((day_start_local + 86399))

if [ "$debug" == "true" ]
then

#
# Print Metrics
#

echo ""
echo "${day}"
echo ""

echo "forecast_daily_air_temp_high ${air_temp_high}"
echo "forecast_daily_air_temp_low ${air_temp_low}"
echo "forecast_daily_conditions ${conditions}"
echo "forecast_daily_day_num ${day_num}"
echo "forecast_daily_day_start_local ${day_start_local}"
echo "forecast_daily_icon ${icon}"
echo "forecast_daily_month_num ${month_num}"
echo "forecast_daily_precip_probability ${precip_probability}"
echo "forecast_daily_sunrise ${sunrise}"
echo "forecast_daily_sunset ${sunset}"

fi

## Send Data To InfluxDB

curl "${curl[@]}" -i -XPOST "${influxdb_url}" -u "${influxdb_username}":"${influxdb_password}" --data-binary "
weatherflow_forecast_daily,collector_type=${collector_type},elevation=${elevation},latitude=${latitude},longitude=${longitude},public_name=${public_name},station_id=${station_id},station_name=${station_name},timezone=${timezone},forecast_day_num=${day_num},forecast_month_num=${month_num} air_temp_high=${air_temp_high} ${day_start_local}000000000
weatherflow_forecast_daily,collector_type=${collector_type},elevation=${elevation},latitude=${latitude},longitude=${longitude},public_name=${public_name},station_id=${station_id},station_name=${station_name},timezone=${timezone},forecast_day_num=${day_num},forecast_month_num=${month_num} air_temp_low=${air_temp_low} ${day_start_local}000000000
weatherflow_forecast_daily,collector_type=${collector_type},elevation=${elevation},latitude=${latitude},longitude=${longitude},public_name=${public_name},station_id=${station_id},station_name=${station_name},timezone=${timezone},forecast_day_num=${day_num},forecast_month_num=${month_num} conditions=\"${conditions}\" ${day_start_local}000000000
weatherflow_forecast_daily,collector_type=${collector_type},elevation=${elevation},latitude=${latitude},longitude=${longitude},public_name=${public_name},station_id=${station_id},station_name=${station_name},timezone=${timezone},forecast_day_num=${day_num},forecast_month_num=${month_num} day_num=${day_num} ${day_start_local}000000000
weatherflow_forecast_daily,collector_type=${collector_type},elevation=${elevation},latitude=${latitude},longitude=${longitude},public_name=${public_name},station_id=${station_id},station_name=${station_name},timezone=${timezone},forecast_day_num=${day_num},forecast_month_num=${month_num} icon=\"${icon}\" ${day_start_local}000000000
weatherflow_forecast_daily,collector_type=${collector_type},elevation=${elevation},latitude=${latitude},longitude=${longitude},public_name=${public_name},station_id=${station_id},station_name=${station_name},timezone=${timezone},forecast_day_num=${day_num},forecast_month_num=${month_num} month_num=${month_num} ${day_start_local}000000000
weatherflow_forecast_daily,collector_type=${collector_type},elevation=${elevation},latitude=${latitude},longitude=${longitude},public_name=${public_name},station_id=${station_id},station_name=${station_name},timezone=${timezone},forecast_day_num=${day_num},forecast_month_num=${month_num} precip_probability=${precip_probability} ${day_start_local}000000000
weatherflow_forecast_daily,collector_type=${collector_type},elevation=${elevation},latitude=${latitude},longitude=${longitude},public_name=${public_name},station_id=${station_id},station_name=${station_name},timezone=${timezone},forecast_day_num=${day_num},forecast_month_num=${month_num} sunrise=${sunrise}000 ${day_start_local}000000000
weatherflow_forecast_daily,collector_type=${collector_type},elevation=${elevation},latitude=${latitude},longitude=${longitude},public_name=${public_name},station_id=${station_id},station_name=${station_name},timezone=${timezone},forecast_day_num=${day_num},forecast_month_num=${month_num} sunset=${sunset}000 ${day_start_local}000000000"

) &

    # allow to execute up to $N jobs in parallel
    if [[ $(jobs -r -p | wc -l) -ge $N ]]; then
        # now there are $N jobs already running, so wait here for any job
        # to be finished so there is a place to start next one.
        wait -n
    fi

done

wait

#
# End "threading"
#

## End Timer

daily_end=$(date +%s%N)
daily_duration=$((daily_end-daily_start))

echo "daily_duration:${daily_duration}"

## Send Timer Metrics To InfluxDB

curl "${curl[@]}" -i -XPOST "${influxdb_url}" -u "${influxdb_username}":"${influxdb_password}" --data-binary "
weatherflow_forecast_daily,collector_type=${collector_type},elevation=${elevation},latitude=${latitude},longitude=${longitude},public_name=${public_name},station_id=${station_id},station_name=${station_name},timezone=${timezone} duration=${daily_duration}"

## Hourly Forecast

## Start Timer

hourly_start=$(date +%s%N)

#
# Start "threading"
#

N=4


for hour in {0..240}; do

(

air_temperature=$(echo "${line}" |jq -r ".forecast.hourly | .[$hour].air_temperature")
conditions=$(echo "${line}" |jq -r ".forecast.hourly | .[$hour].conditions")
feels_like=$(echo "${line}" |jq -r ".forecast.hourly | .[$hour].feels_like")
icon=$(echo "${line}" |jq -r ".forecast.hourly | .[$hour].icon")
local_day=$(echo "${line}" |jq -r ".forecast.hourly | .[$hour].local_day")
local_hour=$(echo "${line}" |jq -r ".forecast.hourly | .[$hour].local_hour")
precip=$(echo "${line}" |jq -r ".forecast.hourly | .[$hour].precip")
precip_icon=$(echo "${line}" |jq -r ".forecast.hourly | .[$hour].precip_icon")
precip_probability=$(echo "${line}" |jq -r ".forecast.hourly | .[$hour].precip_probability")
precip_type=$(echo "${line}" |jq -r ".forecast.hourly | .[$hour].precip_type")
relative_humidity=$(echo "${line}" |jq -r ".forecast.hourly | .[$hour].relative_humidity")
sea_level_pressure=$(echo "${line}" |jq -r ".forecast.hourly | .[$hour].sea_level_pressure")
time=$(echo "${line}" |jq -r ".forecast.hourly | .[$hour].time")
uv=$(echo "${line}" |jq -r ".forecast.hourly | .[$hour].uv")
wind_avg=$(echo "${line}" |jq -r ".forecast.hourly | .[$hour].wind_avg")
wind_direction=$(echo "${line}" |jq -r ".forecast.hourly | .[$hour].wind_direction")
wind_direction_cardinal=$(echo "${line}" |jq -r ".forecast.hourly | .[$hour].wind_direction_cardinal")
wind_gust=$(echo "${line}" |jq -r ".forecast.hourly | .[$hour].wind_gust")

if [ "$debug" == "true" ]
then

#
# Print Metrics
#

echo ""
echo "${hour}"
echo ""

echo "forecast_hourly_air_temperature ${air_temperature}"
echo "forecast_hourly_conditions ${conditions}"
echo "forecast_hourly_feels_like ${feels_like}"
echo "forecast_hourly_icon ${icon}"
echo "forecast_hourly_local_day ${local_day}"
echo "forecast_hourly_local_hour ${local_hour}"
echo "forecast_hourly_precip ${precip}"
echo "forecast_hourly_precip_icon ${precip_icon}"
echo "forecast_hourly_precip_probability ${precip_probability}"
echo "forecast_hourly_precip_type ${precip_type}"
echo "forecast_hourly_relative_humidity ${relative_humidity}"
echo "forecast_hourly_sea_level_pressure ${sea_level_pressure}"
echo "forecast_hourly_time ${time}"
echo "forecast_hourly_uv ${uv}"
echo "forecast_hourly_wind_avg ${wind_avg}"
echo "forecast_hourly_wind_direction ${wind_direction}"
echo "forecast_hourly_wind_direction_cardinal ${wind_direction_cardinal}"
echo "forecast_hourly_wind_gust ${wind_gust}"

fi

## Send Data To InfluxDB

curl "${curl[@]}" -i -XPOST "${influxdb_url}" -u "${influxdb_username}":"${influxdb_password}" --data-binary "
weatherflow_forecast_hourly,collector_type=${collector_type},elevation=${elevation},latitude=${latitude},longitude=${longitude},public_name=${public_name},station_id=${station_id},station_name=${station_name},timezone=${timezone},forecast_day_num=${local_day},forecast_hour_num=${local_hour} air_temperature=${air_temperature} ${time}000000000
weatherflow_forecast_hourly,collector_type=${collector_type},elevation=${elevation},latitude=${latitude},longitude=${longitude},public_name=${public_name},station_id=${station_id},station_name=${station_name},timezone=${timezone},forecast_day_num=${local_day},forecast_hour_num=${local_hour} conditions=\"${conditions}\" ${time}000000000
weatherflow_forecast_hourly,collector_type=${collector_type},elevation=${elevation},latitude=${latitude},longitude=${longitude},public_name=${public_name},station_id=${station_id},station_name=${station_name},timezone=${timezone},forecast_day_num=${local_day},forecast_hour_num=${local_hour} feels_like=${feels_like} ${time}000000000
weatherflow_forecast_hourly,collector_type=${collector_type},elevation=${elevation},latitude=${latitude},longitude=${longitude},public_name=${public_name},station_id=${station_id},station_name=${station_name},timezone=${timezone},forecast_day_num=${local_day},forecast_hour_num=${local_hour} icon=\"${icon}\" ${time}000000000
weatherflow_forecast_hourly,collector_type=${collector_type},elevation=${elevation},latitude=${latitude},longitude=${longitude},public_name=${public_name},station_id=${station_id},station_name=${station_name},timezone=${timezone},forecast_day_num=${local_day},forecast_hour_num=${local_hour} local_day=${local_day} ${time}000000000
weatherflow_forecast_hourly,collector_type=${collector_type},elevation=${elevation},latitude=${latitude},longitude=${longitude},public_name=${public_name},station_id=${station_id},station_name=${station_name},timezone=${timezone},forecast_day_num=${local_day},forecast_hour_num=${local_hour} local_hour=${local_hour} ${time}000000000
weatherflow_forecast_hourly,collector_type=${collector_type},elevation=${elevation},latitude=${latitude},longitude=${longitude},public_name=${public_name},station_id=${station_id},station_name=${station_name},timezone=${timezone},forecast_day_num=${local_day},forecast_hour_num=${local_hour} precip=${precip} ${time}000000000
weatherflow_forecast_hourly,collector_type=${collector_type},elevation=${elevation},latitude=${latitude},longitude=${longitude},public_name=${public_name},station_id=${station_id},station_name=${station_name},timezone=${timezone},forecast_day_num=${local_day},forecast_hour_num=${local_hour} precip_probability=${precip_probability} ${time}000000000
weatherflow_forecast_hourly,collector_type=${collector_type},elevation=${elevation},latitude=${latitude},longitude=${longitude},public_name=${public_name},station_id=${station_id},station_name=${station_name},timezone=${timezone},forecast_day_num=${local_day},forecast_hour_num=${local_hour} relative_humidity=${relative_humidity} ${time}000000000
weatherflow_forecast_hourly,collector_type=${collector_type},elevation=${elevation},latitude=${latitude},longitude=${longitude},public_name=${public_name},station_id=${station_id},station_name=${station_name},timezone=${timezone},forecast_day_num=${local_day},forecast_hour_num=${local_hour} sea_level_pressure=${sea_level_pressure} ${time}000000000
weatherflow_forecast_hourly,collector_type=${collector_type},elevation=${elevation},latitude=${latitude},longitude=${longitude},public_name=${public_name},station_id=${station_id},station_name=${station_name},timezone=${timezone},forecast_day_num=${local_day},forecast_hour_num=${local_hour} uv=${uv} ${time}000000000
weatherflow_forecast_hourly,collector_type=${collector_type},elevation=${elevation},latitude=${latitude},longitude=${longitude},public_name=${public_name},station_id=${station_id},station_name=${station_name},timezone=${timezone},forecast_day_num=${local_day},forecast_hour_num=${local_hour} wind_avg=${wind_avg} ${time}000000000
weatherflow_forecast_hourly,collector_type=${collector_type},elevation=${elevation},latitude=${latitude},longitude=${longitude},public_name=${public_name},station_id=${station_id},station_name=${station_name},timezone=${timezone},forecast_day_num=${local_day},forecast_hour_num=${local_hour} wind_direction=${wind_direction} ${time}000000000
weatherflow_forecast_hourly,collector_type=${collector_type},elevation=${elevation},latitude=${latitude},longitude=${longitude},public_name=${public_name},station_id=${station_id},station_name=${station_name},timezone=${timezone},forecast_day_num=${local_day},forecast_hour_num=${local_hour} wind_direction_cardinal=\"${wind_direction_cardinal}\" ${time}000000000
weatherflow_forecast_hourly,collector_type=${collector_type},elevation=${elevation},latitude=${latitude},longitude=${longitude},public_name=${public_name},station_id=${station_id},station_name=${station_name},timezone=${timezone},forecast_day_num=${local_day},forecast_hour_num=${local_hour} wind_gust=${wind_gust} ${time}000000000"

) &

    # allow to execute up to $N jobs in parallel
    if [[ $(jobs -r -p | wc -l) -ge $N ]]; then
        # now there are $N jobs already running, so wait here for any job
        # to be finished so there is a place to start next one.
        wait -n
    fi

done

wait

#
# End "threading"
#

## End Timer

hourly_end=$(date +%s%N)
hourly_duration=$((hourly_end-hourly_start))

echo "hourly_duration:${hourly_duration}"

## Send Timer Metrics To InfluxDB

curl "${curl[@]}" -i -XPOST "${influxdb_url}" -u "${influxdb_username}":"${influxdb_password}" --data-binary "
weatherflow_forecast_hourly,collector_type=${collector_type},elevation=${elevation},latitude=${latitude},longitude=${longitude},public_name=${public_name},station_id=${station_id},station_name=${station_name},timezone=${timezone} duration=${hourly_duration}"

done < /dev/stdin
