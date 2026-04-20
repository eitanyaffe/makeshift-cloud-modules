#!/bin/bash
# prints versions of tools installed in the mdocker image.
# runs inside the container (see gcp_tools.mk: mdocker_tools_versions).
# output columns: <install_method>\t<tool_name>\t<version>
# if a version cannot be resolved, a DEBUG line follows with path info to help diagnose.

set +e

FMT='%-8s %-28s %s\n'

# self-reported image version (baked at build time via Dockerfile ARG GCP_IMAGE_VER).
# lets a bare "bash tools_versions.sh" run be identifiable without the make-side header.
# if this disagrees with the make-recipe header, something is inconsistent.
printf "$FMT" image GCP_IMAGE_VER "${GCP_IMAGE_VER:-unset}"
echo ""

# returns 0 if the provided version string looks real, 1 if it should trigger a DEBUG line
# ISA_UNSUPPORTED is expected when running an amd64/avx2 binary under arm64 emulation
# (e.g. apple silicon + rosetta/qemu); no debug line needed in that case.
is_bad_version() {
    v="$1"
    case "$v" in
        ""|MISSING|ERROR|NOT_A_REPO*|NOT_INSTALLED*|DIR_MISSING*) return 0 ;;
        *"command not found"*|*"No such file"*|*"not found"*) return 0 ;;
    esac
    return 1
}

# maps a command result (stdout+stderr + exit code) to a version string,
# recognizing "Illegal instruction" (SIGILL -> exit 132) as ISA_UNSUPPORTED.
extract_version() {
    out="$1"; rc="$2"
    if [ "$rc" = 132 ] || echo "$out" | grep -q 'Illegal instruction'; then
        echo "ISA_UNSUPPORTED (illegal instruction; likely x86_64/avx2 binary under arm64 emulation)"
        return
    fi
    v=$(echo "$out" | grep -v '^[[:space:]]*$' | head -1 | tr -d '\r')
    [ -z "$v" ] && v="ERROR"
    # mmseqs "latest" tarballs print a bare 40-char git sha; relabel for readability
    if echo "$v" | grep -qE '^[0-9a-f]{40}$'; then
        v="commit ${v:0:12}"
    fi
    echo "$v"
}

# prints a "DEBUG" companion line showing how/where we looked
print_debug() {
    name="$1"; shift
    hints="$*"
    wpath=$(command -v "$name" 2>/dev/null)
    [ -z "$wpath" ] && wpath="NOTFOUND"
    printf "$FMT" DEBUG "$name" "which=$wpath $hints"
}

print_apt() {
    for pkg in "$@"; do
        ver=$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null)
        if [ -z "$ver" ]; then
            # fall back to apt-cache for transitional/virtual packages
            ver=$(apt-cache policy "$pkg" 2>/dev/null | awk '/Installed:/ {print $2; exit}')
            [ "$ver" = "(none)" ] && ver=""
        fi
        [ -z "$ver" ] && ver="MISSING"
        printf "$FMT" apt "$pkg" "$ver"
        if is_bad_version "$ver"; then
            provider=$(dpkg -L "$pkg" 2>/dev/null | head -1)
            print_debug "$pkg" "dpkg-L-first=${provider:-none}"
        fi
    done
}

# runs cmd args..., keeps first non-empty line as the version string
print_cmd() {
    label="$1"; name="$2"; shift 2
    out=$("$@" 2>&1); rc=$?
    ver=$(extract_version "$out" "$rc")
    printf "$FMT" "$label" "$name" "$ver"
    if is_bad_version "$ver"; then
        print_debug "$name" "cmd=$* rc=$rc"
    fi
}

