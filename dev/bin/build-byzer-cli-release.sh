#!/usr/bin/env bash
#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

##############################################################################
# This script build byzer-lang cli (All in one) tar.
# Tar file name convention: byzer-lang-all-in-one-${os}-amd64-${BYZER_LANG_VERSION}.tar.gz
# Layout looks like:
#├── bin
#│ ├── byzer                 ## byzer-cli
#│ └── bootstrap.sh   ##
#│ └── bootstrap.cmd   ##
#├── libs          ## 3rd-party jars
#│ ├── ansj_seg-5.1.6.jar
#│ └── nlp-lang-1.7.8.jar
#|-- jdk8
#├── main                   ## byzer-lang uber jar
#│ └── byzer-lang-2.4.3-2.11-2.1.0.jar
#├── plugin      ## byzer-lang plugins
#│ ├── mlsql-assert-2.4_2.11-0.1.0-SNAPSHOT.jar
#│ ├── mlsql-excel-2.4_2.11-0.1.0-SNAPSHOT.jar
#│ ├── mlsql-mllib-2.4_2.11-0.1.0-SNAPSHOT.jar
#│ └── mlsql-shell-2.4_2.11-0.1.0-SNAPSHOT.jar
#├── hadoop-3.0.0           ## hadoop native lib for windows
#└── spark                  ## Spark jars
#
# To for Spark 3.1.1 byzer-lang 2.3.0-SNAPSHOT linux
# export SPARK_VERSION=3.1.1
# export BYZER_LANG_VERSION=2.3.0-SNAPSHOT
# export OS=linux
# export JUICEFS_VERSION=0.17.5
# dev/bin/build-byzer-cli-release.sh

##############################################################################

set -e
set -o pipefail
set -u

## Byzer download base url
download_base_url="https://download.byzer.org/"

## linux darwin win
os=${OS:-linux}

function cp_jdk() {

  if [[ ! -d "${lib_path}"/jdk8 ]]; then
    echo "jdk8 is missing from ${lib_path}"
    exit 1
  fi

  cp -R "${lib_path}"/jdk8 "${target_dir}"/jdk8

}

function cp_plugins() {
  [[ -z ${plugins} ]] && echo "plugins variable is not defined" && exit 1
  for p in "${plugins[@]}"; do
    cp "${lib_path}/${p}-${BYZER_SPARK_VERSION}_${SCALA_BINARY_VERSION}-0.1.0-SNAPSHOT.jar" "${target_dir}"/plugin/
  done
  echo "plugin copy succeed"
}

