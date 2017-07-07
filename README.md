# PlanetCatalog ENVI Extension

This code is meant to be used to search and explored Planet Labs' catalog of PlanetScope 4 band datasets. The data is uncalibrated and in it's raw state when downloaded with only an ENVI header file being added that contains the band information associated with the data. 

**Note that this extension needs a PLanet Labs' API key to access the data. The key that you have may not work in all regions of the world or for the data products that are downloaded by the extension. Make sure to check with Planet Labs' for any issues that you may be having due to API keys.**

## Requirements

ENVI 5.3 and IDL 8.5 or newer

API key to access Planet Labs' data


## Installation

There are two different installation options depending on the software that you have.



### ENVI + IDL

If you have ENVI + IDL, then you can either:

1. Place the IDL code directly in ENVI's extension folder. This work's ONLY when you start ENVI + IDL at the same time so that ENVI can compile code on the fly.

2. Build an IDL SAVE file and place that in ENVI's extension folder. This works with or without IDL.

To build the save file you can see the section `Building the SAVE file (requires IDL)` below. The next section `Only ENVI` lists the locations where the SAVE file should be installed so that ENVI is aware of the extension.



### Only ENVI

Place the IDL SAVE file, **planetcatalog.sav**, in ENVI's extension folder which depends on the version of ENVI and the rights that you have as a user.

For ENVI 5.3 and admin rights the directory for Windows is `C:\Program Files\Exelis\ENVI54\extensions`

For ENVI 5.4 and admin rights the directory for Windows is `C:\Program Files\Harris\ENVI54\extensions`

If you do not have admin rights then you can find the local user directory in ENVI under:

**File -> Preferences -> Directories -> Extensions Directory**

Once you place the file in ENVI's extensions you **must restart ENVI** before you will see the new tool in ENVI's toolbox.



## Building the SAVE File (requires IDL)

To build an IDL SAVE file for a custom version of ENVI / IDL you need to issue the following commands in IDL:

1. Press the "Reset" button in the IDL Workbench

2. Open `planetcatalog.pro` in the IDL workbench and make sure it has keyboard focus in the editor.

3. Press the "Compile" button in the IDL workbench

4. Issue the following commands from IDL to save the pre-compiled code to disk:

    ```idl
    save, /ROUTINES, FILENAME = 'planetcatalog.sav'
    ```

    Optionally you can provide a fully-qualified filepath for the `FILENAME` keyword such as :

    ```idl
    save, /ROUTINES, FILENAME = 'C:\Users\yourUsername\Desktop\planetcatalog.sav'
    ```


## Licensing

(c) 2017 Exelis Visual Information Solutions, Inc., a subsidiary of Harris Corporation.

See LICENSE.txt for additional details and information.