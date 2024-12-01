# Ubuntu 20.04.1 LTS
FROM ubuntu:20.04

#############################################################################################
# basics
#############################################################################################

ENV DEBIAN_FRONTEND="noninteractive"
ENV TZ="America/Los_Angeles"

RUN apt-get update && apt-get install --no-install-recommends -y \
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
    libcurl4-gnutls-dev \
    rsync \
    liblapack-dev \
    liblapack3 \
    libopenblas-base \
    libopenblas-dev \
    locate \
    libboost-all-dev \
    lbzip2 \
    valgrind \
    libswitch-perl \
    cpanminus \
    fuse \
    screen \
    && apt-get clean all

# make python3 the default
RUN ln -s /usr/bin/python3 /usr/bin/python

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
# dsub
#############################################################################################

RUN pip3 install dsub

#############################################################################################
# gsutil and gcloud
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

RUN apt-get update && \
    apt-get -y install gcc python3-dev python3-setuptools --no-install-recommends && \
    pip3 uninstall crcmod && \
    pip3 install --no-cache-dir -U crcmod && \
    apt-get clean all

# gcloud
RUN gcloud config set component_manager/disable_update_check true

#############################################################################################
# g++, gnumake
#############################################################################################

RUN apt-get install --no-install-recommends -y build-essential libgsl0-dev && \
    apt-get clean all

#############################################################################################
# R
#############################################################################################

RUN echo "deb https://cloud.r-project.org/bin/linux/ubuntu focal-cran40/" >> /etc/apt/sources.list
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9
RUN apt-get update \
    && apt-get install --no-install-recommends -y r-base r-base-dev \
    && apt-get clean all

#############################################################################################
# R packages
#############################################################################################

# basic packages
RUN R -e "install.packages(c('igraph', 'intervals', 'gplots', 'BiocManager'))"
RUN R -e "install.packages('seqinr', dependencies=TRUE, repos='http://cran.rstudio.com/')"

# visualization
RUN R -e "install.packages(c('umap', 'Rtsne'))"

# Biostrings
RUN R -e "BiocManager::install('Biostrings', ask=F)"

# for strain analysis
RUN R -e "BiocManager::install(c('dendextend', 'phangorn', 'phylogram'))"

# for G4iMGrinder
RUN R -e "BiocManager::install('pqsfinder')"

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

RUN apt-get install --no-install-recommends prodigal && \
    apt-get clean all

#############################################################################################
# samotools
#############################################################################################

RUN apt-get install --no-install-recommends -y bwa samtools && \
    apt-get clean all

#############################################################################################
# sendgrid / khmer / sourmash
#############################################################################################

RUN pip3 install sendgrid khmer sourmash

#############################################################################################
# spades assembler
#############################################################################################

RUN mkdir -p /usr/local/spades && \
    cd /usr/local/spades && \
    wget http://cab.spbu.ru/files/release3.15.3/SPAdes-3.15.3-Linux.tar.gz && \
    tar zvxf SPAdes-3.15.3-Linux.tar.gz && rm -rf SPAdes-3.15.3-Linux.tar.gz

#############################################################################################
# diamond
#############################################################################################

RUN mkdir -p /usr/local/diamond && \
    cd /usr/local/diamond && \
    wget https://github.com/bbuchfink/diamond/releases/download/v2.0.15/diamond-linux64.tar.gz && \
    tar xvf diamond-linux64.tar.gz && rm -rf diamond-linux64.tar.gz && cp diamond /usr/local/bin

#############################################################################################
# sra-tools
#############################################################################################

ARG SRATOOLS_VERSION=current
RUN apt-get update && apt-get --quiet install --yes curl uuid-runtime && apt-get clean all
RUN curl https://ftp-trace.ncbi.nlm.nih.gov/sra/sdk/${SRATOOLS_VERSION}/sratoolkit.${SRATOOLS_VERSION}-centos_linux64-cloud.tar.gz | tar xz -C /
ENV PATH=/usr/local/ncbi/sra-tools/bin:${PATH}
RUN mkdir -p /root/.ncbi && \
    printf '/LIBS/GUID = "%s"\n' `uuidgen` > /root/.ncbi/user-settings.mkfg && \
    printf '/libs/cloud/report_instance_identity = "true"\n' >> /root/.ncbi/user-settings.mkfg && \
    printf '/repository/user/main/public/cache-disabled = "false"\n' >> /root/.ncbi/user-settings.mkfg

# download not from bucket (from Amazon)
# RUN mkdir -p /root/.ncbi && \
#    printf '/LIBS/GUID = "%s"\n' `uuidgen` > /root/.ncbi/user-settings.mkfg && \
#    printf '/libs/cloud/report_instance_identity = "false"\n' >> /root/.ncbi/user-settings.mkfg && \
#    printf '/repository/user/main/public/cache-disabled = "true"\n' >> /root/.ncbi/user-settings.mkfg

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
# MMSeqs2
#############################################################################################

RUN cd /usr/local && \
    wget https://mmseqs.com/latest/mmseqs-linux-avx2.tar.gz && \
    tar xvfz mmseqs-linux-avx2.tar.gz && \
    rm -rf mmseqs-linux-avx2.tar.gz
ENV PATH $PATH:/usr/local/mmseqs/bin