## Assuming byzer-lang binary tar has been downloaded, untarred in dev/lib/byzer-lang
## The function copies byzer-lang main jar , scripts and config files to ${target_dir}/
function cp_byzer_lang() {
  if [[ ! -d "${lib_path}"/byzer-lang ]]; then
    echo "${lib_path}/byzer-lang does not exist"
    exit 1
  fi
  cp "${lib_path}"/byzer-lang/main/byzer-lang-"${SPARK_VERSION}"-"${SCALA_BINARY_VERSION}"-"${BYZER_LANG_VERSION}".jar \
    "${target_dir}"/main/

  ## Copy start and stop script
  cp "${lib_path}"/byzer-lang/bin/* "${target_dir}"/bin/
  cp "${lib_path}"/byzer-lang/conf/* "${target_dir}"/conf/
  cp "${target_dir}"/conf/byzer.properties.all-in-one.example "${target_dir}"/conf/byzer.properties.override
  cp "${lib_path}"/byzer-lang/LICENSE "${target_dir}/"
  cp "${lib_path}"/byzer-lang/README.md "${target_dir}/"
  cp "${lib_path}"/byzer-lang/RELEASES.md "${target_dir}/"

  echo "byzer-lang copy succeed"

}

function download_cli() {
  local url="${download_base_url}/byzer/misc/byzer-cli"
  echo "Downloading byzer-cli"
  if [[ ${os} == "linux" ]]; then
    wget --no-check-certificate --no-verbose "${url}/byzer-lang-linux-amd64" --output-document "${target_dir}/bin/byzer"
    chmod 755 "${target_dir}/bin/byzer"
  elif [[ ${os} == "win" ]]; then
    wget --no-check-certificate --no-verbose "${url}/byzer-lang-win-amd64.exe" --output-document "${target_dir}/bin/byzer.exe"
  else
    wget --no-check-certificate --no-verbose "${url}/byzer-lang-darwin-amd64" --output-document "${target_dir}/bin/byzer"
    chmod 755 "${target_dir}/bin/byzer"
  fi
  echo "Byzer-cli download succeed"
}

function cp_3rd_party_jars() {
  [[ ! -f "${lib_path}"/ansj_seg-5.1.6.jar ]] && echo "${lib_path}/ansj_seg-5.1.6.jar does not exist" && exit 1
  [[ ! -f "${lib_path}"/nlp-lang-1.7.8.jar ]] && echo "${lib_path}/nlp-lang-1.7.8.jar does not exist" && exit 1
  [[ ! -f "${lib_path}"/"${JUICEFS_JAR}" ]] && echo "${lib_path}/${JUICEFS_JAR} does not exist" && exit 1
  (
    cp "${lib_path}/ansj_seg-5.1.6.jar" \
       "${lib_path}/nlp-lang-1.7.8.jar" \
       "${lib_path}"/"${JUICEFS_JAR}" \
       "${target_dir}/libs/"
  ) || exit 1

  echo "Download 3rd-party jars succeed"
}

function download_hadoop_win_lib() {
  (
    wget --no-check-certificate --no-verbose "https://download.byzer.org/byzer/misc/hadoop/hadoop-3.0.0.tar.gz" \
      --directory-prefix "${lib_path}/" &&
      tar -xf "${lib_path}"/hadoop-3.0.0.tar.gz -C "${target_dir}"/ &&
      echo "Download hadoop win libs succeed"
  ) || exit 1
}

function download_cp_byzer_shell {
  echo "Download byzer-shell from download.byzer.org"
    if [[ "${os}" == "linux" ]]
    then
      (
        wget --no-check-certificate --no-verbose \
          https://download.byzer.org/byzer/misc/byzer-shell/1.0.0/byzer-shell-linux \
          --directory-prefix "${lib_path}/" &&
        cp "${lib_path}"/byzer-shell-linux "${target_dir}"/bin/
        chmod +x "${target_dir}"/bin/byzer-shell-linux
      ) || exit 1
    elif [[ "${os}" == "win" ]]
    then
      (
        wget --no-check-certificate --no-verbose https://download.byzer.org/byzer/misc/byzer-shell/1.0.0/byzer-shell.exe \
          --directory-prefix "${lib_path}" &&
        cp "${lib_path}"/byzer-shell.exe "${target_dir}"/bin/
      ) || exit 1
    elif [[ "${os}" == "darwin" ]]
    then
      ## MacOS
      (
        wget --no-check-certificate --no-verbose https://download.byzer.org/byzer/misc/byzer-shell/1.0.0/byzer-shell-darwin \
            --directory-prefix "${lib_path}/" &&
        mv "${lib_path}"/byzer-shell-darwin "${target_dir}"/bin/ &&
        chmod +x "${target_dir}"/bin/byzer-shell-darwin
      ) || exit 1
    else
      echo "No need to download byzer-shell for ${os}"
    fi
    echo "Byzer-shell download & copy succeed"
}

function cp_spark_jars() {

  [[ ! -d "${target_dir}/tmp/" ]] && mkdir -p "${target_dir}/tmp/"

  if [[ ${SPARK_VERSION} == "3.1.1" ]]; then
    cp "${lib_path}/spark-3.1.1-bin-hadoop3.2/jars/"* "${target_dir}/spark/"
    if [[ ! -f "${target_dir}/spark/spark-core_2.12-3.1.1.jar" ]]; then
      echo "Failed to copy spark 3.1.1"
      exit 1
    fi
  fi

  if [[ ${SPARK_VERSION} == "2.4.3" ]]; then
    cp "${lib_path}/spark-2.4.3-bin-hadoop2.7/jars/"* "${target_dir}/spark/"
    if [[ ! -f "${target_dir}/spark/spark-core_2.11-2.4.3.jar" ]]; then
      echo "Failed to copy spark 2.4.3"
      exit 1
    fi
  fi

  if [[ ${SPARK_VERSION} == "3.3.0" ]]; then
    cp "${lib_path}/spark-3.3.0-bin-hadoop3/jars/"* "${target_dir}/spark/"
    if [[ ! -f "${target_dir}/spark/spark-core_2.12-3.3.0.jar" ]]; then
      echo "Failed to copy spark 3.3.0"
      exit 1
    fi
  fi

  [[ -d ${target_dir}/tmp ]] && rm -rf "${target_dir:?}"/tmp/
  echo "Spark copy succeed"
}

echo "Start building byzer-lang-all-in-one-${os}-amd64-${SPARK_VERSION}-${BYZER_LANG_VERSION}"
self=$(cd -P -- "$(dirname -- "$0")" && pwd -P)

## Import function and environment variables
source "${self}"/mlsql-functions.sh
## This function is defined in mlsql-function.sh
download_byzer_lang_related_jars

target_dir="${lib_path}/byzer-lang-all-in-one-${os}-amd64-${SPARK_VERSION}-${BYZER_LANG_VERSION}"
rm -rf "${target_dir:?}/"
echo "make dir ${target_dir}"
mkdir -p "${target_dir}/main"
mkdir -p "${target_dir}/bin"
mkdir -p "${target_dir}/libs"
mkdir -p "${target_dir}/plugin"
mkdir -p "${target_dir}/spark"
mkdir -p "${target_dir}/logs"
mkdir -p "${target_dir}/tmp"
mkdir -p "${target_dir}/conf"

(
  cp_jdk &&
  download_cli &&
  cp_plugins &&
  cp_byzer_lang &&
  cp_3rd_party_jars &&
  cp_spark_jars &&
  download_cp_byzer_shell
) || exit 1

[[ ${os} == "win" ]] && download_hadoop_win_lib

## hello.byzer contains simple Byzer script for testing purposes
cp "${base_dir}/dev/bin/app/hello.byzer" "${target_dir}/bin/" || exit 1

(
  cd "${target_dir}/.." &&
  rm -f "byzer-lang-all-in-one-${os}-amd64-${SPARK_VERSION}-${BYZER_LANG_VERSION}.tar.gz" &&
  tar -czf "byzer-lang-all-in-one-${os}-amd64-${SPARK_VERSION}-${BYZER_LANG_VERSION}.tar.gz" "./byzer-lang-all-in-one-${os}-amd64-${SPARK_VERSION}-${BYZER_LANG_VERSION}"
) || exit 1

cat <<EOF
Build byzer all-in-one for ${os} finished, file name byzer-lang-all-in-one-${os}-amd64-${SPARK_VERSION}-${BYZER_LANG_VERSION}.tar.gz
EOF
