<!-- Back to top anchor -->
<a name="readme-page-top"></a>



<!-- Project Shields -->
<span align="center">

  [![Contributors][contributors-shield]][contributors-url]
  [![Forks][forks-shield]][forks-url]
  [![Stargazers][stars-shield]][stars-url]
  [![Issues][issues-shield]][issues-url]
  [![MIT License][license-shield]][license-url]

</span>



<!-- Project Logo -->
<div align="center">
  <a href="../../">
    <img src="https://user-images.githubusercontent.com/24853106/235458980-7db2599e-b53c-4ee3-83d9-bb0098543189.png" alt="Logo" width="312" height="256">
  </a>
  
  ### ERA 3 - Delphi XE, 10 & 11
  <p align="center">
    <i>Code ported from old Delphi version to modern Delphi (Delphi XE, 10 & 11)<br/>
    Contains ERA and VFS projects as well as B2 library.<br/>
    <br/></i>
    Original commits containing code are from <a href="https://github.com/ethernidee">ethernidee</a> repositories:<br/>
    ERA: <a href="https://github.com/ethernidee/era/tree/4dd5ea55340c0dd014138ea2940ba598acfbc0bb"><strong>4dd5ea5</strong></a><br/>
    VFS: <a href="https://github.com/ethernidee/vfs/tree/5e4a7f0acf1bdfa9eadb3f63c7177e8f0ccbf2e0"><strong>5e4a7f0</strong></a><br/>
    B2:   <a href="https://github.com/ethernidee/b2/tree/001251eb5f45378c329b6a60a4a4d87c346f36a0"><strong>001251e</strong></a>
  </p>
</div>

<span align="center">

  [![Original][OriginalGH-bdg]][OriginalGH-url]
  [![Delphi][Delphi-bdg]][Delphi-url]
  [![Discord][Discord-bdg]][Discord-url]
  [![LinkedIn][linkedin-shield]][linkedin-url]

</span>

<!-- Table of Contents -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li><a href="#compiled-release">Compiled release</a></li>
    <li>
      <a href="#about-the-project">About The Project</a>
    </li>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#prerequisites">Prerequisites</a></li>
        <li><a href="#local-project-setup">Local project setup</a></li>
      </ul>
    </li>
    <li>
      <a href="#build-and-run-project">Build and run project</a>
      <ul>
        <li><a href="#output-directory-is-not-set">Output directory is not set</a></li>
        <li><a href="#output-directory-is-set">Output directory is set</a></li>
      </ul>
    </li>
    <li><a href="#project-structure">Project structure</a></li>
    <li>
      <a href="#code-differences">Code differences</a>
      <ul>
        <li><a href="#version-info">Version info</a></li>
      </ul>
    </li>
    <li><a href="#roadmap">Roadmap</a></li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#acknowledgments">Acknowledgments</a></li>
  </ol>
</details>

---

<!-- About the Project -->
## About The Project
<p align="justify">
  Project code has been ported from the old Delphi 7 version to the newest Delphi version. Minimal changes to 
  code are introduced. Main purpose of this project is to continue its legacy and provide updated functionalities. 
  Original goals and functionalities have been preserved. The porting process has been carefully executed to 
  ensure that the project retains its original essence while leveraging the latest features of the new Delphi version. 
  Original code has beed developed by <a href="https://github.com/ethernidee">ethernidee</a>.
</p>

Project goals:
* Compile code on modern Delphi versions,
* Retain ASCII string compatability,
* Minimal changes to code,
* Code lines numbers in align with original code lines for easier compare,
* No additional features or improvements are added,
* Project will be active until this code become base for future ERA releases.

<div align="right">

[![GoUp][GoToTop-bdg]][GoToTop-url]

</div>



<!-- Getting started -->
## Getting Started
<br/>

<!-- Compiled release -->
### Compiled release

If you prefer using compiled releases, please follow the steps outlined below:

1. Download the latest [Release.zip](../../releases) file,
2. Before proceeding make sure to backup (Era.dll, Vfs.dll, Era.dbgmap and Vfs.dbgmap) files in your game folder,
3. Unzip the Release.zip file to game folder and override files,
4. Start game.
<p align="justify">
  Please note that it is always recommended to create a backup of your game files before making any 
  changes to the game folder. This ensures that in case anything goes wrong during the installation 
  process, you can easily revert back to the previous version without any data loss or damage to your game.
</p>

<div align="right">

[![GoUp][GoToTop-bdg]][GoToTop-url]

</div>



### Prerequisites

<p align="justify">
  The latest version of Delphi can be obtained from the official website. It is recommended to download and install it 
  for optimal performance. If you meet the eligibility criteria, you may choose to use the 
  <a href="https://www.embarcadero.com/products/delphi/starter/free-download">Delphi Community Edition</a>.
  This will allow you to access the features and tools necessary to build this project.<br/>
