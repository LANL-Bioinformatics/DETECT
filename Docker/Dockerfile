FROM debian:8.5

MAINTAINER Chienchi Lo <chienchi@lanl.gov>

LABEL version="1.0"
LABEL software="DETECT"
LABEL description="Pipeline for assay design evaluation."
LABEL website="https://github.com/LANL-Bioinformatics/DETECT"
LABEL tags="genomics"

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

RUN apt-get update --fix-missing && apt-get install -y wget bzip2 ca-certificates \
    libglib2.0-0 libxext6 libsm6 libxrender1 \
    git curl make gcc gfortran g++ grep sed

RUN mkdir -p /opt && \
    cd /opt && git clone https://github.com/LANL-Bioinformatics/DETECT.git && \
    cd DETECT && bash INSTALL.sh && \
    echo 'export PATH=/opt/DETECT:/opt/DETECT/ext/miniconda/bin:$PATH' > /etc/profile.d/DETECT.sh && \
    echo 'export R_LIBS=/opt/targetngs/ext/lib/R_libs' >> /etc/profile.d/DETECT.sh && \
    apt-get clean

ADD start.sh /start.sh

ENV PATH /opt/DETECT:/opt/DETECT/ext/miniconda/bin:$PATH

ENV R_LIBS /opt/DETECT/ext/lib/R_libs

EXPOSE 3838

WORKDIR /data/

CMD [ "/start.sh" ]
