const core = require('@actions/core');
const exec = require('@actions/exec');
const io = require('@actions/io');
const { resolve } = require('path');
const path = require('path');
const os = require('os');

const main = async () => {
    try {
        var modules = '';
        var buildTargets = core.getInput('build-targets');

        if (!buildTargets) {
           modules = core.getInput('modules');
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

            var targets = buildTargets.split(' ');

            for (var target in targets) {
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
            versionFilePath = resolve(exeDir, 'ProjectSettings', 'ProjectVersion.txt');
        }

        var args = `-modulesList \"${modules}\" -versionFilePath \"${versionFilePath}\"`;
        var pwsh = await io.which("pwsh", true);
        var install = path.resolve(__dirname, 'unity-install.ps1');
        var exitCode = 0;

        exitCode = await exec.exec(`"${pwsh}" -Command`, `${install} ${args}`);

        if (exitCode != 0) {
            throw Error(`Unity Installation Failed! exitCode: ${exitCode}`)
        }

        core.setOutput('editor-path', process.env.UNITY_EDITOR_PATH);
        core.setOutput('project-path', process.env.UNITY_PROJECT_PATH);
    } catch (error) {
        core.setFailed(error.message);
    }
}

// Call the main function to run the action
main();