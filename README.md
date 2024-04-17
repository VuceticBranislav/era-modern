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
  
  ### ERA 3 - New era of mod making - Delphi XE, 10, 11 & 12
  <p align="center">
    <i>Code ported from Delphi 7 version to modern Delphi (Delphi XE, 10, 11 & 12)<br/>
    Contains ERA and VFS projects as well as B2 library.<br/>
    <br/></i>
    Original commits containing code are from <a href="https://github.com/ethernidee">ethernidee</a> repositories:<br/>
    ERA: <a href="https://github.com/ethernidee/era/tree/0d64ad2cd6f7bbbc23eded39d22184969c1ad506"><strong>0d64ad2</strong></a><br/>
    VFS: <a href="https://github.com/ethernidee/vfs/tree/f18d56dcb7ddee787c01680b98f078fe409359e9"><strong>f18d56d</strong></a><br/>
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
  Project code has been ported from Delphi 7 version to the newest Delphi version. Minimal changes to 
  code are introduced. Main purpose of this project is to continue its legacy and provide updated functionalities. 
  Original goals and functionalities have been preserved. The porting process has been carefully executed to 
  ensure that the project retains its original essence while leveraging the latest features of the new Delphi version. 
  Original code has beed developed by <a href="https://github.com/ethernidee">ethernidee</a>.
</p>

Project goals:
* Compile code using modern version of Delphi.
* Maintain compatibility with ASCII strings.
* Make minimal changes to the code.
* Ensure that code line numbers align with the original code lines for easier comparison.
* Avoid adding any additional features or improvements.
* Keep the project active until this code becomes the foundation for future ERA releases.

<div align="right">

[![GoUp][GoToTop-bdg]][GoToTop-url]

</div>



<!-- Getting started -->
## Getting Started
<br/>

<!-- Compiled release -->
### Compiled release

If you prefering to use compiled releases, please follow the steps outlined below:

1. Download the latest self extracting [Release package](../../releases),
2. Before proceeding make sure to backup (Era.dll, Vfs.dll, Era.dbgmap and Vfs.dbgmap) files in your game folder,
3. Unpack the [Release package](../../releases) to game folder and override existing files,
4. Play game.
<p align="justify">
  Please note that it is always recommended to create a backup of files before making any changes on them. 
  This ensures that you can easily revert back to the previous version without any data loss or 
  damage to your game in case of problems during installation process.
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

    1.1. If you will not use version control then download <a href="../../archive/refs/heads/main.zip">zip file</a> from GitHub and unpack it to local folder

    1.2. If you will use version control then clone the repository to local folder

        git clone https://github.com/VuceticBranislav/era-modern.git
2. Open project group file in Delphi

        ProjectGroup.groupproj
3. Set host application in Era and Vfs projects to Heroes 3 executable

        Era.dll project > Options... > Debugger > Target > All configurations - Windows 32-bit platform > Host application
        Vfs.dll project > Options... > Debugger > Target > All configurations - Windows 32-bit platform > Host application
4. (Optional) Set output folder for compiled dlls to root of Heroes 3 installation directory

        Era.dll project > Options... > Building > Delphi compiler > Target > All configurations - All platforms > Output directory
        Vfs.dll project > Options... > Building > Delphi compiler > Target > All configurations - All platforms > Output directory

<div align="right">

[![GoUp][GoToTop-bdg]][GoToTop-url]

</div>



## Build and run project

<p align="justify">
  If optional setup step in not taken, the project's files are created in a local folder, then files must be manually 
  copied to the game root folder. It is always good idea to backup old files. File can be backed up by moving to another 
  location or renaming (e.g. Era.dll.off or Era.dbgmap.off ...).
</p>
<p align="justify">
  BuildTools is set of tools used to build Era or Vfs project. BuildTools is used to generate version information 
  resource files in pre-build process. It is also used to generate .dbgmap files in post-build process.
  That is reason why it must be build first, then Era and Vfs projects can be build.
</p>

### Output directory is not set

<p align="justify">
  Dll files must be manually copied to game directory. Also copy .dbgmap to game "DebugMaps" folder. 
  In order to do that replace original files with 
  newly built files. You will not be able to use debugger if you pick this option. 
  Follow next steps run game with new dll files:
</p>

1. (Optional) Backup old Era.dll and Vfs.dll from Heroes 3 installation folder,
2. (Optional) Backup old Era.dbgmap and Vfs.dbgmap from Heroes 3 "DebugMaps" folder,
3. Build All project, (Right click on ProjectGroup in project explorer and select "Build All"),
5. Copy new Era.dll and Vfs.dll from corresponding "Compiled" folders to Heroes 3 installation folder,
6. Copy new Era.dbgmap and Vfs.dbgmap from corresponding "Compiled" to Heroes 3 "DebugMaps" folder,
7. Run Heroes 3 executable.


### Output directory is set

<p align="justify">
  Compiled files will be automatically moved to game folder. If you need old dlls backup it before project build. 
  Debug maps will be automatically generated and moved to game "DebugMaps" folder.
  Follow next steps:
</p>

1. (Optional) Backup old Era.dll and Vfs.dll from Heroes 3 installation folder,
2. (Optional) Backup old Era.dbgmap and Vfs.dbgmap from Heroes 3 "DebugMaps" folder,
3. Build All project, (Right click on ProjectGroup in project explorer and select "Build All"),
4. Select Era.dll as active project by double click on it,
5. Run Era project in debug mode from Delphi,

<div align="right">

[![GoUp][GoToTop-bdg]][GoToTop-url]

</div>



<!-- Project structure -->
## Project structure

Project structure show important content location and default location of compiled dll files if output directory is not set.
<pre>
  .
  │
  ├─ BuildTools          # Tools needed to generate .dbgmap files and update dll version info
  │  ├─ Compiled
  │  │  ├─ Debug
  │  │  ├─ Release
  │  │  └─ ...           # Comiled BuildTools.exe used in build process
  │  └─ ...
  │
  ├─ Era                 # Era project
  │  ├─ Compiled
  │  │  ├─ Debug
  │  │  │  ├─ DebugMaps  # Debug version Era.dbgmap
  │  │  │  └─ ...        # Debug version Era.dll and other debug files
  │  │  └─ Release
  │  │     ├─ DebugMaps  # Release version Era.dbgmap
  │  │     └─ ...        # Release version Era.dll and Era.dbgmap file
  │  ├─ Lua
  │  └─ ...              # Source code and versioning files
  │
  ├─ Lib                 # Additional libraries needed for projects
  │  └─ ...
  │
  ├─ Vfs                 # Virtual file system project
  │  ├─ Compiled
  │  │  ├─ Debug
  │  │  │  ├─ DebugMaps  # Debug version Vfs.dbgmap
  │  │  │  └─ ...        # Debug version Vfs.dll and other debug files
  │  │  └─ Release
  │  │     ├─ DebugMaps  # Release version Vfs.dbgmap
  │  │     └─ ...        # Release version Vfs.dll file
  │  ├─ Tests
  │  └─ ...              # Source code and versioning files
  │
  └─ ...                 # Clean.bat
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
  Versioning info are automatically embended to compiled files trough post build actions. Post build action 
  execut BuildTools.exe that create VersionInfo.rc files and compiles it to VersionInfo.res files using Bcc32.exe.
  During building process VersionInfo.res file is used to bind versioning info. To change versioning info of compiled
  files and ERA_VERSION_STR and ERA_VERSION_INT project variable update VersionInfo.inc file.
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
[OriginalGH-bdg]:      https://img.shields.io/badge/Original_Code-181717?style=flat&logo=github&logoColor=white&colorB=555
[OriginalGH-url]:      https://github.com/ethernidee
[Delphi-bdg]:          https://img.shields.io/badge/Delphi_RAD_Studio-B22222?style=flat&logo=delphi&logoColor=white
[Delphi-url]:          https://www.embarcadero.com/
[Discord-bdg]:         https://img.shields.io/badge/Discord-7289DA?style=flat&logo=discord&logoColor=white
[Discord-url]:         https://discord.com/channels/665742159307341827/1105827060812873748
[GoToTop-bdg]:         https://img.shields.io/badge/Go%20to%20top-blue
[GoToTop-url]:         #readme-page-top