#############################################################################################
# eggNOG
#############################################################################################

RUN mkdir /eggNOG && cd /eggNOG && \
    wget --no-check-certificate https://github.com/eggnogdb/eggnog-mapper/archive/refs/tags/2.1.7.tar.gz && \
    tar xvfz 2.1.7.tar.gz && \
    rm -rf 2.1.7.tar.gz && cd eggnog-mapper-2.1.7 && \
    pip install -r requirements.txt

#############################################################################################
# clustal
#############################################################################################

RUN wget http://www.clustal.org/omega/clustalo-1.2.4-Ubuntu-x86_64 && \
    mv clustalo-1.2.4-Ubuntu-x86_64 /usr/local/bin && \
    chmod a+x /usr/local/bin/clustalo-1.2.4-Ubuntu-x86_64

#############################################################################################
# StrainFinder
#############################################################################################

RUN git clone https://github.com/cssmillie/StrainFinder.git /StrainFinder && \
    apt install -y python2 && \
    curl https://bootstrap.pypa.io/pip/2.7/get-pip.py --output get-pip.py && \
    python2 get-pip.py && \
    apt-get install -y python-dev && apt-get clean all && \
    pip2 install numpy scipy && \
    pip2 install openopt FuncDesigner DerApproximator

#############################################################################################
# Pandas
#############################################################################################

RUN pip install pandas

#############################################################################################
# GTDB-TK
#############################################################################################

# HMMER, PYTHON3, FASTTREE, MASH
RUN apt-get update -y -m && \
    apt-get install --no-install-recommends --no-install-suggests -y \
        hmmer=3.* \
        mash=2.2.* \
        prodigal=1:2.6.* \
        fasttree=2.1.* \
        unzip && \
    apt-get clean all && \
    rm -rf /var/lib/apt/lists/* && \
    ln -s /usr/bin/fasttreeMP /usr/bin/FastTreeMP

# PPLACER
RUN wget https://github.com/matsen/pplacer/releases/download/v1.1.alpha19/pplacer-linux-v1.1.alpha19.zip -q && \
    unzip pplacer-linux-v1.1.alpha19.zip && \
    mv pplacer-Linux-v1.1.alpha19/* /usr/bin && \
    rm pplacer-linux-v1.1.alpha19.zip && \
    rm -rf pplacer-Linux-v1.1.alpha19

# FASTANI
RUN wget https://github.com/ParBLiSS/FastANI/releases/download/v1.33/fastANI-Linux64-v1.33.zip -q && \
    unzip fastANI-Linux64-v1.33.zip -d /usr/bin && \
    rm fastANI-Linux64-v1.33.zip

# GTDB-TK
RUN pip3 install gtdbtk

#############################################################################################
# CheckM
#############################################################################################

RUN pip3 install numpy matplotlib pysam checkm-genome

#############################################################################################
# Domcycle
#############################################################################################

ARG FORCE_REBUILD=unknown
RUN git clone https://github.com/nshalon/DomCycle.git /DomCycle
RUN pip3 install -r /DomCycle/requirements.txt

#############################################################################################
# XML::Parser for parsing GOA_UNIPROT_TABLE
#############################################################################################

RUN cpanm install XML::Parser

#############################################################################################
# gcsfuse
#############################################################################################

# current version (0.42.1) fails to mount
ENV GCSFUSE_VER=0.41.12
RUN curl -L -O https://github.com/GoogleCloudPlatform/gcsfuse/releases/download/v${GCSFUSE_VER}/gcsfuse_${GCSFUSE_VER}_amd64.deb \
    && dpkg --install gcsfuse_${GCSFUSE_VER}_amd64.deb

#RUN GCSFUSE_REPO="gcsfuse-`lsb_release -c -s`"; \
#    echo "deb http://packages.cloud.google.com/apt $GCSFUSE_REPO main" | \
#    tee /etc/apt/sources.list.d/gcsfuse.list
#RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
#RUN apt-get update && apt-get install --no-install-recommends -y gcsfuse && apt-get clean all

#############################################################################################
# appendix
#############################################################################################

RUN R -e "install.packages('remotes')" \
    && R -e "remotes::install_github('Van1yu3/SWKM')"

RUN R -e "install.packages('diagram')"

# for nice scatter plots
RUN R -e "install.packages('ggrepel')"

RUN R -e "install.packages(c('aod', 'pROC', 'caret'))"

RUN sh -c "$(curl -fsSL ftp://ftp.ncbi.nlm.nih.gov/entrez/entrezdirect/install-edirect.sh)"
ENV PATH $PATH:/root/edirect

# vim
RUN apt-get update && apt-get install --no-install-recommends -y vim

# lftp
RUN apt-get update && apt-get install --no-install-recommends -y lftp

# MOB-suite
RUN apt-get -y install libgnutls28-dev
RUN pip3 install Bio
RUN pip3 install mob_suite

RUN R -e "install.packages(c('hexbin', 'MASS'))"

#############################################################################################
# aliases
#############################################################################################

RUN echo 'alias gcat="gsutil cat"' >> ~/.bashrc
RUN echo 'alias gsync="make m=gcp rsync"' >> ~/.bashrc

#############################################################################################
# default command
#############################################################################################

CMD bash
