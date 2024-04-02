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
            if (fs.statSync(`${sDirPath}/${sFileName}`).isDirectory()) {
                aFiles.push(...getAllFiles(`${sDirPath}/${sFileName}`));
            } else {
                aFiles.push(path.join(__dirname, sDirPath, '/', sFileName));
            }
        });

    return aFiles;
};

const sBaseDirectory = '.';

const aAllFiles = getAllFiles(sBaseDirectory)
    // only JS files
    .filter((sFilePath) => sFilePath.indexOf('.js') === sFilePath.length - '.js'.length)
    // remove existing minified files
    .filter((sFilePath) => sFilePath.indexOf('-min.js') === -1)
    // remove current script because... it's useless to minify this script
    .filter((sFilePath) => sFilePath.indexOf('launch_esbuild.js') === -1);

aAllFiles.forEach((sFilePath) => {
    const sMinifiedPath = `${sFilePath.substring(sFilePath.indexOf('.js'), 0)}-min.js`;

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
