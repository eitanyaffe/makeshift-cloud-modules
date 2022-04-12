# Ubuntu 20.04.1 LTS
FROM ubuntu:20.04

#############################################################################################
# basics
#############################################################################################

RUN DEBIAN_FRONTEND="noninteractive" TZ="America/Los_Angeles" \
    apt-get update && apt-get install --no-install-recommends -y \
    git \
    lsb-release \
    curl \
    sudo \
    bash-completion \
    gnupg2 \
    python3.6 \
    python3-pip \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    wget \
    time \
    pigz \
    bc \
    x11-apps \
    less \
    && apt-get clean all

#############################################################################################
# install docker
#############################################################################################

RUN wget -O docker.tgz https://download.docker.com/linux/static/stable/x86_64/docker-20.10.0.tgz && \
    tar --extract \
         --file docker.tgz \
	 --strip-components 1 \
	 --directory /usr/local/bin/ \
    && \
    rm docker.tgz
COPY modprobe.sh /usr/local/bin/modprobe
COPY docker-entrypoint.sh /usr/local/bin/

#############################################################################################
# gcsfuse
#############################################################################################

RUN GCSFUSE_REPO="gcsfuse-`lsb_release -c -s`"; \
    echo "deb http://packages.cloud.google.com/apt $GCSFUSE_REPO main" | \
    tee /etc/apt/sources.list.d/gcsfuse.list
RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
RUN apt-get update && apt-get install --no-install-recommends -y gcsfuse && apt-get clean all

#############################################################################################
# dsub
#############################################################################################

RUN pip3 install dsub

#############################################################################################
# copy local scripts
#############################################################################################

COPY mm mml /usr/local/bin
RUN chmod +x /usr/local/bin/mm /usr/local/bin/mml

#############################################################################################
# g++, gnumake, R
#############################################################################################

RUN apt-get install --no-install-recommends -y build-essential libgsl0-dev && \
    apt-get clean all
RUN DEBIAN_FRONTEND="noninteractive" TZ="America/Los_Angeles" \
    apt-get install --no-install-recommends -y \
    dirmngr gnupg2 apt-transport-https ca-certificates software-properties-common \
    && apt-get clean all
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9
RUN add-apt-repository 'deb https://cloud.r-project.org/bin/linux/ubuntu focal-cran40/'

RUN apt-get install --no-install-recommends -y r-base && apt-get clean all

#############################################################################################
# gsutil
#############################################################################################

# Downloading gcloud package
RUN curl https://dl.google.com/dl/cloudsdk/release/google-cloud-sdk.tar.gz > \
    	 /tmp/google-cloud-sdk.tar.gz \
    && mkdir -p /usr/local/gcloud \
    && tar -C /usr/local/gcloud -xvf /tmp/google-cloud-sdk.tar.gz \
    && /usr/local/gcloud/google-cloud-sdk/install.sh \
    && rm /tmp/google-cloud-sdk.tar.gz

# Adding the package path to local
ENV PATH $PATH:/usr/local/gcloud/google-cloud-sdk/bin

RUN sudo apt-get -y install gcc python3-dev python3-setuptools --no-install-recommends && \
    sudo pip3 uninstall crcmod && \
    sudo pip3 install --no-cache-dir -U crcmod && \
    sudo apt-get clean all

#############################################################################################
# megahit
#############################################################################################

RUN mkdir -p /usr/local/megahit && \
    cd /usr/local/megahit && \
    wget https://github.com/voutcn/megahit/releases/download/v1.2.9/MEGAHIT-1.2.9-Linux-x86_64-static.tar.gz && \
    tar zvxf MEGAHIT-1.2.9-Linux-x86_64-static.tar.gz && rm -rf MEGAHIT-1.2.9-Linux-x86_64-static.tar.gz
ENV MEGAHIT_BIN /usr/local/megahit/MEGAHIT-1.2.9-Linux-x86_64-static/bin/megahit

#############################################################################################
# prodigal
#############################################################################################

RUN sudo apt-get install --no-install-recommends prodigal && \
    sudo apt-get clean all

#############################################################################################
# mapping
#############################################################################################

RUN sudo apt-get install --no-install-recommends -y bwa samtools && \
    sudo apt-get clean all

#############################################################################################
# sendgrid / khmer / sourmash
#############################################################################################

RUN pip3 install sendgrid khmer sourmash

#############################################################################################
# misc
#############################################################################################

