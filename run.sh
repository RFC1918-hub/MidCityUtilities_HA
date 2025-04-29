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
    echo "MQTT Password: ************"

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

    function mqtt_publish() {
        local display_name=$1
        local name=$2
        local value=$3
        local unit=$4
        local device_class=$5
        local state_class=$6

        local topic="homeassistant/sensor/midcity_utilities_${name}"
        local state_topic="${topic}/state"

        local payload=$(cat <<EOF
{
"name": "${display_name}",
"unique_id": "midcity_utilities_${name}",
"state_topic": "${state_topic}",
"unit_of_measurement": "${unit}",
"device_class": "${device_class}",
"state_class": "${state_class}",
"device": {
    "identifiers": ["midcity_utilities"],
    "name": "Sunsynk Inverter",
    "manufacturer": "Sunsynk",
    "model": "Inverter"
}
}
EOF
)

        # Print the payload for debugging
        echo "Publishing MQTT discovery for ${display_name}"
        echo "${payload}"

        # Publish discovery config (retain it)
        mosquitto_pub -h "${MQTT_BROKER}" -p "${MQTT_PORT}" \
            -u "${MQTT_USERNAME}" -P "${MQTT_PASSWORD}" \
            -t "${topic}/config" -m "${payload}" -r

        # Publish the sensor state
        mosquitto_pub -h "${MQTT_BROKER}" -p "${MQTT_PORT}" \
            -u "${MQTT_USERNAME}" -P "${MQTT_PASSWORD}" \
            -t "${state_topic}" -m "${value}"
    }


    function mqtt_publish_text() {
        local display_name=$1
        local name=$2
        local value=$3

        local topic="homeassistant/sensor/${name}"
        local state_topic="${topic}/state"

        local payload=$(cat <<EOF
{
"name": "${display_name}",
"unique_id": "midcity_utilities_${name}",
"state_topic": "${state_topic}",
"icon": "mdi:information-outline",
"device": {
    "identifiers": ["midcity_utilities"],
    "name": "Sunsynk Inverter",
    "manufacturer": "Sunsynk",
    "model": "Inverter"
}
}
EOF
)

        # Print the payload for debugging
        echo "Publishing MQTT discovery for ${display_name}"
        echo "${payload}"

        # Publish discovery config (retain it)
        mosquitto_pub -h "${MQTT_BROKER}" -p "${MQTT_PORT}" \
            -u "${MQTT_USERNAME}" -P "${MQTT_PASSWORD}" \
            -t "${topic}/config" -m "${payload}" -r

        # Publish the state
        mosquitto_pub -h "${MQTT_BROKER}" -p "${MQTT_PORT}" \
            -u "${MQTT_USERNAME}" -P "${MQTT_PASSWORD}" \
            -t "${state_topic}" -m "${value}"
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
    METER_BALANCE=$(jq -r '.meter_balance' midcity_connect.json | grep -o '[0-9\.]\+'); if [ -z "${METER_BALANCE}" ]; then METER_BALANCE=0; fi
    PREDICTED_ZERO_BALANCE=$(jq -r '.predicted_zero_balance' midcity_connect.json | grep -o '[0-9\.]\+'); if [ -z "${PREDICTED_ZERO_BALANCE}" ]; then PREDICTED_ZERO_BALANCE=0; fi

    echo "Meter Balance: ${METER_BALANCE}"
    echo "Predicted Zero Balance: ${PREDICTED_ZERO_BALANCE}"

    # Publish data to MQTT
    mqtt_publish "Meter Balance" "meter_balance" "${METER_BALANCE}" "kWh" "energy" "measurement"
    mqtt_publish_text "Predicted Zero Balance" "predicted_zero_balance" "${PREDICTED_ZERO_BALANCE}"
    
    # Sleep for refresh rate
    sleep $(bashio::config "refresh_time")

done