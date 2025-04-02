ARG BUILD_FROM
FROM $BUILD_FROM

# Install required packages
RUN apk update && apk add --no-cache mosquitto-clients bash python3 py3-pip
RUN pip3 install --no-cache-dir --break-system-packages requests
RUN pip3 install --no-cache-dir --break-system-packages bs4

# Copy data for add-on
COPY run.sh /
COPY pull_midcityutilities.py /
RUN chmod a+x /run.sh

CMD [ "/run.sh" ]