#!/bin/bash

RELEASE_NAME="ProfessionProfessor"
RELEASE_DIR=build

# Grab Version number from the .toc
VERSION=$(grep "Version" ${RELEASE_NAME}.toc | awk '{print $3}')

if [ -z "${VERSION}" ]
then
  VERSION="Unkown"
fi

# Make sure the path exists
mkdir -vp ${RELEASE_DIR}
(
  cd  ${RELEASE_DIR}

  rm -f ${RELEASE_NAME}*.zip
  rm -f ${RELEASE_NAME}
  mkdir -p ${RELEASE_NAME}

  echo "Building Release zip..."
  cp -r ../{Libs,*.toc,*.lua} ${RELEASE_NAME}
  zip -r ${RELEASE_NAME}-v${VERSION}.zip ${RELEASE_NAME}
  # delete old build dir and zip
  rm -rf ${RELEASE_NAME}
  echo Done!

  # Open in gui for uploading
  nemo .
)