// Library
const fs = require('fs');
const path = require('path');
const esbuild = require('esbuild');
const babel = require('@babel/core');

const getAllFiles = (sDirPath, aFiles = []) => {
    // do not parse "node_modules"
    if (sDirPath.indexOf('node_modules') !== -1) {
        return aFiles;
    }

    fs.readdirSync(sDirPath)
        .forEach((sFileName) => {
            if (fs.statSync(path.join(sDirPath, sFileName)).isDirectory()) {
                aFiles.push(...getAllFiles(path.join(sDirPath, sFileName)));
            } else {
                aFiles.push(path.join(sDirPath, sFileName));
            }
        });

    return aFiles;
};

// Take base directory as command line argument
const sBaseDirectory = process.argv[2] || '.';

const aAllFiles = getAllFiles(sBaseDirectory)
    // only JS files
    .filter((sFilePath) => sFilePath.endsWith('.js'))
    // remove existing minified files
    .filter((sFilePath) => !sFilePath.endsWith('-min.js'))
    // remove current script because... it's useless to minify this script
    .filter((sFilePath) => !sFilePath.endsWith('launch_esbuild.js'));

aAllFiles.forEach((sFilePath) => {
    const sMinifiedPath = `${sFilePath.substring(0, sFilePath.lastIndexOf('.js'))}-min.js`;

    // first, use babel to transform the code
    fs.writeFileSync(
        sMinifiedPath,
        babel.transformFileSync(sFilePath, {
            presets: ["@babel/preset-env"],

            // remove strict mode
            sourceType: 'script'
        }).code
    );

    // then apply additional transformation and minification
    esbuild.buildSync({
        entryPoints: [sMinifiedPath],
        outfile: sMinifiedPath,
        minify: true,
        target: ['es5'],
        allowOverwrite: true
    });
});
