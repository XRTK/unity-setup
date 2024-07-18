const core = require('@actions/core');
const exec = require('@actions/exec');
const io = require('@actions/io');
const path = require('path');
const fs = require("fs");
const { readdir } = require('fs/promises');
const os = require('os');

const main = async () => {
    try {
        var modules = '';
        var architecture = core.getInput('architecture');

        if (architecture) {
            core.debug(`architecture: ${architecture}`);
        } else {
            if (os.type() == 'Darwin') {
                if (os.arch() == 'arm64') {
                    architecture = 'arm64';
                } else if (os.arch() == 'x64') {
                    architecture = 'x86_64';
                }
            }
        }

        var buildTargets = core.getInput('build-targets');
        core.debug(`buildTargets: ${buildTargets}`);

        if (!buildTargets) {
            modules = core.getInput('modules');
            var modules = modules.replace(/,/g, '').split(/\s+/);
        } else {
            const osType = os.type();
            var moduleMap = undefined;

            if (osType == 'Linux') {
                moduleMap = {
                    "StandaloneLinux64": "linux-il2cpp",
                    "Android": "android",
                    "WebGL": "webgl",
                    "iOS": "ios",
                };
            } else if (osType == 'Darwin') {
                moduleMap = {
                    "StandaloneOSX": "mac-il2cpp",
                    "iOS": "ios",
                    "Android": "android",
                    "tvOS": "appletv",
                    "StandaloneLinux64": "linux-il2cpp",
                    "WebGL": "webgl",
                    "VisionOS": "visionos"
                };
            } else if (osType == 'Windows_NT') {
                moduleMap = {
                    "StandaloneWindows64": "windows-il2cpp",
                    "WSAPlayer": "universal-windows-platform",
                    "Android": "android",
                    "iOS": "ios",
                    "tvOS": "appletv",
                    "StandaloneLinux64": "linux-il2cpp",
                    "Lumin": "lumin",
                    "WebGL": "webgl",
                };
            } else {
                throw Error(`${osType} not supported`);
            }

            var targets = buildTargets.replace(/,/g, '').split(/\s+/);
            core.debug(`targets: ${targets}`);

            for (const target of targets) {
                core.debug(`target: ${target}`);

                var module = moduleMap[target];

                if (module === undefined) {
                    core.warning(`${target} not a valid build-target`);
                    continue;
                }

                modules += `${module} `;
                core.debug(`  ${target} -> ${module}`);
            }

            modules = modules.trim();
            core.debug(`modules: ${modules}`);
        }

        var unityVersion = core.getInput('unity-version');
        var versionFilePath = core.getInput('version-file-path');
        if (!unityVersion) {
            if (!versionFilePath) {
                // search for license file version
                var exeDir = path.resolve(process.cwd());
                core.debug(`exeDir: ${exeDir}`);
                versionFilePath = await findFile(exeDir, 'ProjectVersion.txt');
                core.debug(`version file path: ${versionFilePath}`);
            }

            core.debug(`modules: ${modules}`);
            core.debug(`versionFilePath: ${versionFilePath}`);

            var args = `-modulesList \"${modules}\" -versionFilePath \"${versionFilePath}\" -architecture \"${architecture}\"`;
        } else {
            core.debug(`unityVersion: ${unityVersion}`);
            var args = `-modulesList \"${modules}\" -unityVersion \"${unityVersion}\" -architecture \"${architecture}\"`;
        }

        var pwsh = await io.which("pwsh", true);
        var install = path.resolve(__dirname, 'unity-install.ps1');
        await exec.exec(`"${pwsh}" -Command`, `${install} ${args}`);
    } catch (error) {
        core.setFailed(`Unity Installation Failed! ${error.message}`);
    }
}

const findFile = async (dir, filePath) => {
    const directories = [];
    const matchedFiles = [];
    const files = await readdir(dir);

    for (const file of files) {
        const item = path.resolve(dir, file);

        if (fs.statSync(`${dir}/${file}`).isDirectory()) {
            directories.push(item);
        } else if (file.endsWith(filePath)) {
            core.debug(`--> Found! ${item}`);
            matchedFiles.push(item);
            break;
        }
    }

    if (matchedFiles.length == 0) {
        for (const subDir of directories) {
            const nestedMatches = await findFile(subDir, filePath);

            for (const nestedMatch of nestedMatches) {
                matchedFiles.push(nestedMatch);
                break;
            }
        }
    }

    return matchedFiles;
};

// Call the main function to run the action
main();