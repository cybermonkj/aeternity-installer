#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

RELEASE_VERSION="latest"
TEMP_RELEASE_FILE=${TEMP_RELEASE_FILE:=/tmp/aeternity.tgz}
TARGET_DIR=${TARGET_DIR:=$HOME/aeternity/node}
SHOW_PROMPT=true

usage () {
    echo -e "Usage:\n"
    echo -e "  $0 [options] release_version\n"
    echo "Options:"
    echo -e "  --no-prompt Disable confirmation prompts.\n"
    echo "Release version format is X.Y.Z where X, Y, and Z are non-negative integers"
    echo "You can find a list of aeternity releases at https://github.com/aeternity/aeternity/releases"
    exit 1
}

for arg in "$@"; do
    case $arg in
        --no-prompt)
            SHOW_PROMPT=false
            shift
        ;;
        --help)
            usage
        ;;
        --*)
            echo -e "ERROR: Unknown option '$arg'\n"
            usage
        ;;
        *)
        # do nothing, it's interpreted as version below
        ;;
    esac
done

# latest argument is interpreted as version
if [ $# -gt 0 ]; then
    RELEASE_VERSION=${@:$#}
fi

in_array() {
    local haystack=${1}[@]
    local needle=${2}
    for i in ${!haystack}; do
        if [[ ${i} == ${needle} ]]; then
            return 0
        fi
    done
    return 1
}

install_prompt () {
    echo -e "\nATTENTION: This script will delete the directory ${TARGET_DIR} if it exists. You should back up any contents before continuing.\n"
    read -p "Continue (y/n)?" inputprerunchoice
    case "$inputprerunchoice" in
        y|Y )
            echo "Continuing..."
            ;;
        n|N )
            echo "Exiting..."
            exit 0
            ;;
        * )
            echo "Invalid input..."
            install_prompt
            ;;
    esac
}

install_deps_anylinux() {
    OS_RELEASE=$(lsb_release -r -s)
    echo -e "\nPrepare host system and install dependencies ...\n"
    sudo apt-get update
    sudo apt-get upgrade -y
    sudo apt-get install -y curl libssl1.0.0

    #if [[ "$OS_RELEASE" = "16.04" ]]; then
    sudo apt-get install -y build-essential
    LIB_VERSION=1.0.16
    wget https://download.libsodium.org/libsodium/releases/old/libsodium-1.0.16.tar.gz #Libsodium was obsolated so i corrected the link
    tar -xf libsodium-${LIB_VERSION}.tar.gz && cd libsodium-${LIB_VERSION} &&
    ./configure && make && sudo make install && sudo ldconfig
    cd .. && rm -rf libsodium-${LIB_VERSION} && rm libsodium-${LIB_VERSION}.tar.gz
    #elif [[ "$OS_RELEASE" = "18.04" ]]; then
    sudo apt-get install -y curl libsodium23
    #else
    #   echo -e "Unsupported Ubuntu version! Please refer to the documentation for supported versions."
    #  exit 1
    #fi
}

install_deps_osx() {
    VER=$(sw_vers -productVersion)

    if ! [[ "$VER" = "10.13"* || $VER = "10.14"* ]]; then
        echo -e "Unsupported OSX version! Please refer to the documentation for supported versions."
        exit 1
    fi

    echo -e "\nInstalling dependencies ...\n"
    brew update
    brew install openssl libsodium
}

install_node() {
    RELEASE_FILE=$1
    echo -e "\nInstalling ${RELEASE_VERSION} release version...\n"

    if curl -Lf -o "${TEMP_RELEASE_FILE}" "${RELEASE_FILE}"; then
        if [ "$SHOW_PROMPT" = true ]; then
            install_prompt
        fi
        rm -rf "${TARGET_DIR}"
        mkdir -p "${TARGET_DIR}"
        tar -C "${TARGET_DIR}" -xzf "${TEMP_RELEASE_FILE}"

        echo -e "\nCleanup...\n"
        rm "${TEMP_RELEASE_FILE}"
    else
        echo -e "ERROR: Release package not found.\n"
        exit 1
    fi
}

if [[ "$OSTYPE" = "linux-gnu" && $(lsb_release -i -s) = "Parrot" ]]; then  #open terminal and type 'lsb_release -i -s' then replace 'Parrot' with its result, for your OS
    install_deps_anylinux
    install_node "https://releases.ops.aeternity.com/aeternity-latest-ubuntu-x86_64.tar.gz"
elif [[ "$OSTYPE" = "darwin"* ]]; then
    install_deps_osx
    install_node "https://releases.ops.aeternity.com/aeternity-latest-macos-x86_64.tar.gz"
elif [[ "$OSTYPE" = "linux-gnu" ]]; then
    install_deps_anylinux
    install_node "https://releases.ops.aeternity.com/aeternity-latest-ubuntu-x86_64.tar.gz"
else
    echo -e "Unsupported platform (OS)! Please refer to the documentation for supported platforms."
    exit 1
fi

echo -e "Installation completed."
echo -e "Run '${TARGET_DIR}/bin/aeternity start' to start the node in the background or"
echo -e "Run '${TARGET_DIR}/bin/aeternity console' to start the node with console output"
$?
