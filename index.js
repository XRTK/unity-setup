const core = require('@actions/core');
const exec = require('@actions/exec');
const io = require('@actions/io');
const path = require('path');

const main = async () => {
    try {
        var args = "";
        var modules = core.getInput('modules');

        if (!modules) {
            throw Error("Missing modules input");
        }

        args += `-modulesList \"${modules}\"`;

        var versionFilePath = core.getInput('version-file-path');

        if (!versionFilePath) {
            throw Error("Missing version-file-path input");
        }

        args += `-projectPath \"${versionFilePath}\" `;

        var pwsh = await io.which("pwsh", true);
        var install = path.resolve(__dirname, 'install-unity.ps1');
        var exitCode = await exec.exec(`"${pwsh}" -Command`, `${install} ${args}`);

        if (exitCode != 0) {
            throw Error(`Unity Installation Failed! exitCode: ${exitCode}`)
        }
    } catch (error) {
        core.setFailed(error.message);
    }
}

// Call the main function to run the action
main();