# runs cmd args..., picks line matching a grep pattern
print_cmd_grep() {
    label="$1"; name="$2"; pattern="$3"; shift 3
    out=$("$@" 2>&1); rc=$?
    if [ "$rc" = 132 ] || echo "$out" | grep -q 'Illegal instruction'; then
        ver="ISA_UNSUPPORTED (illegal instruction; likely x86_64/avx2 binary under arm64 emulation)"
    else
        ver=$(echo "$out" | grep -m1 -E "$pattern" | tr -d '\r')
        [ -z "$ver" ] && ver="ERROR"
    fi
    printf "$FMT" "$label" "$name" "$ver"
    if is_bad_version "$ver"; then
        print_debug "$name" "cmd=$* pattern=$pattern rc=$rc"
    fi
}

print_git() {
    name="$1"; path="$2"
    if [ ! -d "$path/.git" ]; then
        printf "$FMT" git "$name" "NOT_A_REPO"
        print_debug "$name" "path=$path exists=$([ -d $path ] && echo yes || echo no)"
        return
    fi
    head=$(git -C "$path" rev-parse --short HEAD 2>/dev/null)
    desc=$(git -C "$path" describe --tags --always 2>/dev/null)
    printf "$FMT" git "$name" "HEAD=$head describe=$desc"
}

print_pip() {
    runner="$1"; pkg="$2"
    ver=$($runner show "$pkg" 2>/dev/null | awk '/^Version:/ {print $2}')
    [ -z "$ver" ] && ver="MISSING"
    label="pip"
    [ "$runner" = "pip2" ] && label="pip2"
    printf "$FMT" "$label" "$pkg" "$ver"
    if is_bad_version "$ver"; then
        loc=$($runner show "$pkg" 2>/dev/null | awk '/^Location:/ {print $2}')
        print_debug "$pkg" "runner=$runner location=${loc:-none}"
    fi
}

# queries an R package via Rscript (no prompt echo, clean stdout)
print_R() {
    pkg="$1"
    ver=$(Rscript -e "suppressPackageStartupMessages(cat(as.character(packageVersion('$pkg'))))" 2>/dev/null)
    [ -z "$ver" ] && ver="MISSING"
    printf "$FMT" R "$pkg" "$ver"
    if is_bad_version "$ver"; then
        loc=$(Rscript -e "cat(find.package('$pkg', quiet=TRUE))" 2>/dev/null)
        print_debug "$pkg" "find.package=${loc:-none}"
    fi
}

echo "# apt packages (explicit in Dockerfile)"
# libgsl-dev replaces libgsl0-dev on 22.04; query both and keep whichever is installed
print_apt bwa samtools prodigal hmmer fasttree mafft bedtools lftp clustalo \
    vim aria2 unzip cmake r-base r-base-core \
    openjdk-21-jre-headless python3 python3-dev python3-venv python3-pip python3-setuptools \
    libssl-dev pkg-config libgsl-dev libboost-all-dev libgnutls28-dev \
    libcurl4-gnutls-dev liblapack-dev liblapack3 libopenblas-dev libopenblas0 \
    lbzip2 pigz time bc curl wget git sudo screen less rsync locate valgrind \
    bash-completion x11-apps fuse apt-transport-https ca-certificates gnupg gnupg2 \
    libswitch-perl cpanminus lsb-release uuid-runtime \
    python2 python2-dev build-essential

echo ""
echo "# release tarballs / precompiled binaries"
print_cmd       tarball megahit     /usr/local/megahit/MEGAHIT-1.2.9-Linux-x86_64-static/bin/megahit --version
print_cmd       tarball diamond     diamond version
print_cmd       tarball minimap2    minimap2 --version
print_cmd       tarball mash        mash --version
print_cmd_grep  tarball fastANI     'version'          fastANI --version
print_cmd       tarball pplacer     pplacer --version
print_cmd_grep  tarball cd-hit      'CD-HIT version'   cd-hit -h
print_cmd       tarball gcsfuse     gcsfuse --version
print_cmd       tarball skani       skani --version
print_cmd_grep  tarball kmer-db     'Kmer-db'          kmer-db
print_cmd_grep  tarball sra-tools   'fastq-dump[[:space:]]*:'   fastq-dump --version
print_cmd       tarball myloasm     myloasm --version
print_cmd       tarball mmseqs2     mmseqs version
print_cmd_grep  tarball nextflow    'version'          nextflow -v
print_cmd       tarball docker      docker --version
print_cmd_grep  tarball gcloud      'Google Cloud SDK' gcloud --version
print_cmd_grep  tarball blast+      'blastn:'          blastn -version
print_cmd_grep  tarball kraken2     'version'          kraken2 --version
print_cmd       tarball edirect     esearch -version