RUN apt-get install -y liblapack-dev liblapack3 libopenblas-base libopenblas-dev
RUN apt-get install -y r-base-dev
RUN R -e "install.packages('seqinr', dependencies=TRUE, repos='http://cran.rstudio.com/')"

RUN apt-get install -y --no-install-recommends locate libboost-all-dev

RUN ln -s /usr/bin/python3 /usr/bin/python
RUN git clone https://github.com/chrisquince/DESMAN.git /DESMAN
RUN pip3 install Cython
RUN cd /DESMAN && ./setup.py install

RUN apt-get install -y lbzip2

RUN R -e "install.packages(c('umap', 'Rtsne'))"

RUN apt-get install -y valgrind

RUN apt-get install -y libswitch-perl

#############################################################################################
# spades assembler
#############################################################################################

RUN mkdir -p /usr/local/spades && \
    cd /usr/local/spades && \
    wget http://cab.spbu.ru/files/release3.15.3/SPAdes-3.15.3-Linux.tar.gz && \
    tar zvxf SPAdes-3.15.3-Linux.tar.gz && rm -rf SPAdes-3.15.3-Linux.tar.gz

#############################################################################################
# more R packages
#############################################################################################

RUN R -e "install.packages(c('gplots'))"

#############################################################################################
# diamond
#############################################################################################

RUN mkdir -p /usr/local/diamond && \
    cd /usr/local/diamond && \
    wget http://github.com/bbuchfink/diamond/releases/download/v2.0.13/diamond-linux64.tar.gz && \
    tar xvf diamond-linux64.tar.gz && rm -rf diamond-linux64.tar.gz && cp diamond /usr/local/bin

#############################################################################################
# sra-tools
#############################################################################################

ARG SRATOOLS_VERSION=current
RUN apt-get update && apt-get --quiet install --yes curl uuid-runtime && apt-get clean
RUN curl https://ftp-trace.ncbi.nlm.nih.gov/sra/sdk/${SRATOOLS_VERSION}/sratoolkit.${SRATOOLS_VERSION}-centos_linux64-cloud.tar.gz | tar xz -C /
ENV PATH=/usr/local/ncbi/sra-tools/bin:${PATH}
RUN mkdir -p /root/.ncbi && \
    printf '/LIBS/GUID = "%s"\n' `uuidgen` > /root/.ncbi/user-settings.mkfg && \
    printf '/libs/cloud/report_instance_identity = "true"\n' >> /root/.ncbi/user-settings.mkfg && \
    printf '/repository/user/main/public/cache-disabled = "false"\n' >> /root/.ncbi/user-settings.mkfg

# download not from bucket (from Amazon)
#RUN mkdir -p /root/.ncbi && \
#    printf '/LIBS/GUID = "%s"\n' `uuidgen` > /root/.ncbi/user-settings.mkfg && \
#    printf '/libs/cloud/report_instance_identity = "false"\n' >> /root/.ncbi/user-settings.mkfg && \
#    printf '/repository/user/main/public/cache-disabled = "true"\n' >> /root/.ncbi/user-settings.mkfg

#############################################################################################
# BiocManager and Biotstrings
#############################################################################################

RUN sudo apt-get install libcurl4-gnutls-dev
RUN R -e "install.packages('BiocManager')"
RUN R -e "BiocManager::install('Biostrings', ask=F)"

#############################################################################################
# cdhit
#############################################################################################

#### download and compile cd-hit 4.8.1
RUN wget https://github.com/weizhongli/cdhit/releases/download/V4.8.1/cd-hit-v4.8.1-2019-0228.tar.gz && \
    tar xvf cd-hit-v4.8.1-2019-0228.tar.gz && \
    mv cd-hit-v4.8.1-2019-0228 /opt/cd-hit && \
    cd /opt/cd-hit && \
    make && \
    cd /opt/cd-hit/cd-hit-auxtools && \
    make 

#### get NCBI BLAST+ 2.8.1
RUN cd /opt && \
    wget ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/2.8.1/ncbi-blast-2.8.1+-x64-linux.tar.gz && \
    tar xvf ncbi-blast-2.8.1+-x64-linux.tar.gz && \
    rm -f ncbi-blast-2.8.1+-x64-linux.tar.gz

ENV PATH="/opt/cd-hit:/opt/cd-hit/cd-hit-auxtools:/opt/cd-hit/psi-cd-hit:/opt/ncbi-blast-2.8.1+/bin:${PATH}"

#############################################################################################
# more R packages
#############################################################################################

RUN R -e "install.packages(c('igraph', 'intervals'))"

#############################################################################################
# default command
#############################################################################################

CMD bash
