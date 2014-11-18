# TFSBuildScripts

This project provides PowerShell scripts that can be used to extend TFS Build Workflows.

Check the [wiki](https://github.com/CodeblackNL/TFSBuildScripts/wiki) for more information about the scripts, the module and it's functions as well as the status and roadmap of this project. 

## TFS Build

With TFS 2013, the default build workflow changed. The workflow itself, the structure of activities, has almost been reduced to pretty much a simple sequence. Instead of stitching everything together with huge amounts of activities, only a few activities are used that do all the same work under the covers.

More importantly, the default workflow includes extension-points where PowerShell scripts can easily be provided that will run as part of the build. Which is the reason for this project.

## Customizing the build

Starting with TFS 2010, customizing the build process became a lot easier with the introduction of workflow. I created activities, e.g. for versioning, [sonar-analysis](http://www.sonarqube.org/) and sending e-mail with detailed build-details; and used activities from open source projects like [TFS Versioning](http://tfsversioning.codeplex.com/) and [TFS NuGetter](http://nugetter.codeplex.com/).

TFS 2012 did not bring major changes to the build workflow. I did some minor work to upgrade my own activities and upgraded to the latest versions of the open source activities, and that was it.

TFS 2013 did bring major changes. One of the effects of simplifying the workflow was that most variables, that the TFS 2010 & 2012 workflows needed to pass the state from activity to activity, are now kept inside the few activities that are left. This means it is harder (but still possible) to hook your activities into the workflow. This, and the fact that the TFS Versioning and TFS NuGetter projects seem pretty much dead (no checkins or decent responses in over a year), kept me using the same workflows for TFS 2013. But that didn't really bother me. I wasn't to happy about it, but all the builds kept working and most people never noticed. 

But a while ago, we wanted to use Git for some of the projects. The default build workflow for projects using Git is slightly different from those that use TFVC. I had to include the customizations to the Git version of the worklow as well. Ouch. There is no TFS 2012 version of the Git workflow, and using custom activities meant for TFS 2012 in a TFS 2013 style workflow is a pain.

Then I realized I completely forgot about the PowerShell extensibility of the TFS 2013 workflows. I quickly put together some scripts, using information from [MSDN](http://msdn.microsoft.com/en-us/library/dn376353.aspx) and a few blogposts. Now I have most customizations implemented in PowerShell.
