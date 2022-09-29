#!/bin/bash
RELEASE_NAME="ProfessionProfessor"

echo "Building Release zip..."
rm -f ${RELEASE_NAME}.zip
zip -r ${RELEASE_NAME}.zip Libs *.toc *.lua
echo Done!

# Open in gui for uploading
nemo .