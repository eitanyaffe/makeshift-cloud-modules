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

# pinned: the un-versioned google-cloud-sdk.tar.gz url is a rolling pointer
ENV GCLOUD_SDK_VER=530.0.0
RUN curl https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-${GCLOUD_SDK_VER}-linux-x86_64.tar.gz > \
    	 /tmp/google-cloud-sdk.tar.gz \
    && mkdir -p /usr/local/gcloud \
    && tar -C /usr/local/gcloud -xvf /tmp/google-cloud-sdk.tar.gz \
    && /usr/local/gcloud/google-cloud-sdk/install.sh \
    && rm /tmp/google-cloud-sdk.tar.gz

# Adding the package path to local
ENV PATH=$PATH:/usr/local/gcloud/google-cloud-sdk/bin

# Install crcmod in venv
RUN $VENV_PIP install --no-cache-dir crcmod==1.7

# gcloud
RUN gcloud config set component_manager/disable_update_check true

#############################################################################################
# g++, gnumake
#############################################################################################

RUN apt-get update && apt-get install --no-install-recommends -y build-essential libgsl0-dev && \
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

ENV GCSFUSE_VER=3.2.6
RUN curl -L -O https://github.com/GoogleCloudPlatform/gcsfuse/releases/download/v${GCSFUSE_VER}/gcsfuse_${GCSFUSE_VER}_amd64.deb \
    && dpkg --install gcsfuse_${GCSFUSE_VER}_amd64.deb

#############################################################################################
# dsub
#############################################################################################

# Install google-cloud-batch in venv
RUN $VENV_PIP install google-cloud-batch==0.17.20

# Clone dsub and install in venv (pinned to tag v0.5.1)
RUN git clone --branch v0.5.1 --single-branch https://github.com/DataBiosphere/dsub /dsub && \
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
# sendgrid / sourmash
#############################################################################################

# khmer dropped 2026-04-20: upstream (dib-lab/khmer) archived 2019; sdist 2.1.1's
# ez_setup.py bootstrap tries to fetch setuptools from a retired pypi.python.org
# path and fails to build on modern pip.
#
# PIP_CONSTRAINT pins setuptools<81 in pip's isolated build env, for screed 1.1.3
# (pulled in as a sourmash dep, no wheel). screed's build imports pkg_resources
# via an older setuptools_scm; setuptools 81 removed pkg_resources.
# sourmash>=4.9 and screed>=1.2 both require python>=3.11, so they're out of
# reach on ubuntu 22.04 (python 3.10) — the current pins are already the latest
# versions compatible with this image.
RUN echo 'setuptools<81' > /tmp/pip-build.cons && \
    PIP_CONSTRAINT=/tmp/pip-build.cons $VENV_PIP install sendgrid==6.12.4 sourmash==4.8.14 && \
    rm /tmp/pip-build.cons

#############################################################################################
# diamond
#############################################################################################

# 2.1.x changed the .dmnd database format; existing 2.0-built indexes must be rebuilt
RUN mkdir -p /usr/local/diamond && \
    cd /usr/local/diamond && \
    wget https://github.com/bbuchfink/diamond/releases/download/v2.1.24/diamond-linux64.tar.gz && \
    tar xvf diamond-linux64.tar.gz && rm -rf diamond-linux64.tar.gz && cp diamond /usr/local/bin

#############################################################################################
# sra-tools
#############################################################################################

ARG SRATOOLS_VERSION=3.4.1
RUN apt-get update && apt-get --quiet install --yes curl uuid-runtime && apt-get clean all
# NCBI renamed the cloud build from centos_linux64-cloud to alma_linux64-cloud at 3.3
RUN curl https://ftp-trace.ncbi.nlm.nih.gov/sra/sdk/${SRATOOLS_VERSION}/sratoolkit.${SRATOOLS_VERSION}-alma_linux64-cloud.tar.gz | tar xz -C /
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

# avx2 binary: works on linux/amd64 GCP VMs; fails with "Illegal instruction" on arm64 emulation (apple silicon)
# pinned: github release tag (mmseqs.com/latest is a rolling master build)
ENV MMSEQS_VER=18-8cc5c
RUN cd /usr/local && \
    wget https://github.com/soedinglab/MMseqs2/releases/download/${MMSEQS_VER}/mmseqs-linux-avx2.tar.gz && \
    tar xvfz mmseqs-linux-avx2.tar.gz && \
    rm -rf mmseqs-linux-avx2.tar.gz
