ARG extras_require=cpu
ARG base_image=debian:stretch-slim
ARG gpu=false

FROM debian:stretch-slim AS builder
ARG extras_require
RUN apt-get update \
	&& apt-get install -y python3-pip python3-setuptools python3-dev \
	&& apt-get install -y --no-install-recommends build-essential gcc git \
	&& apt-get purge -y

COPY setup.py /app/
COPY loudml /app/loudml
WORKDIR /app
COPY requirements.txt .

RUN python3 -m pip install --upgrade pip \
	&& python3 -m pip install --user --no-cache-dir -r requirements.txt \
	&& python3 -m pip install --user --no-cache-dir .[$extras_require]

FROM $base_image
ARG gpu

# python3-setuptools: Required to import pkg_resources
RUN apt-get update \
	&& apt-get install -y --no-install-recommends python3 python3-setuptools \
	&& apt-get purge -y

COPY --from=builder /root/.local /root/.local

RUN mkdir /var/lib/loudml \
	mkdir /etc/loudml && \
{ if [ "x$gpu" = "xtrue" ] ; then /bin/echo -e '\
---\n\
buckets: []\n\
server:\n\
  listen: 0.0.0.0:8077\n\
inference:\n\
  num_cpus: 1\n\
  num_gpus: 0\n\
training:\n\
  num_cpus: 1\n\
  num_gpus: 1\n\
  batch_size: 256\n\
' \
>> /etc/loudml/config.yml ; \
else /bin/echo -e '\
---\n\
buckets: []\n\
server:\n\
  listen: 0.0.0.0:8077\n\
' \
>> /etc/loudml/config.yml ; \
fi ; }

ENV PATH=/root/.local/bin:$PATH
CMD /bin/bash -c loudmld
LABEL maintainer="packaging_loudml_io.example.com"
EXPOSE 8077