</p>

<p align="justify">
  In order to run the project, it is necessary to have Heroes 3 installed on your system. If you do not have it installed already, 
  you can obtain it through the <a href="https://github.com/daemon1995/h3l">Hero 3 Launcher</a>. 
  The launcher provides further information about the installation process and any necessary updates. 
  Once the game is installed, you will be able to test and run your project as desired. Don't forget to keep your Hero 3 Launcher updated.
  More information about Hero 3 Launcher can be found on <a href="https://discord.com/channels/665742159307341827/832999696858480670/833026509421412423">Discord chaneel</a>.
</p>


### Local project setup

<p align="justify">
  Clone repository to local machine using Git. If you do not plan to use versioning, code can be unpacked from zip file 
  to local project folder. If you plan to use debugger set project output folder to Heroes 3 installation root folder. 
  Follow next steps to setup project:
</p>

1. Obtain local copy of repository from GitHub

    1.1. If you will not use version control then download <a href="../../archive/refs/heads/develop.zip">zip file</a> from GitHub and unpack it to local folder

    1.2. If you will use version control then clone the repository to local folder

        git clone https://github.com/VuceticBranislav/era-modern.git
2. Open project group file in Delphi

        ProjectGroup.groupproj
3. Set host application in Era and Vfs projects

        Era.dll project > Options... > Debugger > Host application
        Vfs.dll project > Options... > Debugger > Host application
4. (Optional) Set output folder for compiled dlls to root of Heroes 3 installation directory

        Era.dll project > Options... > Building > Delphi compiler > Target > All configurations - All platforms > Output directory
        Era.dll project > Options... > Building > Delphi compiler > Target > Release configurations - All platforms > Output directory
        Era.dll project > Options... > Building > Delphi compiler > Target > Debug configurations - All platforms > Output directory
        Vfs.dll project > Options... > Building > Delphi compiler > Target > All configurations - All platforms > Output directory
        Vfs.dll project > Options... > Building > Delphi compiler > Target > Release configurations - All platforms > Output directory
        Vfs.dll project > Options... > Building > Delphi compiler > Target > Debug configurations - All platforms > Output directory

<div align="right">

[![GoUp][GoToTop-bdg]][GoToTop-url]

</div>



## Build and run project

<p align="justify">
  Whether or not the optional setup step is taken depends how project should be run. If the project's DLL 
  files are created in a local folder, then they must be manually copied to the game root folder. 
  It is always good idea to backup old files. File can be backed up by moving to another location or 
  renaming (e.g. Era.dll.off or Vfs.dll.off).
</p>


### Output directory is not set

<p align="justify">
  Dll files must be manually copied to game directory. In order to do that replace original dll files with 
  newly built files. You will not be able to use debugger if you pick this option. 
  Follow next steps run game with new dll files:
</p>

1. Build Era project, (Debug build configuration),
2. Build Vfs project, (Debug build configuration),
3. Backup old Era.dll and Vfs.dll from Heroes 3 installation folder,
4. Copy new Era.dll and Vfs.dll to Heroes 3 installation folder,
5. Run Heroes 3 executable.


### Output directory is set

<p align="justify">
  Compiled files will be automatically moved to game folder. If you need backup old dlls do it before project build. 
  Follow next steps:
</p>

1. Backup old Era.dll and Vfs.dll from Heroes 3 installation folder,
2. Build Era project, (Debug build configuration),
3. Build Vfs project, (Debug build configuration),
4. Run with debug from Delphi,

<div align="right">

[![GoUp][GoToTop-bdg]][GoToTop-url]

</div>



<!-- Project structure -->
## Project structure

Project structure show important content location and default location of compiled dll files if output directory is not set.
<pre>
  .
  ├─ Era
  │  ├─ Debug
  │  │  ├─ Dcu
  │  │  └─ ...     # Debug version Era.dll and other debug files
  │  ├─ Lua
  │  ├─ Releas
  │  │  ├─ Dcu
  │  │  └─ ...     # Release version Era.dll file
  │  └─ ...        # Source and versioning files
  │
  ├─ Lib
  │
  ├─ Vfs
  │  ├─ Debug
  │  │  ├─ Dcu
  │  │  └─ ...     # Debug version Vfs.dll and other debug files
  │  ├─ Releas
  │  │  ├─ Dcu
  │  │  └─ ...     # Release version Vfs.dll file
  │  ├─ Tests
  │  └─ ...        # Source and versioning files
  │
  └─ ...           # Clean.bat
</pre>

<div align="right">

[![GoUp][GoToTop-bdg]][GoToTop-url]

</div>



<!-- Code differences -->
## Code differences

In regards to the original code, there have been a few changes implemented:
* "Legacy.pas" has been added. It contains all the necessary code to ensure that the port works seamlessly,
* Introduced proxy type for string and char types to allows for more efficient and streamlined handling of these types,
* Automatic application versioning information is embended. Version number should be changed in "VersionInfo.inc",
* "Clean.bat" added to remove all unnecessary files from project folder.