ENV PATH=$PATH:/usr/local/mmseqs/bin

#############################################################################################
# eggNOG
#############################################################################################

RUN mkdir /eggNOG && cd /eggNOG && \
    wget --no-check-certificate https://github.com/eggnogdb/eggnog-mapper/archive/refs/tags/2.1.13.tar.gz && \
    tar xvfz 2.1.13.tar.gz && \
    rm -rf 2.1.13.tar.gz && cd eggnog-mapper-2.1.13 && \
    sed -i 's|http://eggnogdb\.embl\.de/download|http://eggnog5.embl.de/download|g' download_eggnog_data.py && \
    $VENV_PIP install -r requirements.txt

#############################################################################################
# clustal
#############################################################################################

# clustal.org direct download 403s via cloudflare (2026-04-20); apt ships the same 1.2.4 upstream
RUN apt-get update && \
    apt-get install --no-install-recommends -y clustalo && \
    apt-get clean all

#############################################################################################
# StrainFinder (Python 2, pinned)
#############################################################################################

# Clone StrainFinder (pinned to commit 745a20a; repo has no release tags)
RUN git clone https://github.com/cssmillie/StrainFinder.git /StrainFinder && \
    cd /StrainFinder && git checkout 745a20a && cd / && \
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

RUN $VENV_PIP install pandas==1.5.3

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
RUN wget https://github.com/ParBLiSS/FastANI/releases/download/v1.34/fastANI-Linux64-v1.34.zip -q && \
    unzip fastANI-Linux64-v1.34.zip -d /usr/bin && \
    rm fastANI-Linux64-v1.34.zip

# SKANI (unpinnable: upstream publishes the precompiled binary only on the rolling
# "latest" github release; versioned tags (v0.3.1, v0.3.0, ...) carry no assets.
# reported version will drift between builds; details.txt captures what landed.
# real pinning would require `cargo install --tag vX.Y.Z` + the rust toolchain.)
RUN wget https://github.com/bluenote-1577/skani/releases/latest/download/skani \
    && chmod +x skani \
    && mv skani /usr/local/bin/

# GTDB-TK
RUN $VENV_PIP install gtdbtk==2.4.1

#############################################################################################
# CheckM
#############################################################################################

RUN $VENV_PIP install numpy==1.23.4 matplotlib==3.10.3 pysam==0.23.3 checkm-genome==1.2.4

#############################################################################################
# XML::Parser for parsing GOA_UNIPROT_TABLE
#############################################################################################

RUN cpanm install XML::Parser@2.47

#############################################################################################
# metaMDBG
#############################################################################################

RUN apt-get update && apt-get -y install cmake
# 1.3.x tags fail to link (missing static member defs for CoverageRegion::low/normal); holding at 1.2
ENV METAMDBG_VER=metaMDBG-1.2
RUN mkdir -p /usr/local/metaMDBG && \
    git clone --branch ${METAMDBG_VER} --single-branch https://github.com/GaetanBenoitDev/metaMDBG.git /usr/local/metaMDBG && \
    cd /usr/local/metaMDBG && mkdir build && cd build && cmake .. && make -j 3
ENV PATH=$PATH:/usr/local/metaMDBG/build/bin

ARG MINIMAP2_VER="2.28"
RUN curl -L https://github.com/lh3/minimap2/releases/download/v${MINIMAP2_VER}/minimap2-${MINIMAP2_VER}_x64-linux.tar.bz2 | tar -jxvf -
ENV PATH=$PATH:/minimap2-${MINIMAP2_VER}_x64-linux

#############################################################################################
# kraken2
#############################################################################################

RUN git clone --branch v2.1.6 --single-branch https://github.com/DerrickWood/kraken2.git /kraken2_code && \
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

RUN git clone --branch v1.10.6 --single-branch https://github.com/tseemann/barrnap.git /opt/barrnap \
    && ln -s /opt/barrnap/bin/barrnap /usr/local/bin/barrnap

#############################################################################################
# myloasm
#############################################################################################

