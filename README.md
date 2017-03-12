![Build Status](https://codeblack.visualstudio.com/_apis/public/build/definitions/7b7058fd-5285-41e5-bc46-1a8502ec5e92/8/badge)

# TFSBuildScripts

This project provides a PowerShell script that can be used to provide versioning as part of a TFS Build.
Check the [wiki](https://github.com/CodeblackNL/TFSBuildScripts/wiki) for more information about the script. 

Previous versions (<= 1.5.0) of TFSBuildScripts provided scripts for the XAML-type builds;
see the [wiki](https://github.com/CodeblackNL/TFSBuildScripts/wiki/XAML-Home) for more information.

With TFS 2015, a new build mechanisme was introduced. It consists of the execution of a list of tasks.
TFS already comes with tasks for running a SonarQube analysis and packaging & publishing NuGet packages.
Also, release management is now integrated.

For TFSBuildScripts, this only leaves versioning; but that's a gooed thing :-).
