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
        var architecture = '';
        var buildTargets = core.getInput('build-targets');
        core.debug(`buildTargets: ${buildTargets}`);

        if (!buildTargets) {
           modules = core.getInput('modules');
           core.debug(`modules: ${modules}`);
        } else {
            var moduleMap = undefined;

            const osType = os.type();
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
                };

                architecture = await getArchitecture();
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

            var targets = buildTargets.split(' ');
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
        }

        var versionFilePath = core.getInput('version-file-path');

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
        var pwsh = await io.which("pwsh", true);
        var install = path.resolve(__dirname, 'unity-install.ps1');
        var exitCode = 0;

        exitCode = await exec.exec(`"${pwsh}" -Command`, `${install} ${args}`);

        if (exitCode != 0) {
            throw Error(`Unity Installation Failed! exitCode: ${exitCode}`)
        }
    } catch (error) {
        core.setFailed(error.message);
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
        for(const subDir of directories) {
            const nestedMatches = await findFile(subDir, filePath);

            for (const nestedMatch of nestedMatches) {
                matchedFiles.push(nestedMatch);
                break;
            }
        }
    }

    return matchedFiles;
};

const getArchitecture = async () => {
    try {
        const sysctlResult = await exec.exec('sysctl', ['-n', 'machdep.cpu.brand_string']);
        const stdout = sysctlResult.stdout.trim();
        core.info(`stdout: ${stdout}`);

        if (stdout.toLowerCase().includes('intel')) {
            core.info('Running on Intel (x86_64) architecture.');
            return 'x86_64';
        } else if (stdout.toLowerCase().includes('apple')) {
            core.info('Running on Apple Silicon (arm64) architecture.');
            return 'arm64';
        } else {
            throw Error('Unknown architecture: Unable to determine architecture');
        }
    } catch (error) {
        throw Error(`Failed to determine architecture: ${error.message}`);
    }
};

// Call the main function to run the action
main();