echo ""
echo "# git clones (HEAD + nearest tag)"
print_git dsub          /dsub
print_git StrainFinder  /StrainFinder
print_git metaMDBG      /usr/local/metaMDBG
print_git barrnap       /opt/barrnap
print_git hifiasm-meta  /hifiasm-meta
print_git Bracken       /opt/bracken
print_git drep          /opt/drep

echo ""
echo "# python (pip) packages (venv at /opt/venv)"
VPIP=/opt/venv/bin/pip
for p in crcmod sendgrid sourmash google-cloud-batch dsub pandas gtdbtk \
         numpy matplotlib pysam checkm-genome Bio mob_suite networkx; do
    print_pip $VPIP "$p"
done

echo ""
echo "# python2 (pip2) packages (StrainFinder)"
for p in numpy scipy openopt FuncDesigner DerApproximator; do
    print_pip pip2 "$p"
done

echo ""
echo "# perl / cpan packages"
xp=$(perl -MXML::Parser -e 'print $XML::Parser::VERSION' 2>/dev/null)
[ -z "$xp" ] && xp="MISSING"
printf "$FMT" cpan "XML::Parser" "$xp"
if is_bad_version "$xp"; then
    loc=$(perl -MXML::Parser -e 'print $INC{"XML/Parser.pm"}' 2>/dev/null)
    print_debug "XML::Parser" "INC=${loc:-none}"
fi

echo ""
echo "# R packages (explicit in Dockerfile)"
for p in igraph intervals gplots BiocManager seqinr umap Rtsne Biostrings \
         dendextend phangorn phylogram patchwork remotes SWKM \
         diagram ggrepel aod pROC caret hexbin MASS ape ggplot2 dplyr tidyr \
         gridExtra phytools ggtree ggtreeExtra htmlwidgets plotly scanstatistics; do
    print_R "$p"
done

echo ""
echo "# distro / baseline"
if [ -r /etc/os-release ]; then
    . /etc/os-release
    printf "$FMT" system "ubuntu" "${VERSION_ID:-unknown} (${VERSION_CODENAME:-?})"
fi
printf "$FMT" system "gcc"    "$(gcc    -dumpfullversion 2>/dev/null || echo MISSING)"
printf "$FMT" system "g++"    "$(g++    -dumpfullversion 2>/dev/null || echo MISSING)"
printf "$FMT" system "make"   "$(make --version 2>/dev/null | head -1 || echo MISSING)"
printf "$FMT" system "perl"   "$(perl --version 2>/dev/null | grep -m1 -E 'v[0-9]' || echo MISSING)"
printf "$FMT" system "bash"   "$(bash --version 2>/dev/null | head -1 || echo MISSING)"
printf "$FMT" system "kernel" "$(uname -r)"

echo ""
echo "# eggnog-mapper (pinned tarball)"
EGG_DIR=/eggNOG/eggnog-mapper-2.1.13
if [ -f $EGG_DIR/eggnogmapper/version.py ]; then
    v=$(grep -E '__(DB_)?VERSION__' $EGG_DIR/eggnogmapper/version.py | tr -d ' "')
    printf "$FMT" special "eggnog-mapper" "2.1.13 ($v)"
else
    printf "$FMT" special "eggnog-mapper" "DIR_MISSING"
    print_debug "eggnog-mapper" "expected=$EGG_DIR listing=$(ls /eggNOG 2>/dev/null | tr '\n' ',')"
fi
