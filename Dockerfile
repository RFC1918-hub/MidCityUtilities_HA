FROM python:3.11-alpine

# Install required packages
RUN apk update && apk add --no-cache mosquitto-clients bash python3 py3-pip
RUN pip3 install --no-cache-dir requests
RUN pip3 install --no-cache-dir bs4

# Copy data for add-on
COPY run.sh /
RUN chmod a+x /run.sh

CMD [ "/run.sh" ]