### Version info

<p align="justify">
  Versioning info are automatically embended to compiled files trough post build custom script. Post build script 
  execut VersionInfo.bat that create VersionInfo.rc and VersionInfo.res files. During building process VersionInfo.res 
  file is used to bind versioning info. To change versioning info of compiled files and ERA_VERSION_STR and ERA_VERSION_INT
  project variable update VersionInfo.inc file.
</p>

<div align="right">

[![GoUp][GoToTop-bdg]][GoToTop-url]

</div>



<!-- Roadmap -->
## Roadmap
<p align="justify">
  The following is a summary of the project's current roadmap, outlining the key features and 
  improvements that are currently in progress or planned for the near future:
</p>

- [x] Use modern Delphi versions to compile Era code,
- [x] Use modern Delphi versions to compile Vfs code,
- [ ] Evaluate the behavior of the newly compiled code in comparison to the original code,

<div align="right">

[![GoUp][GoToTop-bdg]][GoToTop-url]

</div>



<!-- Contributing -->
## Contributing

Any contributions you make are greatly appreciated. If you have a suggestion, please fork the repo and create a pull request. You can also simply open an issue.<br/>
<br/>
To contribute using fork follow next steps:
1. Fork the Project,
2. Create your Feature Branch (`git checkout -b feature/MyFeature`),
3. Commit your Changes (`git commit -m 'Add my feature'`),
4. Push to the Branch (`git push origin feature/MyFeature`),
5. Open a Pull Request.

<div align="right">

[![GoUp][GoToTop-bdg]][GoToTop-url]

</div>



<!-- License -->
## License

See `LICENSE.txt` for more information.

<div align="right">

[![GoUp][GoToTop-bdg]][GoToTop-url]

</div>



<!-- Acknowledgments -->
## Acknowledgments

Aditional helpful resources

* [Creating a pull request from a fork](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/creating-a-pull-request-from-a-fork)
* [Heroes of Might & Magic 3 MODDING GUIDE! How to install Horn of The Abyss & The Wake of Gods](https://www.youtube.com/watch?v=peVlMctCGj0)

<div align="right">

[![GoUp][GoToTop-bdg]][GoToTop-url]

</div>


<!-- =============================================================================================================== -->

<!-- Acknowledgments 
Open Source License          https://choosealicense.com
GitHub Emoji Cheat Sheet     https://www.webpagefx.com/tools/emoji-cheat-sheet
Malven's Flexbox Cheatsheet  https://flexbox.malven.co/
Malven's Grid Cheatsheet     https://grid.malven.co/
Img Shields                  https://shields.io
GitHub Pages                 https://pages.github.com
Font Awesome                 https://fontawesome.com
React Icons                  https://react-icons.github.io/react-icons/search
Markdownguide                https://www.markdownguide.org/basic-syntax/#reference-style-links -->

<!-- MARKDOWN LINKS & IMAGES -->
[contributors-shield]: https://img.shields.io/github/contributors/VuceticBranislav/era-modern.svg?style=flat
[contributors-url]:    ../../graphs/contributors
[forks-shield]:        https://img.shields.io/github/forks/VuceticBranislav/era-modern.svg?style=flat
[forks-url]:           ../../network/members
[stars-shield]:        https://img.shields.io/github/stars/VuceticBranislav/era-modern.svg?style=flat
[stars-url]:           ../../stargazers
[issues-shield]:       https://img.shields.io/github/issues/VuceticBranislav/era-modern.svg?style=flat
[issues-url]:          ../../issues
[license-shield]:      https://img.shields.io/github/license/VuceticBranislav/era-modern.svg?style=flat
[license-url]:         ../../blob/master/LICENSE.txt
[linkedin-shield]:     https://img.shields.io/badge/-LinkedIn-black.svg?style=flat&logo=linkedin&colorB=555
[linkedin-url]:        https://www.linkedin.com/in/vuceticbranislav/
[OriginalGH-bdg]:      https://img.shields.io/badge/Original-181717?style=flat&logo=github&logoColor=white&colorB=555
[OriginalGH-url]:      https://github.com/ethernidee
[Delphi-bdg]:          https://img.shields.io/badge/Delphi_RAD_Studio-B22222?style=flat&logo=delphi&logoColor=white
[Delphi-url]:          https://www.embarcadero.com/
[Discord-bdg]:         https://img.shields.io/badge/Discord-7289DA?style=flat&logo=discord&logoColor=white
[Discord-url]:         https://discord.com/channels/665742159307341827/1105827060812873748
[GoToTop-bdg]:         https://img.shields.io/badge/Go%20to%20top-blue
[GoToTop-url]:         #readme-page-top