# avx2 binary: works on linux/amd64 GCP VMs; fails with "Illegal instruction" on arm64 emulation (apple silicon)
RUN wget https://github.com/bluenote-1577/myloasm/releases/download/v0.5.1/myloasm-0.5.1-x86_64-avx2 && \
    chmod +x myloasm-0.5.1-x86_64-avx2 && \
    mv myloasm-0.5.1-x86_64-avx2 /usr/local/bin/myloasm
    
#############################################################################################
# appendix
#############################################################################################

# unpinned: NCBI ships a single rolling installer (no versioned URL); v1.00 baseline was 25.3
RUN sh -c "$(curl -fsSL ftp://ftp.ncbi.nlm.nih.gov/entrez/entrezdirect/install-edirect.sh)"
ENV PATH=$PATH:/root/edirect

# vim
RUN apt-get update && apt-get install --no-install-recommends -y vim

# lftp
RUN apt-get update && apt-get install --no-install-recommends -y lftp

# MOB-suite
RUN apt-get -y install libgnutls28-dev
RUN $VENV_PIP install Bio==1.8.1
RUN $VENV_PIP install mob_suite==3.1.9

#############################################################################################
# kmer-db
#############################################################################################

# precompiled x86_64 binary (uses avx2): fails with "Illegal instruction" on arm64 emulation (apple silicon)
RUN mkdir -p /usr/local/kmer-db && \
    cd /usr/local/kmer-db && \
    wget https://github.com/refresh-bio/kmer-db/releases/download/v2.3.1/kmer-db-v2.3.1-x64_linux.tar.gz && \
    tar xvf kmer-db-v2.3.1-x64_linux.tar.gz && \
    rm kmer-db-v2.3.1-x64_linux.tar.gz && \
    chmod +x kmer-db

ENV PATH=$PATH:/usr/local/kmer-db

RUN $VENV_PIP install networkx==3.4.2

#############################################################################################
# mafft
#############################################################################################

