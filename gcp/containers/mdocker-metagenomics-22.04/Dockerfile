FROM ubuntu:22.04

#############################################################################################
# basics
#############################################################################################

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Los_Angeles

RUN apt-get update && apt-get install --no-install-recommends -y \
    git \
    lsb-release \
    curl \
    sudo \
    bash-completion \
    gnupg2 \
    python3-pip \
    apt-transport-https \
    ca-certificates \
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
    libopenblas0 \
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
# python venv
#############################################################################################

# Install build tools and venv package first
RUN apt-get update && \
    apt-get -y install gcc python3-dev python3-venv python3-setuptools --no-install-recommends && \
    apt-get clean all

# Create venv
RUN python3 -m venv /opt/venv

# Upgrade pip inside venv
RUN /opt/venv/bin/pip install --upgrade pip

# Add venv bin to PATH
ENV VENV_DIR="/opt/venv"
ENV VENV_PIP="$VENV_DIR/bin/pip"
ENV PATH="$VENV_DIR/bin:$PATH"

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
ENV PATH=$PATH:/usr/local/gcloud/google-cloud-sdk/bin

# Install crcmod in venv
RUN $VENV_PIP install --no-cache-dir -U crcmod

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

RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc \
    | gpg --dearmor -o /etc/apt/keyrings/cran.gpg

RUN echo "deb [signed-by=/etc/apt/keyrings/cran.gpg] \
    https://cloud.r-project.org/bin/linux/ubuntu jammy-cran40/" >> /etc/apt/sources.list

RUN apt-get update \
    && apt-get install --no-install-recommends -y r-base r-base-dev \
    && apt-get clean all

#############################################################################################
# gcsfuse
#############################################################################################

# current version (0.42.1) fails to mount
ENV GCSFUSE_VER=0.41.12
RUN curl -L -O https://github.com/GoogleCloudPlatform/gcsfuse/releases/download/v${GCSFUSE_VER}/gcsfuse_${GCSFUSE_VER}_amd64.deb \
    && dpkg --install gcsfuse_${GCSFUSE_VER}_amd64.deb

#############################################################################################
# dsub
#############################################################################################

# Install google-cloud-batch in venv
RUN $VENV_PIP install google-cloud-batch

# Clone dsub and install in venv
RUN git clone https://github.com/DataBiosphere/dsub /dsub && \
    cd /dsub && $VENV_PIP install .

#############################################################################################
# megahit
#############################################################################################

RUN mkdir -p /usr/local/megahit && \
    cd /usr/local/megahit && \
    wget https://github.com/voutcn/megahit/releases/download/v1.2.9/MEGAHIT-1.2.9-Linux-x86_64-static.tar.gz && \
    tar zvxf MEGAHIT-1.2.9-Linux-x86_64-static.tar.gz && rm -rf MEGAHIT-1.2.9-Linux-x86_64-static.tar.gz
ENV MEGAHIT_BIN=/usr/local/megahit/MEGAHIT-1.2.9-Linux-x86_64-static/bin/megahit

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

RUN $VENV_PIP install sendgrid khmer sourmash

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

ENV PATH=/opt/cd-hit:/opt/cd-hit/cd-hit-auxtools:/opt/cd-hit/psi-cd-hit:/opt/ncbi-blast-2.8.1+/bin:${PATH}

#############################################################################################
# MMSeqs2
#############################################################################################

RUN cd /usr/local && \
    wget https://mmseqs.com/latest/mmseqs-linux-avx2.tar.gz && \
    tar xvfz mmseqs-linux-avx2.tar.gz && \
    rm -rf mmseqs-linux-avx2.tar.gz
ENV PATH=$PATH:/usr/local/mmseqs/bin

#############################################################################################
# eggNOG
#############################################################################################

RUN mkdir /eggNOG && cd /eggNOG && \
    wget --no-check-certificate https://github.com/eggnogdb/eggnog-mapper/archive/refs/tags/2.1.7.tar.gz && \
    tar xvfz 2.1.7.tar.gz && \
    rm -rf 2.1.7.tar.gz && cd eggnog-mapper-2.1.7 && \
    $VENV_PIP install -r requirements.txt

#############################################################################################
# clustal
#############################################################################################

RUN wget http://www.clustal.org/omega/clustalo-1.2.4-Ubuntu-x86_64 && \
    mv clustalo-1.2.4-Ubuntu-x86_64 /usr/local/bin && \
    chmod a+x /usr/local/bin/clustalo-1.2.4-Ubuntu-x86_64

#############################################################################################
# StrainFinder (Python 2, pinned)
#############################################################################################

# Clone StrainFinder
RUN git clone https://github.com/cssmillie/StrainFinder.git /StrainFinder && \
    apt-get update && \
    apt-get install -y python2 python2-dev && \
    curl https://bootstrap.pypa.io/pip/2.7/get-pip.py --output get-pip.py && \
    python2 get-pip.py && \
    rm get-pip.py && \
    apt-get clean all

