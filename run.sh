#!/usr/bin/with-contenv bashio

set +e
while :
do

    ########## Configuration ##########

    # Output debug information
    # Current time and date
    echo "Current time and date: $(date)"

    ##########
    # MQTT
    ##########

    MQTT_BROKER=$(bashio::config "mqtt_broker")
    MQTT_PORT=$(bashio::config "mqtt_port")
    MQTT_USERNAME=$(bashio::config "mqtt_username")
    MQTT_PASSWORD=$(bashio::config "mqtt_password")

    # MQTT
    echo "MQTT Broker: ${MQTT_BROKER}"
    echo "MQTT Port: ${MQTT_PORT}"
    echo "MQTT Username: ${MQTT_USERNAME}"
    echo "MQTT Password: ${MQTT_PASSWORD}"

    # Check if the MQTT Broker is set
    if [ -z "${MQTT_BROKER}" ]; then
        echo "MQTT Broker is not set"
        exit 1
    fi

    ##########
    # MIDCITY Connect
    ##########

    MIDCITY_USERNAME=$(bashio::config 'midcity_username')
    MIDCITY_PASSWORD=$(bashio::config 'midcity_password')

    # MIDCITY Connect
    echo "Midcity Username: ${MIDCITY_USERNAME}"
    echo "Midcity Password: ${MIDCITY_PASSWORD}"

    # Check if the Midcity Username is set
    if [ -z "${MIDCITY_USERNAME}" ]; then
        echo "Midcity Username is not set"
        exit 1
    fi

    ##########
    # Home Assistant
    ##########

    ENABLE_HTTPS=$(bashio::config 'enable_https')

    if [ "${ENABLE_HTTPS}" == "true" ]; then
        HOME_ASSISTANT_PROTOCOL="https"
    else
        HOME_ASSISTANT_PROTOCOL="http"
    fi

    # Home Assistant
    echo "Home Assistant Protocol: ${HOME_ASSISTANT_PROTOCOL}"

    ########## Helper Functions ##########

    function mqtt_pub_sensor {
        local display_name=$1
        local name=$2
        local value=$3
        local unit=$4
        local device_class=$5
        local state_class=$6

        local topic="homeassistant/sensor/${name}"
        local payload=$(cat <<EOF
{
    "name": "${display_name}",
    "unique_id": "midcity_${name}",
    "state_class": "${state_class}",
    "state_topic": "${topic}state",
    "device_class": "${device_class}",
    "unit_of_measurement": "${unit}"
}
EOF
)
        mosquitto_pub -h "${MQTT_BROKER}" -p "${MQTT_PORT}" -u "${MQTT_USERNAME}" -P "${MQTT_PASSWORD}" -t "${topic}/config" -m "${payload}"
        mosquitto_pub -h "${MQTT_BROKER}" -p "${MQTT_PORT}" -u "${MQTT_USERNAME}" -P "${MQTT_PASSWORD}" -t "${topic}state" -m "${value}"
    }

    function mqtt_pub_sensor_text {
        local display_name=$1
        local name=$2
        local value=$3

        local topic="homeassistant/sensor/${name}"
        local payload=$(cat <<EOF
{
    "name": "${display_name}",
    "unique_id": "midcity_${name}",
    "state_topic": "${topic}state",
    "value_template": "{{ value }}"
}
EOF
)
        mosquitto_pub -h "${MQTT_BROKER}" -p "${MQTT_PORT}" -u "${MQTT_USERNAME}" -P "${MQTT_PASSWORD}" -t "${topic}/config" -m "${payload}"
        mosquitto_pub -h "${MQTT_BROKER}" -p "${MQTT_PORT}" -u "${MQTT_USERNAME}" -P "${MQTT_PASSWORD}" -t "${topic}state" -m "${value}"
    }


    ########## Main ##########

    ## Run python script to get data from Midcity Connect
    python3 pull_midcityutilities.py "${MIDCITY_USERNAME}" "${MIDCITY_PASSWORD}" > midcity_connect.json
    if [ $? -ne 0 ]; then
        echo "Failed to run Midcity Connect script"
        exit 1
    fi
    # Check if the file exists
    if [ ! -f midcity_connect.json ]; then
        echo "Midcity Connect script did not create the output file"
        exit 1
    fi
    # Check if the file is empty
    if [ ! -s midcity_connect.json ]; then
        echo "Midcity Connect script output file is empty"
        exit 1
    fi
    # Extract data from the JSON file
    METER_BALANCE=$(jq -r '.meter_balance' midcity_connect.json | grep -o '[0-9\.]\+')
    PREDICTED_ZERO_BALANCE=$(jq -r '.predicted_zero_balance' midcity_connect.json)

    echo "Meter Balance: ${METER_BALANCE}"
    echo "Predicted Zero Balance: ${PREDICTED_ZERO_BALANCE}"

    # Publish data to MQTT
    mqtt_pub_sensor "Meter Balance" "meter_balance" "${METER_BALANCE}" "kWh" "energy" "measurement"
    mqtt_pub_sensor_text "Predicted Zero Balance" "predicted_zero_balance" "${PREDICTED_ZERO_BALANCE}"
    
    # Sleep for refresh rate
    sleep $(bashio::config "refresh_time")

done