RUN apt-get update && \
    apt-get install -y --no-install-recommends mafft && \
    rm -rf /var/lib/apt/lists/*

#############################################################################################
# hifiasm-meta
#############################################################################################

RUN git clone --branch hamtv0.3.5 --single-branch https://github.com/xfengnefx/hifiasm-meta.git && \
    cd hifiasm-meta && make && \
    cp hifiasm_meta /usr/local/bin/

#############################################################################################
# bracken
#############################################################################################

# pinned: commit 8732ef5 (1 commit past tag v3.1; v1.00 baseline)
RUN git clone https://github.com/jenniferlu717/Bracken.git /opt/bracken && \
    cd /opt/bracken && git checkout 8732ef5 && \
    cd /opt/bracken/src && \
    make

ENV PATH=$PATH:/opt/bracken

#############################################################################################
# drep
#############################################################################################

# pinned: commit 7b4b8fb (23 commits past tag v3.4.2; v1.00 baseline)
RUN git clone https://github.com/MrOlm/drep.git /opt/drep && \
    cd /opt/drep && git checkout 7b4b8fb && \
    $VENV_PIP install .

#############################################################################################
# aliases
#############################################################################################

RUN echo 'alias gcat="gsutil cat"' >> ~/.bashrc
RUN echo 'alias gsync="make m=gcp rsync"' >> ~/.bashrc

# glg gets and cleans
COPY glg /usr/local/bin/glg
RUN chmod +x /usr/local/bin/glg

#############################################################################################
# java + nextflow
#############################################################################################

RUN apt-get update && apt-get install --no-install-recommends -y openjdk-21-jre-headless && \
    apt-get clean all

# pinned: get.nextflow.io serves whatever is latest at build time (v1.00 baseline: 25.10.4)
ENV NXF_VER=25.10.4
RUN curl -s https://get.nextflow.io | bash && \
    mv nextflow /usr/local/bin/ && \
    chmod +x /usr/local/bin/nextflow

#############################################################################################
# R packages
#############################################################################################

# prereqs for plotly (compiled from source)
RUN apt-get update && apt-get install --no-install-recommends -y \
    libssl-dev \
    pkg-config \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# every R install ends with stopifnot(requireNamespace(...)) so a silent failure
# (common for BiocManager::install) causes the docker build to fail rather than
# producing an image with ghost packages.

RUN R -q -e 'p <- c("igraph","intervals","gplots","BiocManager"); \
    install.packages(p); \
    stopifnot(all(sapply(p, requireNamespace, quietly=TRUE)))'

RUN R -q -e 'install.packages("seqinr", dependencies=TRUE, repos="http://cran.rstudio.com/"); \
    stopifnot(requireNamespace("seqinr", quietly=TRUE))'

RUN R -q -e 'p <- c("umap","Rtsne"); \
    install.packages(p); \
    stopifnot(all(sapply(p, requireNamespace, quietly=TRUE)))'

RUN R -q -e 'BiocManager::install("Biostrings", ask=FALSE); \
    stopifnot(requireNamespace("Biostrings", quietly=TRUE))'

RUN R -q -e 'p <- c("dendextend","phangorn","phylogram"); \
    BiocManager::install(p, ask=FALSE); \
    stopifnot(all(sapply(p, requireNamespace, quietly=TRUE)))'

# 2026-04-20: dropped pqsfinder + G4iMGrinder. only caller is modules/dev/metagenomics/G4.
# reinstall here if G4 is reactivated; pqsfinder needs BH pinned to a boost-v4 era (<=1.87.0-1)
# to avoid duplicate-symbol errors between system libboost and BH's bundled boost_regex v5.

RUN R -q -e 'install.packages("patchwork"); \
    stopifnot(requireNamespace("patchwork", quietly=TRUE))'

RUN R -q -e 'install.packages("remotes"); \
    stopifnot(requireNamespace("remotes", quietly=TRUE))' && \
    R -q -e 'remotes::install_github("Van1yu3/SWKM"); \
    stopifnot(requireNamespace("SWKM", quietly=TRUE))'

RUN R -q -e 'install.packages("diagram"); \
    stopifnot(requireNamespace("diagram", quietly=TRUE))'

RUN R -q -e 'install.packages("ggrepel"); \
    stopifnot(requireNamespace("ggrepel", quietly=TRUE))'

RUN R -q -e 'p <- c("aod","pROC","caret"); \
    install.packages(p); \
    stopifnot(all(sapply(p, requireNamespace, quietly=TRUE)))'

RUN R -q -e 'p <- c("hexbin","MASS"); \
    install.packages(p); \
    stopifnot(all(sapply(p, requireNamespace, quietly=TRUE)))'

# for phylogenetic tree plotting (evo module; phytools for malign tree layout gallery)
RUN R -q -e 'p <- c("ape","ggplot2","dplyr","tidyr","gridExtra","phytools"); \
    install.packages(p); \
    stopifnot(all(sapply(p, requireNamespace, quietly=TRUE)))'

# system deps newly required by ggtree's Bioc 3.22 transitive graph:
# libuv1-dev for 'fs'; fontconfig/freetype/harfbuzz/fribidi for 'systemfonts'; cairo for 'gdtools'
RUN apt-get update && apt-get install --no-install-recommends -y \
        libuv1-dev libfontconfig1-dev libfreetype6-dev libharfbuzz-dev libfribidi-dev \
        libcairo2-dev && \
    apt-get clean all

RUN R -q -e 'p <- c("ggtree","ggtreeExtra"); \
    BiocManager::install(p, ask=FALSE); \
    stopifnot(all(sapply(p, requireNamespace, quietly=TRUE)))'

RUN R -q -e 'install.packages("htmlwidgets"); \
    stopifnot(requireNamespace("htmlwidgets", quietly=TRUE))'

RUN R -q -e 'install.packages("plotly", repos="https://cloud.r-project.org"); \
    stopifnot(requireNamespace("plotly", quietly=TRUE))'

RUN R -q -e 'install.packages("scanstatistics"); \
    stopifnot(requireNamespace("scanstatistics", quietly=TRUE))'

#############################################################################################
# image identity (kept last: version bumps only invalidate this tiny layer, not the whole image)
#############################################################################################

# GCP_IMAGE_VER is passed via --build-arg from gcp_image.mk (mdocker target).
# bump it in modules/cloud/gcp/gcp_int.mk and rebuild to produce a new versioned image.
ARG GCP_IMAGE_VER=unknown
ENV GCP_IMAGE_VER=${GCP_IMAGE_VER}
LABEL org.opencontainers.image.version="${GCP_IMAGE_VER}"

#############################################################################################
# default command
#############################################################################################

CMD ["bash"]
