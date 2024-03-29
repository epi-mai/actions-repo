#!/bin/bash

#set -e
shopt -s nocasematch

echo "MMMMMMMMMMMMMMMMMMMMMMMMMMMM"
echo "MMMMMMMMMMMMMMMMMMMMMMMMMMMM"
echo "MMMMMMMMMMMMMMMMMMMMMMMMMMMM"

if [[ $TRAVIS_BRANCH == "master" ]] && [[ $TRAVIS_EVENT_TYPE == "push" ]]; then
  echo "[INFO] ${0##*/}: script is enabled for this branch"
elif [[ $TRAVIS_BRANCH =~ ^(staging|release)-.*$ ]] && [[ $TRAVIS_COMMIT_MESSAGE =~ ^.*\[hotfix\].*$ ]] && [[ $TRAVIS_EVENT_TYPE == "push"  ]]; then
  echo "[INFO] ${0##*/}: script is enabled for hotfixes"
else
  echo "[INFO] ${0##*/}: script is disabled for this branch (script is enabled for master and [hotfix] commits)" && exit 0
fi
shopt -u nocasematch

git fetch origin ${TRAVIS_BRANCH}:${TRAVIS_BRANCH}
git checkout ${TRAVIS_BRANCH}
git pull

echo "Start to minify voozanoo javascript's files (+ rollup)"

cd $TRAVIS_BUILD_DIR/
# Install nodejs packages. Use --prefix to be sure to install package in current directory.
npm i esbuild @babel/core @babel/preset-env --prefix ./

# Move to VooLibJs directory
cd $TRAVIS_BUILD_DIR/libs/VooLibJs

# Launch rollup
php rollup.php

# Minify
set +o errexit
node launch_esbuild.js 2>&1 | grep -A 3 "error:"
errcode=$?
set -o errexit

if [[ $errcode == 0 ]]; then
  echo "La minification du code javascript à échoué."
  exit 1
fi

cd ${TRAVIS_BUILD_DIR}
for f in $(find . -type f \( -iname "*-min.js" \)); do git add $f; done
git add libs/VooLibJs/static/yui3-voocore.js $TRAVIS_BUILD_DIR/libs/VooLibJs/min-checksum
git update-index --assume-unchanged ${TRAVIS_BUILD_DIR}/src/configs/APPINFOS
if [[ $TRAVIS_COMMIT_MESSAGE =~ ^.*\[hotfix\].*$ ]]; then
  git diff-index --quiet --cached HEAD -- || git commit -m "Minification of JS files"
else
  git diff-index --quiet --cached HEAD -- || git commit -m "[skip ci] Minification of JS files"
fi
git update-index --no-assume-unchanged ${TRAVIS_BUILD_DIR}/src/configs/APPINFOS
git push https://Epiconcept-Paris:${GIT_TOKEN}@github.com/Epiconcept-Paris/Voozanoo4.git ${TRAVIS_BRANCH}

# Remove nodejs packages
rm -rf ./node_modules

# Back to initial directory

git checkout ${TRAVIS_BRANCH}
git pull
cd ${TRAVIS_BUILD_DIR}

exit 0