# Install numpy first
RUN pip2 install numpy==1.16.6

# Then install the rest
RUN pip2 install \
    scipy==1.2.3 \
    openopt==0.5629 \
    FuncDesigner==0.5629 \
    DerApproximator==0.5201

#############################################################################################
# Pandas
#############################################################################################

RUN $VENV_PIP install pandas

#############################################################################################
# GTDB-TK
#############################################################################################

# HMMER, PYTHON3, FASTTREE, MASH
RUN apt-get update -y -m && \
    apt-get install --no-install-recommends --no-install-suggests -y \
        hmmer=3.* \
        prodigal=1:2.6.* \
        fasttree=2.1.* \
        unzip && \
    apt-get clean all && \
    rm -rf /var/lib/apt/lists/* && \
    ln -s /usr/bin/fasttreeMP /usr/bin/FastTreeMP

# Manually install mash
RUN wget https://github.com/marbl/Mash/releases/download/v2.3/mash-Linux64-v2.3.tar && \
    tar xvf mash-Linux64-v2.3.tar && \
    mv mash-Linux64-v2.3/mash /usr/local/bin && \
    rm -rf mash-Linux64-v2.3 mash-Linux64-v2.3.tar

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

# SKANI
RUN wget https://github.com/bluenote-1577/skani/releases/latest/download/skani \
    && chmod +x skani \
    && mv skani /usr/local/bin/

# GTDB-TK
RUN $VENV_PIP install gtdbtk

#############################################################################################
# CheckM
#############################################################################################

RUN $VENV_PIP install numpy matplotlib pysam checkm-genome

#############################################################################################
# XML::Parser for parsing GOA_UNIPROT_TABLE
#############################################################################################

RUN cpanm install XML::Parser

#############################################################################################
# metaMDBG
#############################################################################################

RUN apt-get update && apt-get -y install cmake
RUN mkdir -p /usr/local/metaMDBG && \
    git clone https://github.com/GaetanBenoitDev/metaMDBG.git /usr/local/metaMDBG && \
    cd /usr/local/metaMDBG && mkdir build && cd build && cmake .. && make -j 3
ENV PATH=$PATH:/usr/local/metaMDBG/build/bin

ARG MINIMAP2_VER="2.28"
RUN curl -L https://github.com/lh3/minimap2/releases/download/v${MINIMAP2_VER}/minimap2-${MINIMAP2_VER}_x64-linux.tar.bz2 | tar -jxvf -
ENV PATH=$PATH:/minimap2-${MINIMAP2_VER}_x64-linux

#############################################################################################
# kraken2
#############################################################################################

RUN git clone https://github.com/DerrickWood/kraken2.git /kraken2_code && \
    cd /kraken2_code && \
    ./install_kraken2.sh /kraken2 && \
    rm -rf /kraken2_code
ENV PATH=$PATH:/kraken2

RUN apt-get update && apt-get install --no-install-recommends -y aria2 && apt-get clean all

#############################################################################################
# barrnap
#############################################################################################

# requires bedtools
RUN apt-get update && apt-get install --no-install-recommends -y bedtools \
    && apt-get clean all

RUN git clone https://github.com/tseemann/barrnap.git /opt/barrnap \
    && ln -s /opt/barrnap/bin/barrnap /usr/local/bin/barrnap

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

RUN R -e "install.packages(c('patchwork'))"

RUN R -e "install.packages('remotes')" \
    && R -e "remotes::install_github('Van1yu3/SWKM')"

RUN R -e "install.packages('diagram')"

# for nice scatter plots
RUN R -e "install.packages('ggrepel')"

RUN R -e "install.packages(c('aod', 'pROC', 'caret'))"

RUN R -e "install.packages(c('hexbin', 'MASS'))"

#############################################################################################
# appendix
#############################################################################################

RUN sh -c "$(curl -fsSL ftp://ftp.ncbi.nlm.nih.gov/entrez/entrezdirect/install-edirect.sh)"
ENV PATH=$PATH:/root/edirect

# vim
RUN apt-get update && apt-get install --no-install-recommends -y vim

# lftp
RUN apt-get update && apt-get install --no-install-recommends -y lftp

# MOB-suite
RUN apt-get -y install libgnutls28-dev
RUN $VENV_PIP install Bio
RUN $VENV_PIP install mob_suite
    
#############################################################################################
# aliases
#############################################################################################

RUN echo 'alias gcat="gsutil cat"' >> ~/.bashrc
RUN echo 'alias gsync="make m=gcp rsync"' >> ~/.bashrc

# glg gets and cleans
COPY glg /usr/local/bin/glg
RUN chmod +x /usr/local/bin/glg

#############################################################################################
# default command
#############################################################################################

CMD ["bash"]
