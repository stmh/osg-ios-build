osg-ios-build
=============

A build-script and some 3rdparty-libs for easier compiling of OpenSceneGraph for IOS.
The script creates 2 cmake configurations, one for device, one for the simulator. Then it 
compiles both configurations and after successful compilation it creates universal libs 
out of the build-products.

At the end you'll find in the subfolder products a set of headers + libs.


Installation
------------

Copy this folder into <osg-source-folder>/PlatformSpecifics/iOS, or add this repository as a 
submodule to your git-repository

The folder-contents of PlatformSpecifics should be

* Android
* iOS
* Windows

Running the script
------------------


	cd <osg-source-dir>/PlatformSpecifics/iOS
	sh build_universal_libs.sh
	
that's it. The script has some command-line-arguments:

* -i : ignore cmake-step, just compile the source
* -o <folder>: use given folder  as target for includes and libs
* -t <semicolon-separated;list;of;targets> list of targets to build, separated by semicolon
* -c clean all targets


have fun. Pull requests welcome.